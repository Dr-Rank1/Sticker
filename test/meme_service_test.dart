import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/memes/meme_service.dart';

void main() {
  test('loads and parses Imgflip meme templates', () async {
    late String requestedPath;
    final service = MemeService(
      apiGet: (path) async {
        requestedPath = path;
        return Response<dynamic>(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'memes': [
                {
                  'id': '181913649',
                  'name': 'Drake Hotline Bling',
                  'url': 'https://i.imgflip.com/30b1gx.jpg',
                  'width': 1200,
                  'height': 1200,
                },
                {'id': 'bad', 'name': 'Missing image', 'url': ''},
              ],
            },
          },
        );
      },
    );

    final templates = await service.getTemplates();

    expect(requestedPath, MemeService.memesPath);
    expect(templates, hasLength(1));
    expect(templates.single.name, 'Drake Hotline Bling');
    expect(templates.single.imageUrl, endsWith('30b1gx.jpg'));
    expect(templates.single.aspectRatio, 1);
  });

  test('configures Dio for the Imgflip API', () {
    final dio = MemeService.createDio();

    expect(dio.options.baseUrl, MemeService.baseUrl);
    expect(dio.options.connectTimeout, const Duration(seconds: 15));
    expect(dio.options.headers['Accept'], 'application/json');
  });

  test('surfaces Imgflip API errors', () {
    final service = MemeService();

    expect(
      () => service.parseTemplates({
        'success': false,
        'error_message': 'Service unavailable',
      }),
      throwsA(
        isA<MemeServiceException>().having(
          (error) => error.message,
          'message',
          'Service unavailable',
        ),
      ),
    );
  });

  test('downloads a selected template to temporary storage', () async {
    final temporary = await Directory.systemTemp.createTemp('stickr_meme_');
    addTearDown(() async {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    });
    final service = MemeService(
      temporaryDirectory: () async => temporary,
      fileDownload: (url, destination, onProgress) async {
        await File(destination).writeAsBytes([1, 2, 3]);
        onProgress?.call(3, 3);
      },
    );
    const template = MemeTemplate(
      id: 'drake/unsafe',
      name: 'Drake',
      imageUrl: 'https://i.imgflip.com/30b1gx.jpg',
      width: 1200,
      height: 1200,
    );

    final file = await service.downloadTemplate(template);

    expect(file.parent.path, temporary.path);
    expect(file.path, contains('stickr_meme_drakeunsafe_'));
    expect(file.path, endsWith('.jpg'));
    expect(await file.length(), 3);
  });
}
