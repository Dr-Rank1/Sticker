import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../discover/tenor_repository.dart';
import 'community_models.dart';

class CommunityStickerPage {
  const CommunityStickerPage({
    required this.stickers,
    required this.nextCursor,
  });

  final List<CommunitySticker> stickers;
  final String? nextCursor;
}

/// Paginated source for the Community masonry feed.
///
/// Production builds with a Tenor key use its transparent WebP endpoint. The
/// deterministic fallback keeps development and offline builds scrollable.
class CommunityStickerFeed {
  CommunityStickerFeed(this._tenor);

  final TenorRepository _tenor;

  Future<CommunityStickerPage> loadPage({String? cursor}) async {
    if (_tenor.hasApiKey) {
      final page = await _tenor.search(
        'trending reaction stickers',
        limit: 24,
        position: cursor,
      );
      return CommunityStickerPage(
        stickers: [
          for (final sticker in page.results)
            CommunitySticker(
              id: sticker.id,
              label: sticker.title,
              imageUrl: sticker.webpUrl,
              width: sticker.width,
              height: sticker.height,
              animated: sticker.animated,
            ),
        ],
        nextCursor: page.next,
      );
    }
    return _mockPage(cursor);
  }

  CommunityStickerPage _mockPage(String? cursor) {
    final page = int.tryParse(cursor ?? '') ?? 0;
    final stickers = <CommunitySticker>[];
    for (var index = 0; index < 24; index++) {
      final source = _mockStickers[(page * 24 + index) % _mockStickers.length];
      final animated = index.isEven;
      final imageUrl = animated
          ? 'https://fonts.gstatic.com/s/e/notoemoji/latest/${source.codepoint}/512.webp'
          : 'https://em-content.zobj.net/source/google/387/${source.slug}_${source.codepoint}.webp';
      stickers.add(
        CommunitySticker(
          id: 'mock_${page}_$index',
          label: source.label,
          imageUrl: '$imageUrl?v=$page',
          width: 512,
          height: switch (index % 5) {
            0 => 620,
            1 => 470,
            2 => 560,
            _ => 512,
          },
          animated: animated,
        ),
      );
    }
    return CommunityStickerPage(stickers: stickers, nextCursor: '${page + 1}');
  }
}

class _MockSticker {
  const _MockSticker(this.label, this.slug, this.codepoint);

  final String label;
  final String slug;
  final String codepoint;
}

const _mockStickers = [
  _MockSticker('Laughing', 'face-with-tears-of-joy', '1f602'),
  _MockSticker('Heart eyes', 'smiling-face-with-heart-eyes', '1f60d'),
  _MockSticker('Fire', 'fire', '1f525'),
  _MockSticker('Mind blown', 'exploding-head', '1f92f'),
  _MockSticker('Party', 'partying-face', '1f973'),
  _MockSticker('Cool', 'smiling-face-with-sunglasses', '1f60e'),
  _MockSticker('Crying', 'loudly-crying-face', '1f62d'),
  _MockSticker('Love', 'red-heart', '2764-fe0f'),
  _MockSticker('Thinking', 'thinking-face', '1f914'),
  _MockSticker('Please', 'pleading-face', '1f97a'),
  _MockSticker('Celebrate', 'raising-hands', '1f64c'),
  _MockSticker('Perfect', 'ok-hand', '1f44c'),
  _MockSticker('Clap', 'clapping-hands', '1f44f'),
  _MockSticker('Wave', 'waving-hand', '1f44b'),
  _MockSticker('Star struck', 'star-struck', '1f929'),
  _MockSticker('Melting', 'melting-face', '1fae0'),
];

final communityStickerFeedProvider = Provider<CommunityStickerFeed>((ref) {
  return CommunityStickerFeed(ref.watch(tenorRepositoryProvider));
});
