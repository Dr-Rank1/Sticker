import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'pack_form_sheet.dart';
import 'pack_models.dart';
import 'pack_providers.dart';

Future<StickerPack?> showSaveToPackSheet(
  BuildContext context, {
  required String stickerPath,
}) {
  return showModalBottomSheet<StickerPack>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SaveToPackSheet(stickerPath: stickerPath),
  );
}

class SaveToPackSheet extends ConsumerWidget {
  const SaveToPackSheet({super.key, required this.stickerPath});

  final String stickerPath;

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
          Text('Save to a pack', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'WhatsApp packs need 3–30 stickers. Pick a pack with room, or make a new one.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: packs.isEmpty
                ? Text(
                    'You don’t have any packs yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: packs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final pack = packs[index];
                      return Material(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        child: ListTile(
                          enabled: !pack.isFull,
                          title: Text(pack.name),
                          subtitle: Text(
                            pack.isFull
                                ? 'Full (${WhatsAppPackRules.maxStickers} stickers)'
                                : '${pack.author} · ${pack.countLabel}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: pack.isFull
                              ? null
                              : () => _add(context, ref, pack),
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
              child: const Text('New pack'),
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
      final updated = await ref.read(packsProvider.notifier).addSticker(
            packId: pack.id,
            sourcePath: stickerPath,
          );
      if (!context.mounted) return;
      Navigator.pop(context, updated);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}
