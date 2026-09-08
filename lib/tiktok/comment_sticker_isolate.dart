import 'dart:async';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'queued_image_downloader.dart';
import 'tiktok_comment_service.dart';

/// Live download progress sent from the worker isolate to the UI isolate.
class CommentStickerProgress {
  const CommentStickerProgress({
    required this.downloaded,
    required this.total,
    this.sticker,
    this.done = false,
    this.error,
  });

  final int downloaded;
  final int total;
  final CommentSticker? sticker;
  final bool done;
  final String? error;

  Map<String, Object?> toMap() {
    return {
      'downloaded': downloaded,
      'total': total,
      'done': done,
      if (sticker != null) 'sticker': sticker!.toJson(),
      if (error != null) 'error': error,
    };
  }

  factory CommentStickerProgress.fromMap(Map<String, dynamic> map) {
    final rawSticker = map['sticker'];
    return CommentStickerProgress(
      downloaded: (map['downloaded'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      done: map['done'] == true,
      error: map['error']?.toString(),
      sticker: rawSticker is Map
          ? CommentSticker.fromJson(Map<String, dynamic>.from(rawSticker))
          : null,
    );
  }
}

/// Prefetches comment sticker images off the UI isolate.
abstract class CommentStickerPipeline {
  Stream<CommentStickerProgress> download({
    required List<CommentSticker> stickers,
    required String directory,
  });
}

/// Yields stickers immediately without hitting the network (tests / offline).
class ImmediateCommentStickerPipeline implements CommentStickerPipeline {
  @override
  Stream<CommentStickerProgress> download({
    required List<CommentSticker> stickers,
    required String directory,
  }) async* {
    final total = stickers.length;
    yield CommentStickerProgress(downloaded: 0, total: total);
    for (var i = 0; i < stickers.length; i++) {
      yield CommentStickerProgress(
        downloaded: i + 1,
        total: total,
        sticker: stickers[i],
      );
    }
    yield CommentStickerProgress(downloaded: total, total: total, done: true);
  }
}

/// Parses work payloads and downloads with a 5-connection Dio queue in an isolate.
class IsolateCommentStickerPipeline implements CommentStickerPipeline {
  Isolate? _isolate;
  ReceivePort? _port;

  @override
  Stream<CommentStickerProgress> download({
    required List<CommentSticker> stickers,
    required String directory,
  }) {
    final port = ReceivePort();
    _port = port;
    final controller = StreamController<CommentStickerProgress>();

    controller.onCancel = () {
      _shutdown();
      if (!controller.isClosed) controller.close();
    };

    () async {
      try {
        _isolate = await Isolate.spawn(
          commentStickerIsolateMain,
          <String, dynamic>{
            'sendPort': port.sendPort,
            'directory': directory,
            'stickers': [for (final sticker in stickers) sticker.toJson()],
          },
        );
        await for (final raw in port) {
          if (raw is! Map) continue;
          final progress = CommentStickerProgress.fromMap(
            Map<String, dynamic>.from(raw),
          );
          if (!controller.isClosed) controller.add(progress);
          if (progress.done || progress.error != null) break;
        }
      } catch (error) {
        if (!controller.isClosed) {
          controller.add(
            CommentStickerProgress(
              downloaded: 0,
              total: stickers.length,
              error: error.toString(),
              done: true,
            ),
          );
        }
      } finally {
        _shutdown();
        if (!controller.isClosed) await controller.close();
      }
    }();

    return controller.stream;
  }

  void _shutdown() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _port?.close();
    _port = null;
  }
}

void commentStickerIsolateMain(dynamic message) {
  unawaited(_runCommentStickerIsolate(message));
}

Future<void> _runCommentStickerIsolate(dynamic message) async {
  final payload = Map<String, dynamic>.from(message as Map);
  final sendPort = payload['sendPort'] as SendPort;
  final directory = payload['directory']?.toString() ?? '';
  final rawStickers = payload['stickers'];
  final stickers = <CommentSticker>[
    if (rawStickers is List)
      for (final item in rawStickers)
        if (item is Map)
          CommentSticker.fromJson(Map<String, dynamic>.from(item)),
  ];

  sendPort.send(
    CommentStickerProgress(downloaded: 0, total: stickers.length).toMap(),
  );

  try {
    await QueuedImageDownloader().downloadAll(
      stickers: stickers,
      directory: directory,
      onProgress: (downloaded, total, ready) {
        sendPort.send(
          CommentStickerProgress(
            downloaded: downloaded,
            total: total,
            sticker: ready,
          ).toMap(),
        );
      },
    );
    sendPort.send(
      CommentStickerProgress(
        downloaded: stickers.length,
        total: stickers.length,
        done: true,
      ).toMap(),
    );
  } catch (error) {
    sendPort.send(
      CommentStickerProgress(
        downloaded: 0,
        total: stickers.length,
        error: error.toString(),
        done: true,
      ).toMap(),
    );
  }
}

final commentStickerPipelineProvider = Provider<CommentStickerPipeline>((ref) {
  return IsolateCommentStickerPipeline();
});
