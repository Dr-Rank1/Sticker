import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/tiktok/queued_image_downloader.dart';
import 'package:stickr/tiktok/tiktok_comment_service.dart';

void main() {
  test('caps in-flight downloads at five connections', () async {
    var inFlight = 0;
    var maxInFlight = 0;
    final started = <String>[];
    final downloader = QueuedImageDownloader(
      save: (url, path) async {
        started.add(url);
        inFlight += 1;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        inFlight -= 1;
      },
    );

    final stickers = [
      for (var i = 0; i < 12; i++)
        CommentSticker(
          id: '$i',
          commentId: '$i',
          imageUrl: 'https://example.com/$i.webp',
          author: 'Ian',
        ),
    ];
    final events = <Map<String, int>>[];

    await downloader.downloadAll(
      stickers: stickers,
      directory: '/tmp',
      onProgress: (downloaded, total, ready) {
        events.add({'downloaded': downloaded, 'total': total});
      },
    );

    expect(
      downloader.maxConcurrent,
      QueuedImageDownloader.defaultMaxConcurrent,
    );
    expect(QueuedImageDownloader.defaultMaxConcurrent, 5);
    expect(maxInFlight, 5);
    expect(started, hasLength(12));
    expect(events, hasLength(12));
    expect(events.first, {'downloaded': 1, 'total': 12});
    expect(events.last, {'downloaded': 12, 'total': 12});
    expect(events.every((event) => event['total'] == 12), isTrue);
  });
}
