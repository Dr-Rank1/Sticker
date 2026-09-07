import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/navigation_controller.dart';
import '../state/theme_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../tiktok/tiktok_import_sheet.dart';
import '../widgets/empty_state.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final themeMode = ref.watch(themeModeProvider);
    final themeController = ref.read(themeModeProvider.notifier);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
          sliver: SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Library',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your packs. Always free, forever.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Appearance: ${themeController.label}',
                    onPressed: themeController.cycle,
                    icon: Icon(switch (themeMode) {
                      ThemeMode.system => Icons.brightness_auto_rounded,
                      ThemeMode.light => Icons.light_mode_rounded,
                      ThemeMode.dark => Icons.dark_mode_rounded,
                    }),
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surface,
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.border),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: colors.border),
              ),
              child: EmptyState(
                icon: Icons.auto_awesome_mosaic_rounded,
                title: 'No packs yet',
                message:
                    'Create stickers from photos or TikToks and they will show up here, ready for WhatsApp.',
                actionLabel: 'Create a sticker',
                onAction: () {
                  ref.read(navigationProvider.notifier).select(AppTab.create);
                  showTiktokImportSheet(context);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
