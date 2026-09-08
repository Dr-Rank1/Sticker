import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'editor_models.dart';
import 'ffmpeg_sticker_service.dart';

/// Foreground confidence mask from on-device segmentation.
class SubjectMask {
  const SubjectMask({
    required this.width,
    required this.height,
    required this.confidences,
  });

  final int width;
  final int height;
  final List<double> confidences;

  bool get hasSubject => confidences.any((value) => value >= 0.5);

  double confidenceAt(int x, int y) {
    if (width <= 0 || height <= 0 || confidences.isEmpty) return 0;
    final cx = x.clamp(0, width - 1);
    final cy = y.clamp(0, height - 1);
    final index = cy * width + cx;
    if (index < 0 || index >= confidences.length) return 0;
    return confidences[index];
  }
}

abstract class SubjectSegmenter {
  Future<SubjectMask?> segment(File image);
}

/// Google ML Kit selfie segmentation. Runs entirely on device.
class MlKitSelfieSegmenter implements SubjectSegmenter {
  @override
  Future<SubjectMask?> segment(File image) async {
    if (kIsWeb) return null;
    if (!(Platform.isAndroid || Platform.isIOS)) return null;

    final segmenter = SelfieSegmenter(
      mode: SegmenterMode.single,
      enableRawSizeMask: true,
    );
    try {
      final mask = await segmenter.processImage(
        InputImage.fromFilePath(image.path),
      );
      if (mask == null || mask.confidences.isEmpty) return null;
      return SubjectMask(
        width: mask.width,
        height: mask.height,
        confidences: mask.confidences,
      );
    } catch (_) {
      return null;
    } finally {
      await segmenter.close();
    }
  }
}

class ImagePrepareResult {
  const ImagePrepareResult({
    required this.file,
    required this.backgroundRemoved,
    required this.autoCropped,
  });

  final File file;
  final bool backgroundRemoved;
  final bool autoCropped;
}

class PixelBounds {
  const PixelBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left + 1;
  int get height => bottom - top + 1;
}

/// Prepares photos (cut-out + auto crop) and encodes static 512×512 WebP stickers.
class ImageStickerService {
  ImageStickerService({
    SubjectSegmenter? segmenter,
    Future<Directory> Function()? tempDirectory,
    Future<int> Function(
      List<String> args,
      void Function(double progress) onProgress,
    )?
    runCommand,
  }) : _segmenter = segmenter ?? MlKitSelfieSegmenter(),
       _tempDirectory = tempDirectory ?? getTemporaryDirectory,
       // ignore: prefer_initializing_formals
       _runCommand = runCommand;

  static const List<int> _qualityLadder = [80, 65, 50, 40, 30, 20];

  final SubjectSegmenter _segmenter;
  final Future<Directory> Function() _tempDirectory;
  final Future<int> Function(
    List<String> args,
    void Function(double progress) onProgress,
  )?
  _runCommand;

  /// Decode, optionally cut out the subject, auto-crop, and fit onto a 512 canvas.
  Future<ImagePrepareResult> prepareForEditor(
    File source, {
    bool removeBackground = true,
  }) async {
    if (!source.existsSync()) {
      throw const StickerExportException('That photo is no longer available.');
    }

    final decoded = decodePhoto(await source.readAsBytes());
    if (decoded == null) {
      throw const StickerExportException(
        'That photo couldn’t be opened. Try another one.',
      );
    }

    var image = constrainLongestSide(decoded, 1280);
    var backgroundRemoved = false;
    var autoCropped = false;

    if (removeBackground) {
      final probe = await _writePng(image, prefix: 'stikk_seg');
      SubjectMask? mask;
      try {
        mask = await _segmenter.segment(probe);
      } finally {
        await _deleteIfPresent(probe);
      }
      if (mask != null && mask.hasSubject) {
        image = applySubjectMask(image, mask);
        final cropped = autoCropToSubject(image);
        if (cropped != null) {
          image = cropped;
          autoCropped = true;
        }
        backgroundRemoved = true;
      }
    }

    if (!backgroundRemoved) {
      image = coverSquare(image);
    }

    final canvas = fitToStickerCanvas(image);
    final file = await _writePng(canvas, prefix: 'stikk_photo');
    return ImagePrepareResult(
      file: file,
      backgroundRemoved: backgroundRemoved,
      autoCropped: autoCropped,
    );
  }

  Future<StickerExportResult> exportStaticSticker({
    required String imagePath,
    String? overlayPngPath,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      throw const StickerExportException(
        'Saving stickers needs the mobile or desktop app.',
      );
    }

    final input = File(imagePath);
    if (!input.existsSync()) {
      throw const StickerExportException('The photo is no longer available.');
    }

    var composed = decodePhoto(await input.readAsBytes());
    if (composed == null) {
      throw const StickerExportException('The photo couldn’t be opened.');
    }
    if (composed.width != WhatsAppStickerSpec.size ||
        composed.height != WhatsAppStickerSpec.size) {
      composed = fitToStickerCanvas(composed);
    }

    if (overlayPngPath != null) {
      final overlayFile = File(overlayPngPath);
      if (overlayFile.existsSync()) {
        final overlay = img.decodeImage(await overlayFile.readAsBytes());
        if (overlay != null) {
          img.compositeImage(composed, overlay);
        }
      }
    }

    final temp = await _tempDirectory();
    final composedPng = File(
      '${temp.path}${Platform.pathSeparator}stikk_static_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await composedPng.writeAsBytes(img.encodePng(composed));

    Object? lastError;
    for (var i = 0; i < _qualityLadder.length; i++) {
      final quality = _qualityLadder[i];
      final output = File(
        '${temp.path}${Platform.pathSeparator}stikk_static_${DateTime.now().millisecondsSinceEpoch}_q$quality.webp',
      );
      if (output.existsSync()) {
        output.deleteSync();
      }

      try {
        final code = await _execute(
          buildStaticArguments(
            inputPath: composedPng.path,
            outputPath: output.path,
            quality: quality,
          ),
          onProgress: (raw) {
            final overall = (i + raw.clamp(0, 1)) / _qualityLadder.length;
            onProgress?.call(overall.clamp(0, 0.99));
          },
        );
        if (code != ReturnCode.success) {
          lastError = StickerExportException(
            'FFmpeg failed while creating the sticker (code $code).',
          );
          await _deleteIfPresent(output);
          continue;
        }
        if (!output.existsSync() || output.lengthSync() == 0) {
          lastError = const StickerExportException(
            'FFmpeg did not write a sticker file.',
          );
          await _deleteIfPresent(output);
          continue;
        }
        final bytes = output.lengthSync();
        if (bytes <= WhatsAppStickerSpec.maxStaticBytes) {
          onProgress?.call(1);
          await _deleteIfPresent(composedPng);
          return StickerExportResult(
            file: output,
            bytes: bytes,
            quality: quality,
            fps: 1,
          );
        }
        lastError = StickerExportException(
          'Sticker was ${(bytes / 1024).round()}KB. Trying a smaller encode...',
        );
        await _deleteIfPresent(output);
      } catch (error) {
        lastError = error;
        await _deleteIfPresent(output);
      }
    }

    await _deleteIfPresent(composedPng);
    throw StickerExportException(
      lastError?.toString() ??
          'Could not keep the sticker under 100KB. Try a simpler photo.',
    );
  }

  Future<void> _deleteIfPresent(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Temporary files may already have been evicted by the OS.
    }
  }

  List<String> buildStaticArguments({
    required String inputPath,
    required String outputPath,
    required int quality,
  }) {
    return [
      '-y',
      '-i',
      inputPath,
      '-an',
      '-vframes',
      '1',
      '-c:v',
      'libwebp',
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

  img.Image? decodePhoto(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return img.bakeOrientation(decoded);
  }

  img.Image constrainLongestSide(img.Image source, int maxSide) {
    final longest = math.max(source.width, source.height);
    if (longest <= maxSide) return source;
    final scale = maxSide / longest;
    return img.copyResize(
      source,
      width: math.max(1, (source.width * scale).round()),
      height: math.max(1, (source.height * scale).round()),
      interpolation: img.Interpolation.cubic,
    );
  }

  img.Image applySubjectMask(
    img.Image source,
    SubjectMask mask, {
    double threshold = 0.4,
  }) {
    final image = source.numChannels == 4
        ? img.Image.from(source)
        : source.convert(numChannels: 4);

    for (final pixel in image) {
      final mx = ((pixel.x + 0.5) * mask.width / image.width).floor();
      final my = ((pixel.y + 0.5) * mask.height / image.height).floor();
      final confidence = mask.confidenceAt(mx, my);
      if (confidence < threshold) {
        pixel.a = 0;
      } else {
        final feather = ((confidence - threshold) / (1 - threshold)).clamp(
          0.0,
          1.0,
        );
        pixel.a = (pixel.a * (0.35 + 0.65 * feather)).round().clamp(0, 255);
      }
    }
    return image;
  }

  PixelBounds? opaqueBounds(img.Image image, {int alphaThreshold = 16}) {
    var minX = image.width;
    var minY = image.height;
    var maxX = -1;
    var maxY = -1;

    for (final pixel in image) {
      if (pixel.a < alphaThreshold) continue;
      if (pixel.x < minX) minX = pixel.x;
      if (pixel.y < minY) minY = pixel.y;
      if (pixel.x > maxX) maxX = pixel.x;
      if (pixel.y > maxY) maxY = pixel.y;
    }

    if (maxX < 0) return null;
    return PixelBounds(left: minX, top: minY, right: maxX, bottom: maxY);
  }

  img.Image? autoCropToSubject(
    img.Image image, {
    double paddingFraction = 0.08,
  }) {
    final bounds = opaqueBounds(image);
    if (bounds == null) return null;
    if (bounds.width < 8 || bounds.height < 8) return null;

    final pad = paddingFraction <= 0
        ? 0
        : math.max(
            4,
            (math.max(bounds.width, bounds.height) * paddingFraction).round(),
          );
    final left = math.max(0, bounds.left - pad);
    final top = math.max(0, bounds.top - pad);
    final right = math.min(image.width - 1, bounds.right + pad);
    final bottom = math.min(image.height - 1, bounds.bottom + pad);
    final width = right - left + 1;
    final height = bottom - top + 1;
    if (width < 8 || height < 8) return null;

    return img.copyCrop(image, x: left, y: top, width: width, height: height);
  }

  img.Image coverSquare(img.Image source) {
    final side = math.min(source.width, source.height);
    if (side <= 0) return source;
    final x = (source.width - side) ~/ 2;
    final y = (source.height - side) ~/ 2;
    return img.copyCrop(source, x: x, y: y, width: side, height: side);
  }

  img.Image fitToStickerCanvas(
    img.Image source, {
    int size = WhatsAppStickerSpec.size,
  }) {
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    if (source.width <= 0 || source.height <= 0) return canvas;

    final scale = math.min(size / source.width, size / source.height);
    final width = math.max(1, (source.width * scale).round().clamp(1, size));
    final height = math.max(1, (source.height * scale).round().clamp(1, size));
    final resized = img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.cubic,
    );
    img.compositeImage(
      canvas,
      resized,
      dstX: (size - width) ~/ 2,
      dstY: (size - height) ~/ 2,
    );
    return canvas;
  }

  Future<File> _writePng(img.Image image, {required String prefix}) async {
    final temp = await _tempDirectory();
    final file = File(
      '${temp.path}${Platform.pathSeparator}${prefix}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(img.encodePng(image));
    return file;
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
          onProgress((millis / 4000).clamp(0.0, 0.99));
        }
      },
    );
    await done.future;
    final returnCode = await session.getReturnCode();
    return returnCode?.getValue() ?? -1;
  }
}
