import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/images/sticker_grid_cache.dart';
import 'package:stickr/images/sticker_grid_image.dart';

void main() {
  test('sticker grid cache caps objects and decode size', () {
    expect(StickerGridCacheManager.maxDecodeExtent, 256);
    expect(StickerGridCacheManager.maxCachedObjects, 64);
    expect(StickerGridCacheManager.cacheKey, 'stickrStickerGrid');
  });

  test('findStickerGridChildIndex maps ValueKeys back to list order', () {
    const ids = ['a', 'b', 'c'];
    expect(findStickerGridChildIndex(const ValueKey('b'), ids), 1);
    expect(findStickerGridChildIndex(const ValueKey('missing'), ids), isNull);
    expect(findStickerGridChildIndex(const ValueKey<int>(0), ids), isNull);
  });

  test('resizeInMemory caps decode to 256 without upscaling', () {
    final resized = StickerGridCacheManager.resizeInMemory(
      FileImage(File('sticker.webp')),
    );
    expect(resized, isA<ResizeImage>());
    final image = resized as ResizeImage;
    expect(image.width, StickerGridCacheManager.maxDecodeExtent);
    expect(image.height, StickerGridCacheManager.maxDecodeExtent);
    expect(image.policy, ResizeImagePolicy.fit);
    expect(image.allowUpscaling, isFalse);
  });

  testWidgets('network thumbs use the shared CacheManager at 256', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StickerGridImage(imageUrl: 'https://example.com/a.webp'),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.memCacheWidth, StickerGridCacheManager.maxDecodeExtent);
    expect(image.memCacheHeight, StickerGridCacheManager.maxDecodeExtent);
    expect(image.cacheManager, StickerGridCacheManager.instance);
  });
}
