import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/editor/layer_transform.dart';

void main() {
  const layerSize = Size(80, 40);

  Matrix4 centered() {
    return LayerTransform.initial(
      canvasSize: const Size(512, 512),
      layerSize: layerSize,
    );
  }

  test('scale and rotation are applied from the widget center', () {
    final origin = centered();
    final before = LayerTransform.centerOf(origin, layerSize);

    final next = LayerTransform.applyGesture(
      source: origin,
      layerSize: layerSize,
      focalPointDelta: Offset.zero,
      scaleMultiplier: 1.75,
      rotationRadians: math.pi / 5,
    );

    final after = LayerTransform.centerOf(next, layerSize);
    expect(after.dx, closeTo(before.dx, 0.001));
    expect(after.dy, closeTo(before.dy, 0.001));
    expect(LayerTransform.scaleOf(next), closeTo(1.75, 0.001));
  });

  test('focal point delta pans the layer in canvas space', () {
    final origin = centered();
    final before = LayerTransform.centerOf(origin, layerSize);

    final next = LayerTransform.applyGesture(
      source: origin,
      layerSize: layerSize,
      focalPointDelta: const Offset(24, -18),
      scaleMultiplier: 1,
      rotationRadians: 0,
    );

    final after = LayerTransform.centerOf(next, layerSize);
    expect(after.dx, closeTo(before.dx + 24, 0.001));
    expect(after.dy, closeTo(before.dy - 18, 0.001));
  });

  test('hit-testing uses distance vectors from the transformed box', () {
    final transform = centered();
    final center = LayerTransform.centerOf(transform, layerSize);

    expect(
      LayerTransform.containsPoint(
        transform: transform,
        layerSize: layerSize,
        point: center,
      ),
      isTrue,
    );
    expect(
      LayerTransform.containsPoint(
        transform: transform,
        layerSize: layerSize,
        point: Offset.zero,
        padding: 0,
      ),
      isFalse,
    );

    final rotated = LayerTransform.applyGesture(
      source: transform,
      layerSize: layerSize,
      focalPointDelta: Offset.zero,
      scaleMultiplier: 1,
      rotationRadians: math.pi / 2,
    );
    expect(
      LayerTransform.containsPoint(
        transform: rotated,
        layerSize: layerSize,
        point: LayerTransform.centerOf(rotated, layerSize),
      ),
      isTrue,
    );
  });

  test('z-index hit-test prefers the top-most overlapping layer', () {
    final bottom = LayerTransform.initial(
      canvasSize: const Size(512, 512),
      layerSize: layerSize,
    );
    final top = LayerTransform.applyGesture(
      source: bottom,
      layerSize: layerSize,
      focalPointDelta: const Offset(8, 8),
      scaleMultiplier: 1,
      rotationRadians: 0,
    );
    final point = LayerTransform.centerOf(top, layerSize);

    expect(
      LayerTransform.hitTestIndex(
        transforms: [bottom, top],
        sizes: [layerSize, layerSize],
        point: point,
      ),
      1,
    );
  });
}
