import 'dart:io';
import 'dart:math';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../database/sticker_pack.dart' as isar_db;
import '../database/sticker_pack_schema_migration.dart';
import '../l10n/l10n.dart';
import '../storage/storage_utility.dart';
import 'sticker_file_store.dart';
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
    required this.temporaryPath,
    TrayIconService? trayIcons,
    StickerFileStore? fileStore,
    DateTime Function()? clock,
  }) : _trayIcons = trayIcons ?? TrayIconService(),
       _fileStore = fileStore ?? StickerFileStore(temporaryPath: temporaryPath),
       _clock = clock ?? DateTime.now;

  final Isar isar;
  final String documentsPath;
  final String temporaryPath;
  final TrayIconService _trayIcons;
  final StickerFileStore _fileStore;
  final DateTime Function() _clock;

  static Future<StickerRepository> open({
    String? directory,
    String name = 'stickr_packs',
    Future<Directory> Function()? documents,
    Future<Directory> Function()? temporary,
    TrayIconService? trayIcons,
    DateTime Function()? clock,
  }) async {
    final docs = await (documents ?? getApplicationDocumentsDirectory)();
    final temp = await getStickrTemporaryDirectory(
      baseTemporaryDirectory: temporary,
    );
    final path = directory ?? docs.path;
    final isar = await Isar.open(
      [isar_db.StickerPackSchema],
      directory: path,
      name: name,
      inspector: false,
    );
    await StickerPackSchemaMigration.migrate(
      isar,
      documentsPath: docs.path,
      clock: clock ?? DateTime.now,
    );
    return StickerRepository(
      isar,
      documentsPath: docs.path,
      temporaryPath: temp.path,
      trayIcons: trayIcons,
      clock: clock,
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
    String? identifier,
  }) async {
    final trimmedName = _requireName(name);
    final publisher = _requirePublisher(author);
    final packIdentifier = identifier ?? _uuidV4();
    if (await isar.stickerPacks.getByIdentifier(packIdentifier) != null) {
      throw PackException(serviceLocalizations.packIdentifierExists);
    }
    final packDir = _packDir(packIdentifier);
    final trayBytes = await _trayIcons.createDefaultBytes(name: trimmedName);
    final trayFile = File('${packDir.path}${Platform.pathSeparator}tray.png');
    await trayFile.writeAsBytes(trayBytes);
    final nowMillis = _clock().millisecondsSinceEpoch;

    final row = isar_db.StickerPack()
      ..identifier = packIdentifier
      ..name = trimmedName
      ..publisher = publisher
      ..trayIconBytes = List<int>.from(trayBytes)
      ..createdAtMillis = nowMillis
      ..updatedAtMillis = nowMillis
      ..stickers = []
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
      ..publisher = pack.author.trim()
      ..updatedAtMillis = _nextRevision(row.updatedAtMillis);
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
    String accessibilityText = '',
  }) async {
    final row = await _requireRow(packId);
    final current = _toDomain(row);
    if (current.isFull) {
      throw PackException(
        serviceLocalizations.packMaximumStickers(WhatsAppPackRules.maxStickers),
      );
    }
    if (!current.acceptsSticker(animated: animated)) {
      throw PackException(
        animated
            ? serviceLocalizations.packStaticOnly
            : serviceLocalizations.packAnimatedOnly,
      );
    }

    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw PackException(serviceLocalizations.stickerFileMissing);
    }

    final packDir = _packDir(packId);
    final stickerId = _uuidV4();
    final fileName = 'sticker_$stickerId.webp';
    final dest = File('${packDir.path}${Platform.pathSeparator}$fileName');
    final createdAtMillis = _clock().millisecondsSinceEpoch;
    row
      ..stickers = [
        ...row.stickers,
        isar_db.StickerRecord()
          ..id = stickerId
          ..filePath = dest.path
          ..createdAtMillis = createdAtMillis
          ..animated = animated
          ..accessibilityText = accessibilityText.trim(),
      ]
      ..stickerPaths = []
      ..updatedAtMillis = _nextRevision(row.updatedAtMillis);
    StickerFilePlacement? placement;
    try {
      await isar.writeTxn(() async {
        placement = await _fileStore.place(source: source, destination: dest);
        await isar.stickerPacks.put(row);
      });
    } catch (_) {
      await placement?.rollback();
      rethrow;
    }
    return _toDomain(row);
  }

  @override
  Future<StickerPack> removeSticker({
    required String packId,
    required String stickerId,
  }) async {
    final row = await _requireRow(packId);
    final remaining = <isar_db.StickerRecord>[];
    String? removedPath;
    for (final sticker in row.stickers) {
      if (removedPath == null &&
          (sticker.filePath == stickerId ||
              sticker.id == stickerId ||
              _pathId(sticker.filePath) == stickerId)) {
        removedPath = sticker.filePath;
      } else {
        remaining.add(sticker);
      }
    }
    if (removedPath == null) return _toDomain(row);
    final file = File(removedPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    row
      ..stickers = remaining
      ..stickerPaths = []
      ..updatedAtMillis = _nextRevision(row.updatedAtMillis);
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
      throw ValidationException(
        serviceLocalizations.packStickerCountRange(
          WhatsAppPackRules.minStickers,
          WhatsAppPackRules.maxStickers,
        ),
      );
    }
    _requireName(pack.name);
    _requirePublisher(pack.author);

    final existing = await isar.stickerPacks.getByIdentifier(pack.id);
    final row = existing ?? (isar_db.StickerPack()..identifier = pack.id);
    final nowMillis = _clock().millisecondsSinceEpoch;
    if (existing == null) {
      final suppliedCreatedAt = pack.createdAt.millisecondsSinceEpoch;
      row.createdAtMillis = suppliedCreatedAt > 0
          ? suppliedCreatedAt
          : nowMillis;
      row.updatedAtMillis = row.createdAtMillis;
    }
    row
      ..name = pack.name.trim()
      ..publisher = pack.author.trim()
      ..trayIconBytes = List<int>.from(pack.trayIconBytes)
      ..stickers = [
        for (final sticker in pack.stickers)
          isar_db.StickerRecord()
            ..id = sticker.id
            ..filePath = sticker.filePath
            ..createdAtMillis = sticker.createdAt.millisecondsSinceEpoch
            ..animated = sticker.animated
            ..accessibilityText = sticker.accessibilityText,
      ]
      ..stickerPaths = []
      ..updatedAtMillis = _nextRevision(row.updatedAtMillis);
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
      await isar.stickerPacks.put(row);
    });
    return _toDomain(row);
  }

  Future<isar_db.StickerPack> _requireRow(String identifier) async {
    final row = await isar.stickerPacks.getByIdentifier(identifier);
    if (row == null) {
      throw PackException(serviceLocalizations.packNoLongerExists);
    }
    return row;
  }

  List<StickerPack> _mapRows(List<isar_db.StickerPack> rows) {
    final sorted = [...rows]
      ..sort((a, b) {
        final revision = b.updatedAtMillis.compareTo(a.updatedAtMillis);
        return revision != 0 ? revision : b.id.compareTo(a.id);
      });
    return [for (final row in sorted) _toDomain(row)];
  }

  StickerPack _toDomain(isar_db.StickerPack row) {
    return StickerPack(
      id: row.identifier,
      name: row.name,
      author: row.publisher,
      trayIconPath: _trayFilePath(row.identifier),
      trayIconBytes: List<int>.from(row.trayIconBytes),
      stickers: [
        for (final sticker in row.stickers)
          StickerItem(
            id: sticker.id,
            filePath: sticker.filePath,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              sticker.createdAtMillis,
            ),
            animated: sticker.animated,
            accessibilityText: sticker.accessibilityText,
          ),
      ],
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAtMillis),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAtMillis),
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
      throw PackException(serviceLocalizations.packNameRequired);
    }
    if (trimmed.length > WhatsAppPackRules.maxNameLength) {
      throw PackException(
        serviceLocalizations.packNameTooLong(WhatsAppPackRules.maxNameLength),
      );
    }
    return trimmed;
  }

  String _requirePublisher(String publisher) {
    final trimmed = publisher.trim();
    if (trimmed.isEmpty) {
      throw PackException(serviceLocalizations.packAuthorRequired);
    }
    if (trimmed.length > WhatsAppPackRules.maxAuthorLength) {
      throw PackException(
        serviceLocalizations.packAuthorTooLong(
          WhatsAppPackRules.maxAuthorLength,
        ),
      );
    }
    return trimmed;
  }

  static String _pathId(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    return name.replaceAll('.webp', '');
  }

  int _nextRevision(int current) {
    final now = _clock().millisecondsSinceEpoch;
    return now > current ? now : current + 1;
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
}
