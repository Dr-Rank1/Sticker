import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'pack_models.dart';

class TrayIconService {
  Future<List<int>> createDefaultBytes({
    required String name,
    Color background = const Color(0xFF00C48C),
  }) async {
    const size = WhatsAppPackRules.traySize;
    final letter = name.trim().isEmpty ? 'S' : name.trim()[0].toUpperCase();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    final rect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(20)),
      Paint()..color = background,
    );

    final painter = TextPainter(
      text: TextSpan(
        text: letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 52,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((size - painter.width) / 2, (size - painter.height) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    if (bytes == null) {
      throw const PackException('Could not create the 96x96 tray icon.');
    }
    return bytes.buffer.asUint8List();
  }

  Future<File> createDefault({
    required Directory directory,
    required String packId,
    required String name,
    Color background = const Color(0xFF00C48C),
  }) async {
    final png = await createDefaultBytes(name: name, background: background);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final file = File('${directory.path}${Platform.pathSeparator}tray.png');
    await file.writeAsBytes(png);
    return file;
  }
}
