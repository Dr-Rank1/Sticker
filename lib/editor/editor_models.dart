import 'package:flutter/material.dart';

enum OverlayKind { text, emoji }

@immutable
class StickerOverlay {
  const StickerOverlay({
    required this.id,
    required this.kind,
    required this.content,
    this.nx = 0.5,
    this.ny = 0.5,
    this.scale = 1,
    this.rotation = 0,
  });

  final String id;
  final OverlayKind kind;
  final String content;

  /// Normalized center (0–1) on the 512×512 canvas.
  final double nx;
  final double ny;
  final double scale;
  final double rotation;

  StickerOverlay copyWith({
    double? nx,
    double? ny,
    double? scale,
    double? rotation,
  }) {
    return StickerOverlay(
      id: id,
      kind: kind,
      content: content,
      nx: nx ?? this.nx,
      ny: ny ?? this.ny,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }
}

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

  final List<StickerOverlay> overlays;
  final double trimStart;
  final double trimEnd;
  final double speed;
  final String? selectedId;
  final double videoDuration;

  double get trimDuration => (trimEnd - trimStart).clamp(0.2, videoDuration);

  StickerOverlay? get selected {
    if (selectedId == null) return null;
    for (final overlay in overlays) {
      if (overlay.id == selectedId) return overlay;
    }
    return null;
  }

  EditorDocument copyWith({
    List<StickerOverlay>? overlays,
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
  static const double maxDurationSeconds = 10;
  static const List<double> speeds = [0.5, 1, 1.5, 2];
}
