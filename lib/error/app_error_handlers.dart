import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../logging/app_logger.dart';
import 'app_error_fallback.dart';

/// Installs process-wide handlers so uncaught Flutter and async errors
/// never present the red error screen in a running app.
void installAppErrorHandlers({AppLogger? logger}) {
  final log = logger ?? appLogger;

  FlutterError.onError = (details) {
    log.e(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    log.e('Uncaught async error', error: error, stackTrace: stack);
    return true;
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
