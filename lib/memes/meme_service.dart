import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

@immutable
class MemeTemplate {
  const MemeTemplate({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.width,
    required this.height,
  });

  final String id;
  final String name;
  final String imageUrl;
  final int width;
  final int height;

  double get aspectRatio {
    if (width <= 0 || height <= 0) return 1;
    return (width / height).clamp(0.65, 1.5);
  }
}

class MemeServiceException implements Exception {
  const MemeServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef ImgflipApiGet = Future<Response<dynamic>> Function(String path);

typedef MemeFileDownload = Future<void> Function(
  String url,
  String destination,
  void Function(int received, int total)? onProgress,
);

class MemeService {
  MemeService({
    Dio? dio,
    Future<Directory> Function()? temporaryDirectory,
    this.apiGet,
    this.fileDownload,
  }) : _dio = dio ?? createDio(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  static const baseUrl = 'https://api.imgflip.com';
  static const memesPath = '/get_memes';

  final Dio _dio;
  final Future<Directory> Function() _temporaryDirectory;
  final ImgflipApiGet? apiGet;
  final MemeFileDownload? fileDownload;

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

  Future<List<MemeTemplate>> getTemplates() async {
    try {
      final customGet = apiGet;
      final response = customGet != null
          ? await customGet(memesPath)
          : await _dio.get<dynamic>(
              memesPath,
              options: Options(responseType: ResponseType.json),
            );
      return parseTemplates(_asMap(response.data));
    } on MemeServiceException {
      rethrow;
    } on DioException catch (error) {
      throw MemeServiceException(_messageForDio(error));
    } on FormatException {
      throw const MemeServiceException(
        'Imgflip returned an unreadable response. Please try again.',
      );
    } on SocketException {
      throw const MemeServiceException(
        'No internet connection. Check your network and try again.',
      );
    }
  }

  List<MemeTemplate> parseTemplates(Map<String, dynamic> body) {
    if (body['success'] != true) {
      final message = body['error_message']?.toString().trim();
      throw MemeServiceException(
        message == null || message.isEmpty
            ? 'Imgflip couldn’t load meme templates right now.'
            : message,
      );
    }

    final rawData = body['data'];
    if (rawData is! Map) throw const FormatException('Missing meme data.');
    final rawMemes = rawData['memes'];
    if (rawMemes is! List) throw const FormatException('Missing meme list.');

    final templates = <MemeTemplate>[];
    for (final raw in rawMemes) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final url = item['url']?.toString().trim() ?? '';
      final uri = Uri.tryParse(url);
      if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
        continue;
      }
      templates.add(
        MemeTemplate(
          id: item['id']?.toString() ?? 'meme_${templates.length}',
          name: item['name']?.toString().trim() ?? 'Meme template',
          imageUrl: url,
          width: _asInt(item['width']),
          height: _asInt(item['height']),
        ),
      );
    }
    return templates;
  }

  Future<File> downloadTemplate(
    MemeTemplate template, {
    void Function(double? progress)? onProgress,
  }) async {
    final uri = Uri.tryParse(template.imageUrl);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      throw const MemeServiceException(
        'That meme template has an invalid image link.',
      );
    }

    final temporary = await _temporaryDirectory();
    final safeId = template.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final extension = uri.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final file = File(
      '${temporary.path}${Platform.pathSeparator}stickr_meme_${safeId.isEmpty ? 'template' : safeId}_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );

    try {
      final customDownload = fileDownload;
      if (customDownload != null) {
        await customDownload(template.imageUrl, file.path, (received, total) {
          onProgress?.call(total > 0 ? received / total : null);
        });
      } else {
        await _dio.download(
          template.imageUrl,
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
      throw MemeServiceException(_messageForDio(error, downloading: true));
    } catch (error) {
      await _deleteIfPresent(file);
      if (error is MemeServiceException) rethrow;
      throw const MemeServiceException(
        'Couldn’t download that meme template. Please try again.',
      );
    }

    if (!await file.exists() || await file.length() == 0) {
      await _deleteIfPresent(file);
      throw const MemeServiceException(
        'Imgflip downloaded an empty meme template.',
      );
    }
    return file;
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

  String _messageForDio(DioException error, {bool downloading = false}) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Imgflip took too long to respond. Please try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Check your network and try again.';
      case DioExceptionType.badResponse:
        if (error.response?.statusCode == 429) {
          return 'Imgflip is busy right now. Wait a moment and try again.';
        }
        return downloading
            ? 'Imgflip couldn’t download that template.'
            : 'Imgflip templates are unavailable right now.';
      case DioExceptionType.cancel:
        return downloading
            ? 'The template download was cancelled.'
            : 'Loading meme templates was cancelled.';
      default:
        return downloading
            ? 'Couldn’t download that meme template. Please try again.'
            : 'Couldn’t load meme templates. Please try again.';
    }
  }

  Future<void> _deleteIfPresent(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // The OS may already have evicted this temporary file.
    }
  }
}

final memeServiceProvider = Provider<MemeService>((ref) {
  return MemeService();
});
