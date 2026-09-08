import 'dart:io';
import 'dart:math';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../database/sticker_pack.dart' as isar_db;
import 'pack_models.dart';
import 'pack_repository.dart';
import 'tray_icon_service.dart';

/// Isar-backed repository for sticker packs.
///
/// [save] is the WhatsApp validation gate. Incremental [addSticker] and
/// [removeSticker] persist immediately so Library can watch the collection.
class StickerRepository implements PackRepository {
  StickerRepository(
    this.isar, {
    required this.documentsPath,
    TrayIconService? trayIcons,
  }) : _trayIcons = trayIcons ?? TrayIconService();

  final Isar isar;
  final String documentsPath;
  final TrayIconService _trayIcons;

  static Future<StickerRepository> open({
    String? directory,
    String name = 'stikk_packs',
    Future<Directory> Function()? documents,
    TrayIconService? trayIcons,
  }) async {
    final docs = await (documents ?? getApplicationDocumentsDirectory)();
    final path = directory ?? docs.path;
    final isar = await Isar.open(
      [isar_db.StickerPackSchema],
      directory: path,
      name: name,
      inspector: false,
    );
    return StickerRepository(
      isar,
      documentsPath: docs.path,
      trayIcons: trayIcons,
    );
  }

  Future<void> close({bool deleteFromDisk = false}) {
    return isar.close(deleteFromDisk: deleteFromDisk);
  }

  @override
  Stream<List<StickerPack>> watchAll() {
    return isar.stickerPacks.where().watch(fireImmediately: true).map(_mapRows);
  }

  @override
  Future<List<StickerPack>> getAll() async {
    final rows = await isar.stickerPacks.where().findAll();
    return _mapRows(rows);
  }

  @override
  Future<StickerPack?> getById(String id) async {
    final row = await isar.stickerPacks.getByIdentifier(id);
    if (row == null) return null;
    return _toDomain(row);
  }

  @override
  Future<StickerPack> createPack({
    required String name,
    required String author,
  }) async {
    final trimmedName = _requireName(name);
    final publisher = _requirePublisher(author);
    final identifier = _uuidV4();
    final packDir = _packDir(identifier);
    final trayBytes = await _trayIcons.createDefaultBytes(name: trimmedName);
    final trayFile = File('${packDir.path}${Platform.pathSeparator}tray.png');
    await trayFile.writeAsBytes(trayBytes);

    final row = isar_db.StickerPack()
      ..identifier = identifier
      ..name = trimmedName
      ..publisher = publisher
      ..trayIconBytes = List<int>.from(trayBytes)
      ..stickerPaths = const [];

    await isar.writeTxn(() async {
      await isar.stickerPacks.put(row);
    });
    return _toDomain(row);
  }

  @override
  Future<StickerPack> updatePack(StickerPack pack) async {
    _requireName(pack.name);
    _requirePublisher(pack.author);
    final row = await _requireRow(pack.id);
    row
      ..name = pack.name.trim()
      ..publisher = pack.author.trim();
    if (pack.trayIconBytes.isNotEmpty) {
      row.trayIconBytes = List<int>.from(pack.trayIconBytes);
      await _writeTrayFile(pack.id, row.trayIconBytes);
    }
    await isar.writeTxn(() async {
      await isar.stickerPacks.put(row);
    });
    return _toDomain(row);
  }

  @override
  Future<StickerPack> addSticker({
    required String packId,
    required String sourcePath,
    bool animated = true,
  }) async {
    final row = await _requireRow(packId);
    final current = _toDomain(row);
    if (current.isFull) {
      throw const PackException(
        'WhatsApp packs can hold at most ${WhatsAppPackRules.maxStickers} stickers.',
      );
    }
    if (!current.acceptsSticker(animated: animated)) {
      throw PackException(
        animated
            ? 'This pack is for static stickers. Create a new pack for animated ones.'
            : 'This pack is for animated stickers. Create a new pack for photo stickers.',
      );
    }

    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw const PackException('The sticker file is missing.');
    }

    final packDir = _packDir(packId);
    final fileName = 'sticker_${DateTime.now().microsecondsSinceEpoch}.webp';
    final dest = File('${packDir.path}${Platform.pathSeparator}$fileName');
    await source.copy(dest.path);

    row.stickerPaths = [...row.stickerPaths, dest.path];
    await isar.writeTxn(() async {
      await isar.stickerPacks.put(row);
    });
    return _toDomain(row);
  }

  @override
  Future<StickerPack> removeSticker({
    required String packId,
    required String stickerId,
  }) async {
    final row = await _requireRow(packId);
    final remaining = <String>[];
    String? removedPath;
    for (final path in row.stickerPaths) {
      if (removedPath == null &&
          (path == stickerId || _pathId(path) == stickerId)) {
        removedPath = path;
      } else {
        remaining.add(path);
      }
    }
    if (removedPath != null) {
      final file = File(removedPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    row.stickerPaths = remaining;
    await isar.writeTxn(() async {
      await isar.stickerPacks.put(row);
    });
    return _toDomain(row);
  }

  @override
  Future<void> deletePack(String id) async {
    await isar.writeTxn(() async {
      await isar.stickerPacks.deleteByIdentifier(id);
    });
    final dir = Directory(_packDirPath(id));
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  @override
  Future<StickerPack> save(StickerPack pack) async {
    final count = pack.stickers.length;
    if (count < WhatsAppPackRules.minStickers ||
        count > WhatsAppPackRules.maxStickers) {
      throw const ValidationException(
        'WhatsApp packs must contain between ${WhatsAppPackRules.minStickers} and ${WhatsAppPackRules.maxStickers} stickers.',
      );
    }
    _requireName(pack.name);
    _requirePublisher(pack.author);

    var row = await isar.stickerPacks.getByIdentifier(pack.id);
    row ??= isar_db.StickerPack()..identifier = pack.id;
    row
      ..name = pack.name.trim()
      ..publisher = pack.author.trim()
      ..trayIconBytes = List<int>.from(pack.trayIconBytes)
      ..stickerPaths = [for (final sticker in pack.stickers) sticker.filePath];
    if (row.trayIconBytes.isEmpty && pack.trayIconPath.isNotEmpty) {
      final tray = File(pack.trayIconPath);
      if (tray.existsSync()) {
        row.trayIconBytes = tray.readAsBytesSync();
      }
    }
    if (row.trayIconBytes.isNotEmpty) {
      await _writeTrayFile(pack.id, row.trayIconBytes);
    }
    await isar.writeTxn(() async {
      await isar.stickerPacks.put(row!);
    });
    return _toDomain(row);
  }

  Future<isar_db.StickerPack> _requireRow(String identifier) async {
    final row = await isar.stickerPacks.getByIdentifier(identifier);
    if (row == null) {
      throw const PackException('That pack no longer exists.');
    }
    return row;
  }

  List<StickerPack> _mapRows(List<isar_db.StickerPack> rows) {
    final sorted = [...rows]..sort((a, b) => b.id.compareTo(a.id));
    return [for (final row in sorted) _toDomain(row)];
  }

  StickerPack _toDomain(isar_db.StickerPack row) {
    final paths = row.stickerPaths;
    return StickerPack(
      id: row.identifier,
      name: row.name,
      author: row.publisher,
      trayIconPath: _trayFilePath(row.identifier),
      trayIconBytes: List<int>.from(row.trayIconBytes),
      stickers: [
        for (final path in paths)
          StickerItem(
            id: _pathId(path),
            filePath: path,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            animated: _webpLooksAnimated(path),
          ),
      ],
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.id),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.id),
    );
  }

  Directory _packDir(String identifier) {
    final dir = Directory(_packDirPath(identifier));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  String _packDirPath(String identifier) {
    return '$documentsPath${Platform.pathSeparator}packs${Platform.pathSeparator}$identifier';
  }

  String _trayFilePath(String identifier) {
    return '${_packDirPath(identifier)}${Platform.pathSeparator}tray.png';
  }

  Future<void> _writeTrayFile(String identifier, List<int> bytes) async {
    final file = File(_trayFilePath(identifier));
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    await file.writeAsBytes(bytes);
  }

  String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const PackException('Give this pack a name.');
    }
    if (trimmed.length > WhatsAppPackRules.maxNameLength) {
      throw const PackException('Pack names can be at most 128 characters.');
    }
    return trimmed;
  }

  String _requirePublisher(String publisher) {
    final trimmed = publisher.trim();
    if (trimmed.isEmpty) {
      throw const PackException('Add an author name.');
    }
    if (trimmed.length > WhatsAppPackRules.maxAuthorLength) {
      throw const PackException('Author names can be at most 128 characters.');
    }
    return trimmed;
  }

  static String _pathId(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    return name.replaceAll('.webp', '');
  }

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int index) => bytes[index].toRadixString(16).padLeft(2, '0');
    return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
        '${hex(4)}${hex(5)}-'
        '${hex(6)}${hex(7)}-'
        '${hex(8)}${hex(9)}-'
        '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
  }

  static bool _webpLooksAnimated(String path) {
    try {
      final bytes = File(path).readAsBytesSync();
      if (bytes.length < 21) return false;
      final fourcc = String.fromCharCodes(bytes.sublist(12, 16));
      if (fourcc != 'VP8X') return false;
      return (bytes[20] & 0x02) != 0;
    } catch (_) {
      return false;
    }
  }
}
