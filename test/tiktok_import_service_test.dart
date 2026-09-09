import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/tiktok/tiktok_import_service.dart';

void main() {
  late TiktokImportService service;

  setUp(() {
    service = TiktokImportService();
  });

  group('extractTikTokUrl', () {
    test('reads a standard video URL', () {
      expect(
        service.extractTikTokUrl(
          'https://www.tiktok.com/@studio/video/7393468652906925317',
        ),
        'https://www.tiktok.com/@studio/video/7393468652906925317',
      );
    });

    test('reads a short vm.tiktok.com link from messy text', () {
      expect(
        service.extractTikTokUrl(
          'watch this https://vm.tiktok.com/ZMh9k2xYz/ 🔥',
        ),
        'https://vm.tiktok.com/ZMh9k2xYz/',
      );
    });

    test('adds https to a bare tiktok host', () {
      expect(
        service.extractTikTokUrl('vt.tiktok.com/ZS8abcde/'),
        'https://vt.tiktok.com/ZS8abcde/',
      );
    });

    test('returns null for empty or unrelated text', () {
      expect(service.extractTikTokUrl(''), isNull);
      expect(service.extractTikTokUrl('https://youtube.com/watch?v=1'), isNull);
    });
  });

  group('isValidTikTokUrl', () {
    test('accepts video and short links', () {
      expect(
        service.isValidTikTokUrl(
          'https://www.tiktok.com/@user/video/1234567890123456789',
        ),
        isTrue,
      );
      expect(
        service.isValidTikTokUrl('https://vm.tiktok.com/ZMabc123/'),
        isTrue,
      );
    });

    test('rejects non-TikTok URLs', () {
      expect(service.isValidTikTokUrl('https://example.com/video/1'), isFalse);
      expect(service.isValidTikTokUrl('not a link'), isFalse);
    });
  });

  group('TikWM API', () {
    test('uses GET /api/ with the TikTok URL and parses data.play', () async {
      const link = 'https://www.tiktok.com/@studio/video/7393468652906925317';
      late String requestedPath;
      late Map<String, dynamic> requestedQuery;
      final api = TiktokImportService(
        apiGet: (path, query) async {
          requestedPath = path;
          requestedQuery = query;
          return Response<dynamic>(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: {
              'code': 0,
              'msg': 'success',
              'data': {
                'id': '7393468652906925317',
                'title': 'A clean clip',
                'play': 'https://cdn.example.com/clean.mp4',
              },
            },
          );
        },
      );

      final video = await api.resolveVideo(link);

      expect(requestedPath, TiktokImportService.apiPath);
      expect(requestedQuery, {'url': link});
      expect(video.playUrl, 'https://cdn.example.com/clean.mp4');
      expect(video.id, '7393468652906925317');
      expect(video.caption, 'A clean clip');
    });

    test('configures Dio for the TikWM REST endpoint', () {
      final dio = TiktokImportService.createDio();

      expect(dio.options.baseUrl, TiktokImportService.apiBaseUrl);
      expect(dio.options.connectTimeout, const Duration(seconds: 20));
      expect(dio.options.receiveTimeout, const Duration(seconds: 90));
      expect(dio.options.headers['Accept'], 'application/json');
    });

    test('maps JSON rate limits to a helpful error', () {
      expect(
        () => service.parseTikwmResponse({
          'code': 429,
          'msg': 'rate limit exceeded',
        }),
        throwsA(
          isA<TiktokImportException>().having(
            (error) => error.message,
            'message',
            contains('too many requests'),
          ),
        ),
      );
    });

    test('maps invalid URL responses to a helpful error', () {
      expect(
        () => service.parseTikwmResponse({'code': -1, 'msg': 'invalid url'}),
        throwsA(
          isA<TiktokImportException>().having(
            (error) => error.message,
            'message',
            contains('Check the link'),
          ),
        ),
      );
    });

    test('rejects a successful response without data.play', () {
      expect(
        () => service.parseTikwmResponse({
          'code': 0,
          'data': {'id': '123'},
        }),
        throwsA(
          isA<TiktokImportException>().having(
            (error) => error.message,
            'message',
            contains('no downloadable video'),
          ),
        ),
      );
    });
  });

  group('describeError', () {
    test('maps import and socket-style errors to friendly copy', () {
      expect(
        service.describeError(
          const TiktokImportException('Paste a video URL and try again.'),
        ),
        'Paste a video URL and try again.',
      );
    });
  });
}
