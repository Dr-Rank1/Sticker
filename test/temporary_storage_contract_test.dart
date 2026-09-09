import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('media pipelines never resolve the general temporary directory', () {
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('storage_utility.dart')) continue;
      if (entity.readAsStringSync().contains('getTemporaryDirectory')) {
        violations.add(entity.path);
      }
    }

    expect(violations, isEmpty);
  });

  test('background cleanup delegates to the scoped storage utility', () {
    final worker = File('lib/storage/cache_cleanup_worker.dart')
        .readAsStringSync();

    expect(worker, contains('StorageUtility().cleanupTemporaryMedia()'));
    expect(worker, isNot(contains('getTemporaryDirectory')));
  });

  test('editor defers permanent ownership until pack selection', () {
    final editor = File('lib/editor/editor_screen.dart').readAsStringSync();
    final repository = File('lib/packs/sticker_repository.dart')
        .readAsStringSync();

    expect(editor, isNot(contains('getApplicationDocumentsDirectory')));
    expect(editor, contains('stickerPath: generatedSticker.path'));
    expect(editor, contains('if (!repositoryAcceptedSticker)'));
    expect(repository, contains('placement = await _fileStore.place('));
  });
}
