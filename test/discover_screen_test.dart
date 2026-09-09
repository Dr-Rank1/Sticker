import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stickr/discover/discover_screen.dart';
import 'package:stickr/discover/tenor_repository.dart';
import 'package:stickr/packs/pack_models.dart';
import 'package:stickr/packs/pack_providers.dart';
import 'package:stickr/packs/pack_repository.dart';
import 'package:stickr/theme/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('searches transparent stickers and saves one to a local pack', (
    tester,
  ) async {
    final temporary = Directory(
      '${Directory.systemTemp.path}/stickr_discover_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    addTearDown(() {
      if (temporary.existsSync()) temporary.deleteSync(recursive: true);
    });
    final tenor = _FakeTenorRepository(temporary);
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
          tenorRepositoryProvider.overrideWithValue(tenor),
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

    expect(tenor.lastQuery, 'happy cat');
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
    expect(savedPacks.single.stickers.single.animated, isFalse);
    expect(tenor.downloadedFile?.existsSync(), isFalse);
  });
}

class _FakeTenorRepository extends TenorRepository {
  _FakeTenorRepository(this.temporary) : super(apiKey: 'test-key');

  final Directory temporary;
  String? lastQuery;
  File? downloadedFile;

  static const sticker = TenorSticker(
    id: 'transparent-1',
    title: 'Happy cat',
    webpUrl: 'https://media.tenor.com/cat.webp',
    width: 320,
    height: 240,
    duration: 0,
  );

  @override
  Future<TenorSearchPage> search(
    String query, {
    int limit = 24,
    String? position,
  }) async {
    lastQuery = query;
    return const TenorSearchPage(results: [sticker], next: null);
  }

  @override
  Future<File> downloadSticker(
    TenorSticker sticker, {
    void Function(double? progress)? onProgress,
  }) async {
    final file = File('${temporary.path}/stickr_tenor_test.webp');
    file.writeAsBytesSync([1, 2, 3, 4]);
    downloadedFile = file;
    onProgress?.call(1);
    return file;
  }
}
