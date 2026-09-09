import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'community_models.dart';
import 'giphy_service.dart';

class CommunityStickerPage {
  const CommunityStickerPage({
    required this.stickers,
    required this.nextCursor,
  });

  final List<CommunitySticker> stickers;
  final String? nextCursor;
}

class CommunityStickerFeed {
  CommunityStickerFeed(this._giphy);

  final GiphyService _giphy;

  Future<CommunityStickerPage> loadPage({String? cursor}) async {
    final offset = int.tryParse(cursor ?? '') ?? 0;
    final page = await _giphy.fetchTrending(offset: offset);
    return CommunityStickerPage(
      stickers: [
        for (final sticker in page.stickers)
          CommunitySticker(
            id: sticker.id,
            label: sticker.title,
            imageUrl: sticker.url,
            width: sticker.width,
            height: sticker.height,
            animated: true,
          ),
      ],
      nextCursor: page.nextOffset?.toString(),
    );
  }
}

final communityStickerFeedProvider = Provider<CommunityStickerFeed>((ref) {
  return CommunityStickerFeed(ref.watch(giphyServiceProvider));
});
