import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accessibility/accessible_tap.dart';
import '../haptics/haptic_service.dart';
import '../packs/pack_detail_screen.dart';
import '../packs/pack_form_sheet.dart';
import '../packs/pack_models.dart';
import '../packs/pack_providers.dart';
import '../packs/pack_tray_image.dart';
import '../settings/settings_screen.dart';
import '../state/navigation_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../tiktok/tiktok_import_sheet.dart';
import '../widgets/empty_state.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final packsAsync = ref.watch(packsProvider);

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
                    tooltip: 'New pack',
                    onPressed: () {
                      hapticService.buttonTap();
                      showCreatePackSheet(context);
                    },
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surface,
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.border),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('open-settings'),
                    tooltip: 'Settings',
                    onPressed: () {
                      hapticService.buttonTap();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_rounded),
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
        ...packsAsync.when(
          loading: () => [
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (error, _) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('$error')),
            ),
          ],
          data: (packs) {
            if (packs.isEmpty) {
              return [
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
                        message: 'Create stickers from photos or TikToks and group them into packs for WhatsApp.',
                        actionLabel: 'Create a sticker',
                        onAction: () {
                          ref
                              .read(navigationProvider.notifier)
                              .select(AppTab.create);
                          showTiktokImportSheet(context);
                        },
                      ),
                    ),
                  ),
                ),
              ];
            }
            return [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio:
                        0.82 /
                        AppTheme.textScalerOf(context)
                            .scale(1)
                            .clamp(1.0, 1.35),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _PackCard(pack: packs[index]),
                    childCount: packs.length,
                  ),
                ),
              ),
            ];
          },
        ),
      ],
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack});

  final StickerPack pack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: AccessibleTap(
        label: pack.name,
        hint: pack.canExportToWhatsApp
            ? 'Opens this pack. Ready for WhatsApp, ${pack.countLabel}.'
            : 'Opens this pack. ${pack.exportBlockReason}',
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PackDetailScreen(packId: pack.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: ColoredBox(
                    color: colors.surfaceMuted,
                    child: Center(
                      child: PackTrayImage(
                        pack: pack,
                        size: 96,
                        borderRadius: AppTheme.radiusMd,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                pack.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                pack.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pack.canExportToWhatsApp
                      ? colors.accentSoft
                      : colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pack.canExportToWhatsApp
                      ? 'Ready · ${pack.countLabel}'
                      : pack.countLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: pack.canExportToWhatsApp
                        ? colors.accentDim
                        : colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
