import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stikk/main.dart';
import 'package:stikk/state/settings_store.dart';
import 'package:stikk/storage/storage_utility.dart';
import 'package:stikk/tiktok/tiktok_app_links.dart';
import 'package:stikk/tiktok/tiktok_share_intent.dart';

import 'tiktok_share_intent_support.dart';

ProviderScope appWithOnboardingDone() {
  final documents = Directory(
    '${Directory.systemTemp.path}/stikk_widget_documents',
  )..createSync(recursive: true);
  final temporary = Directory(
    '${Directory.systemTemp.path}/stikk_widget_temporary',
  )..createSync(recursive: true);
  return ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(
        InMemorySettingsStore(onboardingComplete: true),
      ),
      storageUtilityProvider.overrideWithValue(
        StorageUtility(
          documentsDirectory: () async => documents,
          temporaryDirectory: () async => temporary,
        ),
      ),
      tikTokShareIntentProvider.overrideWithValue(FakeTikTokShareIntent()),
      tikTokAppLinksProvider.overrideWithValue(FakeTikTokAppLinks()),
    ],
    child: const StikkApp(),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    mockShareIntent();
  });

  testWidgets('shows library and switches tabs', (tester) async {
    await tester.pumpWidget(appWithOnboardingDone());
    await tester.pump();

    expect(find.text('Library'), findsWidgets);
    expect(find.text('No packs yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-discover')));
    await tester.pump();

    expect(find.text('Discover'), findsWidgets);
    expect(find.byKey(const Key('discover-search-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-community')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Community'), findsWidgets);
    expect(find.byKey(const Key('community-masonry-grid')), findsOneWidget);
    expect(find.byKey(const Key('community-staging-tray')), findsOneWidget);
    expect(find.text('My Pack  0/30'), findsOneWidget);
  });

  testWidgets('Create opens the TikTok link sheet', (tester) async {
    await tester.pumpWidget(appWithOnboardingDone());
    await tester.pump();

    await tester.tap(find.byKey(const Key('nav-create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('tiktok-link-field')), findsOneWidget);
    expect(find.text('Import video'), findsOneWidget);
    expect(find.text('From a photo'), findsOneWidget);
  });

  testWidgets('opens Settings from the Library app bar', (tester) async {
    await tester.pumpWidget(appWithOnboardingDone());
    await tester.pump();

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Storage'), findsOneWidget);
    expect(
      find.text(
        'See what Stickr uses on this device and remove disposable working files.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('invalid TikTok link shows a friendly snackbar', (tester) async {
    await tester.pumpWidget(appWithOnboardingDone());
    await tester.pump();

    await tester.tap(find.byKey(const Key('nav-create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byKey(const Key('tiktok-link-field')),
      'https://example.com/not-tiktok',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('tiktok-import-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('doesn\'t look like a TikTok link'),
      findsOneWidget,
    );
  });
}
