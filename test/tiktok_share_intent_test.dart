import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:stikk/main.dart';
import 'package:stikk/state/settings_store.dart';
import 'package:stikk/tiktok/apify_service.dart';
import 'package:stikk/tiktok/comment_sticker_isolate.dart';
import 'package:stikk/tiktok/comment_sticker_sheet.dart';
import 'package:stikk/tiktok/tiktok_comment_service.dart';
import 'package:stikk/tiktok/tiktok_app_links.dart';
import 'package:stikk/tiktok/tiktok_share_intent.dart';
import 'package:stikk/widgets/main_scaffold.dart';

import 'tiktok_share_intent_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(mockShareIntent);

  testWidgets('shared TikTok URL skips the home screen and opens the scan UI', (
    tester,
  ) async {
    final gate = Completer<void>();
    await tester.pumpWidget(
      _shareApp(
        apify: _FakeApifyService(gate: gate),
        initialSharedMedia: [
          SharedMediaFile(
            path: 'https://www.tiktok.com/@creator/video/7393468652906925317',
            type: SharedMediaType.text,
            mimeType: 'text/plain',
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('shared-tiktok-scan-page')), findsOneWidget);
    expect(find.text('Scanning comments for stickers...'), findsOneWidget);
    expect(find.byType(MainScaffold), findsNothing);
    expect(find.text('Library'), findsNothing);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Comment stickers'), findsOneWidget);
    expect(find.byKey(const Key('comment-sticker-grid')), findsOneWidget);
    expect(find.byType(MainScaffold), findsNothing);
  });

  testWidgets('getInitialMedia cold start routes into the scan UI', (
    tester,
  ) async {
    final gate = Completer<void>();
    await tester.pumpWidget(
      _shareApp(
        apify: _FakeApifyService(gate: gate),
        shareIntent: FakeTikTokShareIntent(
          initialMedia: [
            SharedMediaFile(
              path: 'https://vm.tiktok.com/ZMshare/',
              type: SharedMediaType.url,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('shared-tiktok-scan-page')), findsOneWidget);
    expect(find.text('Scanning comments for stickers...'), findsOneWidget);
    expect(find.byType(MainScaffold), findsNothing);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Comment stickers'), findsOneWidget);
  });

  testWidgets('background share stream bypasses home and starts scanning', (
    tester,
  ) async {
    final gate = Completer<void>();
    final media = StreamController<List<SharedMediaFile>>.broadcast();
    addTearDown(media.close);

    await tester.pumpWidget(
      _shareApp(
        apify: _FakeApifyService(gate: gate),
        shareIntent: FakeTikTokShareIntent(mediaStream: media.stream),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(MainScaffold), findsOneWidget);
    expect(find.text('Library'), findsWidgets);

    media.add([
      SharedMediaFile(
        path: 'Shared https://vt.tiktok.com/ZMlive/ from TikTok',
        type: SharedMediaType.text,
        mimeType: 'text/plain',
      ),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MainScaffold), findsNothing);
    expect(find.byKey(const Key('shared-tiktok-scan-page')), findsOneWidget);
    expect(find.text('Scanning comments for stickers...'), findsOneWidget);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Comment stickers'), findsOneWidget);
  });

  testWidgets('non-TikTok shared text stays on the home screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _shareApp(
        apify: _FakeApifyService(),
        shareIntent: FakeTikTokShareIntent(
          initialMedia: [
            SharedMediaFile(
              path: 'https://example.com/video/123',
              type: SharedMediaType.text,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(MainScaffold), findsOneWidget);
    expect(find.byKey(const Key('shared-tiktok-scan-page')), findsNothing);
  });

  testWidgets('shared TikTok URL does not skip onboarding', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tikTokShareIntentProvider.overrideWithValue(FakeTikTokShareIntent()),
          tikTokAppLinksProvider.overrideWithValue(FakeTikTokAppLinks()),
        ],
        child: StikkApp(
          initialSharedMedia: [
            SharedMediaFile(
              path: 'https://www.tiktok.com/@creator/video/1234567890',
              type: SharedMediaType.text,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Paste TikTok links'), findsOneWidget);
    expect(find.byKey(const Key('shared-tiktok-scan-page')), findsNothing);
  });

  testWidgets('TikTok app link skips home and opens the Apify scan', (
    tester,
  ) async {
    final gate = Completer<void>();
    await tester.pumpWidget(
      _shareApp(
        apify: _FakeApifyService(gate: gate),
        appLinks: FakeTikTokAppLinks(
          initialUri: Uri.parse(
            'https://www.tiktok.com/@creator/video/7393468652906925317',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('shared-tiktok-scan-page')), findsOneWidget);
    expect(find.text('Scanning comments for stickers...'), findsOneWidget);
    expect(find.byType(MainScaffold), findsNothing);
  });

  testWidgets('vm.tiktok.com app link while running starts the scan', (
    tester,
  ) async {
    final links = StreamController<Uri>.broadcast();
    addTearDown(links.close);
    await tester.pumpWidget(
      _shareApp(
        apify: _FakeApifyService(),
        appLinks: FakeTikTokAppLinks(uris: links.stream),
      ),
    );
    await tester.pump();
    expect(find.byType(MainScaffold), findsOneWidget);

    links.add(Uri.parse('https://vm.tiktok.com/ZMappLink/'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('shared-tiktok-scan-page')), findsOneWidget);
    expect(find.byType(MainScaffold), findsNothing);
  });

  testWidgets('non-TikTok app links stay on the home screen', (tester) async {
    await tester.pumpWidget(
      _shareApp(
        apify: _FakeApifyService(),
        appLinks: FakeTikTokAppLinks(
          initialUri: Uri.parse('https://example.com/not-tiktok'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(MainScaffold), findsOneWidget);
    expect(find.byKey(const Key('shared-tiktok-scan-page')), findsNothing);
  });
}

Widget _shareApp({
  required ApifyService apify,
  List<SharedMediaFile> initialSharedMedia = const [],
  TikTokShareIntent? shareIntent,
  TikTokAppLinks? appLinks,
}) {
  return ProviderScope(
    overrides: [
      apifyServiceProvider.overrideWithValue(apify),
      settingsStoreProvider.overrideWithValue(
        InMemorySettingsStore(onboardingComplete: true),
      ),
      commentStickerCacheDirectoryProvider.overrideWithValue(
        () async => Directory.systemTemp,
      ),
      commentStickerPipelineProvider.overrideWithValue(
        ImmediateCommentStickerPipeline(),
      ),
      tikTokShareIntentProvider.overrideWithValue(
        shareIntent ?? FakeTikTokShareIntent(),
      ),
      tikTokAppLinksProvider.overrideWithValue(
        appLinks ?? FakeTikTokAppLinks(),
      ),
    ],
    child: StikkApp(initialSharedMedia: initialSharedMedia),
  );
}

class _FakeApifyService extends ApifyService {
  _FakeApifyService({this.stickers = const [_sticker], this.gate})
    : super(token: 'test-token');

  static const _sticker = CommentSticker(
    id: '1_0',
    commentId: '1',
    imageUrl: 'https://example.com/sticker.webp',
    author: 'Ian',
  );

  final List<CommentSticker> stickers;
  final Completer<void>? gate;
  String? lastUrl;

  @override
  Future<List<CommentSticker>> fetchCommentStickers(String postUrl) async {
    lastUrl = postUrl;
    final pending = gate;
    if (pending != null) await pending.future;
    return stickers;
  }
}
