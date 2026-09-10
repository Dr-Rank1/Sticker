import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stickr/main.dart';
import 'package:stickr/onboarding/onboarding_screen.dart';
import 'package:stickr/l10n/l10n.dart';
import 'package:stickr/permissions/media_permission_service.dart';
import 'package:stickr/state/settings_store.dart';
import 'package:stickr/tiktok/tiktok_app_links.dart';
import 'package:stickr/tiktok/tiktok_share_intent.dart';

import 'tiktok_share_intent_support.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    mockShareIntent();
  });

  testWidgets('onboarding carousel shows the three feature screens', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tikTokShareIntentProvider.overrideWithValue(FakeTikTokShareIntent()),
          tikTokAppLinksProvider.overrideWithValue(FakeTikTokAppLinks()),
        ],
        child: const StickrApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Paste TikTok links'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-skip')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Edit & remove backgrounds'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Export to WhatsApp'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('Get started explains storage access before entering the app', (
    tester,
  ) async {
    var requested = false;
    final service = MediaPermissionService(
      platform: TargetPlatform.android,
      androidSdkInt: () async => 34,
      readStatus: (_) async => PermissionStatus.denied,
      requestPermissions: (permissions) async {
        requested = true;
        return {
          for (final permission in permissions)
            permission: PermissionStatus.granted,
        };
      },
      openSettings: () async => true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaPermissionServiceProvider.overrideWithValue(service),
          tikTokShareIntentProvider.overrideWithValue(FakeTikTokShareIntent()),
          tikTokAppLinksProvider.overrideWithValue(FakeTikTokAppLinks()),
        ],
        child: const StickrApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Allow access to photos & videos'), findsOneWidget);
    expect(find.textContaining('Nothing is uploaded'), findsOneWidget);

    await tester.tap(find.byKey(const Key('permission-allow')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(requested, isTrue);
    expect(find.text('Scanner'), findsWidgets);
    expect(find.byKey(const Key('scanner-tiktok-field')), findsOneWidget);
  });

  testWidgets('Not now still finishes onboarding', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          mediaPermissionServiceProvider.overrideWithValue(
            MediaPermissionService(
              platform: TargetPlatform.linux,
              requestPermissions: (_) async => {},
            ),
          ),
          tikTokShareIntentProvider.overrideWithValue(FakeTikTokShareIntent()),
          tikTokAppLinksProvider.overrideWithValue(FakeTikTokAppLinks()),
        ],
        child: const StickrApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(const Key('permission-not-now')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Scanner'), findsWidgets);
  });

  test('onboarding copy covers the three product pillars', () {
    expect(kOnboardingPageCount, 3);
    expect(fallbackLocalizations.onboardingTikTokTitle, contains('TikTok'));
    expect(
      fallbackLocalizations.onboardingEditTitle.toLowerCase(),
      contains('background'),
    );
    expect(fallbackLocalizations.onboardingWhatsAppTitle, contains('WhatsApp'));
  });
}
