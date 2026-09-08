import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApifyException implements Exception {
  const ApifyException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef ApifyPost = Future<Response<dynamic>> Function(
  String path,
  Object? data,
);
typedef ApifyGet = Future<Response<dynamic>> Function(
  String path,
  Map<String, dynamic>? queryParameters,
);

/// Runs the Apify TikTok comment scraper and returns its dataset items.
class ApifyService {
  ApifyService({
    String token = apiToken,
    Dio? dio,
    this.apiPost,
    this.apiGet,
    Future<void> Function(Duration)? delay,
    this.pollInterval = const Duration(seconds: 2),
    this.maxWait = const Duration(minutes: 5),
  }) : _token = token,
       _dio = dio ?? createDio(token: token),
       _delay = delay ?? Future<void>.delayed;

  static const actorId = 'X6ACJnuJVBUsBocfe';
  static const baseUrl = 'https://api.apify.com/v2';
  static const apiToken = String.fromEnvironment('APIFY_API_TOKEN');

  static const _terminalFailureStatuses = {'FAILED', 'ABORTED', 'TIMED-OUT'};

  final String _token;
  final Dio _dio;
  final Future<void> Function(Duration) _delay;
  final ApifyPost? apiPost;
  final ApifyGet? apiGet;
  final Duration pollInterval;
  final Duration maxWait;

  static Dio createDio({required String token}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 20),
        contentType: Headers.jsonContentType,
        headers: const {'Accept': 'application/json'},
      ),
    );

    // Apify recommends Bearer authentication. Query-string tokens can be
    // retained in proxy, analytics, and crash logs.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );
    return dio;
  }

  Future<List<dynamic>> runTikTokCommentScraper({
    required String postUrl,
  }) async {
    if (_token.trim().isEmpty && apiPost == null) {
      throw const ApifyException(
        'Apify is not configured. Add APIFY_API_TOKEN to the app build.',
      );
    }

    final uri = Uri.tryParse(postUrl.trim());
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        uri.scheme != 'https' ||
        (host != 'tiktok.com' && !host.endsWith('.tiktok.com'))) {
      throw const ApifyException('Provide a valid HTTPS TikTok post URL.');
    }

    final input = <String, dynamic>{
      'postURLs': [postUrl.trim()],
      'commentsPerPost': 50,
      'maxRepliesPerComment': 25,
      'resultsPerPage': 100,
      'excludePinnedPosts': false,
    };

    try {
      final startResponse = await _post('/acts/$actorId/runs', input);
      final initialRun = _runData(startResponse.data);
      final runId = initialRun['id']?.toString().trim() ?? '';
      var datasetId = initialRun['defaultDatasetId']?.toString().trim() ?? '';
      if (runId.isEmpty) {
        throw const ApifyException(
          'Apify started the Actor but did not return a run ID.',
        );
      }

      final deadline = DateTime.now().add(maxWait);
      while (true) {
        if (DateTime.now().isAfter(deadline)) {
          throw const ApifyException(
            'The TikTok comment scraper took too long to finish.',
          );
        }

        await _delay(pollInterval);
        final statusResponse = await _get('/actor-runs/$runId');
        final run = _runData(statusResponse.data);
        final status = run['status']?.toString().toUpperCase() ?? '';
        final currentDatasetId =
            run['defaultDatasetId']?.toString().trim() ?? '';
        if (currentDatasetId.isNotEmpty) datasetId = currentDatasetId;

        if (status == 'SUCCEEDED') break;
        if (_terminalFailureStatuses.contains(status)) {
          final detail = run['statusMessage']?.toString().trim();
          throw ApifyException(
            detail?.isNotEmpty == true
                ? 'The Apify run $status: $detail'
                : 'The Apify run ended with status $status.',
          );
        }
      }

      if (datasetId.isEmpty) {
        throw const ApifyException(
          'The completed Apify run did not provide a dataset ID.',
        );
      }

      final datasetResponse = await _get(
        '/datasets/$datasetId/items',
        queryParameters: const {'format': 'json', 'clean': true},
      );
      final items = _listData(datasetResponse.data);
      for (final item in items) {
        debugPrint('Apify dataset item: $item');
      }
      return items;
    } on ApifyException {
      rethrow;
    } on DioException catch (error) {
      throw ApifyException(_dioMessage(error));
    } on SocketException {
      throw const ApifyException(
        'No internet connection. Check your network and try again.',
      );
    } on FormatException {
      throw const ApifyException('Apify returned an unreadable response.');
    } catch (error) {
      throw ApifyException('Could not run the Apify scraper: $error');
    }
  }

  Future<Response<dynamic>> _post(String path, Object? data) {
    final customPost = apiPost;
    if (customPost != null) return customPost(path, data);
    return _dio.post<dynamic>(path, data: data);
  }

  Future<Response<dynamic>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    final customGet = apiGet;
    if (customGet != null) return customGet(path, queryParameters);
    return _dio.get<dynamic>(path, queryParameters: queryParameters);
  }

  Map<String, dynamic> _runData(dynamic responseData) {
    final envelope = _asMap(responseData);
    final run = _asMap(envelope?['data']);
    if (run == null) {
      throw const FormatException('Missing Apify run data.');
    }
    return run;
  }

  List<dynamic> _listData(dynamic responseData) {
    if (responseData is List) return List<dynamic>.from(responseData);
    final envelope = _asMap(responseData);
    final items = envelope?['items'];
    if (items is List) return List<dynamic>.from(items);
    throw const FormatException('Missing Apify dataset items.');
  }

  String _dioMessage(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return 'Apify rejected the API token. Check APIFY_API_TOKEN.';
    }
    if (status == 402) {
      return 'The Apify account does not have enough usage credit.';
    }
    if (status == 429) {
      return 'Apify’s request limit was reached. Please try again later.';
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The Apify request timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'Could not connect to Apify.';
      default:
        return 'Apify could not complete the scraper request.';
    }
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
