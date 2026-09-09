import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android pack staging flushes temporary files before atomic commit', () {
    final store = File(
      'android/app/src/main/kotlin/com/stickr/stickr/StickerPackStore.kt',
    ).readAsStringSync();

    expect(store, contains('val temporaryDir = File(root, ".\$id.tmp-'));
    expect(store, contains('FileOutputStream(destination).use'));
    expect(store, contains('output.fd.sync()'));
    expect(store, contains('writeSynced(metadataTemporary'));
    expect(store, contains('commitStagedPack('));
    expect(store, contains('Os.rename(source.path, destination.path)'));
    expect(store, contains('recoverInterruptedStaging(context)'));
    expect(
      store.indexOf('writeSynced(metadataTemporary'),
      lessThan(store.indexOf('commitStagedPack(')),
    );
  });

  test('ContentProvider recovers interrupted staging on process startup', () {
    final provider = File(
      'android/app/src/main/kotlin/com/stickr/stickr/StickerContentProvider.kt',
    ).readAsStringSync();

    expect(
      provider,
      contains('StickerPackStore.recoverInterruptedStaging(ctx)'),
    );
  });
}
