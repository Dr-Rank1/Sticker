import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk/HTTP cache for sticker grid thumbs.
///
/// A shared [CacheManager] keeps `cached_network_image` from opening a new
/// store per tile. Object count is capped so a grid of animated WebPs cannot
/// retain unbounded decoded frames on disk.
class StickerGridCacheManager extends CacheManager {
  StickerGridCacheManager._()
    : super(
        Config(
          cacheKey,
          stalePeriod: const Duration(days: 2),
          maxNrOfCacheObjects: maxCachedObjects,
        ),
      );

  static const cacheKey = 'stikkStickerGrid';
  static const maxCachedObjects = 64;
  static const maxDecodeExtent = 256;

  static final instance = StickerGridCacheManager._();

  /// Decodes [provider] at most 256x256 in RAM, without upscaling smaller art.
  static ImageProvider<Object> resizeInMemory(ImageProvider<Object> provider) {
    return ResizeImage(
      provider,
      width: maxDecodeExtent,
      height: maxDecodeExtent,
      policy: ResizeImagePolicy.fit,
      allowUpscaling: false,
    );
  }
}

/// Maps a [ValueKey] of a stable item id back to its index for GridView reuse.
int? findStickerGridChildIndex(Key key, Iterable<String> ids) {
  if (key is! ValueKey<String>) return null;
  var index = 0;
  for (final id in ids) {
    if (id == key.value) return index;
    index += 1;
  }
  return null;
}
