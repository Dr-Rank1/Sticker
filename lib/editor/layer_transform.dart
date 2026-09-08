import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Matrix4 helpers for sticker-layer gestures, hit-testing, and layout.
class LayerTransform {
  LayerTransform._();

  static const double minScale = 0.4;
  static const double maxScale = 4.0;
  static const double canvasExtent = 512;
  static const double edgePadding = 40;

  /// Places the layer so its center sits on [normalizedCenter] of [canvasSize].
  static Matrix4 initial({
    required Size canvasSize,
    required Size layerSize,
    Offset normalizedCenter = const Offset(0.5, 0.5),
  }) {
    final dx = canvasSize.width * normalizedCenter.dx - layerSize.width / 2;
    final dy = canvasSize.height * normalizedCenter.dy - layerSize.height / 2;
    return Matrix4.identity()..translate(dx, dy);
  }

  /// Applies one scale-gesture frame from the **widget center**, then pans.
  ///
  /// [focalPointDelta] is in the same space as [source] (512×512 canvas).
  /// [scaleMultiplier] and [rotationRadians] are the incremental values for
  /// this frame (not cumulative from gesture start).
  static Matrix4 applyGesture({
    required Matrix4 source,
    required Size layerSize,
    required Offset focalPointDelta,
    required double scaleMultiplier,
    required double rotationRadians,
  }) {
    final next = Matrix4.copy(source);
    final cx = layerSize.width / 2;
    final cy = layerSize.height / 2;
    final clampedScale = _clampedScaleMultiplier(source, scaleMultiplier);

    next
      ..translate(cx, cy)
      ..rotateZ(rotationRadians)
      ..scale(clampedScale)
      ..translate(-cx, -cy);

    next.leftTranslate(focalPointDelta.dx, focalPointDelta.dy);
    return clampToCanvas(next, layerSize);
  }

  static Matrix4 clampToCanvas(Matrix4 source, Size layerSize) {
    final center = centerOf(source, layerSize);
    final clamped = Offset(
      center.dx.clamp(edgePadding, canvasExtent - edgePadding),
      center.dy.clamp(edgePadding, canvasExtent - edgePadding),
    );
    final delta = clamped - center;
    if (delta == Offset.zero) return source;
    final next = Matrix4.copy(source);
    next.leftTranslate(delta.dx, delta.dy);
    return next;
  }

  static Offset centerOf(Matrix4 transform, Size layerSize) {
    return MatrixUtils.transformPoint(
      transform,
      Offset(layerSize.width / 2, layerSize.height / 2),
    );
  }

  static double scaleOf(Matrix4 transform) {
    final storage = transform.storage;
    return math.sqrt(storage[0] * storage[0] + storage[1] * storage[1]);
  }

  static Offset toCanvas(Offset viewPoint, Size viewSize) {
    if (viewSize.width == 0 || viewSize.height == 0) return viewPoint;
    return Offset(
      viewPoint.dx / viewSize.width * canvasExtent,
      viewPoint.dy / viewSize.height * canvasExtent,
    );
  }

  static Offset toCanvasDelta(Offset viewDelta, Size viewSize) {
    return toCanvas(viewDelta, viewSize);
  }

  /// Transforms the local bounding-box corners into canvas space.
  static List<Offset> transformedCorners(Matrix4 transform, Size layerSize) {
    final local = <Offset>[
      Offset.zero,
      Offset(layerSize.width, 0),
      Offset(layerSize.width, layerSize.height),
      Offset(0, layerSize.height),
    ];
    return [
      for (final corner in local) MatrixUtils.transformPoint(transform, corner),
    ];
  }

  /// True when [point] sits inside the transformed quad, using signed
  /// cross-products of each edge (distance vectors from the bounding box).
  static bool containsPoint({
    required Matrix4 transform,
    required Size layerSize,
    required Offset point,
    double padding = 10,
  }) {
    final padded = Size(
      layerSize.width + padding * 2,
      layerSize.height + padding * 2,
    );
    final inset = Matrix4.copy(transform)..translate(-padding, -padding);
    final corners = transformedCorners(inset, padded);
    if (_pointInConvexQuad(point, corners)) return true;

    final inverse = Matrix4.tryInvert(Matrix4.copy(transform));
    if (inverse == null) return false;
    final local = MatrixUtils.transformPoint(inverse, point);
    final bounds = Rect.fromLTWH(
      -padding,
      -padding,
      layerSize.width + padding * 2,
      layerSize.height + padding * 2,
    );
    return bounds.contains(local);
  }

  static Offset deleteHandlePoint(Matrix4 transform, Size layerSize) {
    return MatrixUtils.transformPoint(transform, Offset(layerSize.width, 0));
  }

  static bool hitsDeleteHandle({
    required Matrix4 transform,
    required Size layerSize,
    required Offset point,
    double radius = 22,
  }) {
    final handle = deleteHandlePoint(transform, layerSize);
    return (handle - point).distance <= radius;
  }

  /// Index of the top-most layer under [point], or the closest layer
  /// within [snapDistance]. Returns -1 when nothing is close enough.
  static int hitTestIndex({
    required List<Matrix4> transforms,
    required List<Size> sizes,
    required Offset point,
    double snapDistance = 36,
  }) {
    assert(transforms.length == sizes.length);
    for (var i = transforms.length - 1; i >= 0; i--) {
      if (containsPoint(
        transform: transforms[i],
        layerSize: sizes[i],
        point: point,
      )) {
        return i;
      }
    }

    var closest = -1;
    var best = snapDistance;
    for (var i = transforms.length - 1; i >= 0; i--) {
      final center = centerOf(transforms[i], sizes[i]);
      final distance = (center - point).distance;
      if (distance < best) {
        best = distance;
        closest = i;
      }
    }
    return closest;
  }

  static double _clampedScaleMultiplier(Matrix4 source, double multiplier) {
    final current = scaleOf(source);
    if (current <= 0) return 1;
    final next = (current * multiplier).clamp(minScale, maxScale);
    return next / current;
  }

  static bool _pointInConvexQuad(Offset point, List<Offset> corners) {
    if (corners.length != 4) return false;
    var sign = 0.0;
    for (var i = 0; i < 4; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % 4];
      final edge = b - a;
      final toPoint = point - a;
      final cross = edge.dx * toPoint.dy - edge.dy * toPoint.dx;
      if (cross.abs() < 0.0001) continue;
      if (sign == 0) {
        sign = cross;
      } else if (cross.sign != sign.sign) {
        return false;
      }
    }
    return sign != 0 || _nearAnyEdge(point, corners);
  }

  static bool _nearAnyEdge(Offset point, List<Offset> corners) {
    for (var i = 0; i < corners.length; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % corners.length];
      if ((point - a).distance + (point - b).distance - (b - a).distance <
          1.5) {
        return true;
      }
    }
    return false;
  }
}
