import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:stickr/crashlytics/crash_reporter.dart';
import 'package:stickr/editor/ffmpeg_webp_builder.dart';
import 'package:stickr/error/app_error_handlers.dart';
import 'package:stickr/logging/app_logger.dart';
import 'package:stickr/tiktok/apify_service.dart';

void main() {
  late CrashReporter previousReporter;
  late FlutterExceptionHandler? previousFlutterOnError;
  late bool Function(Object error, StackTrace stack)? previousPlatformOnError;

  setUp(() {
    previousReporter = crashReporter;
    previousFlutterOnError = FlutterError.onError;
    previousPlatformOnError = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    crashReporter = previousReporter;
    FlutterError.onError = previousFlutterOnError;
    PlatformDispatcher.instance.onError = previousPlatformOnError;
  });

  test(
    'main.dart installs FlutterFire fatal and async Crashlytics handlers',
    () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      expect(mainSource, contains('FlutterError.onError'));
      expect(mainSource, contains('recordFlutterFatalError'));
      expect(mainSource, contains('PlatformDispatcher.instance.onError'));
      expect(
        mainSource,
        contains(
          'FirebaseCrashlytics.instance.recordError(error, stack, fatal: true)',
        ),
      );
      expect(mainSource, contains('initializeFirebase()'));
      expect(mainSource, contains('AppEnvironment.validateRequired()'));
    },
  );

  test('installAppErrorHandlers keeps the existing fatal error handler', () {
    var chained = false;
    FlutterError.onError = (_) {
      chained = true;
    };
    installAppErrorHandlers(
      logger: AppLogger(logger: Logger(level: Level.off)),
    );

    FlutterError.onError!(
      FlutterErrorDetails(exception: StateError('framework boom')),
    );

    expect(chained, isTrue);
  });

  test('installAppErrorHandlers keeps the existing async error handler', () {
    var chained = false;
    PlatformDispatcher.instance.onError = (error, stack) {
      chained = true;
      return true;
    };
    installAppErrorHandlers(
      logger: AppLogger(logger: Logger(level: Level.off)),
    );

    final handled = PlatformDispatcher.instance.onError!(
      ArgumentError('async boom'),
      StackTrace.current,
    );

    expect(handled, isTrue);
    expect(chained, isTrue);
  });

  test('Apify logs breadcrumbs before scraping and isolate parse', () async {
    final recorder = RecordingCrashReporter();
    crashReporter = recorder;
    final service = ApifyService(
      token: 'test-token',
      apiPost: (_, _) async => _response([
        {
          'commentId': '2',
          'authorNickname': 'Ian',
          'images': ['https://example.com/a.webp'],
        },
      ]),
    );

    await service.fetchCommentStickers(
      'https://www.tiktok.com/@creator/video/1234567890',
    );

    expect(
      recorder.logs,
      contains(
        'Apify synchronous scraper started for https://www.tiktok.com/@creator/video/1234567890',
      ),
    );
    expect(
      recorder.logs,
      contains('Apify parsing 1 dataset items on a background isolate'),
    );
    expect(
      recorder.keys['apify_post_url'],
      'https://www.tiktok.com/@creator/video/1234567890',
    );
    expect(recorder.keys['apify_parse_count'], 1);
  });

  test('FFmpeg logs input size before a heavy encode', () async {
    final recorder = RecordingCrashReporter();
    crashReporter = recorder;
    final temp = await Directory.systemTemp.createTemp('stickr_crash_ffmpeg_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final input = File('${temp.path}${Platform.pathSeparator}in.mp4')
      ..writeAsBytesSync(const [1, 2, 3, 4]);

    final builder = FFmpegWebpBuilder(
      tempDirectory: () async => temp,
      runCommand: (args, onProgress) async {
        File(args.last).writeAsBytesSync(List<int>.filled(32, 1));
        throw Exception('simulated OOM');
      },
    );

    await expectLater(
      builder.assemble(sourceMp4: input.path),
      throwsA(isA<StickerExportException>()),
    );

    expect(recorder.logs.first, 'FFmpeg started with input size: 4');
    expect(recorder.keys['ffmpeg_input_bytes'], 4);
    expect(recorder.keys.containsKey('ffmpeg_quality'), isTrue);
    expect(
      recorder.logs.any((line) => line.startsWith('FFmpeg encode failed')),
      isTrue,
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
