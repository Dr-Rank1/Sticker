import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../l10n/l10n.dart';
import 'tiktok_comment_service.dart';

/// Downloads sticker images with a hard cap on in-flight HTTP connections.
class QueuedImageDownloader {
  QueuedImageDownloader({
    Dio? dio,
    this.maxConcurrent = defaultMaxConcurrent,
    this.save,
  }) : _dio = dio ?? Dio(_defaultOptions);

  static const defaultMaxConcurrent = 5;

  static final _defaultOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 15),
    followRedirects: true,
    responseType: ResponseType.bytes,
  );

  final Dio _dio;
  final int maxConcurrent;
  final Future<void> Function(String url, String savePath)? save;

  Future<void> downloadAll({
    required List<CommentSticker> stickers,
    required String directory,
    required void Function(int downloaded, int total, CommentSticker? ready)
    onProgress,
  }) async {
    final pending = List<CommentSticker>.from(stickers);
    final total = stickers.length;
    var downloaded = 0;

    Future<void> worker() async {
      while (pending.isNotEmpty) {
        final sticker = pending.removeAt(0);
        CommentSticker? ready;
        try {
          ready = await _downloadOne(sticker, directory);
        } catch (_) {
          ready = null;
        }
        downloaded += 1;
        onProgress(downloaded, total, ready);
      }
    }

    final workers = math.min(maxConcurrent, stickers.length);
    if (workers <= 0) {
      onProgress(0, 0, null);
      return;
    }
    await Future.wait(List<Future<void>>.generate(workers, (_) => worker()));
  }

  Future<CommentSticker> _downloadOne(
    CommentSticker sticker,
    String directory,
  ) async {
    final safeId = sticker.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final path = '$directory${Platform.pathSeparator}comment_$safeId.img';
    final customSave = save;
    if (customSave != null) {
      await customSave(sticker.imageUrl, path);
    } else {
      final response = await _dio.get<List<int>>(sticker.imageUrl);
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw TikTokCommentException(
          serviceLocalizations.emptyTikTokStickerImage,
        );
      }
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return sticker.copyWith(localPath: path);
  }
}
