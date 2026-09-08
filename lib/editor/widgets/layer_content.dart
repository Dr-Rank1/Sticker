import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../editor_models.dart';
import '../sticker_fonts.dart';
import '../../theme/app_colors.dart';

/// Renders a layer's Text, Emoji, or Image widget inside its untransformed box.
class LayerContent extends StatelessWidget {
  const LayerContent({super.key, required this.layer});

  final StickerLayer layer;

  @override
  Widget build(BuildContext context) {
    return switch (layer.widget) {
      TextLayerWidget(:final text, :final fontName) => _OutlinedText(
        text,
        fontName: fontName,
      ),
      EmojiLayerWidget(:final emoji) => Center(
        child: Text(emoji, style: const TextStyle(fontSize: 56)),
      ),
      ImageLayerWidget(:final path, :final bytes) => _ImageLayer(
        path: path,
        bytes: bytes,
      ),
    };
  }
}

class _ImageLayer extends StatelessWidget {
  const _ImageLayer({required this.path, this.bytes});

  final String path;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return Image.memory(
        bytes!,
        fit: BoxFit.fill,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const ColoredBox(color: Colors.white24),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.fill,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(color: Colors.white24),
    );
  }
}

class _OutlinedText extends StatelessWidget {
  const _OutlinedText(this.text, {required this.fontName});

  final String text;
  final String fontName;

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      height: 1.1,
    );
    final style = StickerFontCatalog.styleFor(fontName, base);
    return Center(
      child: Stack(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 7
                ..strokeJoin = StrokeJoin.round
                ..color = Colors.black,
            ),
          ),
          Text(
            text,
            textAlign: TextAlign.center,
            style: style.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class DashedSelectionBorder extends StatelessWidget {
  const DashedSelectionBorder({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(color: context.colors.accent),
      child: const SizedBox.expand(),
    );
  }
}

class LayerDeleteHandle extends StatelessWidget {
  const LayerDeleteHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Color(0xE6000000),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 5.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next.toDouble()), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
