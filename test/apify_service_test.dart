import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikk/tiktok/apify_service.dart';

void main() {
  test('starts, polls, and fetches the Actor dataset', () async {
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
        if (path.contains('actor-runs')) {
          polls += 1;
          return _response({
            'data': {
              'id': 'run-123',
              'defaultDatasetId': 'dataset-123',
              'status': polls == 1 ? 'RUNNING' : 'SUCCEEDED',
            },
          });
        }
        expect(query, {'format': 'json', 'clean': true});
        return _response([
          {'commentId': '1', 'text': 'hello'},
          {
            'commentId': '2',
            'images': ['https://example.com/a.webp'],
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
      '/actor-runs/run-123',
      '/actor-runs/run-123',
      '/datasets/dataset-123/items',
    ]);
    expect(delays, [const Duration(seconds: 2), const Duration(seconds: 2)]);
    expect(items, hasLength(2));
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
}

Response<dynamic> _response(dynamic data) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: '/'),
    statusCode: 200,
    data: data,
  );
}
