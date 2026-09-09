import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/storage/storage_utility.dart';

void main() {
  late Directory root;
  late Directory documents;
  late Directory temporary;
  late Directory ownedTemporary;
  late StorageUtility utility;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('stickr_storage_test_');
    documents = Directory('${root.path}${Platform.pathSeparator}documents')
      ..createSync();
    temporary = Directory('${root.path}${Platform.pathSeparator}temporary')
      ..createSync();
    utility = StorageUtility(
      documentsDirectory: () async => documents,
      temporaryDirectory: () async => temporary,
    );
    ownedTemporary = await utility.ownedTemporaryDirectory();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('measures document storage and only Stickr cache files', () async {
    final packs = Directory('${documents.path}${Platform.pathSeparator}packs')
      ..createSync();
    File('${packs.path}${Platform.pathSeparator}sticker.webp')
        .writeAsBytesSync(List.filled(2048, 1));
    File('${ownedTemporary.path}${Platform.pathSeparator}stickr_raw.mp4')
        .writeAsBytesSync(List.filled(1024, 1));
    File('${temporary.path}${Platform.pathSeparator}another_app.tmp')
        .writeAsBytesSync(List.filled(4096, 1));

    final usage = await utility.getUsage();

    expect(usage.documentsBytes, 2048);
    expect(usage.cacheBytes, 1024);
    expect(usage.totalBytes, 3072);
  });

  test(
    'clearCache deletes raw videos and intermediates but preserves other files',
    () async {
      final raw = File(
        '${ownedTemporary.path}${Platform.pathSeparator}stickr_raw.mp4',
      )..writeAsBytesSync(List.filled(100, 1));
      final intermediate = File(
        '${ownedTemporary.path}${Platform.pathSeparator}stickr_overlay.png',
      )..writeAsBytesSync(List.filled(50, 1));
      final unrelated = File(
        '${temporary.path}${Platform.pathSeparator}other_app.tmp',
      )..writeAsBytesSync(List.filled(75, 1));

      final result = await utility.clearCache();

      expect(result.bytesFreed, 150);
      expect(result.filesDeleted, 2);
      expect(raw.existsSync(), isFalse);
      expect(intermediate.existsSync(), isFalse);
      expect(unrelated.existsSync(), isTrue);
    },
  );

  test('cleanupTemporaryMedia deletes nested mp4 and png files and leaves webp', () async {
    final nested = Directory(
      '${ownedTemporary.path}${Platform.pathSeparator}stickr_work${Platform.pathSeparator}raw',
    )..createSync(recursive: true);
    final video = File('${nested.path}${Platform.pathSeparator}clip.mp4')
      ..writeAsBytesSync(List.filled(40, 1));
    final overlay = File(
      '${ownedTemporary.path}${Platform.pathSeparator}frame.PNG',
    )..writeAsBytesSync(List.filled(20, 1));
    final tempWebp = File(
      '${ownedTemporary.path}${Platform.pathSeparator}staged.webp',
    )..writeAsBytesSync(List.filled(10, 1));
    final unrelatedVideo = File(
      '${temporary.path}${Platform.pathSeparator}plugin_recording.mp4',
    )..writeAsBytesSync(List.filled(30, 1));
    final unrelatedPng = File(
      '${temporary.path}${Platform.pathSeparator}plugin_preview.png',
    )..writeAsBytesSync(List.filled(30, 1));
    final saved = File(
      '${documents.path}${Platform.pathSeparator}pack_sticker.webp',
    )..writeAsBytesSync(List.filled(80, 1));
    final savedPng = File('${documents.path}${Platform.pathSeparator}tray.png')
      ..writeAsBytesSync(List.filled(15, 1));

    final result = await utility.cleanupTemporaryMedia();

    expect(result.filesDeleted, 2);
    expect(result.bytesFreed, 60);
    expect(video.existsSync(), isFalse);
    expect(overlay.existsSync(), isFalse);
    expect(tempWebp.existsSync(), isTrue);
    expect(unrelatedVideo.existsSync(), isTrue);
    expect(unrelatedPng.existsSync(), isTrue);
    expect(saved.existsSync(), isTrue);
    expect(savedPng.existsSync(), isTrue);
  });

  test(
    'post-save cleanup deletes staged WebP but nothing outside app temp',
    () async {
      final raw = File(
        '${ownedTemporary.path}${Platform.pathSeparator}stickr_raw.mp4',
      )..writeAsBytesSync(List.filled(100, 1));
      final staged = File(
        '${ownedTemporary.path}${Platform.pathSeparator}generated.webp',
      )..writeAsBytesSync(List.filled(40, 1));
      final unrelated = File(
        '${temporary.path}${Platform.pathSeparator}stickr_raw.mp4',
      )..writeAsBytesSync(List.filled(50, 1));
      final saved = File(
        '${documents.path}${Platform.pathSeparator}stickr_saved.webp',
      )..writeAsBytesSync(List.filled(80, 1));

      await utility.cleanupAfterStickerSaved([
        raw.path,
        staged.path,
        saved.path,
      ]);

      expect(raw.existsSync(), isFalse);
      expect(staged.existsSync(), isFalse);
      expect(unrelated.existsSync(), isTrue);
      expect(saved.existsSync(), isTrue);
    },
  );

  test('post-save cleanup rejects links outside owned storage', () async {
    final outside = File(
      '${temporary.path}${Platform.pathSeparator}plugin_video.mp4',
    )..writeAsBytesSync(List.filled(50, 1));
    final link = Link(
      '${ownedTemporary.path}${Platform.pathSeparator}linked_video.mp4',
    )..createSync(outside.path);

    final result = await utility.cleanupAfterStickerSaved([link.path]);

    expect(result.filesDeleted, 0);
    expect(outside.existsSync(), isTrue);
    expect(link.existsSync(), isTrue);
  });

  test(
    'canonical resolver creates only the Stickr-owned subdirectory',
    () async {
      final resolved = await getStickrTemporaryDirectory(
        baseTemporaryDirectory: () async => temporary,
      );

      expect(resolved.path, ownedTemporary.path);
      expect(resolved.path.split(Platform.pathSeparator).last, 'stickr_temp');
      expect(resolved.existsSync(), isTrue);
    },
  );

  test('formats storage values for the settings UI', () {
    expect(formatStorageBytes(512), '512 B');
    expect(formatStorageBytes(1536), '1.5 KB');
    expect(formatStorageBytes(2 * 1024 * 1024), '2.0 MB');
  });
}
