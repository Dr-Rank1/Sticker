import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'tiktok_import_controller.dart';

class TikTokCommentException implements Exception {
  const TikTokCommentException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CommentSticker {
  const CommentSticker({
    required this.id,
    required this.commentId,
    required this.imageUrl,
    required this.author,
  });

  final String id;
  final String commentId;
  final String imageUrl;
  final String author;

  static List<CommentSticker> fromComment(Map<String, dynamic> comment) {
    final commentId = comment['id']?.toString() ?? '';
    final authorData = _asMap(comment['author']);
    final author = authorData?['nickname']?.toString().trim().isNotEmpty == true
        ? authorData!['nickname'].toString().trim()
        : authorData?['unique_id']?.toString().trim() ?? '';
    final urls = _imageUrls(comment['image_urls']);

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

  static List<String> _imageUrls(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where(_isHttpUrl)
        .toList(growable: false);
  }

  static bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}

typedef CommentApiGet = Future<Response<dynamic>> Function(
  String path,
  Map<String, dynamic> queryParameters,
);
typedef TikTokVideoIdResolver = Future<String> Function(String videoUrl);

/// Reads TikTok comment image attachments from ScrapeBadger.
///
/// Supply the API key at build/run time:
/// `--dart-define=SCRAPEBADGER_API_KEY=...`
class TikTokCommentService {
  TikTokCommentService({
    Dio? dio,
    this.videoIdResolver,
    Future<Directory> Function()? temporaryDirectory,
    this.apiGet,
    this.maxPages = 2,
    String key = apiKey,
  }) : _dio = dio ?? createDio(key: key),
       _credential = key,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  static const baseUrl = 'https://scrapebadger.com';
  static const apiKey = String.fromEnvironment('SCRAPEBADGER_API_KEY');
  static final _videoIdPattern = RegExp(r'/video/(\d+)');

  final Dio _dio;
  final String _credential;
  final TikTokVideoIdResolver? videoIdResolver;
  final Future<Directory> Function() _temporaryDirectory;
  final CommentApiGet? apiGet;

  /// Caps credit usage: ScrapeBadger charges 8 credits per page.
  final int maxPages;

  static Dio createDio({String key = apiKey}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 20),
        headers: const {'Accept': 'application/json'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.host == Uri.parse(baseUrl).host) {
            options.headers['x-api-key'] = key;
          }
          handler.next(options);
        },
      ),
    );
    return dio;
  }

  Future<List<CommentSticker>> fetchStickers(String videoUrl) async {
    if (_credential.isEmpty && apiGet == null) {
      throw const TikTokCommentException(
        'Comment scanning is not configured. Add SCRAPEBADGER_API_KEY to the app build.',
      );
    }

    final videoId = await _resolveVideoId(videoUrl);
    final found = <String, CommentSticker>{};
    String? cursor;

    try {
      for (var page = 0; page < maxPages; page++) {
        final query = <String, dynamic>{
          'region': 'US',
          'count': 50,
          'cursor': ?cursor,
        };
        final path = '/v1/tiktok/videos/$videoId/comments';
        final customGet = apiGet;
        final response = customGet != null
            ? await customGet(path, query)
            : await _dio.get<dynamic>(
                path,
                queryParameters: query,
                options: Options(responseType: ResponseType.json),
              );
        _throwForStatus(response.statusCode);
        final body = _asMap(response.data);
        if (body == null) {
          throw const TikTokCommentException(
            'The comment service returned an unreadable response.',
          );
        }

        for (final sticker in parseStickers(body)) {
          found.putIfAbsent(sticker.imageUrl, () => sticker);
        }

        final pagination = _asMap(body['pagination']);
        final hasMore = pagination?['has_more'] == true;
        final nextCursor = pagination?['cursor']?.toString();
        if (!hasMore || nextCursor == null || nextCursor == cursor) break;
        cursor = nextCursor;
      }
      return found.values.toList(growable: false);
    } on TikTokCommentException {
      rethrow;
    } on DioException catch (error) {
      throw TikTokCommentException(_messageForDio(error));
    } on SocketException {
      throw const TikTokCommentException(
        'No internet connection. Check your network and try again.',
      );
    }
  }

  List<CommentSticker> parseStickers(Map<String, dynamic> body) {
    final comments = body['comments'];
    if (comments is! List) return const [];

    final stickers = <CommentSticker>[];
    for (final raw in comments) {
      final comment = _asMap(raw);
      if (comment != null) _collectStickers(comment, stickers);
    }
    return stickers;
  }

  void _collectStickers(
    Map<String, dynamic> comment,
    List<CommentSticker> output,
  ) {
    output.addAll(CommentSticker.fromComment(comment));
    final replies = comment['replies'];
    if (replies is! List) return;
    for (final raw in replies) {
      final reply = _asMap(raw);
      if (reply != null) _collectStickers(reply, output);
    }
  }

  Future<File> downloadSticker(CommentSticker sticker) async {
    final directory = await _temporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}tiktok_comment_${DateTime.now().microsecondsSinceEpoch}.img',
    );
    try {
      final response = await _dio.download(sticker.imageUrl, file.path);
      _throwForImageStatus(response.statusCode);
      if (!file.existsSync() || file.lengthSync() == 0) {
        throw const TikTokCommentException(
          'TikTok returned an empty sticker image.',
        );
      }
      return file;
    } on TikTokCommentException {
      if (file.existsSync()) file.deleteSync();
      rethrow;
    } on DioException catch (error) {
      if (file.existsSync()) file.deleteSync();
      throw TikTokCommentException(_messageForDio(error));
    }
  }

  void _throwForImageStatus(int? status) {
    if (status != null && status >= 400) {
      throw const TikTokCommentException(
        'That comment sticker is no longer available.',
      );
    }
  }

  Future<String> _resolveVideoId(String videoUrl) async {
    final directId = _videoIdPattern.firstMatch(videoUrl)?.group(1);
    if (directId != null) return directId;
    final resolver = videoIdResolver;
    if (resolver == null) {
      throw const TikTokCommentException(
        'The shortened TikTok link could not be resolved.',
      );
    }
    try {
      final id = (await resolver(videoUrl)).trim();
      if (!RegExp(r'^\d+$').hasMatch(id)) {
        throw const TikTokCommentException(
          'TikTok did not return a valid video ID.',
        );
      }
      return id;
    } catch (error) {
      if (error is TikTokCommentException) rethrow;
      throw TikTokCommentException(
        'Could not resolve that TikTok link: $error',
      );
    }
  }

  void _throwForStatus(int? status) {
    if (status == null || status < 400) return;
    if (status == 401 || status == 403) {
      throw const TikTokCommentException(
        'Comment scanning is not authorized. Check the ScrapeBadger API key.',
      );
    }
    if (status == 402 || status == 429) {
      throw const TikTokCommentException(
        'The comment scan limit has been reached. Please try again later.',
      );
    }
    throw const TikTokCommentException(
      'TikTok comments are unavailable right now. Please try again.',
    );
  }

  String _messageForDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The comment scan timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'Could not connect to the comment service.';
      default:
        return 'Could not scan TikTok comments. Please try again.';
    }
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

final tikTokCommentServiceProvider = Provider<TikTokCommentService>((ref) {
  final importService = ref.watch(tiktokImportServiceProvider);
  return TikTokCommentService(
    videoIdResolver: (url) async => (await importService.resolveVideo(url)).id,
  );
});
