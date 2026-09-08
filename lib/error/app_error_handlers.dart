import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../logging/app_logger.dart';
import 'app_error_fallback.dart';

/// Installs process-wide handlers so uncaught Flutter and async errors
/// never present the red error screen in a running app.
///
/// Existing [FlutterError.onError] and [PlatformDispatcher.instance.onError]
/// callbacks (Crashlytics in `main`) are preserved and invoked after logging.
void installAppErrorHandlers({AppLogger? logger}) {
  final log = logger ?? appLogger;
  final previousFlutterOnError = FlutterError.onError;
  final previousPlatformOnError = PlatformDispatcher.instance.onError;

  FlutterError.onError = (details) {
    log.e(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
    previousFlutterOnError?.call(details);
    if (kDebugMode && previousFlutterOnError == null) {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    log.e('Uncaught async error', error: error, stackTrace: stack);
    return previousPlatformOnError?.call(error, stack) ?? true;
  };

  ErrorWidget.builder = (details) {
    log.e(
      'Widget build error',
      error: details.exception,
      stackTrace: details.stack,
    );
    return AppErrorFallback(details: details);
  };
}
