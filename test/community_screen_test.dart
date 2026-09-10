import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stickr/community/community_models.dart';
import 'package:stickr/community/community_sticker_feed.dart';
import 'package:stickr/community/giphy_service.dart';
import 'package:stickr/editor/image_sticker_service.dart';
import 'package:stickr/main.dart';
import 'package:stickr/packs/batch_export_use_case.dart';
import 'package:stickr/packs/pack_models.dart';
import 'package:stickr/packs/pack_providers.dart';
import 'package:stickr/packs/pack_repository.dart';
import 'package:stickr/packs/whatsapp_export_service.dart';
import 'package:stickr/state/settings_store.dart';
import 'package:stickr/tiktok/comment_sticker_formatter.dart';
import 'package:stickr/tiktok/tiktok_app_links.dart';
import 'package:stickr/tiktok/tiktok_share_intent.dart';

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
  GiphyService? giphy,
  WhatsAppExportService? whatsApp,
}) {
  final formatter = _FakeFormatter();
  return ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(
        InMemorySettingsStore(onboardingComplete: true),
      ),
      communityStickerFeedProvider.overrideWithValue(feed),
      if (repository != null)
        packRepositoryProvider.overrideWithValue(repository),
      if (giphy != null) giphyServiceProvider.overrideWithValue(giphy),
      if (whatsApp != null)
        whatsAppExportServiceProvider.overrideWithValue(whatsApp),
      commentStickerFormatterProvider.overrideWithValue(formatter),
      if (repository != null && whatsApp != null)
        batchExportUseCaseProvider.overrideWithValue(
          _WidgetBatchExportUseCase(repository, whatsApp, formatter),
        ),
      tikTokShareIntentProvider.overrideWithValue(FakeTikTokShareIntent()),
      tikTokAppLinksProvider.overrideWithValue(FakeTikTokAppLinks()),
    ],
    child: const StickrApp(),
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

    expect(find.text('Trending'), findsWidgets);
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
    final giphy = _FakeGiphyService();
    final whatsApp = _FakeWhatsAppExportService();
    await tester.pumpWidget(
      communityApp(
        feed: _FakeFeed(),
        repository: repo,
        giphy: giphy,
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
    expect(giphy.downloadedIds, ['one', 'two', 'three']);
    expect(whatsApp.exportedPack?.id, packs.single.id);
    expect(find.text('My Pack  0/30'), findsOneWidget);
    export = tester.widget<FilledButton>(
      find.byKey(const Key('community-export-pack')),
    );
    expect(export.onPressed, isNull);
  });

  testWidgets('failed Giphy request shows a Retry button', (tester) async {
    await tester.pumpWidget(communityApp(feed: _FailingFeed()));
    await tester.pump();
    await openCommunity(tester);

    expect(find.text('Could not load trending stickers.'), findsOneWidget);
    expect(find.byKey(const Key('community-retry')), findsOneWidget);
  });
}

class _FakeFeed extends CommunityStickerFeed {
  _FakeFeed() : super(GiphyService(apiKey: 'test-key'));

  @override
  Future<CommunityStickerPage> loadPage({String? cursor}) async {
    return const CommunityStickerPage(stickers: stickers, nextCursor: null);
  }
}

class _FailingFeed extends CommunityStickerFeed {
  _FailingFeed() : super(GiphyService(apiKey: 'test-key'));

  @override
  Future<CommunityStickerPage> loadPage({String? cursor}) {
    throw const GiphyException('Could not load trending stickers.');
  }
}

class _FakeGiphyService extends GiphyService {
  _FakeGiphyService() : super(apiKey: 'test-key');

  final List<String> downloadedIds = [];

  @override
  Future<File> downloadSticker({
    required String id,
    required String url,
    CancelToken? cancelToken,
  }) async {
    downloadedIds.add(id);
    return File('download_$id.gif');
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

class _WidgetBatchExportUseCase extends BatchExportUseCase {
  _WidgetBatchExportUseCase(
    this.repository,
    this.whatsApp,
    CommentStickerFormatter formatter,
  ) : super(repository, whatsApp, formatter);

  final PackRepository repository;
  final WhatsAppExportService whatsApp;

  @override
  Stream<BatchExportProgress> export({
    required List<BatchExportItem> items,
    required String packName,
    required String author,
  }) async* {
    final files = <File>[];
    for (var index = 0; index < items.length; index++) {
      files.add((await items[index].download()).file);
      yield BatchExportProgress(
        stage: BatchExportStage.itemReady,
        itemId: items[index].id,
        itemIndex: index,
        completedItems: index + 1,
        totalItems: items.length,
      );
    }
    final now = DateTime.now();
    final draft = StickerPack(
      id: 'community_batch',
      name: packName,
      author: author,
      trayIconPath: 'tray.png',
      trayIconBytes: const [1],
      stickers: [
        for (var index = 0; index < files.length; index++)
          StickerItem(
            id: items[index].id,
            filePath: files[index].path,
            createdAt: now,
            animated: false,
          ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    final result = await whatsApp.exportToWhatsApp(draft);
    var saved = await repository.createPack(
      name: packName,
      author: author,
      identifier: draft.id,
    );
    for (final file in files) {
      saved = await repository.addSticker(
        packId: saved.id,
        sourcePath: file.path,
        animated: false,
      );
    }
    saved = await repository.save(saved);
    yield BatchExportProgress(
      stage: BatchExportStage.complete,
      completedItems: items.length,
      totalItems: items.length,
      result: BatchExportResult(pack: saved, message: result.message),
    );
  }
}
