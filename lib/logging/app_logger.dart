import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Process-wide structured logger. Debug chatter is silenced in release.
class AppLogger {
  AppLogger({Logger? logger})
    : _logger =
          logger ??
          Logger(
            filter: ProductionFilter(),
            printer: PrettyPrinter(
              methodCount: 0,
              errorMethodCount: 8,
              lineLength: 80,
              colors: false,
              dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
            ),
            level: kReleaseMode ? Level.warning : Level.debug,
          );

  final Logger _logger;

  void d(String message) => _logger.d(message);

  void i(String message) => _logger.i(message);

  void w(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  void e(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}

final appLogger = AppLogger();
