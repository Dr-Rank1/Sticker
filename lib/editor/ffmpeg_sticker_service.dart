import 'dart:io';

import 'editor_models.dart';
import 'ffmpeg_webp_builder.dart';

export 'ffmpeg_webp_builder.dart'
    show StickerExportCancelled, StickerExportException, StickerExportResult;

/// Video-sticker export facade used by the editor.
///
/// Command generation, the GPL WebP filter graph, cancel, and temp-file
/// cleanup live in [FFmpegWebpBuilder].
class FfmpegStickerService {
  FfmpegStickerService({
    Future<Directory> Function()? tempDirectory,
    Future<int> Function(
      List<String> args,
      void Function(double progress) onProgress,
    )?
    runCommand,
    Future<void> Function()? cancelSessions,
    FFmpegWebpBuilder? builder,
  }) : _builder =
           builder ??
           FFmpegWebpBuilder(
             tempDirectory: tempDirectory,
             runCommand: runCommand,
             cancelSessions: cancelSessions,
           );

  final FFmpegWebpBuilder _builder;

  Future<void> cancel() => _builder.cancel();

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
    return _builder.buildCommand(
      sourceMp4: inputPath,
      outputPath: outputPath,
      overlayPng: overlayPngPath,
      startSeconds: startSeconds,
      durationSeconds: durationSeconds,
      speed: speed,
      quality: quality,
    );
  }

  String buildFilterGraph({
    required double speed,
    required int fps,
    required bool hasOverlay,
  }) {
    return _builder.buildFilterGraph(hasOverlay: hasOverlay, speed: speed);
  }

  Future<StickerExportResult> exportSticker({
    required String inputPath,
    required EditorDocument document,
    String? overlayPngPath,
    void Function(double progress)? onProgress,
  }) {
    final duration = document.trimDuration > FFmpegWebpBuilder.clipSeconds
        ? FFmpegWebpBuilder.clipSeconds
        : document.trimDuration;
    return _builder.assemble(
      sourceMp4: inputPath,
      overlayPng: overlayPngPath,
      startSeconds: document.trimStart,
      durationSeconds: duration,
      speed: document.speed,
      onProgress: onProgress,
    );
  }
}
