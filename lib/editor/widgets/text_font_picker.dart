import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../sticker_fonts.dart';

class TextFontPicker extends StatelessWidget {
  const TextFontPicker({
    super.key,
    required this.selectedFont,
    required this.onSelected,
  });

  final String selectedFont;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      key: const Key('text-font-picker'),
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: StickerFontCatalog.fonts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final font = StickerFontCatalog.fonts[index];
          final selected = font == selectedFont;
          final base = Theme.of(context).textTheme.titleMedium!.copyWith(
            color: selected ? colors.accentOn : Colors.white,
            fontWeight: FontWeight.w700,
          );
          return Material(
            color: selected ? colors.accent : const Color(0xFF2A2F36),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: Key('font-option-$font'),
              onTap: () => onSelected(font),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                constraints: const BoxConstraints(minWidth: 104),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Aa',
                      style: StickerFontCatalog.styleFor(
                        font,
                        base.copyWith(fontSize: 22),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      font,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected ? colors.accentOn : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
