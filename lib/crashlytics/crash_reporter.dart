import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../logging/app_logger.dart';

/// Process-wide Crashlytics facade. Production uses Firebase; tests inject
/// [RecordingCrashReporter].
abstract class CrashReporter {
  void log(String message);
  Future<void> setCustomKey(String key, Object value);
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
  void log(String message) {}

  @override
  Future<void> setCustomKey(String key, Object value) async {}

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
  void log(String message) {
    if (!_ready) return;
    FirebaseCrashlytics.instance.log(message);
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    if (!_ready) return;
    await FirebaseCrashlytics.instance.setCustomKey(key, value);
  }

  @override
  void recordFlutterFatalError(FlutterErrorDetails details) {
    if (!_ready) return;
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    if (!_ready) return;
    await FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
  }
}

/// In-memory reporter for unit tests.
class RecordingCrashReporter implements CrashReporter {
  final logs = <String>[];
  final keys = <String, Object>{};
  final errors = <Object>[];

  @override
  void log(String message) => logs.add(message);

  @override
  Future<void> setCustomKey(String key, Object value) async {
    keys[key] = value;
  }

  @override
  void recordFlutterFatalError(FlutterErrorDetails details) {
    errors.add(details.exception);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    errors.add(error);
  }
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
    return true;
  } catch (error, stack) {
    appLogger.w(
      'Firebase Crashlytics unavailable',
      error: error,
      stackTrace: stack,
    );
    crashReporter = const NoOpCrashReporter();
    return false;
  }
}
