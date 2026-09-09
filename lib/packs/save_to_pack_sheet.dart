import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../haptics/haptic_service.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'pack_form_sheet.dart';
import 'pack_models.dart';
import 'pack_providers.dart';

Future<StickerPack?> showSaveToPackSheet(
  BuildContext context, {
  required String stickerPath,
  bool animated = true,
}) {
  return showModalBottomSheet<StickerPack>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) =>
        SaveToPackSheet(stickerPath: stickerPath, animated: animated),
  );
}

class SaveToPackSheet extends ConsumerWidget {
  const SaveToPackSheet({
    super.key,
    required this.stickerPath,
    this.animated = true,
  });

  final String stickerPath;
  final bool animated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(packsProvider).value ?? const <StickerPack>[];
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.saveToPack,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            animated
                ? context.l10n.saveAnimatedStickerDescription
                : context.l10n.saveStaticStickerDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: packs.isEmpty
                ? Text(
                    context.l10n.noPacksAvailable,
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: packs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final pack = packs[index];
                      final typeMismatch = !pack.acceptsSticker(
                        animated: animated,
                      );
                      final enabled = !pack.isFull && !typeMismatch;
                      return Material(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        child: ListTile(
                          enabled: enabled,
                          title: Text(pack.name),
                          subtitle: Text(
                            pack.isFull
                                ? context.l10n.fullStickerPack(
                                    WhatsAppPackRules.maxStickers,
                                  )
                                : typeMismatch
                                ? (animated
                                      ? context.l10n.packForPhotoStickers
                                      : context.l10n.packForAnimatedStickers)
                                : context.l10n.packAuthorCount(
                                    pack.author,
                                    pack.countLabel,
                                  ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: enabled
                              ? () {
                                  hapticService.buttonTap();
                                  _add(context, ref, pack);
                                }
                              : null,
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final created = await showCreatePackSheet(context);
                if (created == null || !context.mounted) return;
                await _add(context, ref, created);
              },
              child: Text(context.l10n.newPack),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    StickerPack pack,
  ) async {
    try {
      final updated = await ref
          .read(packsProvider.notifier)
          .addSticker(
            packId: pack.id,
            sourcePath: stickerPath,
            animated: animated,
          );
      if (!context.mounted) return;
      hapticService.success();
      Navigator.pop(context, updated);
    } catch (error) {
      if (!context.mounted) return;
      hapticService.error();
      final message = error is PackException
          ? error.message
          : context.l10n.couldNotAddStickerToPack;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
