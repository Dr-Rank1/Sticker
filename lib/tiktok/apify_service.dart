import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import '../crashlytics/crash_reporter.dart';
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
    super.message = 'Apify request limit was reached. Please try again later.',
  ]);
}

typedef ApifyPost = Future<Response<dynamic>> Function(
  String path,
  Object? data,
);

class ApifyService {
  ApifyService({
    String token = AppEnvironment.apifyApiToken,
    Dio? dio,
    this.apiPost,
  }) : _token = token.trim(),
       _dio = dio ?? createDio();

  static const synchronousDatasetPath =
      'https://api.apify.com/v2/actors/api-ninja~tiktok-comments-scraper/run-sync-get-dataset-items';

  static const scraperInputDefaults = <String, dynamic>{
    'commentsPerUrl': 50,
    'scrapeAll': false,
    'repliesPerComment': 0,
    'parseAllReplies': false,
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

  final String _token;
  final Dio _dio;
  final ApifyPost? apiPost;

  String get synchronousDatasetEndpoint {
    return '$synchronousDatasetPath?token=${Uri.encodeQueryComponent(_token)}';
  }

  static Dio createDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: 60000),
        receiveTimeout: const Duration(milliseconds: 60000),
        sendTimeout: const Duration(milliseconds: 60000),
        contentType: Headers.jsonContentType,
        headers: const {'Accept': 'application/json'},
      ),
    );
  }

  Future<List<Map<String, dynamic>>> runTikTokCommentScraper({
    required String postUrl,
  }) async {
    _ensureConfigured();
    final input = scraperInput(postUrl: postUrl);
    crashReporter.log('Apify synchronous scraper started for $postUrl');
    await crashReporter.setCustomKey('apify_post_url', postUrl);

    try {
      final customPost = apiPost;
      final response = customPost != null
          ? await customPost(synchronousDatasetEndpoint, input)
          : await _dio.post<dynamic>(synchronousDatasetEndpoint, data: input);
      final items = _listData(response.data)
          .map(_asMap)
          .whereType<Map<String, dynamic>>()
          .where(hasStickerOrImageUrl)
          .toList(growable: false);
      crashReporter.log(
        'Apify returned ${items.length} comment sticker items.',
      );
      await crashReporter.setCustomKey('apify_item_count', items.length);
      return items;
    } on ApifyException {
      rethrow;
    } on DioException catch (error) {
      throw _fromDio(error);
    } on SocketException {
      throw const ApifyNetworkException();
    } on FormatException {
      throw const ApifyException(
        'Apify returned an unreadable dataset response.',
      );
    } catch (error) {
      throw ApifyException(
        'Could not run the synchronous Apify scraper: $error',
      );
    }
  }

  Future<List<String>> fetchStickerUrls(String postUrl) async {
    final items = await runTikTokCommentScraper(postUrl: postUrl);
    final urls = <String>{};
    for (final item in items) {
      urls.addAll(imageUrlsFrom(item));
    }
    return urls.toList(growable: false);
  }

  Future<List<CommentSticker>> fetchCommentStickers(String postUrl) async {
    final items = await runTikTokCommentScraper(postUrl: postUrl);
    if (items.isEmpty) return const [];
    crashReporter.log(
      'Apify parsing ${items.length} dataset items on a background isolate',
    );
    await crashReporter.setCustomKey('apify_parse_count', items.length);
    return Isolate.run(() => parseApifyItems(items));
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
      'searchUrls': [trimmed],
      ...scraperInputDefaults,
    };
  }

  void _ensureConfigured() {
    if (_token.isEmpty) {
      throw const ApifyException(
        'Apify is not configured. Add APIFY_API_TOKEN to the app build.',
      );
    }
  }

  static bool hasStickerOrImageUrl(Map<String, dynamic> item) {
    return imageUrlsFrom(item).isNotEmpty;
  }

  static List<String> imageUrlsFrom(Map<String, dynamic> item) {
    final urls = <String>[];
    final data = _asMap(item['data']);
    final raw = _asMap(data?['raw']);
    for (final source in [item, ?data, ?raw]) {
      for (final key in _imageFieldKeys) {
        urls.addAll(_urlsFrom(source[key]));
      }
    }
    return urls.toSet().toList(growable: false);
  }

  static List<CommentSticker> stickersFromItem(Map<String, dynamic> item) {
    final data = _asMap(item['data']);
    final commentId =
        item['commentId']?.toString() ??
        item['id']?.toString() ??
        data?['id']?.toString() ??
        item['replyId']?.toString() ??
        '';
    final authorMap = _asMap(item['author']) ?? _asMap(data?['user']);
    final nickname = item['authorNickname']?.toString().trim() ?? '';
    final mappedNickname = authorMap?['nickname']?.toString().trim() ?? '';
    final username = item['authorUsername']?.toString().trim() ?? '';
    final uniqueId =
        (authorMap?['unique_id'] ?? authorMap?['uniqueId'])
            ?.toString()
            .trim() ??
        '';
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

  List<dynamic> _listData(dynamic responseData) {
    if (responseData is List) return List<dynamic>.from(responseData);
    throw const FormatException('Expected an Apify dataset array.');
  }

  ApifyException _fromDio(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return const ApifyException('Apify rejected the API token.');
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

List<CommentSticker> parseApifyItems(List<dynamic> items) {
  final found = <String, CommentSticker>{};
  for (final raw in items) {
    final item = _asMap(raw);
    if (item == null) continue;
    for (final sticker in ApifyService.stickersFromItem(item)) {
      found.putIfAbsent(sticker.imageUrl, () => sticker);
    }
  }
  return found.values.toList(growable: false);
}

final apifyServiceProvider = Provider<ApifyService>((ref) {
  return ApifyService();
});
