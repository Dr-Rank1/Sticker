import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'editor_models.dart';
import 'sticker_fonts.dart';

/// Fallback rasterizer for when a [RepaintBoundary] capture is unavailable.
///
/// Applies each layer's [Matrix4] in 512×512 canvas space so FFmpeg can
/// composite the same layout onto video.
class OverlayComposer {
  static Future<File?> compose({
    required List<StickerLayer> overlays,
    required Directory directory,
    int size = WhatsAppStickerSpec.size,
  }) async {
    if (overlays.isEmpty) return null;

    await StickerFontCatalog.ensureLoaded(
      overlays
          .where((overlay) => overlay.kind == OverlayKind.text)
          .map((overlay) => overlay.fontName),
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );

    for (final overlay in overlays) {
      canvas
        ..save()
        ..transform(overlay.transform.storage);

      switch (overlay.widget) {
        case EmojiLayerWidget(:final emoji):
          _paintText(
            canvas,
            emoji,
            fontSize: 56,
            outlined: false,
            box: overlay.size,
          );
        case TextLayerWidget(:final text, :final fontName):
          _paintText(
            canvas,
            text,
            fontSize: 34,
            outlined: true,
            fontName: fontName,
            box: overlay.size,
          );
        case ImageLayerWidget(:final path, :final bytes):
          await _paintImage(canvas, overlay.size, path: path, bytes: bytes);
      }
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    if (byteData == null) return null;

    final file = File(
      '${directory.path}${Platform.pathSeparator}stickr_overlays_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  static Future<void> _paintImage(
    Canvas canvas,
    Size box, {
    required String path,
    Uint8List? bytes,
  }) async {
    try {
      final data = bytes ?? Uint8List.fromList(await File(path).readAsBytes());
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      paintImage(
        canvas: canvas,
        rect: Offset.zero & box,
        image: frame.image,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      );
      frame.image.dispose();
    } catch (_) {
      // Missing overlay images are skipped so export can still finish.
    }
  }

  static void _paintText(
    Canvas canvas,
    String text, {
    required double fontSize,
    required bool outlined,
    required Size box,
    String fontName = StickerFontCatalog.defaultFont,
  }) {
    TextPainter painter(TextStyle style) {
      return TextPainter(
        text: TextSpan(text: text, style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: box.width);
    }

    if (outlined) {
      final stroke = painter(
        StickerFontCatalog.styleFor(
          fontName,
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
        ),
      );
      stroke.paint(
        canvas,
        Offset(
          (box.width - stroke.width) / 2,
          (box.height - stroke.height) / 2,
        ),
      );
    }

    final fill = painter(
      StickerFontCatalog.styleFor(
        fontName,
        TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1.1,
          color: Colors.white,
        ),
      ),
    );
    fill.paint(
      canvas,
      Offset((box.width - fill.width) / 2, (box.height - fill.height) / 2),
    );
  }
}
