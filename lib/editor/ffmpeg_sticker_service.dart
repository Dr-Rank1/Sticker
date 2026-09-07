import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'editor_models.dart';

class StickerExportException implements Exception {
  const StickerExportException(this.message);
  final String message;
  @override
  String toString() => message;
}

class StickerExportResult {
  const StickerExportResult({
    required this.file,
    required this.bytes,
    required this.quality,
    required this.fps,
  });

  final File file;
  final int bytes;
  final int quality;
  final int fps;
}

/// Builds and runs the WhatsApp sticker FFmpeg pipeline.
///
/// The original `ffmpeg_kit_flutter` package is unmaintained; this service uses
/// the drop-in `FFmpegKit` API from `ffmpeg_kit_flutter_new`.
class FfmpegStickerService {
  FfmpegStickerService({
    Future<Directory> Function()? tempDirectory,
    Future<int> Function(
      List<String> args,
      void Function(double progress) onProgress,
    )? runCommand,
  })  : _tempDirectory = tempDirectory ?? getTemporaryDirectory,
        // ignore: prefer_initializing_formals
        _runCommand = runCommand;

  static const List<({int fps, int quality})> _qualityLadder = [
    (fps: 12, quality: 50),
    (fps: 10, quality: 40),
    (fps: 8, quality: 30),
    (fps: 8, quality: 20),
    (fps: 6, quality: 15),
  ];

  final Future<Directory> Function() _tempDirectory;
  final Future<int> Function(List<String> args, void Function(double progress) onProgress)?
      _runCommand;

  /// Public so tests can assert WhatsApp constraints without running FFmpeg.
  List<String> buildArguments({
    required String inputPath,
    required String outputPath,
    required double startSeconds,
    required double durationSeconds,
    required double speed,
    required int fps,
    required int quality,
    String? overlayPngPath,
  }) {
    final filter = buildFilterGraph(
      speed: speed,
      fps: fps,
      hasOverlay: overlayPngPath != null,
    );

    return [
      '-y',
      '-ss',
      startSeconds.toStringAsFixed(3),
      '-t',
      durationSeconds.toStringAsFixed(3),
      '-i',
      inputPath,
      if (overlayPngPath != null) ...['-i', overlayPngPath],
      '-filter_complex',
      filter,
      '-an',
      '-vsync',
      '0',
      '-c:v',
      'libwebp',
      '-loop',
      '0',
      '-quality',
      '$quality',
      '-preset',
      'default',
      '-compression_level',
      '6',
      '-s',
      '${WhatsAppStickerSpec.size}x${WhatsAppStickerSpec.size}',
      outputPath,
    ];
  }

  String buildFilterGraph({
    required double speed,
    required int fps,
    required bool hasOverlay,
  }) {
    final safeSpeed = speed <= 0 ? 1.0 : speed;
    final size = WhatsAppStickerSpec.size;
    final video =
        '[0:v]setpts=PTS/$safeSpeed,fps=$fps,scale=$size:$size:force_original_aspect_ratio=increase:flags=lanczos,crop=$size:$size,setsar=1';
    if (!hasOverlay) return video;
    return '$video[vid];[1:v]format=rgba,scale=$size:$size[ov];[vid][ov]overlay=0:0:format=auto';
  }

  Future<StickerExportResult> exportSticker({
    required String inputPath,
    required EditorDocument document,
    String? overlayPngPath,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      throw const StickerExportException(
        'Saving stickers needs the mobile or desktop app.',
      );
    }

    final input = File(inputPath);
    if (!input.existsSync()) {
      throw const StickerExportException('The source video is no longer available.');
    }

    var duration = document.trimDuration / (document.speed <= 0 ? 1 : document.speed);
    if (duration > WhatsAppStickerSpec.maxDurationSeconds) {
      duration = WhatsAppStickerSpec.maxDurationSeconds;
    }
    final sourceDuration = duration * (document.speed <= 0 ? 1 : document.speed);

    final temp = await _tempDirectory();
    Object? lastError;

    for (var i = 0; i < _qualityLadder.length; i++) {
      final attempt = _qualityLadder[i];
      final output = File(
        '${temp.path}${Platform.pathSeparator}stikk_${DateTime.now().millisecondsSinceEpoch}_${attempt.fps}q${attempt.quality}.webp',
      );
      if (output.existsSync()) {
        output.deleteSync();
      }

      final args = buildArguments(
        inputPath: inputPath,
        outputPath: output.path,
        startSeconds: document.trimStart,
        durationSeconds: sourceDuration,
        speed: document.speed,
        fps: attempt.fps,
        quality: attempt.quality,
        overlayPngPath: overlayPngPath,
      );

      try {
        final code = await _execute(
          args,
          onProgress: (raw) {
            final overall = (i + raw.clamp(0, 1)) / _qualityLadder.length;
            onProgress?.call(overall.clamp(0, 0.99));
          },
        );
        if (code != ReturnCode.success) {
          lastError = StickerExportException(
            'FFmpeg failed while creating the sticker (code $code).',
          );
          continue;
        }
        if (!output.existsSync() || output.lengthSync() == 0) {
          lastError = const StickerExportException('FFmpeg did not write a sticker file.');
          continue;
        }
        final bytes = output.lengthSync();
        if (bytes <= WhatsAppStickerSpec.maxBytes) {
          onProgress?.call(1);
          return StickerExportResult(
            file: output,
            bytes: bytes,
            quality: attempt.quality,
            fps: attempt.fps,
          );
        }
        lastError = StickerExportException(
          'Sticker was ${ (bytes / 1024).round() }KB. Trying a smaller encode...',
        );
      } catch (error) {
        lastError = error;
      }
    }

    throw StickerExportException(
      lastError?.toString() ??
          'Could not keep the sticker under 500KB. Try a shorter clip.',
    );
  }

  Future<int> _execute(
    List<String> args, {
    required void Function(double progress) onProgress,
  }) async {
    final runCommand = _runCommand;
    if (runCommand != null) {
      return runCommand(args, onProgress);
    }

    final done = Completer<void>();
    final session = await FFmpegKit.executeWithArgumentsAsync(
      args,
      (completed) {
        if (!done.isCompleted) done.complete();
      },
      null,
      (stats) {
        final millis = stats.getTime();
        if (millis > 0) {
          onProgress((millis / 10000).clamp(0.0, 0.99));
        }
      },
    );
    await done.future;
    final returnCode = await session.getReturnCode();
    return returnCode?.getValue() ?? -1;
  }
}
