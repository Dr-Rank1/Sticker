import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/database/sticker_pack.dart';
import 'package:stickr/database/sticker_pack_schema_migration.dart';

void main() {
  test('migrates path-only packs into embedded sticker records', () {
    final directory = Directory.systemTemp.createTempSync(
      'stickr_schema_migration',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final modifiedAt = DateTime.utc(2025, 6, 1);
    final animatedFile = File('${directory.path}/legacy.webp')
      ..writeAsBytesSync(_animatedWebpHeader())
      ..setLastModifiedSync(modifiedAt);
    final missingPath = '${directory.path}/missing.webp';
    final row = StickerPack()
      ..identifier = 'legacy-pack'
      ..name = 'Legacy'
      ..publisher = 'Stickr'
      ..stickerPaths = [animatedFile.path, missingPath];
    final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

    final changed = StickerPackSchemaMigration.migrateRow(
      row,
      documentsPath: directory.path,
      nowMillis: now,
    );

    expect(changed, isTrue);
    expect(row.stickerPaths, isEmpty);
    expect(row.stickers, hasLength(2));
    expect(row.stickers.first.id, 'legacy');
    expect(row.stickers.first.filePath, animatedFile.path);
    expect(
      row.stickers.first.createdAtMillis,
      modifiedAt.millisecondsSinceEpoch,
    );
    expect(row.stickers.first.animated, isTrue);
    expect(row.stickers.first.accessibilityText, isEmpty);
    expect(row.stickers.last.id, 'missing');
    expect(row.stickers.last.filePath, missingPath);
    expect(row.stickers.last.createdAtMillis, now);
    expect(row.createdAtMillis, modifiedAt.millisecondsSinceEpoch);
    expect(row.updatedAtMillis, modifiedAt.millisecondsSinceEpoch);
    expect(
      StickerPackSchemaMigration.migrateRow(
        row,
        documentsPath: directory.path,
        nowMillis: now,
      ),
      isFalse,
    );
  });

  test('preserves existing embedded metadata and explicit timestamps', () {
    final createdAt = DateTime.utc(2025, 1, 1).millisecondsSinceEpoch;
    final updatedAt = createdAt + 10;
    final row = StickerPack()
      ..identifier = 'current-pack'
      ..name = 'Current'
      ..publisher = 'Stickr'
      ..createdAtMillis = createdAt
      ..updatedAtMillis = updatedAt
      ..stickers = [
        StickerRecord()
          ..id = 'stable-id'
          ..filePath = '/missing/current.webp'
          ..createdAtMillis = createdAt
          ..animated = false
          ..accessibilityText = 'A waving hand',
      ];

    final changed = StickerPackSchemaMigration.migrateRow(
      row,
      documentsPath: '/missing',
      nowMillis: DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
    );

    expect(changed, isFalse);
    expect(row.createdAtMillis, createdAt);
    expect(row.updatedAtMillis, updatedAt);
    expect(row.stickers.single.id, 'stable-id');
    expect(row.stickers.single.accessibilityText, 'A waving hand');
  });
}

List<int> _animatedWebpHeader() {
  final bytes = List<int>.filled(21, 0);
  bytes.setRange(12, 16, 'VP8X'.codeUnits);
  bytes[20] = 0x02;
  return bytes;
}
