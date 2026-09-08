import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikk/tiktok/apify_service.dart';

void main() {
  test('starts, polls, and returns only items with image URLs', () async {
    late String postPath;
    late Map<String, dynamic> payload;
    final getPaths = <String>[];
    final delays = <Duration>[];
    var polls = 0;

    final service = ApifyService(
      token: 'test-token',
      delay: (duration) async => delays.add(duration),
      apiPost: (path, data) async {
        postPath = path;
        payload = Map<String, dynamic>.from(data! as Map);
        return _response({
          'data': {
            'id': 'run-123',
            'defaultDatasetId': 'dataset-123',
            'status': 'READY',
          },
        });
      },
      apiGet: (path, query) async {
        getPaths.add(path);
        if (path.contains('/runs/')) {
          polls += 1;
          return _response({
            'data': {
              'id': 'run-123',
              'defaultDatasetId': 'dataset-123',
              'status': polls == 1 ? 'RUNNING' : 'SUCCEEDED',
            },
          });
        }
        expect(query, {
          'token': 'test-token',
          'format': 'json',
          'clean': true,
        });
        return _response([
          {'commentId': '1', 'text': 'hello'},
          {
            'commentId': '2',
            'authorNickname': 'Ian',
            'images': ['https://example.com/a.webp'],
          },
          {
            'commentId': '3',
            'imageUrl': null,
          },
        ]);
      },
    );

    final items = await service.runTikTokCommentScraper(
      postUrl:
          'https://www.tiktok.com/@phamxuanhieu2510/video/7562014017833749768',
    );

    expect(postPath, '/acts/X6ACJnuJVBUsBocfe/runs');
    expect(payload, {
      'postURLs': [
        'https://www.tiktok.com/@phamxuanhieu2510/video/7562014017833749768',
      ],
      'commentsPerPost': 50,
      'maxRepliesPerComment': 25,
      'resultsPerPage': 100,
      'excludePinnedPosts': false,
    });
    expect(getPaths, [
      '/acts/X6ACJnuJVBUsBocfe/runs/run-123',
      '/acts/X6ACJnuJVBUsBocfe/runs/run-123',
      '/datasets/dataset-123/items',
    ]);
    expect(delays, [const Duration(seconds: 3), const Duration(seconds: 3)]);
    expect(items, hasLength(1));
    expect(items.single['commentId'], '2');
  });

  test('maps filtered items into comment stickers', () async {
    final service = ApifyService(
      token: 'test-token',
      delay: (_) async {},
      apiPost: (_, _) async => _response({
        'data': {
          'id': 'run-123',
          'defaultDatasetId': 'dataset-123',
          'status': 'SUCCEEDED',
        },
      }),
      apiGet: (_, _) async => _response([
        {
          'commentId': '2',
          'authorNickname': 'Ian',
          'images': ['https://example.com/a.webp'],
        },
      ]),
    );

    final stickers = await service.fetchCommentStickers(
      'https://www.tiktok.com/@creator/video/1234567890',
    );

    expect(stickers, hasLength(1));
    expect(stickers.single.commentId, '2');
    expect(stickers.single.author, 'Ian');
    expect(stickers.single.imageUrl, 'https://example.com/a.webp');
  });

  test('stops polling when the Actor fails', () async {
    final service = ApifyService(
      token: 'test-token',
      delay: (_) async {},
      apiPost: (_, _) async => _response({
        'data': {'id': 'run-123', 'defaultDatasetId': 'dataset-123'},
      }),
      apiGet: (_, _) async => _response({
        'data': {
          'id': 'run-123',
          'status': 'FAILED',
          'statusMessage': 'Actor crashed',
        },
      }),
    );

    await expectLater(
      service.runTikTokCommentScraper(
        postUrl: 'https://vm.tiktok.com/ZMexample/',
      ),
      throwsA(
        isA<ApifyException>().having(
          (error) => error.message,
          'message',
          contains('Actor crashed'),
        ),
      ),
    );
  });

  test('throws ApifyLimitException when the API rejects the request', () async {
    final service = ApifyService(
      token: 'test-token',
      apiPost: (_, _) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/acts/X6ACJnuJVBUsBocfe/runs'),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 429,
          ),
        );
      },
    );

    await expectLater(
      service.runTikTokCommentScraper(
        postUrl: 'https://www.tiktok.com/@creator/video/1234567890',
      ),
      throwsA(isA<ApifyLimitException>()),
    );
  });

  test('throws ApifyNetworkException when the connection fails', () async {
    final service = ApifyService(
      token: 'test-token',
      apiPost: (_, _) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/acts/X6ACJnuJVBUsBocfe/runs'),
          type: DioExceptionType.connectionError,
        );
      },
    );

    await expectLater(
      service.runTikTokCommentScraper(
        postUrl: 'https://www.tiktok.com/@creator/video/1234567890',
      ),
      throwsA(isA<ApifyNetworkException>()),
    );
  });
}

Response<dynamic> _response(dynamic data) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: '/'),
    statusCode: 200,
    data: data,
  );
}
