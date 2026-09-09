import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stickr/settings/settings_screen.dart';
import 'package:stickr/storage/storage_utility.dart';
import 'package:stickr/theme/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows storage usage and clears temporary Stickr files', (
    tester,
  ) async {
    final utility = _FakeStorageUtility();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageUtilityProvider.overrideWithValue(utility)],
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('App documents'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(find.text('Temporary cache'), findsOneWidget);
    expect(find.text('1.0 KB'), findsOneWidget);
    expect(find.text('3.0 KB'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear-cache-button')));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(utility.cacheCleared, isTrue);
    expect(find.text('0 B'), findsOneWidget);
    expect(find.textContaining('Freed 1.0 KB'), findsOneWidget);
  });
}

class _FakeStorageUtility extends StorageUtility {
  var cacheCleared = false;

  @override
  Future<StorageUsage> getUsage() async {
    return StorageUsage(
      documentsBytes: 2 * 1024,
      cacheBytes: cacheCleared ? 0 : 1024,
    );
  }

  @override
  Future<CacheClearResult> clearCache() async {
    cacheCleared = true;
    return const CacheClearResult(bytesFreed: 1024, filesDeleted: 1);
  }
}
