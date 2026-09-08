import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stikk/editor/image_sticker_service.dart';
import 'package:stikk/packs/pack_providers.dart';
import 'package:stikk/packs/pack_repository.dart';
import 'package:stikk/state/settings_store.dart';
import 'package:stikk/theme/app_theme.dart';
import 'package:stikk/tiktok/apify_service.dart';
import 'package:stikk/tiktok/comment_sticker_formatter.dart';
import 'package:stikk/tiktok/comment_sticker_isolate.dart';
import 'package:stikk/tiktok/comment_sticker_sheet.dart';
import 'package:stikk/tiktok/tiktok_comment_service.dart';
import 'package:stikk/widgets/main_scaffold.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('clipboard TikTok URL shows a scan dialog then a sticker grid', (
    tester,
  ) async {
    final gate = Completer<void>();
    final apify = _FakeApifyService(
      gate: gate,
      stickers: const [
        CommentSticker(
          id: '1_0',
          commentId: '1',
          imageUrl: 'https://example.com/sticker.webp',
          author: 'Ian',
        ),
        CommentSticker(
          id: '2_0',
          commentId: '2',
          imageUrl: 'https://example.com/reply.webp',
          author: 'Ada',
        ),
      ],
    );
    _mockClipboard(
      tester,
      'https://www.tiktok.com/@creator/video/7393468652906925317',
    );

    await tester.pumpWidget(_app(apify));
    await tester.pump();
    await tester.pump();

    expect(find.text('Scanning comments for stickers...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.byType(CommentScanLoadingDialog), findsOneWidget);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Scanning comments for stickers...'), findsNothing);
    expect(find.text('Comment stickers'), findsOneWidget);
    expect(find.byKey(const Key('comment-sticker-grid')), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNWidgets(2));
    final grid = tester.widget<GridView>(
      find.byKey(const Key('comment-sticker-grid')),
    );
    final delegate = grid.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.findChildIndexCallback, isNotNull);
    expect(delegate.findChildIndexCallback!(const ValueKey('1_0')), 0);
    expect(delegate.findChildIndexCallback!(const ValueKey('2_0')), 1);
    final thumb = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage).first,
    );
    expect(thumb.memCacheWidth, 256);
    expect(thumb.memCacheHeight, 256);
    expect(find.byKey(const Key('comment-sticker-progress')), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.byType(InkWell), findsWidgets);
    expect(apify.lastUrl, contains('7393468652906925317'));
  });

  testWidgets('resumed lifecycle reads a new clipboard TikTok URL', (
    tester,
  ) async {
    final apify = _FakeApifyService(
      stickers: const [
        CommentSticker(
          id: '1_0',
          commentId: '1',
          imageUrl: 'https://example.com/sticker.webp',
          author: 'Ian',
        ),
      ],
    );
    var clipboard = '';
    _mockClipboardReader(tester, () => clipboard);

    await tester.pumpWidget(_app(apify));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CommentScanLoadingDialog), findsNothing);

    clipboard = 'https://vm.tiktok.com/ZMexample/';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Comment stickers'), findsOneWidget);
    expect(find.byKey(const Key('comment-sticker-grid')), findsOneWidget);
    expect(apify.lastUrl, 'https://vm.tiktok.com/ZMexample/');
  });

  testWidgets('API errors close the dialog and show a message', (tester) async {
    final apify = _FakeApifyService(
      error: const ApifyException('Apify’s request limit was reached.'),
    );
    _mockClipboard(
      tester,
      'https://www.tiktok.com/@creator/video/7393468652906925317',
    );

    await tester.pumpWidget(_app(apify));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CommentScanLoadingDialog), findsNothing);
    expect(find.text('Comment stickers'), findsNothing);
    expect(find.text('Apify’s request limit was reached.'), findsOneWidget);
  });

  testWidgets('tapping a sticker formats it and saves it to Library', (
    tester,
  ) async {
    final repo = InMemoryPackRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packRepositoryProvider.overrideWithValue(repo),
          tikTokCommentServiceProvider.overrideWithValue(
            _FakeCommentService(File('dl.img')),
          ),
          commentStickerFormatterProvider.overrideWithValue(
            _FakeFormatter(File('ready.webp')),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: CommentStickerSheet(
              stickers: [
                CommentSticker(
                  id: '1_0',
                  commentId: '1',
                  imageUrl: 'https://example.com/sticker.webp',
                  author: 'Ian',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final tile = tester.widget<InkWell>(
      find.byKey(const Key('comment-sticker-1_0')),
    );
    tile.onTap!.call();
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Sticker formatted and saved to Library!'),
      findsOneWidget,
    );
    final packs = await repo.getAll();
    expect(packs.single.name, commentPackName);
    expect(packs.single.stickers, hasLength(1));
    expect(packs.single.stickers.single.animated, isFalse);
  });

  testWidgets('grid populates as download progress arrives over the port', (
    tester,
  ) async {
    final controller = StreamController<CommentStickerProgress>();
    addTearDown(controller.close);
    const first = CommentSticker(
      id: '1_0',
      commentId: '1',
      imageUrl: 'https://example.com/sticker.webp',
      author: 'Ian',
    );
    const second = CommentSticker(
      id: '2_0',
      commentId: '2',
      imageUrl: 'https://example.com/reply.webp',
      author: 'Ada',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          commentStickerCacheDirectoryProvider.overrideWithValue(
            () async => Directory.systemTemp,
          ),
          commentStickerPipelineProvider.overrideWithValue(
            _ScriptedCommentStickerPipeline(controller.stream),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: CommentStickerSheet(
              stickers: [first, second],
              prefetchDownloads: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('comment-sticker-grid')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('0 / 2'), findsOneWidget);

    controller.add(
      const CommentStickerProgress(downloaded: 1, total: 2, sticker: first),
    );
    await tester.pump();

    expect(find.byKey(const Key('comment-sticker-grid')), findsOneWidget);
    expect(find.byKey(const Key('comment-sticker-1_0')), findsOneWidget);
    expect(find.byKey(const Key('comment-sticker-2_0')), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    controller.add(
      const CommentStickerProgress(downloaded: 2, total: 2, sticker: second),
    );
    await tester.pump();

    expect(find.byKey(const Key('comment-sticker-1_0')), findsOneWidget);
    expect(find.byKey(const Key('comment-sticker-2_0')), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNWidgets(2));
    expect(find.text('2 / 2'), findsOneWidget);
  });
}

Widget _app(ApifyService apify) {
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
    ],
    child: MaterialApp(theme: AppTheme.light, home: const MainScaffold()),
  );
}

void _mockClipboard(WidgetTester tester, String text) {
  var value = text;
  _mockClipboardReader(tester, () => value, onSet: (next) => value = next);
}

void _mockClipboardReader(
  WidgetTester tester,
  String Function() read, {
  void Function(String value)? onSet,
}) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      switch (call.method) {
        case 'Clipboard.getData':
          final text = read();
          if (text.isEmpty) return null;
          return <String, dynamic>{'text': text};
        case 'Clipboard.setData':
          final arguments = call.arguments;
          if (arguments is Map && onSet != null) {
            onSet(arguments['text']?.toString() ?? '');
          }
          return null;
        case 'Clipboard.hasStrings':
          return <String, dynamic>{'value': read().isNotEmpty};
        case 'HapticFeedback.vibrate':
          return null;
      }
      return null;
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
}

class _ScriptedCommentStickerPipeline implements CommentStickerPipeline {
  _ScriptedCommentStickerPipeline(this._stream);

  final Stream<CommentStickerProgress> _stream;

  @override
  Stream<CommentStickerProgress> download({
    required List<CommentSticker> stickers,
    required String directory,
  }) => _stream;
}

class _FakeApifyService extends ApifyService {
  _FakeApifyService({this.stickers = const [], this.error, this.gate})
    : super(
        token: 'test-token',
        delay: (_) async {},
        apiPost: (_, _) async =>
            Response<dynamic>(requestOptions: RequestOptions(path: '/')),
        apiGet: (_, _) async =>
            Response<dynamic>(requestOptions: RequestOptions(path: '/')),
      );

  final List<CommentSticker> stickers;
  final Object? error;
  final Completer<void>? gate;
  String? lastUrl;

  @override
  Future<List<CommentSticker>> fetchCommentStickers(String postUrl) async {
    lastUrl = postUrl;
    final pending = gate;
    if (pending != null) await pending.future;
    final thrown = error;
    if (thrown != null) throw thrown;
    return stickers;
  }
}

class _FakeCommentService extends TikTokCommentService {
  _FakeCommentService(this.file)
    : super(
        apiGet: (_, _) async =>
            Response<dynamic>(requestOptions: RequestOptions(path: '/')),
      );

  final File file;

  @override
  Future<File> downloadSticker(CommentSticker sticker) async => file;
}

class _FakeFormatter extends CommentStickerFormatter {
  _FakeFormatter(this.file) : super(ImageStickerService());

  final File file;

  @override
  Future<File> makeWhatsAppReady(File source) async => file;
}
