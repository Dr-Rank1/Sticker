import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stickr/community/giphy_service.dart';
import 'package:stickr/discover/discover_screen.dart';
import 'package:stickr/packs/pack_models.dart';
import 'package:stickr/packs/pack_providers.dart';
import 'package:stickr/packs/pack_repository.dart';
import 'package:stickr/theme/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('searches Giphy, paginates, and saves one to a local pack', (
    tester,
  ) async {
    final temporary = Directory(
      '${Directory.systemTemp.path}/stickr_discover_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    addTearDown(() {
      if (temporary.existsSync()) temporary.deleteSync(recursive: true);
    });
    final giphy = _FakeGiphyService(temporary);
    final now = DateTime(2026, 1, 1);
    final packs = InMemoryPackRepository(
      seed: {
        'pack-1': StickerPack(
          id: 'pack-1',
          name: 'Ready pack',
          author: 'Ian',
          trayIconPath: 'tray.png',
          stickers: const [],
          createdAt: now,
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          giphyServiceProvider.overrideWithValue(giphy),
          packRepositoryProvider.overrideWithValue(packs),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: DiscoverScreen()),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('discover-search-field')),
      'happy cat',
    );
    await tester.tap(find.byKey(const Key('discover-search-button')));
    await tester.pump();
    await tester.pump();

    expect(giphy.lastQuery, 'happy cat');
    expect(giphy.requestedOffsets, [0]);
    expect(find.byKey(const Key('discover-masonry-grid')), findsOneWidget);
    expect(
      find.byKey(const Key('discover-sticker-transparent-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('discover-sticker-transparent-1')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Save to a pack'), findsOneWidget);
    await tester.tap(find.text('Ready pack'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final savedPacks = await packs.getAll();
    expect(savedPacks.single.stickers, hasLength(1));
    expect(savedPacks.single.stickers.single.animated, isTrue);
    expect(giphy.downloadedFile?.existsSync(), isFalse);

    await tester.drag(
      find.byKey(const Key('discover-masonry-grid')),
      const Offset(0, -1200),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(giphy.requestedOffsets, contains(12));
    await tester.drag(
      find.byKey(const Key('discover-masonry-grid')),
      const Offset(0, -600),
    );
    await tester.pump();
    expect(find.byKey(const Key('discover-sticker-next-page')), findsOneWidget);
  });
}

class _FakeGiphyService extends GiphyService {
  _FakeGiphyService(this.temporary) : super(apiKey: 'test-key');

  final Directory temporary;
  String? lastQuery;
  final requestedOffsets = <int>[];
  File? downloadedFile;

  static const sticker = GiphySticker(
    id: 'transparent-1',
    title: 'Happy cat',
    url: 'https://media.giphy.com/cat.webp',
    width: 320,
    height: 240,
  );

  @override
  Future<GiphyStickerPage> search(String query, {int offset = 0}) async {
    lastQuery = query;
    requestedOffsets.add(offset);
    if (offset > 0) {
      return const GiphyStickerPage(
        stickers: [
          GiphySticker(
            id: 'next-page',
            title: 'Next result',
            url: 'https://media.giphy.com/next.webp',
            width: 320,
            height: 320,
          ),
        ],
        nextOffset: null,
      );
    }
    return GiphyStickerPage(
      stickers: [
        sticker,
        for (var index = 1; index < 12; index++)
          GiphySticker(
            id: 'result-$index',
            title: 'Result $index',
            url: 'https://media.giphy.com/result-$index.webp',
            width: 320,
            height: 240,
          ),
      ],
      nextOffset: 12,
    );
  }

  @override
  Future<File> downloadSticker({
    required String id,
    required String url,
  }) async {
    final file = File('${temporary.path}/stickr_giphy_test.webp');
    file.writeAsBytesSync([1, 2, 3, 4]);
    downloadedFile = file;
    return file;
  }
}
