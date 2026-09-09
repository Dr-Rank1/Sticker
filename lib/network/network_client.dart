import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';

enum NetworkErrorKind {
  offline('networkOffline'),
  rateLimited('serviceRateLimited'),
  timeout('networkTimeout'),
  cancelled('networkRequestCancelled'),
  serviceUnavailable('networkServiceUnavailable'),
  requestFailed('networkRequestFailed');

  const NetworkErrorKind(this.localizationKey);

  final String localizationKey;
}

class NetworkFailure implements Exception {
  const NetworkFailure({
    required this.kind,
    this.statusCode,
    this.retryAfter,
    this.cause,
  });

  final NetworkErrorKind kind;
  final int? statusCode;
  final Duration? retryAfter;
  final Object? cause;

  String get localizationKey => kind.localizationKey;

  String get message => switch (kind) {
    NetworkErrorKind.offline => serviceLocalizations.networkOffline,
    NetworkErrorKind.rateLimited => serviceLocalizations.serviceRateLimited,
    NetworkErrorKind.timeout => serviceLocalizations.networkTimeout,
    NetworkErrorKind.cancelled => serviceLocalizations.networkRequestCancelled,
    NetworkErrorKind.serviceUnavailable =>
      serviceLocalizations.networkServiceUnavailable,
    NetworkErrorKind.requestFailed => serviceLocalizations.networkRequestFailed,
  };

  @override
  String toString() => message;
}

class NetworkErrorNormalizer {
  const NetworkErrorNormalizer._();

  static NetworkFailure fromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    final retryAfter = RetryAfterParser.fromHeaders(error.response?.headers);

    if (error.type == DioExceptionType.cancel) {
      return NetworkFailure(
        kind: NetworkErrorKind.cancelled,
        statusCode: statusCode,
        cause: error,
      );
    }
    if (statusCode == 429) {
      return NetworkFailure(
        kind: NetworkErrorKind.rateLimited,
        statusCode: statusCode,
        retryAfter: retryAfter,
        cause: error,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return NetworkFailure(
        kind: NetworkErrorKind.serviceUnavailable,
        statusCode: statusCode,
        retryAfter: retryAfter,
        cause: error,
      );
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => NetworkFailure(
        kind: NetworkErrorKind.timeout,
        statusCode: statusCode,
        cause: error,
      ),
      DioExceptionType.connectionError => NetworkFailure(
        kind: NetworkErrorKind.offline,
        statusCode: statusCode,
        cause: error,
      ),
      _ when error.error is SocketException => NetworkFailure(
        kind: NetworkErrorKind.offline,
        statusCode: statusCode,
        cause: error,
      ),
      _ => NetworkFailure(
        kind: NetworkErrorKind.requestFailed,
        statusCode: statusCode,
        cause: error,
      ),
    };
  }
}

class RetryAfterParser {
  const RetryAfterParser._();

  static Duration? fromHeaders(Headers? headers, {DateTime? now}) {
    final value = headers?.value('retry-after')?.trim();
    if (value == null || value.isEmpty) return null;

    final seconds = int.tryParse(value);
    if (seconds != null) {
      return Duration(seconds: max(0, seconds));
    }

    try {
      final retryAt = HttpDate.parse(value).toUtc();
      final delay = retryAt.difference((now ?? DateTime.now()).toUtc());
      return delay.isNegative ? Duration.zero : delay;
    } on FormatException {
      return null;
    } on HttpException {
      return null;
    }
  }
}

class NetworkClient {
  NetworkClient({
    Dio? dio,
    this.maxGetRetries = 2,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    Future<void> Function(Duration)? delay,
    Duration Function(int retryNumber)? jitter,
  }) : _dio = dio ?? Dio(),
       _delay = delay ?? Future<void>.delayed,
       _jitter = jitter ?? _defaultJitter {
    _dio.options
      ..connectTimeout = connectTimeout ?? NetworkClient.connectTimeout
      ..sendTimeout = sendTimeout ?? NetworkClient.sendTimeout
      ..receiveTimeout = receiveTimeout ?? NetworkClient.receiveTimeout;
    _dio.interceptors.add(
      _SafeGetRetryInterceptor(
        _dio,
        maxRetries: maxGetRetries,
        delay: _delay,
        jitter: _jitter,
      ),
    );
  }

  static const connectTimeout = Duration(seconds: 60);
  static const sendTimeout = Duration(seconds: 60);
  static const receiveTimeout = Duration(seconds: 90);

  final Dio _dio;
  final int maxGetRetries;
  final Future<void> Function(Duration) _delay;
  final Duration Function(int retryNumber) _jitter;

  BaseOptions get options => _dio.options;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _normalize(
      () => _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _normalize(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<dynamic>> download(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _normalize(
      () => _dio.download(
        url,
        savePath,
        onReceiveProgress: onReceiveProgress,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> _normalize<T>(
    Future<Response<T>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw NetworkErrorNormalizer.fromDio(error);
    }
  }

  static Duration _defaultJitter(int retryNumber) {
    final random = Random();
    final ceiling = 150 * (1 << (retryNumber - 1));
    return Duration(milliseconds: 100 + random.nextInt(ceiling + 1));
  }
}

class _SafeGetRetryInterceptor extends Interceptor {
  _SafeGetRetryInterceptor(
    this._dio, {
    required this.maxRetries,
    required this.delay,
    required this.jitter,
  });

  static const _attemptKey = 'stickr-network-retry-attempt';
  final Dio _dio;
  final int maxRetries;
  final Future<void> Function(Duration) delay;
  final Duration Function(int retryNumber) jitter;

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final attempt = request.extra[_attemptKey] as int? ?? 0;
    if (!_canRetry(error, request, attempt)) {
      handler.next(error);
      return;
    }

    final retryNumber = attempt + 1;
    request.extra[_attemptKey] = retryNumber;
    final retryAfter = RetryAfterParser.fromHeaders(error.response?.headers);
    final jitterDelay = jitter(retryNumber);
    final wait = retryAfter != null && retryAfter > jitterDelay
        ? retryAfter
        : jitterDelay;

    try {
      final cancellation = request.cancelToken?.whenCancel;
      if (cancellation == null) {
        await delay(wait);
      } else {
        await Future.any<void>([delay(wait), cancellation.then<void>((_) {})]);
      }
      if (request.cancelToken?.isCancelled ?? false) {
        handler.next(request.cancelToken?.cancelError ?? error);
        return;
      }
      handler.resolve(await _dio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _canRetry(DioException error, RequestOptions request, int attempt) {
    if (maxRetries <= 0 ||
        attempt >= maxRetries ||
        request.method.toUpperCase() != 'GET' ||
        error.type == DioExceptionType.cancel ||
        (request.cancelToken?.isCancelled ?? false)) {
      return false;
    }

    final statusCode = error.response?.statusCode;
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        statusCode == 408 ||
        statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }
}

final networkClientProvider = Provider<NetworkClient>((ref) {
  return NetworkClient();
});
