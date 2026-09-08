import 'package:flutter/material.dart';

import '../editor_models.dart';
import '../layer_transform.dart';
import 'layer_content.dart';

class OverlayCanvas extends StatefulWidget {
  const OverlayCanvas({
    super.key,
    required this.layers,
    required this.selectedId,
    required this.onSelect,
    required this.onChanged,
    required this.onGestureStart,
    required this.onGestureEnd,
    required this.onDelete,
    this.captureKey,
    this.showSelection = true,
  });

  final List<StickerLayer> layers;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final ValueChanged<StickerLayer> onChanged;
  final VoidCallback onGestureStart;
  final VoidCallback onGestureEnd;
  final ValueChanged<String> onDelete;
  final GlobalKey? captureKey;
  final bool showSelection;

  @override
  State<OverlayCanvas> createState() => _OverlayCanvasState();
}

class _OverlayCanvasState extends State<OverlayCanvas> {
  StickerLayer? _active;
  double _lastScale = 1;
  double _lastRotation = 0;

  Offset _localPoint(ScaleStartDetails details, Size viewSize) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return LayerTransform.toCanvas(
      box.globalToLocal(details.focalPoint),
      viewSize,
    );
  }

  void _onScaleStart(ScaleStartDetails details, Size viewSize) {
    final point = _localPoint(details, viewSize);
    final selected = widget.layers
        .where((layer) => layer.id == widget.selectedId)
        .firstOrNull;

    if (widget.showSelection &&
        selected != null &&
        LayerTransform.hitsDeleteHandle(
          transform: selected.transform,
          layerSize: selected.size,
          point: point,
        )) {
      widget.onDelete(selected.id);
      _active = null;
      return;
    }

    final hitIndex = LayerTransform.hitTestIndex(
      transforms: widget.layers.map((layer) => layer.transform).toList(),
      sizes: widget.layers.map((layer) => layer.size).toList(),
      point: point,
    );
    _lastScale = 1;
    _lastRotation = 0;
    if (hitIndex < 0) {
      _active = null;
      widget.onSelect(null);
      return;
    }

    final hit = widget.layers[hitIndex];

    _active = hit;
    widget.onSelect(hit.id);
    widget.onGestureStart();
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size viewSize) {
    final active = _active;
    if (active == null) return;

    final current = widget.layers
        .where((layer) => layer.id == active.id)
        .firstOrNull;
    if (current == null) return;

    final scaleMultiplier = _lastScale == 0 ? 1.0 : details.scale / _lastScale;
    final rotationRadians = details.rotation - _lastRotation;
    _lastScale = details.scale;
    _lastRotation = details.rotation;

    final next = current.copyWith(
      transform: LayerTransform.applyGesture(
        source: current.transform,
        layerSize: current.size,
        focalPointDelta: LayerTransform.toCanvasDelta(
          details.focalPointDelta,
          viewSize,
        ),
        scaleMultiplier: scaleMultiplier,
        rotationRadians: rotationRadians,
      ),
    );
    _active = next;
    widget.onChanged(next);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_active != null) {
      widget.onGestureEnd();
    }
    _active = null;
    _lastScale = 1;
    _lastRotation = 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) => _onScaleStart(details, viewSize),
          onScaleUpdate: (details) => _onScaleUpdate(details, viewSize),
          onScaleEnd: _onScaleEnd,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: LayerTransform.canvasExtent,
              height: LayerTransform.canvasExtent,
              child: RepaintBoundary(
                key: widget.captureKey,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final layer in widget.layers)
                      _LayerView(
                        layer: layer,
                        selected:
                            widget.showSelection &&
                            layer.id == widget.selectedId,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LayerView extends StatelessWidget {
  const _LayerView({required this.layer, required this.selected});

  final StickerLayer layer;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Transform(
      key: Key('sticker-layer-${layer.id}'),
      transform: layer.transform,
      alignment: Alignment.topLeft,
      filterQuality: FilterQuality.medium,
      child: SizedBox(
        width: layer.size.width,
        height: layer.size.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(child: LayerContent(layer: layer)),
            ),
            if (selected) ...[
              const Positioned.fill(
                child: IgnorePointer(child: DashedSelectionBorder()),
              ),
              Positioned(
                right: -10,
                top: -10,
                child: IgnorePointer(
                  child: LayerDeleteHandle(
                    key: Key('layer-delete-${layer.id}'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
