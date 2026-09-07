import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'pack_models.dart';
import 'tray_icon_service.dart';

abstract class PackRepository {
  Future<List<StickerPack>> getAll();
  Future<StickerPack?> getById(String id);
  Future<StickerPack> createPack({
    required String name,
    required String author,
  });
  Future<StickerPack> updatePack(StickerPack pack);
  Future<StickerPack> addSticker({
    required String packId,
    required String sourcePath,
  });
  Future<StickerPack> removeSticker({
    required String packId,
    required String stickerId,
  });
  Future<void> deletePack(String id);
}

class HivePackRepository implements PackRepository {
  HivePackRepository({
    required this.box,
    required this.documents,
    TrayIconService? trayIcons,
  }) : trayIcons = trayIcons ?? TrayIconService();

  static const boxName = 'sticker_packs';

  final Box<dynamic> box;
  final Future<Directory> Function() documents;
  final TrayIconService trayIcons;

  static Future<HivePackRepository> open({
    String? hivePath,
    Future<Directory> Function()? documents,
  }) async {
    if (hivePath != null) {
      Hive.init(hivePath);
    } else {
      await Hive.initFlutter();
    }
    final box = await Hive.openBox<dynamic>(boxName);
    return HivePackRepository(
      box: box,
      documents: documents ?? getApplicationDocumentsDirectory,
    );
  }

  @override
  Future<List<StickerPack>> getAll() async {
    final packs = box.values.map(_decode).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return packs;
  }

  @override
  Future<StickerPack?> getById(String id) async {
    final raw = box.get(id);
    if (raw == null) return null;
    return _decode(raw);
  }

  @override
  Future<StickerPack> createPack({
    required String name,
    required String author,
  }) async {
    final trimmedName = _requireName(name);
    final trimmedAuthor = _requireAuthor(author);
    final id = 'pack_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    final packDir = await _packDir(id);
    final tray = await trayIcons.createDefault(
      directory: packDir,
      packId: id,
      name: trimmedName,
    );

    final pack = StickerPack(
      id: id,
      name: trimmedName,
      author: trimmedAuthor,
      trayIconPath: tray.path,
      stickers: const [],
      createdAt: now,
      updatedAt: now,
    );
    await box.put(id, pack.toMap());
    return pack;
  }

  @override
  Future<StickerPack> updatePack(StickerPack pack) async {
    _requireName(pack.name);
    _requireAuthor(pack.author);
    final next = pack.copyWith(updatedAt: DateTime.now());
    await box.put(next.id, next.toMap());
    return next;
  }

  @override
  Future<StickerPack> addSticker({
    required String packId,
    required String sourcePath,
  }) async {
    final pack = await getById(packId);
    if (pack == null) {
      throw const PackException('That pack no longer exists.');
    }
    if (pack.isFull) {
      throw const PackException(
        'WhatsApp packs can hold at most ${WhatsAppPackRules.maxStickers} stickers.',
      );
    }

    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw const PackException('The sticker file is missing.');
    }

    final stickerId = 'sticker_${DateTime.now().microsecondsSinceEpoch}';
    final packDir = await _packDir(packId);
    final dest = File(
      '${packDir.path}${Platform.pathSeparator}$stickerId.webp',
    );
    await source.copy(dest.path);

    final next = pack.copyWith(
      stickers: [
        ...pack.stickers,
        StickerItem(
          id: stickerId,
          filePath: dest.path,
          createdAt: DateTime.now(),
        ),
      ],
      updatedAt: DateTime.now(),
    );
    await box.put(packId, next.toMap());
    return next;
  }

  @override
  Future<StickerPack> removeSticker({
    required String packId,
    required String stickerId,
  }) async {
    final pack = await getById(packId);
    if (pack == null) {
      throw const PackException('That pack no longer exists.');
    }
    StickerItem? removed;
    final remaining = <StickerItem>[];
    for (final sticker in pack.stickers) {
      if (sticker.id == stickerId) {
        removed = sticker;
      } else {
        remaining.add(sticker);
      }
    }
    if (removed != null) {
      final file = File(removed.filePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    final next = pack.copyWith(stickers: remaining, updatedAt: DateTime.now());
    await box.put(packId, next.toMap());
    return next;
  }

  @override
  Future<void> deletePack(String id) async {
    final pack = await getById(id);
    await box.delete(id);
    if (pack == null) return;
    final dir = Directory(
      '${(await documents()).path}${Platform.pathSeparator}packs${Platform.pathSeparator}$id',
    );
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  Future<Directory> _packDir(String packId) async {
    final root = await documents();
    final dir = Directory(
      '${root.path}${Platform.pathSeparator}packs${Platform.pathSeparator}$packId',
    );
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  StickerPack _decode(dynamic raw) {
    return StickerPack.fromMap(Map<dynamic, dynamic>.from(raw as Map));
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

  String _requireAuthor(String author) {
    final trimmed = author.trim();
    if (trimmed.isEmpty) {
      throw const PackException('Add an author name.');
    }
    if (trimmed.length > WhatsAppPackRules.maxAuthorLength) {
      throw const PackException('Author names can be at most 128 characters.');
    }
    return trimmed;
  }
}

class InMemoryPackRepository implements PackRepository {
  InMemoryPackRepository({Map<String, StickerPack>? seed}) : _packs = {...?seed};

  final Map<String, StickerPack> _packs;
  var _seq = 0;

  @override
  Future<List<StickerPack>> getAll() async {
    return _packs.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<StickerPack?> getById(String id) async => _packs[id];

  @override
  Future<StickerPack> createPack({
    required String name,
    required String author,
  }) async {
    if (name.trim().isEmpty) {
      throw const PackException('Give this pack a name.');
    }
    if (author.trim().isEmpty) {
      throw const PackException('Add an author name.');
    }
    _seq += 1;
    final now = DateTime.now();
    final pack = StickerPack(
      id: 'mem_$_seq',
      name: name.trim(),
      author: author.trim(),
      trayIconPath: 'tray_$_seq.png',
      stickers: const [],
      createdAt: now,
      updatedAt: now,
    );
    _packs[pack.id] = pack;
    return pack;
  }

  @override
  Future<StickerPack> updatePack(StickerPack pack) async {
    _packs[pack.id] = pack.copyWith(updatedAt: DateTime.now());
    return _packs[pack.id]!;
  }

  @override
  Future<StickerPack> addSticker({
    required String packId,
    required String sourcePath,
  }) async {
    final pack = _packs[packId];
    if (pack == null) {
      throw const PackException('That pack no longer exists.');
    }
    if (pack.isFull) {
      throw const PackException(
        'WhatsApp packs can hold at most ${WhatsAppPackRules.maxStickers} stickers.',
      );
    }
    _seq += 1;
    final next = pack.copyWith(
      stickers: [
        ...pack.stickers,
        StickerItem(
          id: 'sticker_$_seq',
          filePath: sourcePath,
          createdAt: DateTime.now(),
        ),
      ],
      updatedAt: DateTime.now(),
    );
    _packs[packId] = next;
    return next;
  }

  @override
  Future<StickerPack> removeSticker({
    required String packId,
    required String stickerId,
  }) async {
    final pack = _packs[packId];
    if (pack == null) {
      throw const PackException('That pack no longer exists.');
    }
    final next = pack.copyWith(
      stickers: [
        for (final sticker in pack.stickers)
          if (sticker.id != stickerId) sticker,
      ],
      updatedAt: DateTime.now(),
    );
    _packs[packId] = next;
    return next;
  }

  @override
  Future<void> deletePack(String id) async {
    _packs.remove(id);
  }
}
