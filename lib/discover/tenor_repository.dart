import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class TenorConfig {
  TenorConfig._();

  /// Supply at build/run time with:
  /// `--dart-define=TENOR_API_KEY=your_google_tenor_key`
  static const apiKey = String.fromEnvironment('TENOR_API_KEY');
  static const clientKey = 'stikk';
}

@immutable
class TenorSticker {
  const TenorSticker({
    required this.id,
    required this.title,
    required this.webpUrl,
    required this.width,
    required this.height,
    required this.duration,
  });

  final String id;
  final String title;
  final String webpUrl;
  final int width;
  final int height;
  final double duration;

  double get aspectRatio {
    if (width <= 0 || height <= 0) return 1;
    return (width / height).clamp(0.65, 1.5);
  }

  bool get animated => duration > 0;
}

class TenorSearchPage {
  const TenorSearchPage({required this.results, required this.next});

  final List<TenorSticker> results;
  final String? next;
}

class TenorException implements Exception {
  const TenorException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef TenorApiGet = Future<Response<dynamic>> Function(
  String path,
  Map<String, dynamic> queryParameters,
);

typedef TenorFileDownload = Future<void> Function(
  String url,
  String destination,
  void Function(int received, int total)? onProgress,
);

class TenorRepository {
  TenorRepository({
    Dio? dio,
    String apiKey = TenorConfig.apiKey,
    Future<Directory> Function()? temporaryDirectory,
    this.apiGet,
    this.fileDownload,
  }) : _dio = dio ?? createDio(),
       _apiKey = apiKey.trim(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  static const baseUrl = 'https://tenor.googleapis.com';
  static const searchPath = '/v2/search';
  static const stickerFilter = 'sticker';
  static const transparentMediaFilter = 'webp_transparent';

  final Dio _dio;
  final String _apiKey;
  final Future<Directory> Function() _temporaryDirectory;
  final TenorApiGet? apiGet;
  final TenorFileDownload? fileDownload;

  bool get hasApiKey => _apiKey.isNotEmpty;

  static Dio createDio() {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
        headers: const {'Accept': 'application/json'},
        validateStatus: (status) => status != null && status < 400,
      ),
    );
  }

  Future<TenorSearchPage> search(
    String query, {
    int limit = 24,
    String? position,
  }) async {
    final term = query.trim();
    if (term.isEmpty) {
      throw const TenorException('Type something to search for stickers.');
    }
    if (!hasApiKey) {
      throw const TenorException(
        'Discover needs a Tenor API key. Add TENOR_API_KEY when running the app.',
      );
    }

    final parameters = <String, dynamic>{
      'q': term,
      'key': _apiKey,
      'client_key': TenorConfig.clientKey,
      'limit': limit.clamp(1, 50),
      'searchfilter': stickerFilter,
      'media_filter': transparentMediaFilter,
      'contentfilter': 'medium',
      if (position != null && position.isNotEmpty) 'pos': position,
    };

    try {
      final customGet = apiGet;
      final response = customGet != null
          ? await customGet(searchPath, parameters)
          : await _dio.get<dynamic>(
              searchPath,
              queryParameters: parameters,
              options: Options(responseType: ResponseType.json),
            );
      return _parseSearchResponse(_asMap(response.data));
    } on TenorException {
      rethrow;
    } on DioException catch (error) {
      throw TenorException(_messageForDio(error));
    } on FormatException {
      throw const TenorException(
        'Tenor returned an unreadable response. Please try again.',
      );
    } on SocketException {
      throw const TenorException(
        'No internet connection. Check your network and try again.',
      );
    }
  }

  Future<File> downloadSticker(
    TenorSticker sticker, {
    void Function(double? progress)? onProgress,
  }) async {
    final uri = Uri.tryParse(sticker.webpUrl);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      throw const TenorException('That sticker has an invalid download link.');
    }

    final temporary = await _temporaryDirectory();
    final safeId = sticker.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final file = File(
      '${temporary.path}${Platform.pathSeparator}stikk_tenor_${safeId.isEmpty ? 'sticker' : safeId}_${DateTime.now().millisecondsSinceEpoch}.webp',
    );

    try {
      final customDownload = fileDownload;
      if (customDownload != null) {
        await customDownload(sticker.webpUrl, file.path, (received, total) {
          onProgress?.call(total > 0 ? received / total : null);
        });
      } else {
        await _dio.download(
          sticker.webpUrl,
          file.path,
          onReceiveProgress: (received, total) {
            onProgress?.call(total > 0 ? received / total : null);
          },
          options: Options(
            followRedirects: true,
            validateStatus: (status) => status != null && status < 400,
          ),
        );
      }
    } on DioException catch (error) {
      await _deleteIfPresent(file);
      throw TenorException(_messageForDio(error, downloading: true));
    } catch (error) {
      await _deleteIfPresent(file);
      if (error is TenorException) rethrow;
      throw const TenorException(
        'Couldn’t download that sticker. Please try again.',
      );
    }

    if (!await file.exists() || await file.length() == 0) {
      await _deleteIfPresent(file);
      throw const TenorException('Tenor downloaded an empty sticker.');
    }
    return file;
  }

  TenorSearchPage _parseSearchResponse(Map<String, dynamic> body) {
    final rawResults = body['results'];
    if (rawResults is! List) {
      throw const FormatException('Missing results.');
    }

    final stickers = <TenorSticker>[];
    for (final raw in rawResults) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final rawFormats = item['media_formats'];
      if (rawFormats is! Map) continue;
      final formats = Map<String, dynamic>.from(rawFormats);
      final rawTransparent = formats[transparentMediaFilter];
      if (rawTransparent is! Map) continue;
      final transparent = Map<String, dynamic>.from(rawTransparent);
      final url = transparent['url']?.toString().trim() ?? '';
      final uri = Uri.tryParse(url);
      if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
        continue;
      }

      final dimensions = transparent['dims'];
      final width = dimensions is List && dimensions.isNotEmpty
          ? _asInt(dimensions[0])
          : 0;
      final height = dimensions is List && dimensions.length > 1
          ? _asInt(dimensions[1])
          : 0;
      stickers.add(
        TenorSticker(
          id: item['id']?.toString() ?? 'tenor_${stickers.length}',
          title: (item['content_description'] ?? item['title'] ?? 'Sticker')
              .toString(),
          webpUrl: url,
          width: width,
          height: height,
          duration: _asDouble(transparent['duration']),
        ),
      );
    }

    final nextValue = body['next']?.toString();
    return TenorSearchPage(
      results: stickers,
      next: nextValue == null || nextValue.isEmpty ? null : nextValue,
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw const FormatException('Expected a JSON object.');
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _messageForDio(DioException error, {bool downloading = false}) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Tenor took too long to respond. Please try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Check your network and try again.';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == 401 || status == 403) {
          return 'The Tenor API key is missing or invalid.';
        }
        if (status == 429) {
          return 'Tenor’s search limit was reached. Wait a moment and try again.';
        }
        return downloading
            ? 'Tenor couldn’t download that sticker.'
            : 'Tenor search is unavailable right now. Please try again.';
      case DioExceptionType.cancel:
        return downloading
            ? 'The sticker download was cancelled.'
            : 'The search was cancelled.';
      default:
        return downloading
            ? 'Couldn’t download that sticker. Please try again.'
            : 'Couldn’t search Tenor. Please try again.';
    }
  }

  Future<void> _deleteIfPresent(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // The OS may have already evicted the temporary file.
    }
  }
}

final tenorRepositoryProvider = Provider<TenorRepository>((ref) {
  return TenorRepository();
});
