import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;

import '../l10n/l10n.dart';
import '../storage/storage_utility.dart';
import 'ffmpeg_sticker_service.dart';

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

/// Google ML Kit selfie segmentation. The model runs entirely on-device.
class MlKitSelfieSegmenter implements SubjectSegmenter {
  @override
  Future<SubjectMask?> segment(File image) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return null;

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

class BackgroundRemovalResult {
  const BackgroundRemovalResult({
    required this.file,
    required this.width,
    required this.height,
  });

  final File file;
  final int width;
  final int height;
}

/// Converts ML Kit's confidence mask into alpha pixels, then renders the
/// foreground through a transparent Flutter [Canvas] and exports a PNG.
class BackgroundRemovalService {
  BackgroundRemovalService({
    SubjectSegmenter? segmenter,
    Future<Directory> Function()? temporaryDirectory,
  }) : _segmenter = segmenter ?? MlKitSelfieSegmenter(),
       _temporaryDirectory =
           temporaryDirectory ?? (() => getStickrTemporaryDirectory());

  final SubjectSegmenter _segmenter;
  final Future<Directory> Function() _temporaryDirectory;

  Future<BackgroundRemovalResult?> removeBackground(File source) async {
    if (!await source.exists()) {
      throw StickerExportException(serviceLocalizations.photoUnavailable);
    }

    final mask = await _segmenter.segment(source);
    if (mask == null || !mask.hasSubject) return null;

    final decoded = img.decodeImage(await source.readAsBytes());
    if (decoded == null) {
      throw StickerExportException(serviceLocalizations.photoOpenFailed);
    }
    final oriented = img.bakeOrientation(decoded);
    final foreground = applySubjectMask(oriented, mask);
    final pngBytes = await renderOnTransparentCanvas(foreground);

    final temporary = await _temporaryDirectory();
    final output = File(
      '${temporary.path}${Platform.pathSeparator}stickr_segmented_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await output.writeAsBytes(pngBytes, flush: true);
    return BackgroundRemovalResult(
      file: output,
      width: foreground.width,
      height: foreground.height,
    );
  }

  /// Produces an RGBA image array with low-confidence background pixels
  /// transparent and softly feathered subject edges.
  img.Image applySubjectMask(
    img.Image source,
    SubjectMask mask, {
    double threshold = 0.35,
  }) {
    final image = source.numChannels == 4
        ? img.Image.from(source)
        : source.convert(numChannels: 4);

    for (final pixel in image) {
      final mx = ((pixel.x + 0.5) * mask.width / image.width).floor();
      final my = ((pixel.y + 0.5) * mask.height / image.height).floor();
      final confidence = mask.confidenceAt(mx, my);
      final alpha = _smoothStep(threshold, 0.8, confidence);
      pixel.a = (pixel.a * alpha).round().clamp(0, 255);
    }
    return image;
  }

  @visibleForTesting
  Future<Uint8List> renderOnTransparentCanvas(img.Image foreground) async {
    final encoded = Uint8List.fromList(img.encodePng(foreground));
    final codec = await ui.instantiateImageCodec(encoded);
    final frame = await codec.getNextFrame();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas
      ..drawColor(Colors.transparent, BlendMode.src)
      ..drawImage(frame.image, Offset.zero, Paint());
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(foreground.width, foreground.height);
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);

    frame.image.dispose();
    codec.dispose();
    picture.dispose();
    rendered.dispose();
    if (bytes == null) {
      throw StickerExportException(
        serviceLocalizations.transparentForegroundRenderFailed,
      );
    }
    return bytes.buffer.asUint8List();
  }

  double _smoothStep(double edge0, double edge1, double value) {
    final x = ((value - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }
}
