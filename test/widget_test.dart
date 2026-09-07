import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stikk/main.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows library and switches tabs', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StikkApp()));
    await tester.pump();

    expect(find.text('Library'), findsWidgets);
    expect(find.text('No packs yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-community')));
    await tester.pump();

    expect(find.text('Community'), findsWidgets);
    expect(find.text('Monday moods'), findsOneWidget);
  });

  testWidgets('Create opens the TikTok link sheet', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StikkApp()));
    await tester.pump();

    await tester.tap(find.byKey(const Key('nav-create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('tiktok-link-field')), findsOneWidget);
    expect(find.text('Import video'), findsOneWidget);
    expect(find.text('From a photo'), findsOneWidget);
  });

  testWidgets('invalid TikTok link shows a friendly snackbar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StikkApp()));
    await tester.pump();

    await tester.tap(find.byKey(const Key('nav-create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byKey(const Key('tiktok-link-field')),
      'https://example.com/not-tiktok',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('tiktok-import-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('doesn\'t look like a TikTok link'),
      findsOneWidget,
    );
  });
}
