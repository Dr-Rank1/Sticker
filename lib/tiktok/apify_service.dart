import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';
import 'tiktok_comment_service.dart';

class ApifyException implements Exception {
  const ApifyException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApifyNetworkException extends ApifyException {
  const ApifyNetworkException([
    super.message = 'No internet connection. Check your network and try again.',
  ]);
}

class ApifyLimitException extends ApifyException {
  const ApifyLimitException([
    super.message = 'Apify’s request limit was reached. Please try again later.',
  ]);
}

typedef ApifyPost = Future<Response<dynamic>> Function(
  String path,
  Object? data,
);
typedef ApifyGet = Future<Response<dynamic>> Function(
  String path,
  Map<String, dynamic>? queryParameters,
);

/// Fetches TikTok comments from Apify Actor `X6ACJnuJVBUsBocfe`.
class ApifyService {
  ApifyService({
    String token = apiToken,
    Dio? dio,
    this.apiPost,
    this.apiGet,
    Future<void> Function(Duration)? delay,
    this.pollInterval = const Duration(seconds: 3),
    this.maxWait = const Duration(minutes: 5),
  }) : _token = token,
       _dio = dio ?? createDio(token: token),
       _delay = delay ?? Future<void>.delayed;

  static const actorId = 'X6ACJnuJVBUsBocfe';
  static const baseUrl = 'https://api.apify.com/v2';
  static const apiToken = String.fromEnvironment('APIFY_API_TOKEN');

  static const scraperInputDefaults = <String, dynamic>{
    'commentsPerPost': 50,
    'maxRepliesPerComment': 25,
    'resultsPerPage': 100,
    'excludePinnedPosts': false,
  };

  static const _imageFieldKeys = <String>[
    'images',
    'image_urls',
    'imageUrls',
    'imageUrl',
    'image_url',
    'stickerUrl',
    'sticker_url',
    'sticker',
    'image',
  ];

  static const _terminalFailureStatuses = {'FAILED', 'ABORTED', 'TIMED-OUT'};

  final String _token;
  final Dio _dio;
  final Future<void> Function(Duration) _delay;
  final ApifyPost? apiPost;
  final ApifyGet? apiGet;
  final Duration pollInterval;
  final Duration maxWait;

  static Dio createDio({required String token}) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 20),
        contentType: Headers.jsonContentType,
        headers: const {'Accept': 'application/json'},
        queryParameters: {'token': token},
      ),
    );
  }

  /// Runs the Actor, waits until it succeeds, then returns dataset items that
  /// include a sticker or image URL.
  Future<List<Map<String, dynamic>>> runTikTokCommentScraper({
    required String postUrl,
  }) async {
    _ensureConfigured();
    final input = scraperInput(postUrl: postUrl);

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

      var run = initialRun;
      final deadline = DateTime.now().add(maxWait);
      while (_statusOf(run) != 'SUCCEEDED') {
        if (_terminalFailureStatuses.contains(_statusOf(run))) {
          throw ApifyException(_failureMessage(run, _statusOf(run)));
        }
        if (DateTime.now().isAfter(deadline)) {
          throw const ApifyException(
            'The TikTok comment scraper took too long to finish.',
          );
        }

        await _delay(pollInterval);
        final statusResponse = await _get('/acts/$actorId/runs/$runId');
        run = _runData(statusResponse.data);
        final currentDatasetId =
            run['defaultDatasetId']?.toString().trim() ?? '';
        if (currentDatasetId.isNotEmpty) datasetId = currentDatasetId;
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
      final items = _listData(datasetResponse.data)
          .map(_asMap)
          .whereType<Map<String, dynamic>>()
          .where(hasStickerOrImageUrl)
          .toList(growable: false);
      appLogger.d('Apify returned ${items.length} comment stickers.');
      return items;
    } on ApifyException {
      rethrow;
    } on DioException catch (error) {
      throw _fromDio(error);
    } on SocketException {
      throw const ApifyNetworkException();
    } on FormatException {
      throw const ApifyException('Apify returned an unreadable response.');
    } catch (error) {
      throw ApifyException('Could not run the Apify scraper: $error');
    }
  }

  Future<List<CommentSticker>> fetchCommentStickers(String postUrl) async {
    final items = await runTikTokCommentScraper(postUrl: postUrl);
    final found = <String, CommentSticker>{};
    for (final item in items) {
      for (final sticker in stickersFromItem(item)) {
        found.putIfAbsent(sticker.imageUrl, () => sticker);
      }
    }
    return found.values.toList(growable: false);
  }

  Map<String, dynamic> scraperInput({required String postUrl}) {
    final trimmed = postUrl.trim();
    final uri = Uri.tryParse(trimmed);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        uri.scheme != 'https' ||
        (host != 'tiktok.com' && !host.endsWith('.tiktok.com'))) {
      throw const ApifyException('Provide a valid HTTPS TikTok post URL.');
    }

    return <String, dynamic>{
      'postURLs': [trimmed],
      ...scraperInputDefaults,
    };
  }

  static bool hasStickerOrImageUrl(Map<String, dynamic> item) {
    return imageUrlsFrom(item).isNotEmpty;
  }

  static List<String> imageUrlsFrom(Map<String, dynamic> item) {
    final urls = <String>[];
    final nested = _asMap(item['data']);
    for (final source in [item, if (nested != null) nested]) {
      for (final key in _imageFieldKeys) {
        urls.addAll(_urlsFrom(source[key]));
      }
    }
    return urls.toList(growable: false);
  }

  static List<CommentSticker> stickersFromItem(Map<String, dynamic> item) {
    final commentId =
        item['commentId']?.toString() ??
        item['id']?.toString() ??
        item['replyId']?.toString() ??
        '';
    final authorMap = _asMap(item['author']);
    final nickname = item['authorNickname']?.toString().trim() ?? '';
    final mappedNickname = authorMap?['nickname']?.toString().trim() ?? '';
    final username = item['authorUsername']?.toString().trim() ?? '';
    final uniqueId = authorMap?['unique_id']?.toString().trim() ?? '';
    final author = [
      nickname,
      mappedNickname,
      username,
      uniqueId,
    ].firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final urls = imageUrlsFrom(item);
    return [
      for (var index = 0; index < urls.length; index++)
        CommentSticker(
          id: '${commentId}_$index',
          commentId: commentId,
          imageUrl: urls[index],
          author: author,
        ),
    ];
  }

  void _ensureConfigured() {
    if (_token.trim().isEmpty && apiPost == null && apiGet == null) {
      throw const ApifyException(
        'Apify is not configured. Add APIFY_API_TOKEN to the app build.',
      );
    }
  }

  Future<Response<dynamic>> _post(String path, Object? data) {
    final customPost = apiPost;
    if (customPost != null) return customPost(path, data);
    return _dio.post<dynamic>(
      path,
      data: data,
      queryParameters: _tokenQuery(),
    );
  }

  Future<Response<dynamic>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    final query = _tokenQuery(queryParameters);
    final customGet = apiGet;
    if (customGet != null) return customGet(path, query);
    return _dio.get<dynamic>(path, queryParameters: query);
  }

  Map<String, dynamic> _tokenQuery([Map<String, dynamic>? extra]) {
    return <String, dynamic>{
      'token': _token,
      if (extra != null) ...extra,
    };
  }

  String _statusOf(Map<String, dynamic> run) {
    return run['status']?.toString().toUpperCase() ?? '';
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

  String _failureMessage(Map<String, dynamic> run, String status) {
    final detail = run['statusMessage']?.toString().trim();
    return detail?.isNotEmpty == true
        ? 'The Apify run $status: $detail'
        : 'The Apify run ended with status $status.';
  }

  ApifyException _fromDio(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return const ApifyException(
        'Apify rejected the API token. Check APIFY_API_TOKEN.',
      );
    }
    if (status == 402 || status == 429) {
      return const ApifyLimitException();
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApifyNetworkException(
          'The Apify request timed out. Please try again.',
        );
      case DioExceptionType.connectionError:
        return const ApifyNetworkException('Could not connect to Apify.');
      default:
        if (error.error is SocketException) {
          return const ApifyNetworkException();
        }
        return const ApifyException(
          'Apify could not complete the scraper request.',
        );
    }
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<String> _urlsFrom(dynamic value) {
  if (value == null) return const [];
  if (value is String) {
    return _isHttpUrl(value.trim()) ? [value.trim()] : const [];
  }
  if (value is List) {
    return value
        .expand(_urlsFrom)
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
  }
  final map = _asMap(value);
  if (map != null) {
    return _urlsFrom(
      map['url'] ?? map['imageUrl'] ?? map['image_url'] ?? map['src'],
    );
  }
  return const [];
}

bool _isHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

final apifyServiceProvider = Provider<ApifyService>((ref) {
  return ApifyService();
});
