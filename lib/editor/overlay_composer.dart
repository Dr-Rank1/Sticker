import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'editor_models.dart';

/// Renders text and emoji overlays into a transparent 512×512 PNG so FFmpeg
/// can composite them onto the trimmed video.
class OverlayComposer {
  static Future<File?> compose({
    required List<StickerOverlay> overlays,
    required Directory directory,
    int size = WhatsAppStickerSpec.size,
  }) async {
    if (overlays.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));

    for (final overlay in overlays) {
      final center = Offset(overlay.nx * size, overlay.ny * size);
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(overlay.rotation)
        ..scale(overlay.scale);

      if (overlay.kind == OverlayKind.emoji) {
        _paintText(
          canvas,
          overlay.content,
          fontSize: 64,
          outlined: false,
        );
      } else {
        _paintText(
          canvas,
          overlay.content,
          fontSize: 42,
          outlined: true,
        );
      }
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    if (bytes == null) return null;

    final file = File(
      '${directory.path}${Platform.pathSeparator}stikk_overlays_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return file;
  }

  static void _paintText(
    Canvas canvas,
    String text, {
    required double fontSize,
    required bool outlined,
  }) {
    TextPainter painter(TextStyle style) {
      final result = TextPainter(
        text: TextSpan(text: text, style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      return result;
    }

    if (outlined) {
      final stroke = painter(
        TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1.1,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.black,
        ),
      );
      stroke.paint(canvas, Offset(-stroke.width / 2, -stroke.height / 2));
    }

    final fill = painter(
      TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        height: 1.1,
        color: Colors.white,
      ),
    );
    fill.paint(canvas, Offset(-fill.width / 2, -fill.height / 2));
  }
}
