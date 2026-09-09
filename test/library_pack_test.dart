import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stickr/main.dart';
import 'package:stickr/packs/pack_detail_screen.dart';
import 'package:stickr/packs/pack_models.dart';
import 'package:stickr/packs/pack_providers.dart';
import 'package:stickr/packs/pack_repository.dart';
import 'package:stickr/packs/whatsapp_export_service.dart';
import 'package:stickr/state/settings_store.dart';
import 'package:stickr/tiktok/tiktok_app_links.dart';
import 'package:stickr/tiktok/tiktok_share_intent.dart';

import 'tiktok_share_intent_support.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    mockShareIntent();
  });

  testWidgets('library shows saved packs and opens detail', (tester) async {
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

    expect(find.text('Monday moods'), findsOneWidget);
    expect(find.textContaining('Ready'), findsOneWidget);

    await tester.tap(find.text('Monday moods'));
    await tester.pumpAndSettle();

    expect(find.byType(PackDetailScreen), findsOneWidget);
    expect(find.byKey(const Key('add-to-whatsapp')), findsOneWidget);
    expect(find.byKey(const Key('share-pack')), findsOneWidget);
    expect(find.byKey(const Key('pack-sticker-grid')), findsOneWidget);
    final grid = tester.widget<GridView>(
      find.byKey(const Key('pack-sticker-grid')),
    );
    final delegate = grid.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.findChildIndexCallback, isNotNull);
    expect(delegate.findChildIndexCallback!(const ValueKey('s0')), 0);
  });

  testWidgets('Add to WhatsApp shakes and explains the 3-sticker minimum', (
    tester,
  ) async {
    final now = DateTime(2026, 1, 1);
    final repo = InMemoryPackRepository(
      seed: {
        'p2': StickerPack(
          id: 'p2',
          name: 'Draft pack',
          author: 'Ian',
          trayIconPath: 'tray.png',
          stickers: [
            StickerItem(id: 's1', filePath: 's1.webp', createdAt: now),
            StickerItem(id: 's2', filePath: 's2.webp', createdAt: now),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [packRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: PackDetailScreen(packId: 'p2')),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('add-to-whatsapp')),
    );
    expect(button.onPressed, isNotNull);
    expect(find.textContaining('minimum 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-to-whatsapp')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final transform = tester.widget<Transform>(
      find.byKey(const Key('whatsapp-export-shake')),
    );
    expect(transform.transform.getTranslation().x, isNot(0));
    expect(
      find.textContaining('WhatsApp requires at least 3 stickers'),
      findsOneWidget,
    );
  });

  testWidgets('Add to WhatsApp shows feedback when WhatsApp is missing', (
    tester,
  ) async {
    final now = DateTime(2026, 1, 1);
    final repo = InMemoryPackRepository(
      seed: {
        'p3': StickerPack(
          id: 'p3',
          name: 'Ready pack',
          author: 'Ian',
          trayIconPath: 'tray.png',
          stickers: [
            for (var i = 0; i < 3; i++)
              StickerItem(id: 's$i', filePath: 's$i.webp', createdAt: now),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      },
    );

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(WhatsAppExportService.channelName),
      (call) async {
        throw PlatformException(code: 'WHATSAPP_NOT_INSTALLED');
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel(WhatsAppExportService.channelName),
        null,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packRepositoryProvider.overrideWithValue(repo),
          whatsAppExportServiceProvider.overrideWithValue(
            WhatsAppExportService(canLaunch: (_) async => false),
          ),
        ],
        child: const MaterialApp(home: PackDetailScreen(packId: 'p3')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-to-whatsapp')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('whatsapp-not-installed-title')),
      findsOneWidget,
    );
    expect(find.text('Install WhatsApp'), findsOneWidget);
    expect(find.text('Install WhatsApp Business'), findsOneWidget);
  });

  testWidgets(
    'library grid updates when a pack is added through the repository',
    (tester) async {
      final repo = InMemoryPackRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            packRepositoryProvider.overrideWithValue(repo),
            settingsStoreProvider.overrideWithValue(
              InMemorySettingsStore(onboardingComplete: true),
            ),
            tikTokShareIntentProvider.overrideWithValue(
              FakeTikTokShareIntent(),
            ),
            tikTokAppLinksProvider.overrideWithValue(FakeTikTokAppLinks()),
          ],
          child: const StickrApp(),
        ),
      );
      await tester.pump();
      expect(find.text('No packs yet'), findsOneWidget);

      await repo.createPack(name: 'Fresh pack', author: 'Ian');
      await tester.pump();
      await tester.pump();

      expect(find.text('Fresh pack'), findsOneWidget);
      expect(find.text('No packs yet'), findsNothing);
    },
  );
}
