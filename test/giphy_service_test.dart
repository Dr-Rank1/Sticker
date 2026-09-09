import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/community/giphy_service.dart';

void main() {
  test('requests fifty safe-rated trending stickers', () async {
    late String requestedPath;
    late Map<String, dynamic> requestedParameters;
    final service = GiphyService(
      apiKey: 'test-giphy-key',
      apiGet: (path, parameters) async {
        requestedPath = path;
        requestedParameters = parameters;
        return _response({
          'data': [
            {
              'id': 'sticker-1',
              'title': 'A sticker',
              'images': {
                'fixed_height': {
                  'url': 'https://media.giphy.com/sticker.gif',
                  'width': '200',
                  'height': '240',
                },
                'original': {
                  'url': 'https://media.giphy.com/original.gif',
                  'width': '500',
                  'height': '600',
                },
              },
            },
          ],
          'pagination': {'offset': 0, 'count': 1, 'total_count': 60},
        });
      },
    );

    final page = await service.fetchTrending();

    expect(requestedPath, GiphyService.endpoint);
    expect(requestedParameters, {
      'api_key': 'test-giphy-key',
      'limit': 50,
      'rating': 'g',
      'offset': 0,
    });
    expect(page.stickers, hasLength(1));
    expect(page.stickers.single.url, 'https://media.giphy.com/sticker.gif');
    expect(page.stickers.single.width, 200);
    expect(page.stickers.single.height, 240);
    expect(page.nextOffset, 1);
  });

  test('filters entries without valid sticker image URLs', () async {
    final service = GiphyService(
      apiKey: 'test-key',
      apiGet: (_, _) async => _response({
        'data': [
          {
            'id': 'invalid',
            'images': {
              'fixed_height': {'url': 'not-a-url'},
            },
          },
        ],
        'pagination': {'offset': 0, 'count': 1, 'total_count': 1},
      }),
    );

    final page = await service.fetchTrending();

    expect(page.stickers, isEmpty);
    expect(page.nextOffset, isNull);
  });

  test('searches stickers with the query and offset', () async {
    late String requestedPath;
    late Map<String, dynamic> requestedParameters;
    final service = GiphyService(
      apiKey: 'test-key',
      apiGet: (path, parameters) async {
        requestedPath = path;
        requestedParameters = parameters;
        return _response({
          'data': [
            {
              'id': 'search-1',
              'title': 'Happy cat',
              'images': {
                'fixed_height': {
                  'url': 'https://media.giphy.com/cat.gif',
                  'webp': 'https://media.giphy.com/cat.webp',
                  'width': '320',
                  'height': '240',
                },
              },
            },
          ],
          'pagination': {'offset': 50, 'count': 1, 'total_count': 100},
        });
      },
    );

    final page = await service.search(' happy cat ', offset: 50);

    expect(requestedPath, GiphyService.searchEndpoint);
    expect(requestedParameters, {
      'api_key': 'test-key',
      'q': 'happy cat',
      'limit': 50,
      'rating': 'g',
      'offset': 50,
    });
    expect(page.stickers.single.url, endsWith('cat.webp'));
    expect(page.stickers.single.aspectRatio, closeTo(4 / 3, 0.01));
    expect(page.nextOffset, 51);
  });

  test('search rejects an empty query', () async {
    final service = GiphyService(apiKey: 'test-key');

    await expectLater(service.search('  '), throwsA(isA<GiphyException>()));
  });

  test('converts rate limits into a Giphy error', () async {
    final service = GiphyService(
      apiKey: 'test-key',
      apiGet: (_, _) async {
        throw DioException(
          requestOptions: RequestOptions(path: GiphyService.endpoint),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: GiphyService.endpoint),
            statusCode: 429,
          ),
        );
      },
    );

    await expectLater(
      service.fetchTrending(),
      throwsA(isA<GiphyRateLimitException>()),
    );
  });
}

Response<dynamic> _response(dynamic data) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: GiphyService.endpoint),
    statusCode: 200,
    data: data,
  );
}
