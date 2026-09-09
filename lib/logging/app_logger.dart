import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Process-wide structured logger. Debug chatter is silenced in release.
class AppLogger {
  AppLogger({Logger? logger})
    : _logger =
          logger ??
          Logger(
            filter: ProductionFilter(),
            printer: SimplePrinter(colors: false, printTime: true),
            level: kReleaseMode ? Level.warning : Level.debug,
          );

  final Logger _logger;

  void d(String message) => _logger.d(_sanitize(message));

  void i(String message) => _logger.i(_sanitize(message));

  void w(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.w(
      _sanitize(message),
      error: error?.runtimeType,
      stackTrace: _sanitizeStack(stackTrace),
    );
  }

  void e(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(
      _sanitize(message),
      error: error?.runtimeType,
      stackTrace: _sanitizeStack(stackTrace),
    );
  }

  String _sanitize(String value) {
    var sanitized = value.replaceAll(RegExp(r'https?://\S+'), '[redacted_url]');
    sanitized = sanitized.replaceAll(
      RegExp(r'(?<![A-Za-z0-9_])/(?:[^/\s:]+/)+[^)\s:]+'),
      '[redacted_path]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'[A-Za-z]:\\(?:[^\\\s:]+\\)+[^)\s:]+'),
      '[redacted_path]',
    );
    return sanitized;
  }

  StackTrace? _sanitizeStack(StackTrace? stack) {
    if (stack == null) return null;
    return StackTrace.fromString(_sanitize(stack.toString()));
  }
}

final appLogger = AppLogger();
