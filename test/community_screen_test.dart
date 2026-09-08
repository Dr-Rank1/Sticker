import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stikk/community/community_catalog.dart';
import 'package:stikk/community/community_pack_detail_screen.dart';
import 'package:stikk/main.dart';
import 'package:stikk/packs/pack_providers.dart';
import 'package:stikk/packs/pack_repository.dart';
import 'package:stikk/state/settings_store.dart';
import 'package:stikk/tiktok/tiktok_app_links.dart';
import 'package:stikk/tiktok/tiktok_share_intent.dart';

import 'tiktok_share_intent_support.dart';

CommunityCatalog loadBundledCatalog() {
  return CommunityCatalog.fromJsonString(
    File('assets/community/packs.json').readAsStringSync(),
  );
}

ProviderScope communityApp({
  Duration downloadDelay = Duration.zero,
  PackRepository? repository,
}) {
  final catalog = loadBundledCatalog();
  return ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(
        InMemorySettingsStore(onboardingComplete: true),
      ),
      communityCatalogProvider.overrideWith((ref) async => catalog),
      communityDownloadDelayProvider.overrideWithValue(downloadDelay),
      if (repository != null)
        packRepositoryProvider.overrideWithValue(repository),
      tikTokShareIntentProvider.overrideWithValue(FakeTikTokShareIntent()),
      tikTokAppLinksProvider.overrideWithValue(FakeTikTokAppLinks()),
    ],
    child: const StikkApp(),
  );
}

Future<void> openCommunity(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav-community')));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    mockShareIntent();
  });

  testWidgets('community feed shows trending pack cards', (tester) async {
    await tester.pumpWidget(communityApp());
    await tester.pump();
    await openCommunity(tester);

    expect(find.text('Community'), findsWidgets);
    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('Anime reactions'), findsOneWidget);
    expect(find.text('sakura.ink'), findsOneWidget);
    expect(find.text('210.8k'), findsOneWidget);
    expect(find.text('#anime'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Monday moods'), 400);
    expect(find.text('Monday moods'), findsOneWidget);
    expect(find.text('nina.makes'), findsOneWidget);
    expect(find.text('#funny'), findsWidgets);
  });

  testWidgets('New filter reorders the feed', (tester) async {
    await tester.pumpWidget(communityApp());
    await tester.pump();
    await openCommunity(tester);

    await tester.tap(find.byKey(const Key('community-filter-newest')));
    await tester.pump();

    expect(find.text('Weekend plans'), findsOneWidget);
    expect(find.text('sun.day'), findsOneWidget);
  });

  testWidgets('tapping a pack opens the detail screen', (tester) async {
    await tester.pumpWidget(communityApp());
    await tester.pump();
    await openCommunity(tester);

    await tester.tap(
      find.byKey(const Key('community-pack-comm_anime_reactions')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CommunityPackDetailScreen), findsOneWidget);
    expect(find.text('Download Pack'), findsOneWidget);
    expect(find.text('Big feelings, bigger eyes, zero chill.'), findsOneWidget);
    expect(find.text('8 stickers'), findsOneWidget);
    expect(find.text('#anime'), findsWidgets);
  });

  testWidgets('Download Pack shows a loading state then saves to library', (
    tester,
  ) async {
    final repo = InMemoryPackRepository();
    await tester.pumpWidget(
      communityApp(
        downloadDelay: const Duration(milliseconds: 250),
        repository: repo,
      ),
    );
    await tester.pump();
    await openCommunity(tester);

    await tester.tap(
      find.byKey(const Key('community-pack-comm_anime_reactions')),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('download-community-pack')));
    await tester.pump();

    expect(find.text('Downloading…'), findsOneWidget);
    expect(
      find.byKey(const Key('download-community-pack-loading')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(find.text('In library'), findsOneWidget);
    expect(find.textContaining('saved to Library'), findsWidgets);

    final packs = await repo.getAll();
    expect(packs, hasLength(1));
    expect(packs.single.name, 'Anime reactions');
    expect(packs.single.author, 'sakura.ink');
  });
}
