import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stickr/editor/canvas_exporter.dart';
import 'package:stickr/editor/editor_models.dart';
import 'package:stickr/editor/widgets/layer_content.dart';
import 'package:stickr/editor/widgets/overlay_canvas.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('tapping a layer selects it and shows a dashed delete chrome', (
    tester,
  ) async {
    String? selected;
    final layer = StickerLayer.text('Hello', id: 'ov_1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return OverlayCanvas(
                    layers: [layer],
                    selectedId: selected,
                    onSelect: (id) => setState(() => selected = id),
                    onChanged: (_) {},
                    onGestureStart: () {},
                    onGestureEnd: () {},
                    onDelete: (_) {},
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(OverlayCanvas));
    await tester.pump();

    expect(selected, 'ov_1');
    expect(find.byType(DashedSelectionBorder), findsOneWidget);
    expect(find.byKey(const Key('layer-delete-ov_1')), findsOneWidget);
  });

  testWidgets('scale gesture pans the active layer via Matrix4', (
    tester,
  ) async {
    var layer = StickerLayer.text('Hi', id: 'ov_1');
    final startX = layer.transform.storage[12];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return OverlayCanvas(
                    layers: [layer],
                    selectedId: layer.id,
                    onSelect: (_) {},
                    onChanged: (next) => setState(() => layer = next),
                    onGestureStart: () {},
                    onGestureEnd: () {},
                    onDelete: (_) {},
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(OverlayCanvas), const Offset(36, 0));
    await tester.pump();

    expect(layer.transform.storage[12], greaterThan(startX));
    expect(find.byType(DashedSelectionBorder), findsOneWidget);
    expect(find.byKey(const Key('layer-delete-ov_1')), findsOneWidget);
  });

  testWidgets('RepaintBoundary capture returns a flat PNG byte array', (
    tester,
  ) async {
    final captureKey = GlobalKey();
    final layer = StickerLayer.text('Export me', id: 'ov_1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: OverlayCanvas(
                captureKey: captureKey,
                layers: [layer],
                selectedId: null,
                showSelection: false,
                onSelect: (_) {},
                onChanged: (_) {},
                onGestureStart: () {},
                onGestureEnd: () {},
                onDelete: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final bytes = await tester.runAsync(
      () => CanvasExporter.capturePng(captureKey),
    );
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(100));
    expect(bytes[0], 0x89);
    expect(bytes[1], 0x50); // PNG magic
  });
}
