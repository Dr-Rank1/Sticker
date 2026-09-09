import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../l10n/l10n.dart';
import '../storage/storage_utility.dart';

class TiktokImportException implements Exception {
  const TiktokImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TiktokImportResult {
  const TiktokImportResult({
    required this.file,
    required this.videoId,
    required this.caption,
    required this.sourceUrl,
  });

  final File file;
  final String videoId;
  final String caption;
  final String sourceUrl;
}

class TikwmVideo {
  const TikwmVideo({
    required this.playUrl,
    required this.id,
    required this.caption,
  });

  final String playUrl;
  final String id;
  final String caption;
}

typedef TikwmApiGet = Future<Response<dynamic>> Function(
  String path,
  Map<String, dynamic> queryParameters,
);

/// Resolves a TikTok share link through TikWM, then stores its clean MP4 in
/// Stickr's temporary directory for the existing FFmpeg editor pipeline.
class TiktokImportService {
  TiktokImportService({
    Dio? dio,
    Future<Directory> Function()? tempDirectory,
    this.apiGet,
  }) : _dio = dio ?? createDio(),
       _tempDirectory = tempDirectory ?? (() => getStickrTemporaryDirectory());

  static const apiBaseUrl = 'https://www.tikwm.com';
  static const apiPath = '/api/';
  static const desktopUserAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';

  static Dio createDio() {
    return Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 20),
        followRedirects: true,
        maxRedirects: 8,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': desktopUserAgent,
        },
        validateStatus: (status) => status != null && status < 400,
      ),
    );
  }

  static final _urlWithScheme = RegExp(
    r'https?://(?:www\.|m\.|vm\.|vt\.)?tiktok\.com/[^\s]+',
    caseSensitive: false,
  );

  static final _urlBare = RegExp(
    r'(?:www\.|m\.|vm\.|vt\.)?tiktok\.com/[^\s]+',
    caseSensitive: false,
  );

  final Dio _dio;
  final Future<Directory> Function() _tempDirectory;
  final TikwmApiGet? apiGet;

  /// Pulls a TikTok URL out of messy clipboard text.
  String? extractTikTokUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final withScheme = _urlWithScheme.firstMatch(trimmed)?.group(0);
    if (withScheme != null) {
      return _stripTrailingPunctuation(withScheme);
    }

    final bare = _urlBare.firstMatch(trimmed)?.group(0);
    if (bare != null) {
      return _stripTrailingPunctuation('https://$bare');
    }

    return null;
  }

  bool isValidTikTokUrl(String raw) {
    final url = extractTikTokUrl(raw);
    if (url == null) return false;

    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    if (!uri.host.toLowerCase().endsWith('tiktok.com')) return false;

    final host = uri.host.toLowerCase();
    final path = uri.path;
    return path.contains('/video/') ||
        host.startsWith('vm.') ||
        host.startsWith('vt.') ||
        path.startsWith('/t/');
  }

  Future<TiktokImportResult> import({
    required String rawLink,
    void Function(TiktokImportProgress progress)? onProgress,
  }) async {
    final url = extractTikTokUrl(rawLink);
    if (url == null || !isValidTikTokUrl(url)) {
      throw TiktokImportException(serviceLocalizations.invalidTikTokLink);
    }

    onProgress?.call(const TiktokImportProgress.resolving());
    final video = await resolveVideo(url);

    onProgress?.call(const TiktokImportProgress.downloading(0));
    try {
      final file = await _downloadToTemp(
        downloadUrl: video.playUrl,
        videoId: video.id,
        onReceiveProgress: (received, total) {
          final value = total > 0 ? (received / total).clamp(0.0, 1.0) : null;
          onProgress?.call(TiktokImportProgress.downloading(value));
        },
      );
      return TiktokImportResult(
        file: file,
        videoId: video.id,
        caption: video.caption,
        sourceUrl: url,
      );
    } on TiktokImportException {
      rethrow;
    } on DioException catch (error) {
      throw TiktokImportException(_friendlyDioMessage(error));
    } on SocketException {
      throw TiktokImportException(serviceLocalizations.noInternetConnection);
    }
  }

  /// Calls `GET /api/?url=<TikTok URL>` and extracts TikWM's `data.play`.
  Future<TikwmVideo> resolveVideo(String url) async {
    try {
      final query = <String, dynamic>{'url': url};
      final customGet = apiGet;
      final response = customGet != null
          ? await customGet(apiPath, query)
          : await _dio.get<dynamic>(
              apiPath,
              queryParameters: query,
              options: Options(responseType: ResponseType.json),
            );
      final body = _asJsonMap(response.data);
      return parseTikwmResponse(body);
    } on TiktokImportException {
      rethrow;
    } on DioException catch (error) {
      throw TiktokImportException(_friendlyDioMessage(error, resolving: true));
    } on FormatException {
      throw TiktokImportException(serviceLocalizations.unreadableTikwmResponse);
    } on SocketException {
      throw TiktokImportException(serviceLocalizations.noInternetConnection);
    }
  }

  TikwmVideo parseTikwmResponse(Map<String, dynamic> body) {
    final code = _numericCode(body['code']);
    final message = (body['msg'] ?? body['message'] ?? '').toString().trim();

    if (code != 0) {
      throw TiktokImportException(_messageForApiError(code, message));
    }

    final rawData = body['data'];
    if (rawData is! Map) {
      throw TiktokImportException(serviceLocalizations.tikwmVideoNotFound);
    }
    final data = Map<String, dynamic>.from(rawData);
    final play = data['play']?.toString().trim() ?? '';
    final playUri = Uri.tryParse(play);
    if (play.isEmpty ||
        playUri == null ||
        !(playUri.scheme == 'http' || playUri.scheme == 'https')) {
      throw TiktokImportException(serviceLocalizations.tikwmNoDownload);
    }

    final id = data['id']?.toString().trim();
    final caption = data['title']?.toString().trim();
    return TikwmVideo(
      playUrl: play,
      id: (id == null || id.isEmpty)
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : id,
      caption: caption == null || caption == 'null' ? '' : caption,
    );
  }

  Future<File> _downloadToTemp({
    required String downloadUrl,
    required String videoId,
    required ProgressCallback onReceiveProgress,
  }) async {
    final directory = await _tempDirectory();
    final safeId = videoId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final effectiveId = safeId.isEmpty
        ? DateTime.now().millisecondsSinceEpoch
        : safeId;
    final file = File(
      '${directory.path}${Platform.pathSeparator}stickr_${effectiveId}_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    try {
      await _dio.download(
        downloadUrl,
        file.path,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          headers: const {'User-Agent': desktopUserAgent},
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
    } catch (_) {
      await _deletePartialDownload(file);
      rethrow;
    }

    if (!file.existsSync() || file.lengthSync() == 0) {
      await _deletePartialDownload(file);
      throw TiktokImportException(serviceLocalizations.emptyVideoDownload);
    }
    return file;
  }

  String describeError(Object error) {
    if (error is TiktokImportException) return error.message;
    if (error is DioException) return _friendlyDioMessage(error);
    if (error is SocketException) {
      return serviceLocalizations.noInternetConnection;
    }
    return serviceLocalizations.tiktokImportFailed;
  }

  Map<String, dynamic> _asJsonMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw const FormatException('Expected a JSON object.');
  }

  int _numericCode(dynamic raw) {
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? -1;
  }

  String _messageForApiError(int code, String message) {
    final lower = message.toLowerCase();
    if (code == 429 ||
        lower.contains('rate') ||
        lower.contains('too many') ||
        lower.contains('limit')) {
      return serviceLocalizations.tikwmRateLimited;
    }
    if (code == 400 ||
        code == 404 ||
        lower.contains('invalid') ||
        lower.contains('not found') ||
        lower.contains('url')) {
      return serviceLocalizations.tikwmTikTokNotFound;
    }
    return serviceLocalizations.tikwmProcessFailed;
  }

  String _friendlyDioMessage(DioException error, {bool resolving = false}) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return serviceLocalizations.connectionTimedOut;
      case DioExceptionType.connectionError:
        return serviceLocalizations.noInternetConnection;
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 429) {
          return serviceLocalizations.tikwmRateLimited;
        }
        if (code == 400 || code == 404) {
          return serviceLocalizations.tikwmTikTokNotFound;
        }
        return resolving
            ? serviceLocalizations.tikwmLookupFailed
            : serviceLocalizations.videoDownloadFailed;
      case DioExceptionType.cancel:
        return serviceLocalizations.downloadCancelled;
      default:
        if (error.error is SocketException) {
          return serviceLocalizations.noInternetConnection;
        }
        return resolving
            ? serviceLocalizations.tikwmLookupFailed
            : serviceLocalizations.downloadFailed;
    }
  }

  Future<void> _deletePartialDownload(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // The OS may already have removed the temporary partial download.
    }
  }

  String _stripTrailingPunctuation(String url) {
    return url.replaceAll(RegExp(r'[).,]+$'), '');
  }
}

enum TiktokImportStage { resolving, downloading }

class TiktokImportProgress {
  const TiktokImportProgress.resolving()
    : stage = TiktokImportStage.resolving,
      fraction = null;

  const TiktokImportProgress.downloading(this.fraction)
    : stage = TiktokImportStage.downloading;

  final TiktokImportStage stage;

  /// `null` means the server did not report a total size yet.
  final double? fraction;
}
