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
}

Widget _app(ApifyService apify) {
  return ProviderScope(
    overrides: [
      apifyServiceProvider.overrideWithValue(apify),
      settingsStoreProvider.overrideWithValue(
        InMemorySettingsStore(onboardingComplete: true),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const MainScaffold(),
    ),
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

class _FakeApifyService extends ApifyService {
  _FakeApifyService({
    this.stickers = const [],
    this.error,
    this.gate,
  }) : super(
         token: 'test-token',
         delay: (_) async {},
         apiPost: (_, _) async => Response<dynamic>(
           requestOptions: RequestOptions(path: '/'),
         ),
         apiGet: (_, _) async => Response<dynamic>(
           requestOptions: RequestOptions(path: '/'),
         ),
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
        apiGet: (_, _) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/'),
        ),
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
