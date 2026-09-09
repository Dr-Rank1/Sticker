import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/packs/sticker_file_store.dart';

void main() {
  late Directory root;
  late Directory temporary;
  late Directory documents;
  late StickerFileStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('stickr_file_store_');
    temporary = Directory('${root.path}${Platform.pathSeparator}stickr_temp')
      ..createSync();
    documents = Directory('${root.path}${Platform.pathSeparator}documents')
      ..createSync();
    store = StickerFileStore(temporaryPath: temporary.path);
  });

  tearDown(() async {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('moves an app-owned temporary sticker into permanent storage', () async {
    final source = File(
      '${temporary.path}${Platform.pathSeparator}generated.webp',
    )..writeAsBytesSync(const [1, 2, 3, 4]);
    final destination = File(
      '${documents.path}${Platform.pathSeparator}stored.webp',
    );

    final placement = await store.place(
      source: source,
      destination: destination,
    );

    expect(placement.transferredOwnership, isTrue);
    expect(source.existsSync(), isFalse);
    expect(destination.readAsBytesSync(), const [1, 2, 3, 4]);
  });

  test('rollback restores a transferred temporary sticker', () async {
    final source = File(
      '${temporary.path}${Platform.pathSeparator}generated.webp',
    )..writeAsBytesSync(const [5, 6, 7, 8]);
    final destination = File(
      '${documents.path}${Platform.pathSeparator}stored.webp',
    );
    final placement = await store.place(
      source: source,
      destination: destination,
    );

    await placement.rollback();

    expect(source.readAsBytesSync(), const [5, 6, 7, 8]);
    expect(destination.existsSync(), isFalse);
  });

  test('copies a non-temporary source without taking ownership', () async {
    final source = File('${root.path}${Platform.pathSeparator}external.webp')
      ..writeAsBytesSync(const [9, 10]);
    final destination = File(
      '${documents.path}${Platform.pathSeparator}stored.webp',
    );

    final placement = await store.place(
      source: source,
      destination: destination,
    );
    await placement.rollback();

    expect(placement.transferredOwnership, isFalse);
    expect(source.readAsBytesSync(), const [9, 10]);
    expect(destination.existsSync(), isFalse);
  });
}
