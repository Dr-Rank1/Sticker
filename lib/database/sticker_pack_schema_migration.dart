import 'dart:io';

import 'package:isar/isar.dart';

import 'sticker_pack.dart';

class StickerPackSchemaMigration {
  const StickerPackSchemaMigration._();

  static Future<void> migrate(
    Isar isar, {
    required String documentsPath,
    DateTime Function() clock = DateTime.now,
  }) async {
    final rows = await isar.stickerPacks.where().findAll();
    final changed = <StickerPack>[];
    for (final row in rows) {
      if (migrateRow(
        row,
        documentsPath: documentsPath,
        nowMillis: clock().millisecondsSinceEpoch,
      )) {
        changed.add(row);
      }
    }
    if (changed.isEmpty) return;
    await isar.writeTxn(() => isar.stickerPacks.putAll(changed));
  }

  static bool migrateRow(
    StickerPack row, {
    required String documentsPath,
    required int nowMillis,
  }) {
    var changed = false;
    if (row.stickers.isEmpty && row.stickerPaths.isNotEmpty) {
      final usedIds = <String>{};
      row.stickers = [
        for (var index = 0; index < row.stickerPaths.length; index++)
          _recordFromLegacyPath(
            row.stickerPaths[index],
            index: index,
            usedIds: usedIds,
          ),
      ];
      changed = true;
    }

    final usedIds = <String>{};
    for (var index = 0; index < row.stickers.length; index++) {
      final sticker = row.stickers[index];
      if (sticker.id.isEmpty || usedIds.contains(sticker.id)) {
        sticker.id = _uniqueId(sticker.filePath, index, usedIds);
        changed = true;
      } else {
        usedIds.add(sticker.id);
      }
      if (sticker.createdAtMillis <= 0) {
        sticker.createdAtMillis = _fileTimestamp(sticker.filePath) ?? nowMillis;
        changed = true;
      }
    }

    final trayTimestamp = _fileTimestamp(
      '$documentsPath${Platform.pathSeparator}packs'
      '${Platform.pathSeparator}${row.identifier}'
      '${Platform.pathSeparator}tray.png',
    );
    final fileTimestamps = <int>[
      ?trayTimestamp,
      for (final sticker in row.stickers) ?_fileTimestamp(sticker.filePath),
    ];
    final inferredCreatedAt = fileTimestamps.isEmpty
        ? nowMillis
        : fileTimestamps.reduce((a, b) => a < b ? a : b);
    final inferredUpdatedAt = fileTimestamps.isEmpty
        ? inferredCreatedAt
        : fileTimestamps.reduce((a, b) => a > b ? a : b);

    if (row.createdAtMillis <= 0) {
      row.createdAtMillis = inferredCreatedAt;
      changed = true;
    }
    if (row.updatedAtMillis < row.createdAtMillis) {
      row.updatedAtMillis = inferredUpdatedAt < row.createdAtMillis
          ? row.createdAtMillis
          : inferredUpdatedAt;
      changed = true;
    }
    if (row.stickerPaths.isNotEmpty) {
      row.stickerPaths = [];
      changed = true;
    }
    return changed;
  }

  static StickerRecord _recordFromLegacyPath(
    String path, {
    required int index,
    required Set<String> usedIds,
  }) {
    return StickerRecord()
      ..id = _uniqueId(path, index, usedIds)
      ..filePath = path
      ..createdAtMillis = _fileTimestamp(path) ?? 0
      ..animated = _webpLooksAnimated(path)
      ..accessibilityText = '';
  }

  static String _uniqueId(String path, int index, Set<String> usedIds) {
    final fileName = path.replaceAll('\\', '/').split('/').last;
    final base = fileName.replaceFirst(
      RegExp(r'\.webp$', caseSensitive: false),
      '',
    );
    final candidate = base.isEmpty ? 'sticker_$index' : base;
    var unique = candidate;
    var suffix = 1;
    while (!usedIds.add(unique)) {
      unique = '${candidate}_${suffix++}';
    }
    return unique;
  }

  static int? _fileTimestamp(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      return file.lastModifiedSync().millisecondsSinceEpoch;
    } on FileSystemException {
      return null;
    }
  }

  static bool _webpLooksAnimated(String path) {
    try {
      final bytes = File(path).readAsBytesSync();
      if (bytes.length < 21) return false;
      if (String.fromCharCodes(bytes.sublist(12, 16)) != 'VP8X') return false;
      return (bytes[20] & 0x02) != 0;
    } on FileSystemException {
      return false;
    }
  }
}
