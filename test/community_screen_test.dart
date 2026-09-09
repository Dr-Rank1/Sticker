import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stikk/community/community_models.dart';
import 'package:stikk/community/community_sticker_feed.dart';
import 'package:stikk/discover/tenor_repository.dart';
import 'package:stikk/editor/image_sticker_service.dart';
import 'package:stikk/main.dart';
import 'package:stikk/packs/pack_models.dart';
import 'package:stikk/packs/pack_providers.dart';
import 'package:stikk/packs/pack_repository.dart';
import 'package:stikk/packs/whatsapp_export_service.dart';
import 'package:stikk/state/settings_store.dart';
import 'package:stikk/tiktok/comment_sticker_formatter.dart';
import 'package:stikk/tiktok/tiktok_app_links.dart';
import 'package:stikk/tiktok/tiktok_share_intent.dart';

import 'tiktok_share_intent_support.dart';

const stickers = [
  CommunitySticker(
    id: 'one',
    label: 'One',
    imageUrl: 'https://example.com/one.webp',
    animated: true,
  ),
  CommunitySticker(
    id: 'two',
    label: 'Two',
    imageUrl: 'https://example.com/two.webp',
    width: 400,
    height: 600,
  ),
  CommunitySticker(
    id: 'three',
    label: 'Three',
    imageUrl: 'https://example.com/three.webp',
  ),
  CommunitySticker(
    id: 'four',
    label: 'Four',
    imageUrl: 'https://example.com/four.webp',
  ),
  CommunitySticker(
    id: 'five',
    label: 'Five',
    imageUrl: 'https://example.com/five.webp',
  ),
  CommunitySticker(
    id: 'six',
    label: 'Six',
    imageUrl: 'https://example.com/six.webp',
  ),
];

ProviderScope communityApp({
  required CommunityStickerFeed feed,
  PackRepository? repository,
  TenorRepository? tenor,
  WhatsAppExportService? whatsApp,
}) {
  return ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(
        InMemorySettingsStore(onboardingComplete: true),
      ),
      communityStickerFeedProvider.overrideWithValue(feed),
      if (repository != null)
        packRepositoryProvider.overrideWithValue(repository),
      if (tenor != null) tenorRepositoryProvider.overrideWithValue(tenor),
      if (whatsApp != null)
        whatsAppExportServiceProvider.overrideWithValue(whatsApp),
      commentStickerFormatterProvider.overrideWithValue(_FakeFormatter()),
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

  testWidgets('shows a masonry feed and persistent empty staging tray', (
    tester,
  ) async {
    await tester.pumpWidget(communityApp(feed: _FakeFeed()));
    await tester.pump();
    await openCommunity(tester);

    expect(find.text('Community'), findsWidgets);
    expect(find.byKey(const Key('community-masonry-grid')), findsOneWidget);
    expect(find.byKey(const Key('community-staging-tray')), findsOneWidget);
    expect(find.text('My Pack  0/30'), findsOneWidget);
    expect(find.text('GIF'), findsWidgets);
    final export = tester.widget<FilledButton>(
      find.byKey(const Key('community-export-pack')),
    );
    expect(export.onPressed, isNull);
  });

  testWidgets('three collected stickers enable and export My Pack', (
    tester,
  ) async {
    final repo = InMemoryPackRepository();
    final tenor = _FakeTenorRepository();
    final whatsApp = _FakeWhatsAppExportService();
    await tester.pumpWidget(
      communityApp(
        feed: _FakeFeed(),
        repository: repo,
        tenor: tenor,
        whatsApp: whatsApp,
      ),
    );
    await tester.pump();
    await openCommunity(tester);

    for (final id in ['one', 'two', 'three']) {
      final add = find.byKey(Key('community-add-$id'));
      await tester.scrollUntilVisible(
        add,
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('community-masonry-grid')),
          matching: find.byType(Scrollable),
        ),
      );
      tester.widget<IconButton>(add).onPressed!.call();
      await tester.pump();
    }

    expect(find.text('My Pack  3/30'), findsOneWidget);
    expect(find.byKey(const Key('community-tray-list')), findsOneWidget);
    var export = tester.widget<FilledButton>(
      find.byKey(const Key('community-export-pack')),
    );
    expect(export.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('community-export-pack')));
    await tester.pump();
    await tester.pump();

    final packs = await repo.getAll();
    expect(packs, hasLength(1));
    expect(packs.single.name, 'My Pack');
    expect(packs.single.stickers, hasLength(3));
    expect(packs.single.stickers.every((item) => !item.animated), isTrue);
    expect(tenor.downloadedIds, ['one', 'two', 'three']);
    expect(whatsApp.exportedPack?.id, packs.single.id);
    expect(find.text('My Pack  0/30'), findsOneWidget);
    export = tester.widget<FilledButton>(
      find.byKey(const Key('community-export-pack')),
    );
    expect(export.onPressed, isNull);
  });

  test(
    'mock feed supplies distinct endless pages of transparent WebPs',
    () async {
      final feed = CommunityStickerFeed(TenorRepository());
      final first = await feed.loadPage();
      final second = await feed.loadPage(cursor: first.nextCursor);

      expect(first.stickers, hasLength(24));
      expect(second.stickers, hasLength(24));
      expect(first.nextCursor, isNotNull);
      expect(second.nextCursor, isNot(first.nextCursor));
      expect(
        first.stickers.every((item) => item.imageUrl.contains('.webp')),
        isTrue,
      );
      expect(first.stickers.any((item) => item.animated), isTrue);
      expect(first.stickers.any((item) => !item.animated), isTrue);
    },
  );
}

class _FakeFeed extends CommunityStickerFeed {
  _FakeFeed() : super(TenorRepository());

  @override
  Future<CommunityStickerPage> loadPage({String? cursor}) async {
    return const CommunityStickerPage(stickers: stickers, nextCursor: null);
  }
}

class _FakeTenorRepository extends TenorRepository {
  final List<String> downloadedIds = [];

  @override
  Future<File> downloadSticker(
    TenorSticker sticker, {
    void Function(double? progress)? onProgress,
  }) async {
    downloadedIds.add(sticker.id);
    return File('download_${sticker.id}.webp');
  }
}

class _FakeFormatter extends CommentStickerFormatter {
  _FakeFormatter() : super(ImageStickerService());

  @override
  Future<File> makeWhatsAppReady(File source) async {
    return File('ready_${source.path}');
  }
}

class _FakeWhatsAppExportService extends WhatsAppExportService {
  StickerPack? exportedPack;

  @override
  Future<WhatsAppExportResult> exportToWhatsApp(StickerPack pack) async {
    exportedPack = pack;
    return WhatsAppExportResult(pack: pack, message: 'Added to WhatsApp.');
  }
}
