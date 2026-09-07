import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stikk/main.dart';
import 'package:stikk/packs/pack_detail_screen.dart';
import 'package:stikk/packs/pack_models.dart';
import 'package:stikk/packs/pack_providers.dart';
import 'package:stikk/packs/pack_repository.dart';
import 'package:stikk/packs/whatsapp_export_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
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
              StickerItem(
                id: 's$i',
                filePath: 's$i.webp',
                createdAt: now,
              ),
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
        ],
        child: const StikkApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monday moods'), findsOneWidget);
    expect(find.textContaining('Ready'), findsOneWidget);

    await tester.tap(find.text('Monday moods'));
    await tester.pumpAndSettle();

    expect(find.byType(PackDetailScreen), findsOneWidget);
    expect(find.byKey(const Key('add-to-whatsapp')), findsOneWidget);
  });

  testWidgets('Add to WhatsApp is disabled until 3 stickers', (tester) async {
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
        overrides: [
          packRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: PackDetailScreen(packId: 'p2'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('add-to-whatsapp')),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('minimum 3'), findsOneWidget);
  });

  testWidgets('Add to WhatsApp shows feedback when WhatsApp is missing', (tester) async {
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
        ],
        child: const MaterialApp(
          home: PackDetailScreen(packId: 'p3'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-to-whatsapp')));
    await tester.pumpAndSettle();

    expect(find.text('WhatsApp isn’t installed on this device.'), findsOneWidget);
  });
}
