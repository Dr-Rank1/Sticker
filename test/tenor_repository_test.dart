import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikk/discover/tenor_repository.dart';

void main() {
  test(
    'search always requests sticker-only transparent WebP results',
    () async {
      late String requestedPath;
      late Map<String, dynamic> requestedParameters;
      final repository = TenorRepository(
        apiKey: 'test-key',
        apiGet: (path, parameters) async {
          requestedPath = path;
          requestedParameters = parameters;
          return Response<dynamic>(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: {
              'next': 'next-page',
              'results': [
                {
                  'id': 'transparent-1',
                  'content_description': 'Happy cat',
                  'media_formats': {
                    'webp_transparent': {
                      'url': 'https://media.tenor.com/cat.webp',
                      'dims': [320, 240],
                      'duration': 1.5,
                    },
                    'gif': {'url': 'https://media.tenor.com/cat.gif'},
                  },
                },
                {
                  'id': 'gif-only',
                  'media_formats': {
                    'gif': {'url': 'https://media.tenor.com/ignored.gif'},
                  },
                },
              ],
            },
          );
        },
      );

      final page = await repository.search('happy cat');

      expect(requestedPath, TenorRepository.searchPath);
      expect(requestedParameters['q'], 'happy cat');
      expect(
        requestedParameters['searchfilter'],
        TenorRepository.stickerFilter,
      );
      expect(
        requestedParameters['media_filter'],
        TenorRepository.transparentMediaFilter,
      );
      expect(requestedParameters['key'], 'test-key');
      expect(page.results, hasLength(1));
      expect(page.results.single.webpUrl, endsWith('cat.webp'));
      expect(page.results.single.aspectRatio, closeTo(4 / 3, 0.01));
      expect(page.results.single.animated, isTrue);
      expect(page.next, 'next-page');
    },
  );

  test('requires an API key without committing one to source', () async {
    final repository = TenorRepository(apiKey: '');

    await expectLater(
      repository.search('hello'),
      throwsA(
        isA<TenorException>().having(
          (error) => error.message,
          'message',
          contains('TENOR_API_KEY'),
        ),
      ),
    );
  });

  test('downloads the transparent WebP into Stikk temporary storage', () async {
    final temporary = await Directory.systemTemp.createTemp('stikk_tenor_');
    addTearDown(() async {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    });
    late String requestedUrl;
    final repository = TenorRepository(
      apiKey: 'test-key',
      temporaryDirectory: () async => temporary,
      fileDownload: (url, destination, onProgress) async {
        requestedUrl = url;
        await File(destination).writeAsBytes([1, 2, 3, 4]);
        onProgress?.call(4, 4);
      },
    );
    const sticker = TenorSticker(
      id: 'cat/unsafe',
      title: 'Cat',
      webpUrl: 'https://media.tenor.com/cat.webp',
      width: 320,
      height: 320,
      duration: 0,
    );

    final file = await repository.downloadSticker(sticker);

    expect(requestedUrl, sticker.webpUrl);
    expect(file.parent.path, temporary.path);
    expect(file.path, contains('stikk_tenor_catunsafe_'));
    expect(await file.length(), 4);
  });
}
