import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/network/network_client.dart';
import 'package:stickr/tiktok/apify_service.dart';

void main() {
  const postUrl = 'https://www.tiktok.com/@creator/video/1234567890123456789';

  test('posts actor input to the synchronous dataset endpoint', () async {
    late String requestUrl;
    late Map<String, dynamic> payload;
    final service = ApifyService(
      token: 'test-token',
      apiPost: (path, data) async {
        requestUrl = path;
        payload = Map<String, dynamic>.from(data! as Map);
        return _response([
          {'id': '1', 'text': 'No image'},
          {
            'itemType': 'comment',
            'data': {
              'id': '2',
              'images': [
                {'url': 'https://example.com/sticker.webp'},
              ],
            },
          },
        ]);
      },
    );

    final items = await service.runTikTokCommentScraper(postUrl: postUrl);

    expect(requestUrl, service.synchronousDatasetEndpoint);
    expect(
      requestUrl,
      '${ApifyService.synchronousDatasetPath}?token=test-token',
    );
    expect(payload, {
      'searchUrls': ['1234567890123456789'],
      'commentsPerUrl': 100,
      'scrapeAll': false,
      'repliesPerComment': 0,
      'parseAllReplies': false,
    });
    expect(items, hasLength(1));
  });

  test('resolves short share links before calling Apify', () async {
    late Map<String, dynamic> payload;
    final service = ApifyService(
      token: 'test-token',
      videoIdResolver: (url) async {
        expect(url, 'https://vt.tiktok.com/ZSqURv8Xp/');
        return '7672778337843989792';
      },
      apiPost: (_, data) async {
        payload = Map<String, dynamic>.from(data! as Map);
        return _response([
          {
            'data': {
              'id': 'sticker-1',
              'images': ['https://example.com/sticker.webp'],
            },
          },
        ]);
      },
    );

    final stickers = await service.fetchCommentStickers(
      'https://vt.tiktok.com/ZSqURv8Xp/',
    );

    expect(payload['searchUrls'], ['7672778337843989792']);
    expect(stickers, hasLength(1));
    expect(stickers.single.imageUrl, 'https://example.com/sticker.webp');
  });

  test('uses the central network client timeouts', () {
    final options = NetworkClient().options;

    expect(options.connectTimeout, NetworkClient.connectTimeout);
    expect(options.receiveTimeout, NetworkClient.receiveTimeout);
    expect(options.sendTimeout, NetworkClient.sendTimeout);
  });

  test('configures dio with at least sixty second sync timeouts', () {
    final service = ApifyService(token: 'test-token');
    final options = service.networkOptions;

    expect(options.connectTimeout, const Duration(milliseconds: 120000));
    expect(options.receiveTimeout, const Duration(milliseconds: 120000));
    expect(options.sendTimeout, const Duration(milliseconds: 120000));
  });

  test('prefers sticker-pack URLs over photo-comment uploads', () async {
    final service = ApifyService(
      token: 'test-token',
      apiPost: (_, _) async => _response([
        {
          'data': {
            'id': 'both',
            'images': [
              'https://p16.tiktokcdn.com/tos-alisg-i-zt8igodiya-sg/photo~tplv-image-origin.jpeg',
            ],
            'stickerUrl':
                'https://p16-va.tiktokcdn.com/sticker/pack_asset~tplv.image',
          },
        },
        {
          'data': {
            'id': 'photo-only',
            'images': [
              'https://p16.tiktokcdn.com/tos-alisg-i-zt8igodiya-sg/other~tplv-image-origin.jpeg',
            ],
          },
        },
      ]),
    );

    final urls = await service.fetchStickerUrls(postUrl);

    expect(urls, [
      'https://p16-va.tiktokcdn.com/sticker/pack_asset~tplv.image',
    ]);
  });

  test('falls back to photo comments when no sticker assets exist', () async {
    final service = ApifyService(
      token: 'test-token',
      apiPost: (_, _) async => _response([
        {
          'data': {
            'id': 'photo-only',
            'images': [
              'https://p16.tiktokcdn.com/tos-alisg-i-zt8igodiya-sg/photo~tplv-image-origin.jpeg',
            ],
          },
        },
      ]),
    );

    final urls = await service.fetchStickerUrls(postUrl);

    expect(urls, [
      'https://p16.tiktokcdn.com/tos-alisg-i-zt8igodiya-sg/photo~tplv-image-origin.jpeg',
    ]);
  });

  test('returns only unique valid sticker URLs', () async {
    final service = ApifyService(
      token: 'test-token',
      apiPost: (_, _) async => _response([
        {
          'data': {
            'images': [
              'https://example.com/a.webp',
              'not-a-url',
              'https://example.com/a.webp',
            ],
          },
        },
        {'imageUrl': 'https://example.com/b.webp'},
        {'images': []},
      ]),
    );

    final urls = await service.fetchStickerUrls(postUrl);

    expect(urls, ['https://example.com/a.webp', 'https://example.com/b.webp']);
  });

  test('maps nested actor output into comment stickers', () async {
    final service = ApifyService(
      token: 'test-token',
      apiPost: (_, _) async => _response([
        {
          'itemType': 'comment',
          'data': {
            'id': 'comment-2',
            'images': ['https://example.com/a.webp'],
            'user': {'nickname': 'Ian'},
          },
        },
      ]),
    );

    final stickers = await service.fetchCommentStickers(postUrl);

    expect(stickers, hasLength(1));
    expect(stickers.single.commentId, 'comment-2');
    expect(stickers.single.author, 'Ian');
    expect(stickers.single.imageUrl, 'https://example.com/a.webp');
  });

  test('parseApifyItems remains safe for background isolates', () async {
    final items = [
      for (var i = 0; i < 40; i++)
        {
          'data': {
            'id': '$i',
            'images': ['https://example.com/$i.webp'],
          },
        },
    ];

    final stickers = await Isolate.run(() => parseApifyItems(items));

    expect(stickers, hasLength(40));
    expect(stickers.first.imageUrl, 'https://example.com/0.webp');
    expect(stickers.last.commentId, '39');
  });

  test('throws ApifyLimitException for API rate limits', () async {
    final service = ApifyService(
      token: 'test-token',
      apiPost: (_, _) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/sync'),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/sync'),
            statusCode: 429,
          ),
        );
      },
    );

    await expectLater(
      service.fetchStickerUrls(postUrl),
      throwsA(isA<ApifyLimitException>()),
    );
  });

  test(
    'throws ApifyNetworkException for synchronous request timeouts',
    () async {
      final service = ApifyService(
        token: 'test-token',
        apiPost: (_, _) async {
          throw DioException(
            requestOptions: RequestOptions(path: '/sync'),
            type: DioExceptionType.receiveTimeout,
          );
        },
      );

      await expectLater(
        service.fetchStickerUrls(postUrl),
        throwsA(
          isA<ApifyNetworkException>().having(
            (error) => error.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
    },
  );
}

Response<dynamic> _response(dynamic data) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: '/sync'),
    statusCode: 200,
    data: data,
  );
}
