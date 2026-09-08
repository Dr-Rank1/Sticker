import 'package:flutter/material.dart';

import '../editor_models.dart';
import '../sticker_fonts.dart';
import '../../theme/app_colors.dart';

class OverlayCanvas extends StatelessWidget {
  const OverlayCanvas({
    super.key,
    required this.overlays,
    required this.selectedId,
    required this.onSelect,
    required this.onChanged,
    required this.onGestureStart,
    required this.onGestureEnd,
  });

  final List<StickerOverlay> overlays;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final ValueChanged<StickerOverlay> onChanged;
  final VoidCallback onGestureStart;
  final VoidCallback onGestureEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => onSelect(null),
          child: Stack(
            children: [
              for (final overlay in overlays)
                _OverlayItem(
                  overlay: overlay,
                  selected: overlay.id == selectedId,
                  canvasSize: Size(constraints.maxWidth, constraints.maxHeight),
                  onSelect: () => onSelect(overlay.id),
                  onChanged: onChanged,
                  onGestureStart: onGestureStart,
                  onGestureEnd: onGestureEnd,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OverlayItem extends StatefulWidget {
  const _OverlayItem({
    required this.overlay,
    required this.selected,
    required this.canvasSize,
    required this.onSelect,
    required this.onChanged,
    required this.onGestureStart,
    required this.onGestureEnd,
  });

  final StickerOverlay overlay;
  final bool selected;
  final Size canvasSize;
  final VoidCallback onSelect;
  final ValueChanged<StickerOverlay> onChanged;
  final VoidCallback onGestureStart;
  final VoidCallback onGestureEnd;

  @override
  State<_OverlayItem> createState() => _OverlayItemState();
}

class _OverlayItemState extends State<_OverlayItem> {
  StickerOverlay? _gestureOrigin;
  Offset _panDelta = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final overlay = widget.overlay;

    return Align(
      alignment: Alignment(overlay.nx * 2 - 1, overlay.ny * 2 - 1),
      child: GestureDetector(
        onTap: widget.onSelect,
        onScaleStart: (_) {
          _gestureOrigin = overlay;
          _panDelta = Offset.zero;
          widget.onSelect();
          widget.onGestureStart();
        },
        onScaleUpdate: (details) {
          final origin = _gestureOrigin ?? overlay;
          _panDelta += details.focalPointDelta;
          final next = origin.copyWith(
            nx: (origin.nx + _panDelta.dx / widget.canvasSize.width).clamp(
              0.08,
              0.92,
            ),
            ny: (origin.ny + _panDelta.dy / widget.canvasSize.height).clamp(
              0.08,
              0.92,
            ),
            scale: (origin.scale * details.scale).clamp(0.4, 4.0),
            rotation: origin.rotation + details.rotation,
          );
          widget.onChanged(next);
        },
        onScaleEnd: (_) {
          _gestureOrigin = null;
          widget.onGestureEnd();
        },
        child: Transform.rotate(
          angle: overlay.rotation,
          child: Transform.scale(
            scale: overlay.scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: widget.selected
                    ? Border.all(color: colors.accent, width: 2)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: overlay.kind == OverlayKind.emoji
                    ? Text(
                        overlay.content,
                        style: const TextStyle(fontSize: 56),
                      )
                    : _OutlinedText(
                        overlay.content,
                        fontName: overlay.fontName,
                      ),
              ),
            ),
          ),
        ),
      ),
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
    return Stack(
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
    );
  }
}
