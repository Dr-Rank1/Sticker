import 'package:flutter/material.dart';

import '../../haptics/haptic_service.dart';
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
    this.haptics,
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
  final HapticService? haptics;

  @override
  State<OverlayCanvas> createState() => _OverlayCanvasState();
}

class _OverlayCanvasState extends State<OverlayCanvas> {
  StickerLayer? _active;
  double _lastScale = 1;
  double _lastRotation = 0;
  var _didMoveHaptic = false;

  HapticService get _haptics => widget.haptics ?? hapticService;

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
    _didMoveHaptic = false;
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

    final moving =
        details.focalPointDelta.distance > 0.5 ||
        details.scale != 1 ||
        details.rotation != 0;
    if (moving && !_didMoveHaptic) {
      _didMoveHaptic = true;
      _haptics.stickerMoved();
    }

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
    _didMoveHaptic = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Semantics(
          key: const Key('sticker-canvas'),
          container: true,
          explicitChildNodes: true,
          button: true,
          label: 'Sticker canvas',
          hint: 'Drag a sticker to move it. Pinch to resize. Rotate with two fingers.',
          child: GestureDetector(
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
                          onSelect: () => widget.onSelect(layer.id),
                          onDelete: () => widget.onDelete(layer.id),
                        ),
                    ],
                  ),
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
  const _LayerView({
    required this.layer,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
  });

  final StickerLayer layer;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Transform(
      key: Key('sticker-layer-${layer.id}'),
      transform: layer.transform,
      alignment: Alignment.topLeft,
      filterQuality: FilterQuality.medium,
      child: Semantics(
        button: true,
        selected: selected,
        label: layer.semanticsLabel,
        hint: selected
            ? StickerLayer.selectedHint
            : StickerLayer.unselectedHint,
        onTap: onSelect,
        child: SizedBox(
          width: layer.size.width,
          height: layer.size.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(child: LayerContent(layer: layer)),
                ),
              ),
              if (selected) ...[
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(child: DashedSelectionBorder()),
                  ),
                ),
                Positioned(
                  right: -10,
                  top: -10,
                  child: Semantics(
                    button: true,
                    label: 'Delete sticker',
                    hint: 'Removes this sticker from the canvas',
                    onTap: onDelete,
                    child: IgnorePointer(
                      child: LayerDeleteHandle(
                        key: Key('layer-delete-${layer.id}'),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
