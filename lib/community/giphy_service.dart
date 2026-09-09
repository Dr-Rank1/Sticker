import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import '../l10n/l10n.dart';
import '../storage/storage_utility.dart';

class GiphyException implements Exception {
  const GiphyException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GiphyRateLimitException extends GiphyException {
  GiphyRateLimitException() : super(serviceLocalizations.giphyRateLimitReached);
}

@immutable
class GiphySticker {
  const GiphySticker({
    required this.id,
    required this.title,
    required this.url,
    required this.width,
    required this.height,
  });

  final String id;
  final String title;
  final String url;
  final int width;
  final int height;

  double get aspectRatio {
    if (width <= 0 || height <= 0) return 1;
    return (width / height).clamp(0.65, 1.5);
  }

  bool get animated => true;
}

class GiphyStickerPage {
  const GiphyStickerPage({required this.stickers, required this.nextOffset});

  final List<GiphySticker> stickers;
  final int? nextOffset;
}

typedef GiphyApiGet = Future<Response<dynamic>> Function(
  String path,
  Map<String, dynamic> queryParameters,
);

class GiphyService {
  GiphyService({
    Dio? dio,
    String apiKey = AppEnvironment.giphyApiKey,
    this.apiGet,
    Future<Directory> Function()? temporaryDirectory,
  }) : _dio = dio ?? Dio(),
       _apiKey = apiKey.trim(),
       _temporaryDirectory =
           temporaryDirectory ?? (() => getStickrTemporaryDirectory());

  static const endpoint = 'https://api.giphy.com/v1/stickers/trending';
  static const searchEndpoint = 'https://api.giphy.com/v1/stickers/search';
  static const pageSize = 50;

  final Dio _dio;
  final String _apiKey;
  final GiphyApiGet? apiGet;
  final Future<Directory> Function() _temporaryDirectory;

  bool get hasApiKey => _apiKey.isNotEmpty;

  Future<GiphyStickerPage> fetchTrending({int offset = 0}) async {
    if (!hasApiKey) {
      throw GiphyException(serviceLocalizations.giphyTrendingUnavailable);
    }

    final parameters = <String, dynamic>{
      'api_key': _apiKey,
      'limit': pageSize,
      'rating': 'g',
      'offset': offset,
    };

    return _fetchPage(
      endpoint: endpoint,
      parameters: parameters,
      fallbackMessage: serviceLocalizations.couldNotLoadTrending,
    );
  }

  Future<GiphyStickerPage> search(String query, {int offset = 0}) async {
    final term = query.trim();
    if (term.isEmpty) {
      throw GiphyException(serviceLocalizations.giphySearchRequired);
    }
    if (!hasApiKey) {
      throw GiphyException(serviceLocalizations.giphySearchUnavailable);
    }

    return _fetchPage(
      endpoint: searchEndpoint,
      parameters: <String, dynamic>{
        'api_key': _apiKey,
        'q': term,
        'limit': pageSize,
        'rating': 'g',
        'offset': offset,
      },
      fallbackMessage: serviceLocalizations.couldNotSearchGiphy,
    );
  }

  Future<File> downloadSticker({
    required String id,
    required String url,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      throw GiphyException(serviceLocalizations.invalidStickerDownloadUrl);
    }

    final directory = await _temporaryDirectory();
    final safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final extension = uri.path.toLowerCase().endsWith('.webp') ? 'webp' : 'gif';
    final file = File(
      '${directory.path}${Platform.pathSeparator}giphy_${safeId.isEmpty ? 'sticker' : safeId}_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    try {
      await _dio.download(url, file.path);
      if (!await file.exists() || await file.length() == 0) {
        throw GiphyException(serviceLocalizations.giphyEmptySticker);
      }
      return file;
    } on GiphyException {
      rethrow;
    } on DioException catch (error) {
      if (await file.exists()) await file.delete();
      throw _fromDio(error);
    } catch (_) {
      if (await file.exists()) await file.delete();
      throw GiphyException(serviceLocalizations.stickerDownloadFailed);
    }
  }

  GiphyStickerPage _parseResponse(dynamic responseData) {
    final response = _asMap(responseData);
    final rawData = response?['data'];
    if (rawData is! List) {
      throw const FormatException('Missing Giphy sticker data.');
    }

    final stickers = <GiphySticker>[];
    for (final raw in rawData) {
      final item = _asMap(raw);
      final images = _asMap(item?['images']);
      final image =
          _asMap(images?['fixed_height']) ?? _asMap(images?['original']);
      final url =
          image?['webp']?.toString().trim() ??
          image?['url']?.toString().trim() ??
          '';
      final uri = Uri.tryParse(url);
      if (item == null ||
          image == null ||
          uri == null ||
          !(uri.scheme == 'https' || uri.scheme == 'http')) {
        continue;
      }
      stickers.add(
        GiphySticker(
          id: item['id']?.toString() ?? 'giphy_${stickers.length}',
          title:
              item['title']?.toString().trim() ??
              serviceLocalizations.trendingSticker,
          url: url,
          width: _asInt(image['width']),
          height: _asInt(image['height']),
        ),
      );
    }

    final pagination = _asMap(response?['pagination']);
    final offset = _asInt(pagination?['offset']);
    final count = _asInt(pagination?['count']);
    final total = _asInt(pagination?['total_count']);
    final nextOffset = count > 0 && offset + count < total
        ? offset + count
        : null;
    return GiphyStickerPage(stickers: stickers, nextOffset: nextOffset);
  }

  Future<GiphyStickerPage> _fetchPage({
    required String endpoint,
    required Map<String, dynamic> parameters,
    required String fallbackMessage,
  }) async {
    try {
      final customGet = apiGet;
      final response = customGet != null
          ? await customGet(endpoint, parameters)
          : await _dio.get<dynamic>(
              endpoint,
              queryParameters: parameters,
              options: Options(responseType: ResponseType.json),
            );
      return _parseResponse(response.data);
    } on GiphyException {
      rethrow;
    } on DioException catch (error) {
      throw _fromDio(error);
    } on FormatException {
      throw GiphyException(serviceLocalizations.giphyUnreadableResponse);
    } on SocketException {
      throw GiphyException(serviceLocalizations.giphyConnectionFailed);
    } catch (_) {
      throw GiphyException(fallbackMessage);
    }
  }

  GiphyException _fromDio(DioException error) {
    final status = error.response?.statusCode;
    if (status == 429) return GiphyRateLimitException();
    if (status == 401 || status == 403) {
      return GiphyException(serviceLocalizations.giphyRejectedApiKey);
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return GiphyException(serviceLocalizations.giphyTimedOut);
      case DioExceptionType.connectionError:
        return GiphyException(serviceLocalizations.giphyConnectionFailed);
      default:
        return GiphyException(serviceLocalizations.giphyRequestFailed);
    }
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

final giphyServiceProvider = Provider<GiphyService>((ref) {
  return GiphyService();
});
