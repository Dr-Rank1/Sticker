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
        contains('crashReporter.recordError(error, stack, fatal: true)'),
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

  test(
    'Apify records categorized breadcrumbs without the TikTok URL',
    () async {
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
        recorder.breadcrumbs,
        containsAll([
          CrashBreadcrumb.apifyScrapeStarted,
          CrashBreadcrumb.apifyItemsReceived,
          CrashBreadcrumb.apifyParseStarted,
        ]),
      );
      expect(recorder.keys.containsKey('apify_post_url'), isFalse);
      expect(recorder.keys['apify_item_count'], 1);
      expect(recorder.keys['apify_parse_count'], 1);
    },
  );

  test('FFmpeg records size and quality buckets before encoding', () async {
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

    expect(
      recorder.breadcrumbs,
      containsAll([
        CrashBreadcrumb.ffmpegStarted,
        CrashBreadcrumb.ffmpegEncodeAttempt,
        CrashBreadcrumb.ffmpegEncodeFailed,
      ]),
    );
    expect(recorder.keys['ffmpeg_input_size_bucket'], 'under_5_mb');
    expect(recorder.keys.containsKey('ffmpeg_input_bytes'), isFalse);
    expect(recorder.keys.containsKey('ffmpeg_quality_bucket'), isTrue);
  });

  test(
    'CrashReporter removes error messages, URLs, paths, and bytes',
    () async {
      final recorder = RecordingCrashReporter();
      const privatePath = '/data/user/0/com.stickr.stickr/private/photo.jpg';
      const privateUrl = 'https://www.tiktok.com/@private/video/123';

      await recorder.setAttribute(CrashAttribute.ffmpegOs, privateUrl);
      await recorder.setAttribute(CrashAttribute.ffmpegQualityBucket, const [
        1,
        2,
        3,
        4,
      ]);
      await recorder.recordError(
        StateError('Failed for $privateUrl at $privatePath'),
        StackTrace.fromString(
          '#0 pipeline ($privatePath:10)\n#1 request ($privateUrl)',
        ),
      );

      expect(recorder.keys['ffmpeg_os'], 'redacted');
      expect(recorder.keys['ffmpeg_quality_bucket'], 'redacted');
      expect(recorder.errors.single.toString(), isNot(contains(privateUrl)));
      expect(recorder.errors.single.toString(), isNot(contains(privatePath)));
      expect(recorder.stacks.single.toString(), isNot(contains(privateUrl)));
      expect(recorder.stacks.single.toString(), isNot(contains(privatePath)));
    },
  );
}

Response<dynamic> _response(dynamic data) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: '/'),
    statusCode: 200,
    data: data,
  );
}
