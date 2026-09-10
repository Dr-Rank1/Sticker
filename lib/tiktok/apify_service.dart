import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import '../crashlytics/crash_reporter.dart';
import '../l10n/l10n.dart';
import '../network/network_client.dart';
import 'tiktok_comment_service.dart';
import 'tiktok_import_controller.dart';

class ApifyException implements Exception {
  const ApifyException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApifyNetworkException extends ApifyException {
  ApifyNetworkException([String? message])
    : super(message ?? serviceLocalizations.apifyNetworkError);
}

class ApifyLimitException extends ApifyException {
  ApifyLimitException([String? message])
    : super(message ?? serviceLocalizations.apifyLimitReached);
}

typedef ApifyPost = Future<Response<dynamic>> Function(
  String path,
  Object? data,
);

typedef ApifyVideoIdResolver = Future<String> Function(String videoUrl);

class ApifyService {
  ApifyService({
    String token = AppEnvironment.apifyApiToken,
    NetworkClient? networkClient,
    Dio? dio,
    this.apiPost,
    this.videoIdResolver,
  }) : _token = token.trim(),
       _networkClient =
           networkClient ??
           NetworkClient(
             dio: dio,
             connectTimeout: _syncTimeout,
             sendTimeout: _syncTimeout,
             receiveTimeout: _syncTimeout,
           );

  static const synchronousDatasetPath =
      'https://api.apify.com/v2/actors/api-ninja~tiktok-comments-scraper/run-sync-get-dataset-items';

  static const scraperInputDefaults = <String, dynamic>{
    // Actor schema requires commentsPerUrl >= 100.
    'commentsPerUrl': 100,
    'scrapeAll': false,
    'repliesPerComment': 0,
    'parseAllReplies': false,
  };

  static const _syncTimeout = Duration(milliseconds: 120000);
  static final _videoIdInPath = RegExp(r'/video/(\d+)');
  static final _bareVideoId = RegExp(r'^\d{8,}$');

  /// Sticker-pack assets (prefer these over photo-comment uploads).
  static const _stickerFieldKeys = <String>[
    'stickerUrl',
    'sticker_url',
    'sticker',
    'stickerUrls',
    'sticker_urls',
  ];

  /// Generic image fields. Photo-comment CDNs are filtered when stickers exist.
  static const _imageFieldKeys = <String>[
    'images',
    'image_urls',
    'imageUrls',
    'imageUrl',
    'image_url',
    'mediaUrls',
    'media_urls',
    'image',
    'url_list',
    'urlList',
  ];

  /// TikTok photo-comment object storage (uploaded screenshots/photos).
  static final _photoCommentMarkers = RegExp(
    r'zt8igodiya|image-origin|bwwwqb46tv|f3l3iwwzn0|image_list',
    caseSensitive: false,
  );

  static final _stickerUrlMarkers = RegExp(
    r'/sticker/|\.webp(?:$|\?)|sticker',
    caseSensitive: false,
  );

  final String _token;
  final NetworkClient _networkClient;
  final ApifyPost? apiPost;
  final ApifyVideoIdResolver? videoIdResolver;

  BaseOptions get networkOptions => _networkClient.options;

  String get synchronousDatasetEndpoint {
    return '$synchronousDatasetPath?token=${Uri.encodeQueryComponent(_token)}';
  }

  Future<List<Map<String, dynamic>>> runTikTokCommentScraper({
    required String postUrl,
    CancelToken? cancelToken,
  }) async {
    _ensureConfigured();
    final input = await scraperInput(postUrl: postUrl);
    crashReporter.breadcrumb(CrashBreadcrumb.apifyScrapeStarted);

    try {
      final customPost = apiPost;
      final response = customPost != null
          ? await customPost(synchronousDatasetEndpoint, input)
          : await _networkClient.post<dynamic>(
              synchronousDatasetEndpoint,
              data: input,
              options: Options(
                contentType: Headers.jsonContentType,
                headers: const {'Accept': 'application/json'},
              ),
              cancelToken: cancelToken,
            );
      final items = _listData(response.data)
          .map(_asMap)
          .whereType<Map<String, dynamic>>()
          .where(hasStickerOrImageUrl)
          .toList(growable: false);
      crashReporter.breadcrumb(CrashBreadcrumb.apifyItemsReceived);
      await crashReporter.setAttribute(
        CrashAttribute.apifyItemCount,
        items.length,
      );
      return items;
    } on ApifyException {
      rethrow;
    } on NetworkFailure catch (error) {
      throw _fromNetwork(error);
    } on DioException catch (error) {
      throw _fromNetwork(NetworkErrorNormalizer.fromDio(error));
    } on SocketException {
      throw ApifyNetworkException(serviceLocalizations.networkOffline);
    } on FormatException {
      throw ApifyException(serviceLocalizations.apifyUnreadableResponse);
    } catch (error) {
      throw ApifyException(
        serviceLocalizations.apifyRunFailed(error.toString()),
      );
    }
  }

  Future<List<String>> fetchStickerUrls(
    String postUrl, {
    CancelToken? cancelToken,
  }) async {
    final items = await runTikTokCommentScraper(
      postUrl: postUrl,
      cancelToken: cancelToken,
    );
    final urls = <String>{};
    for (final item in items) {
      urls.addAll(imageUrlsFrom(item));
    }
    return preferStickerUrls(urls).toList(growable: false);
  }

  Future<List<CommentSticker>> fetchCommentStickers(
    String postUrl, {
    CancelToken? cancelToken,
  }) async {
    final items = await runTikTokCommentScraper(
      postUrl: postUrl,
      cancelToken: cancelToken,
    );
    if (items.isEmpty) return const [];
    crashReporter.breadcrumb(CrashBreadcrumb.apifyParseStarted);
    await crashReporter.setAttribute(
      CrashAttribute.apifyParseCount,
      items.length,
    );
    return Isolate.run(() => parseApifyItems(items));
  }

  Future<Map<String, dynamic>> scraperInput({required String postUrl}) async {
    final target = await resolveSearchTarget(postUrl);
    return <String, dynamic>{
      'searchUrls': [target],
      ...scraperInputDefaults,
    };
  }

  /// Short share links (vt/vm) return empty Apify datasets. Prefer a bare
  /// video ID, which the actor accepts and resolves reliably.
  Future<String> resolveSearchTarget(String postUrl) async {
    final trimmed = postUrl.trim();
    _ensureValidTikTokReference(trimmed);

    final fromPath = _videoIdInPath.firstMatch(trimmed)?.group(1);
    if (fromPath != null) return fromPath;
    if (_bareVideoId.hasMatch(trimmed)) return trimmed;

    final resolver = videoIdResolver;
    if (resolver == null) {
      throw ApifyException(serviceLocalizations.shortTikTokLinkUnresolved);
    }
    try {
      final resolved = (await resolver(trimmed)).trim();
      final nestedId = _videoIdInPath.firstMatch(resolved)?.group(1);
      if (nestedId != null) return nestedId;
      if (_bareVideoId.hasMatch(resolved)) return resolved;
      throw ApifyException(serviceLocalizations.invalidTikTokVideoId);
    } on ApifyException {
      rethrow;
    } catch (error) {
      throw ApifyException(
        serviceLocalizations.couldNotResolveTikTokLink(error.toString()),
      );
    }
  }

  void _ensureValidTikTokReference(String value) {
    if (_bareVideoId.hasMatch(value)) return;
    final uri = Uri.tryParse(value);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        uri.scheme != 'https' ||
        (host != 'tiktok.com' && !host.endsWith('.tiktok.com'))) {
      throw ApifyException(serviceLocalizations.invalidHttpsTikTokUrl);
    }
  }

  void _ensureConfigured() {
    if (_token.isEmpty) {
      throw ApifyException(serviceLocalizations.apifyNotConfigured);
    }
  }

  static bool hasStickerOrImageUrl(Map<String, dynamic> item) {
    return imageUrlsFrom(item).isNotEmpty;
  }

  /// When a scan finds sticker-pack assets, drop photo-comment uploads.
  /// Photo comments are only kept when no sticker assets were found — and the
  /// UI cut-out pipeline turns those into stickers before display/export.
  static Iterable<String> preferStickerUrls(Iterable<String> urls) {
    final all = urls.where(_isHttpUrl).toList(growable: false);
    final stickers = all.where(isStickerCommentUrl).toList(growable: false);
    if (stickers.isNotEmpty) return stickers;
    // Keep photo comments only as sticker source material to cut out.
    return all.where(isPhotoCommentUrl).isNotEmpty
        ? all.where(isPhotoCommentUrl)
        : all;
  }

  /// True for uploaded photo comments (opaque JPEGs), not sticker-pack assets.
  static bool isPhotoCommentUrl(String url) {
    return _photoCommentMarkers.hasMatch(url);
  }

  /// True for sticker-pack / webp assets TikTok serves for sticker comments.
  static bool isStickerCommentUrl(String url) {
    if (isPhotoCommentUrl(url)) return false;
    return _stickerUrlMarkers.hasMatch(url);
  }

  static List<String> imageUrlsFrom(Map<String, dynamic> item) {
    final stickerFieldUrls = <String>[];
    final imageFieldUrls = <String>[];
    final data = _asMap(item['data']);
    final raw = _asMap(data?['raw']);
    for (final source in [item, ?data, ?raw]) {
      for (final key in _stickerFieldKeys) {
        stickerFieldUrls.addAll(_urlsFrom(source[key]));
      }
      for (final key in _imageFieldKeys) {
        imageFieldUrls.addAll(_urlsFrom(source[key]));
      }
    }

    // Explicit sticker fields win, then sticker-like URLs in image fields.
    final stickers = <String>{
      ...stickerFieldUrls.where(_isHttpUrl),
      ...imageFieldUrls.where(isStickerCommentUrl),
    };
    if (stickers.isNotEmpty) {
      return stickers.toList(growable: false);
    }

    // Fall back to photo comments so scan still yields assets to cut out.
    final photos = imageFieldUrls
        .where(_isHttpUrl)
        .where(isPhotoCommentUrl)
        .toSet();
    if (photos.isNotEmpty) {
      return photos.toList(growable: false);
    }

    return imageFieldUrls.where(_isHttpUrl).toSet().toList(growable: false);
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

  ApifyException _fromNetwork(NetworkFailure error) {
    final status = error.statusCode;
    if (status == 401 || status == 403) {
      return ApifyException(serviceLocalizations.apifyRejectedToken);
    }
    if (status == 402 || error.kind == NetworkErrorKind.rateLimited) {
      return ApifyLimitException(error.message);
    }
    switch (error.kind) {
      case NetworkErrorKind.offline:
      case NetworkErrorKind.timeout:
        return ApifyNetworkException(error.message);
      case NetworkErrorKind.cancelled:
      case NetworkErrorKind.serviceUnavailable:
      case NetworkErrorKind.requestFailed:
        return ApifyException(error.message);
      case NetworkErrorKind.rateLimited:
        return ApifyLimitException(error.message);
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
      map['url'] ??
          map['imageUrl'] ??
          map['image_url'] ??
          map['src'] ??
          map['static_url'] ??
          map['staticUrl'] ??
          map['animate_url'] ??
          map['animateUrl'] ??
          map['url_list'] ??
          map['urlList'],
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
  final preferred = ApifyService.preferStickerUrls(found.keys).toSet();
  return found.values
      .where((sticker) => preferred.contains(sticker.imageUrl))
      .toList(growable: false);
}

final apifyServiceProvider = Provider<ApifyService>((ref) {
  final importService = ref.watch(tiktokImportServiceProvider);
  return ApifyService(
    videoIdResolver: (url) async => (await importService.resolveVideo(url)).id,
  );
});
