import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'editor_models.dart';

/// Captures a [RepaintBoundary] that contains the composed Matrix4 layers.
class CanvasExporter {
  CanvasExporter._();

  static Future<ui.Image?> captureImage(
    GlobalKey key, {
    int size = WhatsAppStickerSpec.size,
  }) async {
    final context = key.currentContext;
    if (context == null) return null;
    final boundary = context.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final logical = boundary.size;
    if (logical.isEmpty) return null;
    final pixelRatio = size / logical.width;
    return boundary.toImage(pixelRatio: pixelRatio);
  }

  static Future<Uint8List?> capturePng(
    GlobalKey key, {
    int size = WhatsAppStickerSpec.size,
  }) async {
    final image = await captureImage(key, size: size);
    if (image == null) return null;
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes?.buffer.asUint8List();
  }

  static Future<File?> captureToFile({
    required GlobalKey key,
    required Directory directory,
    int size = WhatsAppStickerSpec.size,
  }) async {
    final bytes = await capturePng(key, size: size);
    if (bytes == null || bytes.isEmpty) return null;
    final file = File(
      '${directory.path}${Platform.pathSeparator}stikk_overlays_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    return file;
  }
}
