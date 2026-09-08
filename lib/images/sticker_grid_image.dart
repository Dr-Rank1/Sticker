import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'sticker_grid_cache.dart';

/// Grid thumbnail that decodes at [StickerGridCacheManager.maxDecodeExtent].
class StickerGridImage extends StatelessWidget {
  const StickerGridImage({
    super.key,
    this.filePath,
    this.imageUrl,
    this.fit = BoxFit.contain,
  });

  final String? filePath;
  final String? imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path = filePath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return Image(
        image: StickerGridCacheManager.resizeInMemory(FileImage(File(path))),
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    }
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        cacheManager: StickerGridCacheManager.instance,
        memCacheWidth: StickerGridCacheManager.maxDecodeExtent,
        memCacheHeight: StickerGridCacheManager.maxDecodeExtent,
        fit: fit,
        placeholder: (_, _) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    }
    return const Center(child: Icon(Icons.broken_image_outlined));
  }
}
