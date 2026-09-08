import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StickerFontCatalog {
  StickerFontCatalog._();

  static const defaultFont = 'Roboto';
  static const fonts = [
    'Roboto',
    'Anton',
    'Pacifico',
    'Bangers',
    'Permanent Marker',
  ];

  /// Uses the regular downloadable font file and lets Flutter synthesize the
  /// requested weight. This avoids requesting unavailable bold variants for
  /// display families such as Pacifico.
  static TextStyle styleFor(String fontName, TextStyle base) {
    final regular = GoogleFonts.getFont(
      _safeName(fontName),
      textStyle: base.copyWith(fontWeight: FontWeight.w400),
    );
    return regular.copyWith(fontWeight: base.fontWeight);
  }

  /// Starts any missing HTTP font loads and waits until Flutter's FontLoader
  /// has registered them before text is rasterized into the export overlay.
  static Future<void> ensureLoaded(Iterable<String> fontNames) async {
    final styles = <TextStyle>[
      for (final name in fontNames.toSet())
        GoogleFonts.getFont(_safeName(name)),
    ];
    await GoogleFonts.pendingFonts(styles);
  }

  static String _safeName(String fontName) {
    return fonts.contains(fontName) ? fontName : defaultFont;
  }
}
