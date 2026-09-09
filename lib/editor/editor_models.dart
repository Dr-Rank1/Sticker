import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'layer_transform.dart';
import 'sticker_fonts.dart';

enum OverlayKind { text, emoji, image }

/// Visual payload for a [StickerLayer]: text, emoji, or image.
@immutable
sealed class StickerLayerWidget {
  const StickerLayerWidget();
}

@immutable
class TextLayerWidget extends StickerLayerWidget {
  const TextLayerWidget(
    this.text, {
    this.fontName = StickerFontCatalog.defaultFont,
  });

  final String text;
  final String fontName;
}

@immutable
class EmojiLayerWidget extends StickerLayerWidget {
  const EmojiLayerWidget(this.emoji);

  final String emoji;
}

@immutable
class ImageLayerWidget extends StickerLayerWidget {
  const ImageLayerWidget(this.path, {this.bytes});

  final String path;
  final Uint8List? bytes;
}

/// A single interactive overlay. [transform] is a [Matrix4] in 512×512
/// canvas space. List order in [EditorDocument.overlays] is z-index
/// (later entries paint on top).
@immutable
class StickerLayer {
  StickerLayer({
    required this.id,
    required this.widget,
    Matrix4? transform,
    Size? size,
  }) : size = size ?? measure(widget),
       transform = Matrix4.copy(
         transform ??
             LayerTransform.initial(
               canvasSize: const Size(
                 LayerTransform.canvasExtent,
                 LayerTransform.canvasExtent,
               ),
               layerSize: size ?? measure(widget),
             ),
       );

  factory StickerLayer.text(
    String text, {
    required String id,
    String fontName = StickerFontCatalog.defaultFont,
    Offset normalizedCenter = const Offset(0.5, 0.5),
  }) {
    final widget = TextLayerWidget(text, fontName: fontName);
    final size = measure(widget);
    return StickerLayer(
      id: id,
      widget: widget,
      size: size,
      transform: LayerTransform.initial(
        canvasSize: const Size(
          LayerTransform.canvasExtent,
          LayerTransform.canvasExtent,
        ),
        layerSize: size,
        normalizedCenter: normalizedCenter,
      ),
    );
  }

  factory StickerLayer.emoji(
    String emoji, {
    required String id,
    Offset normalizedCenter = const Offset(0.5, 0.62),
  }) {
    final content = EmojiLayerWidget(emoji);
    final size = measure(content);
    return StickerLayer(
      id: id,
      widget: content,
      size: size,
      transform: LayerTransform.initial(
        canvasSize: const Size(
          LayerTransform.canvasExtent,
          LayerTransform.canvasExtent,
        ),
        layerSize: size,
        normalizedCenter: normalizedCenter,
      ),
    );
  }

  factory StickerLayer.image(
    String path, {
    required String id,
    Uint8List? bytes,
    Offset normalizedCenter = const Offset(0.5, 0.5),
  }) {
    final widget = ImageLayerWidget(path, bytes: bytes);
    final size = measure(widget);
    return StickerLayer(
      id: id,
      widget: widget,
      size: size,
      transform: LayerTransform.initial(
        canvasSize: const Size(
          LayerTransform.canvasExtent,
          LayerTransform.canvasExtent,
        ),
        layerSize: size,
        normalizedCenter: normalizedCenter,
      ),
    );
  }

  final String id;

  /// Text, emoji, or image content rendered on the canvas.
  final StickerLayerWidget widget;
  final Matrix4 transform;
  final Size size;

  OverlayKind get kind => switch (widget) {
    TextLayerWidget() => OverlayKind.text,
    EmojiLayerWidget() => OverlayKind.emoji,
    ImageLayerWidget() => OverlayKind.image,
  };

  String get content => switch (widget) {
    TextLayerWidget(:final text) => text,
    EmojiLayerWidget(:final emoji) => emoji,
    ImageLayerWidget(:final path) => path,
  };

  String get fontName => switch (widget) {
    TextLayerWidget(:final fontName) => fontName,
    _ => StickerFontCatalog.defaultFont,
  };

  String get semanticsLabel => switch (widget) {
    TextLayerWidget(:final text) =>
      text.trim().isEmpty
          ? serviceLocalizations.textSticker
          : serviceLocalizations.textStickerWithText(text),
    EmojiLayerWidget() => serviceLocalizations.emojiSticker,
    ImageLayerWidget() => serviceLocalizations.imageSticker,
  };

  String get semanticsHint => selectedHint;

  static String get selectedHint => serviceLocalizations.selectedStickerHint;
  static String get unselectedHint =>
      serviceLocalizations.unselectedStickerHint;

  StickerLayer copyWith({
    StickerLayerWidget? widget,
    Matrix4? transform,
    Size? size,
  }) {
    return StickerLayer(
      id: id,
      widget: widget ?? this.widget,
      transform: transform ?? this.transform,
      size: size ?? this.size,
    );
  }

  StickerLayer withFont(String fontName) {
    final current = widget;
    if (current is! TextLayerWidget || current.fontName == fontName) {
      return this;
    }
    final nextWidget = TextLayerWidget(current.text, fontName: fontName);
    final nextSize = measure(nextWidget);
    final oldCenter = LayerTransform.centerOf(transform, size);
    final nextTransform = Matrix4.copy(transform);
    final newCenter = LayerTransform.centerOf(nextTransform, nextSize);
    nextTransform.leftTranslateByDouble(
      oldCenter.dx - newCenter.dx,
      oldCenter.dy - newCenter.dy,
      0,
      1,
    );
    return copyWith(
      widget: nextWidget,
      size: nextSize,
      transform: nextTransform,
    );
  }

  static Size measure(StickerLayerWidget widget) {
    switch (widget) {
      case TextLayerWidget(:final text):
        final width = (text.length * 21.0 + 24).clamp(64.0, 480.0);
        return Size(width, 56);
      case EmojiLayerWidget():
        return const Size(80, 80);
      case ImageLayerWidget():
        return const Size(168, 168);
    }
  }
}

/// Back-compat alias used by older editor tests and export helpers.
typedef StickerOverlay = StickerLayer;

@immutable
class EditorDocument {
  const EditorDocument({
    this.overlays = const [],
    this.trimStart = 0,
    this.trimEnd = 3,
    this.speed = 1,
    this.selectedId,
    this.videoDuration = 0,
  });

  /// Z-ordered sticker layers. Later entries are drawn on top.
  final List<StickerLayer> overlays;
  final double trimStart;
  final double trimEnd;
  final double speed;
  final String? selectedId;
  final double videoDuration;

  double get trimDuration => (trimEnd - trimStart).clamp(0.2, videoDuration);

  StickerLayer? get selected {
    if (selectedId == null) return null;
    for (final overlay in overlays) {
      if (overlay.id == selectedId) return overlay;
    }
    return null;
  }

  EditorDocument copyWith({
    List<StickerLayer>? overlays,
    double? trimStart,
    double? trimEnd,
    double? speed,
    String? selectedId,
    double? videoDuration,
    bool clearSelection = false,
  }) {
    return EditorDocument(
      overlays: overlays ?? this.overlays,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      speed: speed ?? this.speed,
      selectedId: clearSelection ? null : selectedId ?? this.selectedId,
      videoDuration: videoDuration ?? this.videoDuration,
    );
  }
}

class WhatsAppStickerSpec {
  static const int size = 512;
  static const int maxBytes = 500 * 1024;
  static const int maxStaticBytes = 100 * 1024;
  static const double animatedClipSeconds = 3;
  static const int animatedFps = 15;
  static const List<double> speeds = [0.5, 1, 1.5, 2];

  static double maxSourceDurationForSpeed(double speed) {
    final normalized = speed.isFinite && speed > 0 ? speed : 1.0;
    return (animatedClipSeconds * normalized).clamp(0.2, animatedClipSeconds);
  }
}
