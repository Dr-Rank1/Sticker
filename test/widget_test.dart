import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stickr/community/giphy_service.dart';
import 'package:stickr/main.dart';
import 'package:stickr/state/settings_store.dart';
import 'package:stickr/storage/storage_utility.dart';
import 'package:stickr/tiktok/tiktok_app_links.dart';
import 'package:stickr/tiktok/tiktok_share_intent.dart';

import 'tiktok_share_intent_support.dart';

ProviderScope appWithOnboardingDone() {
  final documents = Directory(
    '${Directory.systemTemp.path}/stickr_widget_documents',
  )..createSync(recursive: true);
  final temporary = Directory(
    '${Directory.systemTemp.path}/stickr_widget_temporary',
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
      giphyServiceProvider.overrideWithValue(
        GiphyService(
          apiKey: 'test-key',
          apiGet: (_, _) async => Response<dynamic>(
            requestOptions: RequestOptions(path: GiphyService.endpoint),
            statusCode: 200,
            data: {
              'data': <dynamic>[],
              'pagination': {'offset': 0, 'count': 0, 'total_count': 0},
            },
          ),
        ),
      ),
      tikTokShareIntentProvider.overrideWithValue(FakeTikTokShareIntent()),
      tikTokAppLinksProvider.overrideWithValue(FakeTikTokAppLinks()),
    ],
    child: const StickrApp(),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    mockShareIntent();
  });

  testWidgets('shows scanner home and switches tabs', (tester) async {
    await tester.pumpWidget(appWithOnboardingDone());
    await tester.pump();

    expect(find.text('Scanner'), findsWidgets);
    expect(find.byKey(const Key('scanner-tiktok-field')), findsOneWidget);
    expect(find.byKey(const Key('scanner-scan-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-library')));
    await tester.pump();

    expect(find.text('My Packs'), findsWidgets);
    expect(find.text('No packs yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-community')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Trending'), findsWidgets);
    expect(find.byKey(const Key('community-masonry-grid')), findsOneWidget);
    expect(find.byKey(const Key('community-staging-tray')), findsOneWidget);
    expect(find.text('My Pack  0/30'), findsOneWidget);
  });

  testWidgets('Scanner rejects an invalid TikTok link', (tester) async {
    await tester.pumpWidget(appWithOnboardingDone());
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('scanner-tiktok-field')),
      'https://example.com/not-tiktok',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('scanner-scan-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('doesn\'t look like a TikTok link'),
      findsOneWidget,
    );
  });

  testWidgets('opens Settings from the My Packs app bar', (tester) async {
    await tester.pumpWidget(appWithOnboardingDone());
    await tester.pump();

    await tester.tap(find.byKey(const Key('nav-library')));
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
}
