import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/network/network_client.dart';

void main() {
  test('applies the shared timeout policy', () {
    final client = NetworkClient();

    expect(client.options.connectTimeout, NetworkClient.connectTimeout);
    expect(client.options.sendTimeout, NetworkClient.sendTimeout);
    expect(client.options.receiveTimeout, NetworkClient.receiveTimeout);
  });

  test('retries safe GET requests and respects Retry-After', () async {
    final adapter = _SequenceAdapter([503, 200], retryAfter: '2');
    final dio = Dio()..httpClientAdapter = adapter;
    final delays = <Duration>[];
    final client = NetworkClient(
      dio: dio,
      delay: (duration) async => delays.add(duration),
      jitter: (_) => const Duration(milliseconds: 100),
    );

    final response = await client.get<String>('https://example.com/data');

    expect(response.statusCode, 200);
    expect(adapter.requests, 2);
    expect(delays, [const Duration(seconds: 2)]);
  });

  test('does not retry POST requests', () async {
    final adapter = _SequenceAdapter([503, 200]);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = NetworkClient(
      dio: dio,
      delay: (_) async {},
      jitter: (_) => Duration.zero,
    );

    await expectLater(
      client.post<String>('https://example.com/data'),
      throwsA(
        isA<NetworkFailure>().having(
          (error) => error.kind,
          'kind',
          NetworkErrorKind.serviceUnavailable,
        ),
      ),
    );
    expect(adapter.requests, 1);
  });

  test('limits GET retries to the configured maximum', () async {
    final adapter = _SequenceAdapter([503, 503, 503, 200]);
    final dio = Dio()..httpClientAdapter = adapter;
    final delays = <Duration>[];
    final client = NetworkClient(
      dio: dio,
      maxGetRetries: 2,
      delay: (duration) async => delays.add(duration),
      jitter: (_) => const Duration(milliseconds: 100),
    );

    await expectLater(
      client.get<String>('https://example.com/data'),
      throwsA(
        isA<NetworkFailure>().having(
          (error) => error.kind,
          'kind',
          NetworkErrorKind.serviceUnavailable,
        ),
      ),
    );
    expect(adapter.requests, 3);
    expect(delays, hasLength(2));
  });

  test('normalizes offline, timeout, rate-limit, and cancellation errors', () {
    NetworkFailure normalize(DioExceptionType type, {int? statusCode}) {
      final request = RequestOptions(path: '/');
      return NetworkErrorNormalizer.fromDio(
        DioException(
          requestOptions: request,
          type: type,
          response: statusCode == null
              ? null
              : Response<void>(requestOptions: request, statusCode: statusCode),
        ),
      );
    }

    final offline = normalize(DioExceptionType.connectionError);
    expect(offline.kind, NetworkErrorKind.offline);
    expect(offline.localizationKey, 'networkOffline');
    expect(
      normalize(DioExceptionType.receiveTimeout).kind,
      NetworkErrorKind.timeout,
    );
    expect(
      normalize(DioExceptionType.badResponse, statusCode: 429).kind,
      NetworkErrorKind.rateLimited,
    );
    expect(normalize(DioExceptionType.cancel).kind, NetworkErrorKind.cancelled);
  });

  test('cancelled requests are not retried', () async {
    final adapter = _SequenceAdapter([200]);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = NetworkClient(dio: dio);
    final token = CancelToken()..cancel('Screen closed.');

    await expectLater(
      client.get<String>('https://example.com/data', cancelToken: token),
      throwsA(
        isA<NetworkFailure>().having(
          (error) => error.kind,
          'kind',
          NetworkErrorKind.cancelled,
        ),
      ),
    );
    expect(adapter.requests, 0);
  });

  test('cancellation interrupts a pending retry delay', () async {
    final adapter = _SequenceAdapter([503, 200], retryAfter: '30');
    final dio = Dio()..httpClientAdapter = adapter;
    final delayGate = Completer<void>();
    final client = NetworkClient(
      dio: dio,
      delay: (_) => delayGate.future,
      jitter: (_) => Duration.zero,
    );
    final token = CancelToken();

    final request = client.get<String>(
      'https://example.com/data',
      cancelToken: token,
    );
    for (var attempt = 0; attempt < 10 && adapter.requests == 0; attempt++) {
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(Duration.zero);
    token.cancel('Screen closed.');

    await expectLater(
      request,
      throwsA(
        isA<NetworkFailure>().having(
          (error) => error.kind,
          'kind',
          NetworkErrorKind.cancelled,
        ),
      ),
    );
    expect(adapter.requests, 1);
  });
}

class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this.statusCodes, {this.retryAfter});

  final List<int> statusCodes;
  final String? retryAfter;
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final index = requests.clamp(0, statusCodes.length - 1);
    final statusCode = statusCodes[index];
    requests++;
    return ResponseBody.fromString(
      statusCode == 200 ? '{"ok":true}' : '{"error":"unavailable"}',
      statusCode,
      headers: retryAfter == null
          ? null
          : {
              'retry-after': [retryAfter!],
            },
    );
  }

  @override
  void close({bool force = false}) {}
}
