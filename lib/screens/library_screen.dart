import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accessibility/accessible_tap.dart';
import '../create/manual_create.dart';
import '../haptics/haptic_service.dart';
import '../l10n/l10n.dart';
import '../packs/pack_detail_screen.dart';
import '../packs/pack_form_sheet.dart';
import '../packs/pack_models.dart';
import '../packs/pack_providers.dart';
import '../packs/pack_tray_image.dart';
import '../settings/settings_screen.dart';
import '../state/navigation_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final packsAsync = ref.watch(packsProvider);
    final l10n = context.l10n;

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
                          l10n.myPacks,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.librarySubtitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.newPack,
                    onPressed: () {
                      hapticService.buttonTap();
                      showCreatePackSheet(context);
                    },
                    icon: const Icon(Icons.create_new_folder_outlined),
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surface,
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.border),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('open-settings'),
                    tooltip: l10n.settings,
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
              child: Center(child: Text(context.l10n.couldNotLoadPacks)),
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
                        title: l10n.noPacksYet,
                        message: l10n.noPacksMessage,
                        actionLabel: l10n.scanCommentsForStickers,
                        onAction: () {
                          ref
                              .read(navigationProvider.notifier)
                              .select(AppTab.scanner);
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

class LibraryCreateFab extends ConsumerStatefulWidget {
  const LibraryCreateFab({super.key});

  @override
  ConsumerState<LibraryCreateFab> createState() => _LibraryCreateFabState();
}

class _LibraryCreateFabState extends ConsumerState<LibraryCreateFab> {
  final _fabKey = GlobalKey();
  var _importingVideo = false;

  Future<void> _openCreateMenu() async {
    final button = _fabKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final l10n = context.l10n;
    final selected = await showMenu<_ManualCreateAction>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          key: const Key('create-from-photo'),
          value: _ManualCreateAction.photo,
          child: Text(l10n.fromPhotoMenu),
        ),
        PopupMenuItem(
          key: const Key('create-from-video'),
          value: _ManualCreateAction.video,
          child: Text(l10n.fromVideoMenu),
        ),
      ],
    );

    if (!mounted || selected == null) return;
    switch (selected) {
      case _ManualCreateAction.photo:
        await openPhotoCreateFlow(context);
      case _ManualCreateAction.video:
        if (_importingVideo) return;
        setState(() => _importingVideo = true);
        try {
          await openLocalVideoCreateFlow(context: context, ref: ref);
        } finally {
          if (mounted) setState(() => _importingVideo = false);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: 72),
      child: FloatingActionButton.small(
        key: _fabKey,
        heroTag: 'library-manual-create-fab',
        tooltip: l10n.create,
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: BorderSide(color: colors.border),
        ),
        onPressed: _importingVideo ? null : _openCreateMenu,
        child: _importingVideo
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.textPrimary,
                ),
              )
            : const Icon(Icons.add_rounded, key: Key('library-create-fab')),
      ),
    );
  }
}

enum _ManualCreateAction { photo, video }

class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack});

  final StickerPack pack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

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
            ? l10n.opensReadyPack(pack.countLabel)
            : l10n.opensBlockedPack(pack.exportBlockReason),
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
                      ? l10n.readyCount(pack.countLabel)
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
