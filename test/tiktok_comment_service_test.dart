import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikk/tiktok/tiktok_comment_service.dart';

void main() {
  test('parses only valid comment image URLs', () {
    final service = TikTokCommentService(apiGet: (_, _) async => _response({}));
    final stickers = service.parseStickers({
      'comments': [
        {
          'id': 'comment-1',
          'text': '[Sticker]',
          'aweme_id': '7393468652906925317',
          'image_urls': [
            'https://cdn.example.com/sticker.webp',
            '',
            'not-a-url',
          ],
          'author': {'nickname': 'Ian'},
        },
        {
          'id': 'text-only',
          'text': 'Great video',
          'image_urls': <String>[],
          'replies': [
            {
              'id': 'reply-1',
              'image_urls': ['https://cdn.example.com/reply.webp'],
            },
          ],
        },
      ],
    });

    expect(stickers, hasLength(2));
    expect(stickers.first.commentId, 'comment-1');
    expect(stickers.first.author, 'Ian');
    expect(stickers.first.imageUrl, endsWith('sticker.webp'));
    expect(stickers.last.imageUrl, endsWith('reply.webp'));
  });

  test('uses the video ID and paginates while deduplicating URLs', () async {
    final requests = <Map<String, dynamic>>[];
    final service = TikTokCommentService(
      maxPages: 2,
      apiGet: (path, query) async {
        requests.add({'path': path, ...query});
        return _response({
          'comments': [
            {
              'id': '${requests.length}',
              'image_urls': ['https://cdn.example.com/same.webp'],
            },
          ],
          'pagination': {
            'has_more': requests.length == 1,
            'cursor': '${requests.length * 50}',
          },
        });
      },
    );

    final stickers = await service.fetchStickers(
      'https://www.tiktok.com/@creator/video/7393468652906925317',
    );

    expect(requests, hasLength(2));
    expect(
      requests.first['path'],
      '/v1/tiktok/videos/7393468652906925317/comments',
    );
    expect(requests.last['cursor'], '50');
    expect(stickers, hasLength(1));
  });

  test('resolves a vm.tiktok.com link before requesting comments', () async {
    var resolved = false;
    final service = TikTokCommentService(
      maxPages: 1,
      videoIdResolver: (url) async {
        resolved = url.contains('vm.tiktok.com');
        return '7393468652906925317';
      },
      apiGet: (path, query) async => _response({
        'comments': <dynamic>[],
        'pagination': {'has_more': false},
      }),
    );

    await service.fetchStickers('https://vm.tiktok.com/ZMexample/');
    expect(resolved, isTrue);
  });

  test('downloads a sticker to temporary storage', () async {
    final temp = await Directory.systemTemp.createTemp('comment_sticker');
    addTearDown(() => temp.deleteSync(recursive: true));
    final dio = Dio();
    dio.httpClientAdapter = _DownloadAdapter();
    final service = TikTokCommentService(
      dio: dio,
      temporaryDirectory: () async => temp,
      apiGet: (_, _) async => _response({}),
    );

    final file = await service.downloadSticker(
      const CommentSticker(
        id: '1_0',
        commentId: '1',
        imageUrl: 'https://cdn.example.com/sticker.webp',
        author: '',
      ),
    );

    expect(file.existsSync(), isTrue);
    expect(file.readAsBytesSync(), [1, 2, 3]);
  });
}

Response<dynamic> _response(dynamic data) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: '/'),
    statusCode: 200,
    data: data,
  );
}

class _DownloadAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      [1, 2, 3],
      200,
      headers: {
        Headers.contentLengthHeader: ['3'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
