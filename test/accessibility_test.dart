import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stickr/editor/editor_models.dart';
import 'package:stickr/editor/widgets/overlay_canvas.dart';
import 'package:stickr/haptics/haptic_service.dart';
import 'package:stickr/main.dart';
import 'package:stickr/packs/pack_models.dart';
import 'package:stickr/packs/pack_providers.dart';
import 'package:stickr/packs/pack_repository.dart';
import 'package:stickr/state/settings_store.dart';
import 'package:stickr/theme/app_theme.dart';
import 'package:stickr/tiktok/tiktok_app_links.dart';
import 'package:stickr/tiktok/tiktok_share_intent.dart';

import 'tiktok_share_intent_support.dart';

void main() {
  late HapticService previousHaptics;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    mockShareIntent();
  });

  setUp(() {
    previousHaptics = hapticService;
  });

  tearDown(() {
    hapticService = previousHaptics;
  });

  testWidgets('sticker canvas exposes TalkBack labels and hints', (
    tester,
  ) async {
    final layer = StickerLayer.text('Hello', id: 'ov_1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: OverlayCanvas(
                layers: [layer],
                selectedId: layer.id,
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

    expect(find.bySemanticsLabel('Sticker canvas'), findsOneWidget);
    expect(find.bySemanticsLabel('Text sticker, Hello'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete sticker'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('sticker-canvas'))),
      matchesSemantics(
        label: 'Sticker canvas',
        hint: 'Drag a sticker to move it. Pinch to resize. Rotate with two fingers.',
        isButton: true,
      ),
    );
  });

  testWidgets('moving a sticker fires a light haptic once per gesture', (
    tester,
  ) async {
    final recorder = RecordingHapticService();
    hapticService = recorder;
    var layer = StickerLayer.text('Hi', id: 'ov_1');

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

    expect(
      recorder.events.where((event) => event == 'lightImpact'),
      hasLength(1),
    );
  });

  testWidgets('theme builder clamps MediaQuery.textScalerOf', (tester) async {
    late TextScaler scaler;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.4)),
        child: Builder(
          builder: (context) {
            return AppTheme.appBuilder(
              context,
              Builder(
                builder: (context) {
                  scaler = MediaQuery.textScalerOf(context);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );

    expect(scaler.scale(10), closeTo(16.0, 0.01));
    expect(AppTheme.maxTextScale, 1.6);
  });

  testWidgets('library pack cards stay within bounds at a large text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final now = DateTime(2026, 1, 1);
    final repo = InMemoryPackRepository(
      seed: {
        'p1': StickerPack(
          id: 'p1',
          name: 'Monday moods',
          author: 'nina',
          trayIconPath: 'missing.png',
          stickers: [
            for (var i = 0; i < 3; i++)
              StickerItem(id: 's$i', filePath: 's$i.webp', createdAt: now),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packRepositoryProvider.overrideWithValue(repo),
          settingsStoreProvider.overrideWithValue(
            InMemorySettingsStore(onboardingComplete: true),
          ),
          tikTokShareIntentProvider.overrideWithValue(FakeTikTokShareIntent()),
          tikTokAppLinksProvider.overrideWithValue(FakeTikTokAppLinks()),
        ],
        child: const StickrApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Monday moods'), findsOneWidget);
    expect(find.bySemanticsLabel('Monday moods'), findsWidgets);
  });
}
