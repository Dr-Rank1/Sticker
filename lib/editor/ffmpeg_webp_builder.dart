import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../crashlytics/crash_reporter.dart';
import '../logging/app_logger.dart';
import 'editor_models.dart';

class StickerExportException implements Exception {
  const StickerExportException(this.message);
  final String message;
  @override
  String toString() => message;
}

class StickerExportCancelled extends StickerExportException {
  const StickerExportCancelled() : super('Export cancelled.');
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

/// Assembles an animated WhatsApp WebP from an `.mp4` plus an optional
/// transparent PNG captured from the editor [RepaintBoundary].
///
/// Uses the Full-GPL FFmpeg Kit (`ffmpeg_kit_flutter_new`, successor to
/// `ffmpeg_kit_flutter_full_gpl`) so `libwebp` encoding is available.
class FFmpegWebpBuilder {
  FFmpegWebpBuilder({
    Future<Directory> Function()? tempDirectory,
    Future<int> Function(
      List<String> args,
      void Function(double progress) onProgress,
    )?
    runCommand,
    Future<void> Function()? cancelSessions,
  }) : _tempDirectory = tempDirectory ?? getTemporaryDirectory,
       // ignore: prefer_initializing_formals
       _runCommand = runCommand,
       // ignore: prefer_initializing_formals
       _cancelSessions = cancelSessions;

  static const int fps = WhatsAppStickerSpec.animatedFps;
  static const int defaultQuality = 50;
  static const int compressionLevel = 4;
  static const double clipSeconds = WhatsAppStickerSpec.animatedClipSeconds;

  /// Lower `q:v` if the first encode misses the 500KB WhatsApp cap.
  static const List<int> qualityLadder = [50, 40, 30, 20, 15];

  final Future<Directory> Function() _tempDirectory;
  final Future<int> Function(
    List<String> args,
    void Function(double progress) onProgress,
  )?
  _runCommand;
  final Future<void> Function()? _cancelSessions;

  var _cancelled = false;

  /// Stops in-flight FFmpeg sessions so low-end devices can reclaim memory.
  Future<void> cancel() async {
    _cancelled = true;
    appLogger.i('FFmpeg WebP export cancelled.');
    final hook = _cancelSessions;
    if (hook != null) {
      await hook();
      return;
    }
    await FFmpegKit.cancel();
  }

  String buildFilterGraph({required bool hasOverlay}) {
    const size = WhatsAppStickerSpec.size;
    final video =
        '[0:v]fps=$fps,'
        'scale=$size:$size:force_original_aspect_ratio=decrease,'
        'pad=$size:$size:(ow-iw)/2:(oh-ih)/2:color=white@0.0';
    if (!hasOverlay) return video;
    return '$video[vid];[vid][1:v]overlay=0:0';
  }

  /// Builds the full argument list: trim, filter graph, and WebP limits.
  List<String> buildCommand({
    required String sourceMp4,
    required String outputPath,
    String? overlayPng,
    double startSeconds = 0,
    double durationSeconds = clipSeconds,
    int quality = defaultQuality,
  }) {
    final duration = durationSeconds.clamp(0.2, clipSeconds).toDouble();
    return [
      '-y',
      '-ss',
      formatTimestamp(startSeconds),
      '-t',
      formatTimestamp(duration),
      '-i',
      sourceMp4,
      if (overlayPng != null) ...['-i', overlayPng],
      '-filter_complex',
      buildFilterGraph(hasOverlay: overlayPng != null),
      '-vcodec',
      'libwebp',
      '-lossless',
      '0',
      '-compression_level',
      '$compressionLevel',
      '-q:v',
      '$quality',
      '-loop',
      '0',
      '-an',
      outputPath,
    ];
  }

  static String formatTimestamp(double seconds) {
    final clamped = seconds.clamp(0, 359999);
    final whole = clamped.floor();
    final h = (whole ~/ 3600).toString().padLeft(2, '0');
    final m = ((whole % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (whole % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<StickerExportResult> assemble({
    required String sourceMp4,
    String? overlayPng,
    double startSeconds = 0,
    double durationSeconds = clipSeconds,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      throw const StickerExportException(
        'Saving stickers needs the mobile or desktop app.',
      );
    }

    final input = File(sourceMp4);
    if (!input.existsSync()) {
      throw const StickerExportException(
        'The source video is no longer available.',
      );
    }

    _cancelled = false;
    final inputSize = input.lengthSync();
    crashReporter.log('FFmpeg started with input size: $inputSize');
    await crashReporter.setCustomKey('ffmpeg_input_bytes', inputSize);
    await crashReporter.setCustomKey('ffmpeg_has_overlay', overlayPng != null);
    await crashReporter.setCustomKey('ffmpeg_os', defaultTargetPlatform.name);
    final temp = await _tempDirectory();
    final leftovers = <File>[];
    File? kept;
    Object? lastError;

    try {
      for (var i = 0; i < qualityLadder.length; i++) {
        _throwIfCancelled();
        final quality = qualityLadder[i];
        final output = File(
          '${temp.path}${Platform.pathSeparator}stikk_${DateTime.now().millisecondsSinceEpoch}_${fps}q$quality.webp',
        );
        leftovers.add(output);
        if (output.existsSync()) {
          output.deleteSync();
        }

        final args = buildCommand(
          sourceMp4: sourceMp4,
          outputPath: output.path,
          overlayPng: overlayPng,
          startSeconds: startSeconds,
          durationSeconds: durationSeconds,
          quality: quality,
        );

        try {
          crashReporter.log(
            'FFmpeg encode attempt quality=$quality input size: $inputSize',
          );
          await crashReporter.setCustomKey('ffmpeg_quality', quality);
          final code = await _execute(
            args,
            onProgress: (raw) {
              final overall = (i + raw.clamp(0, 1)) / qualityLadder.length;
              onProgress?.call(overall.clamp(0, 0.99));
            },
          );
          _throwIfCancelled();
          if (_isCancelCode(code)) {
            throw const StickerExportCancelled();
          }
          if (code != ReturnCode.success) {
            lastError = StickerExportException(
              'FFmpeg failed while creating the sticker (code $code).',
            );
            continue;
          }
          if (!output.existsSync() || output.lengthSync() == 0) {
            lastError = const StickerExportException(
              'FFmpeg did not write a sticker file.',
            );
            continue;
          }
          final bytes = output.lengthSync();
          if (bytes <= WhatsAppStickerSpec.maxBytes) {
            onProgress?.call(1);
            kept = output;
            leftovers.remove(output);
            return StickerExportResult(
              file: output,
              bytes: bytes,
              quality: quality,
              fps: fps,
            );
          }
          lastError = StickerExportException(
            'Sticker was ${(bytes / 1024).round()}KB. Trying a smaller encode...',
          );
        } on StickerExportCancelled {
          rethrow;
        } catch (error, stack) {
          lastError = error;
          crashReporter.log('FFmpeg encode failed quality=$quality: $error');
          appLogger.w(
            'FFmpeg WebP attempt failed; retrying with stronger compression',
            error: error,
            stackTrace: stack,
          );
        }
      }

      throw StickerExportException(
        lastError?.toString() ??
            'Could not keep the sticker under 500KB. Try a shorter clip.',
      );
    } finally {
      if (kept == null) {
        for (final file in leftovers) {
          await _deleteIfPresent(file);
        }
      } else {
        for (final file in leftovers) {
          if (file.path != kept.path) {
            await _deleteIfPresent(file);
          }
        }
      }
    }
  }

  void _throwIfCancelled() {
    if (_cancelled) {
      throw const StickerExportCancelled();
    }
  }

  bool _isCancelCode(int code) {
    return ReturnCode.isCancel(ReturnCode(code));
  }

  Future<void> _deleteIfPresent(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // The OS may already have evicted temporary output.
    }
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
          onProgress((millis / (clipSeconds * 1000)).clamp(0.0, 0.99));
        }
      },
    );
    await done.future;
    if (_cancelled) {
      return ReturnCode.cancel;
    }
    final returnCode = await session.getReturnCode();
    return returnCode?.getValue() ?? -1;
  }
}
