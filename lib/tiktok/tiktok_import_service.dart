import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tiktok_scraper/enums.dart';
import 'package:tiktok_scraper/tiktok_scraper.dart';

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

typedef TiktokVideoResolver = Future<TiktokVideo> Function(
  String url, {
  required ScrapeVideoSource source,
});

/// Resolves a TikTok share link to a watermark-free MP4 and stores it in temp.
class TiktokImportService {
  TiktokImportService({
    Dio? dio,
    Future<Directory> Function()? tempDirectory,
    TiktokVideoResolver? resolveWithSource,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 90),
                sendTimeout: const Duration(seconds: 20),
                followRedirects: true,
                maxRedirects: 8,
                headers: {
                  'User-Agent': desktopUserAgent,
                  'Referer': 'https://www.tiktok.com/',
                },
              ),
            ),
        _tempDirectory = tempDirectory ?? getTemporaryDirectory,
        _resolveWithSource = resolveWithSource ?? _defaultResolve;

  static const desktopUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';

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
  final TiktokVideoResolver _resolveWithSource;

  static Future<TiktokVideo> _defaultResolve(
    String url, {
    required ScrapeVideoSource source,
  }) {
    return TiktokScraper.getVideoInfo(url, source: source);
  }

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
      throw const TiktokImportException(
        'That doesn\'t look like a TikTok link. Paste a video URL and try again.',
      );
    }

    onProgress?.call(const TiktokImportProgress.resolving());

    final video = await _resolveVideo(url);
    final downloadUrls = _preferWatermarkFree(video.downloadUrls);
    if (downloadUrls.isEmpty) {
      throw const TiktokImportException(
        'We found the TikTok, but it doesn\'t have a downloadable video.',
      );
    }

    onProgress?.call(const TiktokImportProgress.downloading(0));

    Object? lastError;
    for (final downloadUrl in downloadUrls) {
      try {
        final file = await _downloadToTemp(
          downloadUrl: downloadUrl,
          videoId: video.id,
          onReceiveProgress: (received, total) {
            final value = total > 0 ? (received / total).clamp(0.0, 1.0) : null;
            onProgress?.call(TiktokImportProgress.downloading(value));
          },
        );
        return TiktokImportResult(
          file: file,
          videoId: video.id,
          caption: video.description == 'null' ? '' : video.description,
          sourceUrl: url,
        );
      } catch (error) {
        lastError = error;
      }
    }

    throw lastError ??
        const TiktokImportException(
          'We couldn\'t download that video. Try another link.',
        );
  }

  Future<TiktokVideo> _resolveVideo(String url) async {
    try {
      final video = await _resolveWithSource(
        url,
        source: ScrapeVideoSource.TikDownloader,
      );
      if (video.downloadUrls.isNotEmpty) return video;
    } catch (_) {
      // Fall through to the official page scrape.
    }

    try {
      final video = await _resolveWithSource(
        url,
        source: ScrapeVideoSource.OfficialSite,
      );
      if (video.downloadUrls.isNotEmpty) return video;
    } on TikTokException catch (error) {
      throw TiktokImportException(_friendlyScrapeMessage(error.message));
    }

    throw const TiktokImportException(
      'We couldn\'t find a video at that link. Check it and try again.',
    );
  }

  Future<File> _downloadToTemp({
    required String downloadUrl,
    required String videoId,
    required ProgressCallback onReceiveProgress,
  }) async {
    final directory = await _tempDirectory();
    final safeId = videoId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final file = File(
      '${directory.path}/stikk_${safeId}_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    await _dio.download(
      downloadUrl,
      file.path,
      onReceiveProgress: onReceiveProgress,
      options: Options(
        headers: {
          'User-Agent': desktopUserAgent,
          'Referer': 'https://www.tiktok.com/',
          'Origin': 'https://www.tiktok.com',
        },
        followRedirects: true,
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    if (!file.existsSync() || file.lengthSync() == 0) {
      throw const TiktokImportException(
        'The download finished, but the video file was empty.',
      );
    }

    return file;
  }

  String describeError(Object error) {
    if (error is TiktokImportException) return error.message;
    if (error is TikTokException) return _friendlyScrapeMessage(error.message);
    if (error is DioException) return _friendlyDioMessage(error);
    if (error is SocketException) {
      return 'No internet connection. Check your network and try again.';
    }
    return 'Something went wrong while importing that TikTok. Please try again.';
  }

  List<String> _preferWatermarkFree(List<String> urls) {
    final unique = <String>[];
    for (final url in urls) {
      if (url.isEmpty || url == 'null') continue;
      if (!unique.contains(url)) unique.add(url);
    }

    final clean = unique.where((url) => !url.contains('watermark=1')).toList();
    if (clean.isEmpty) return unique;
    return [...clean, ...unique.where((url) => !clean.contains(url))];
  }

  String _friendlyScrapeMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('no records') || lower.contains('not found')) {
      return 'We couldn\'t find that TikTok. Check the link and try again.';
    }
    if (lower.contains('rate limit')) {
      return 'TikTok is busy right now. Wait a moment and try again.';
    }
    return 'We couldn\'t open that TikTok. Check the link and try again.';
  }

  String _friendlyDioMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The connection timed out. Try again on a stronger network.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Check your network and try again.';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 404) {
          return 'That TikTok is unavailable. It may have been removed.';
        }
        if (code == 403) {
          return 'TikTok blocked the download. Try a different video.';
        }
        return 'We couldn\'t download that video right now. Please try again.';
      case DioExceptionType.cancel:
        return 'The download was cancelled.';
      default:
        if (error.error is SocketException) {
          return 'No internet connection. Check your network and try again.';
        }
        return 'Something went wrong while downloading. Please try again.';
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
