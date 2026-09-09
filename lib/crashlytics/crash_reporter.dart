import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../analytics/analytics_service.dart';
import '../firebase_options.dart';
import '../logging/app_logger.dart';

enum CrashBreadcrumb {
  apifyScrapeStarted('apify_scrape_started'),
  apifyItemsReceived('apify_items_received'),
  apifyParseStarted('apify_parse_started'),
  ffmpegStarted('ffmpeg_started'),
  ffmpegEncodeAttempt('ffmpeg_encode_attempt'),
  ffmpegEncodeFailed('ffmpeg_encode_failed');

  const CrashBreadcrumb(this.value);
  final String value;
}

enum CrashAttribute {
  apifyItemCount('apify_item_count'),
  apifyParseCount('apify_parse_count'),
  ffmpegInputSizeBucket('ffmpeg_input_size_bucket'),
  ffmpegHasOverlay('ffmpeg_has_overlay'),
  ffmpegOs('ffmpeg_os'),
  ffmpegSpeed('ffmpeg_speed'),
  ffmpegQualityBucket('ffmpeg_quality_bucket');

  const CrashAttribute(this.value);
  final String value;
}

/// Process-wide Crashlytics facade. Production uses Firebase; tests inject
/// [RecordingCrashReporter].
abstract class CrashReporter {
  void breadcrumb(CrashBreadcrumb breadcrumb);
  Future<void> setAttribute(CrashAttribute attribute, Object value);
  void recordFlutterFatalError(FlutterErrorDetails details);
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  });
}

class NoOpCrashReporter implements CrashReporter {
  const NoOpCrashReporter();

  @override
  void breadcrumb(CrashBreadcrumb breadcrumb) {}

  @override
  Future<void> setAttribute(CrashAttribute attribute, Object value) async {}

  @override
  void recordFlutterFatalError(FlutterErrorDetails details) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {}
}

class FirebaseCrashReporter implements CrashReporter {
  const FirebaseCrashReporter();

  bool get _ready => Firebase.apps.isNotEmpty;

  @override
  void breadcrumb(CrashBreadcrumb breadcrumb) {
    if (!_ready) return;
    FirebaseCrashlytics.instance.log(breadcrumb.value);
  }

  @override
  Future<void> setAttribute(CrashAttribute attribute, Object value) async {
    if (!_ready) return;
    await FirebaseCrashlytics.instance.setCustomKey(
      attribute.value,
      _safeAttributeValue(value),
    );
  }

  @override
  void recordFlutterFatalError(FlutterErrorDetails details) {
    if (!_ready) return;
    FirebaseCrashlytics.instance.recordFlutterFatalError(
      FlutterErrorDetails(
        exception: SanitizedCrashException(details.exception.runtimeType),
        stack: _sanitizedStack(details.stack ?? StackTrace.current),
        library: 'application',
      ),
    );
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    if (!_ready) return;
    await FirebaseCrashlytics.instance.recordError(
      SanitizedCrashException(error.runtimeType),
      _sanitizedStack(stack),
      fatal: fatal,
    );
  }
}

/// In-memory reporter for unit tests.
class RecordingCrashReporter implements CrashReporter {
  final breadcrumbs = <CrashBreadcrumb>[];
  final keys = <String, Object>{};
  final errors = <Object>[];
  final stacks = <StackTrace>[];

  @override
  void breadcrumb(CrashBreadcrumb breadcrumb) => breadcrumbs.add(breadcrumb);

  @override
  Future<void> setAttribute(CrashAttribute attribute, Object value) async {
    keys[attribute.value] = _safeAttributeValue(value);
  }

  @override
  void recordFlutterFatalError(FlutterErrorDetails details) {
    errors.add(SanitizedCrashException(details.exception.runtimeType));
    stacks.add(_sanitizedStack(details.stack ?? StackTrace.current));
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    errors.add(SanitizedCrashException(error.runtimeType));
    stacks.add(_sanitizedStack(stack));
  }
}

class SanitizedCrashException implements Exception {
  const SanitizedCrashException(this.category);

  final Type category;

  @override
  String toString() => 'Application error category: $category';
}

Object _safeAttributeValue(Object value) {
  if (value is bool || value is num) return value;
  if (value is String && RegExp(r'^[a-z0-9_.-]{1,64}$').hasMatch(value)) {
    return value;
  }
  return 'redacted';
}

StackTrace _sanitizedStack(StackTrace stack) {
  var value = stack.toString();
  value = value.replaceAll(RegExp(r'https?://\S+'), '[redacted_url]');
  value = value.replaceAll(
    RegExp(r'(?<![A-Za-z0-9_])/(?:[^/\s:]+/)+[^)\s:]+'),
    '[redacted_path]',
  );
  value = value.replaceAll(
    RegExp(r'[A-Za-z]:\\(?:[^\\\s:]+\\)+[^)\s:]+'),
    '[redacted_path]',
  );
  return StackTrace.fromString(value);
}

CrashReporter crashReporter = const NoOpCrashReporter();

/// Initializes FlutterFire and enables Crashlytics collection in release.
Future<bool> initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );
    crashReporter = const FirebaseCrashReporter();
    analyticsService = FirebaseAnalyticsService();
    return true;
  } catch (error, stack) {
    appLogger.w(
      'Firebase Crashlytics unavailable',
      error: error,
      stackTrace: stack,
    );
    crashReporter = const NoOpCrashReporter();
    analyticsService = const NoOpAnalyticsService();
    return false;
  }
}
