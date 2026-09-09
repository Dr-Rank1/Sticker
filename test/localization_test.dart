import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/l10n/l10n.dart';
import 'package:stickr/main.dart';

void main() {
  test('unsupported locales fall back strictly to English', () {
    expect(
      resolveStickrLocale(
        const Locale('fr'),
        AppLocalizations.supportedLocales,
      ),
      fallbackLocale,
    );
    expect(serviceLocalizations.localeName, 'en');
  });

  test('English resources cover UI, errors, and accessibility copy', () {
    final file = File('lib/l10n/app_en.arb');
    final resources =
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

    expect(resources['@@locale'], 'en');
    expect(resources['appTitle'], 'Stickr');
    expect(resources, contains('couldNotImportPack'));
    expect(resources, contains('giphyRequestFailed'));
    expect(resources, contains('stickerCanvasHint'));
    expect(resources, contains('removeStickerHint'));
    expect(resources.length, greaterThan(150));
  });
}
