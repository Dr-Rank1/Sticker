import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/navigation_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../tiktok/tiktok_import_sheet.dart';
import 'pack_form_sheet.dart';
import 'pack_models.dart';
import 'pack_providers.dart';
import 'whatsapp_export_service.dart';

class PackDetailScreen extends ConsumerStatefulWidget {
  const PackDetailScreen({super.key, required this.packId});

  final String packId;

  @override
  ConsumerState<PackDetailScreen> createState() => _PackDetailScreenState();
}

class _PackDetailScreenState extends ConsumerState<PackDetailScreen> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final pack = ref.watch(packByIdProvider(widget.packId));
    if (pack == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pack')),
        body: const Center(child: Text('This pack was deleted.')),
      );
    }

    final colors = context.colors;
    final canExport = pack.canExportToWhatsApp;

    return Scaffold(
      appBar: AppBar(
        title: Text(pack.name),
        actions: [
          IconButton(
            tooltip: 'Edit pack',
            onPressed: () => showCreatePackSheet(context, existing: pack),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete pack',
            onPressed: () => _confirmDelete(context, ref, pack),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                _TrayView(path: pack.trayIconPath, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pack.author, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${pack.countLabel} stickers · 96×96 tray',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: pack.stickers.isEmpty
                ? Center(
                    child: Text(
                      'No stickers in this pack yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: pack.stickers.length,
                    itemBuilder: (context, index) {
                      final sticker = pack.stickers[index];
                      return Material(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onLongPress: () => _confirmRemoveSticker(
                            context,
                            ref,
                            pack,
                            sticker,
                          ),
                          child: _StickerImage(path: sticker.filePath),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!canExport)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    pack.exportBlockReason,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: pack.isFull
                          ? null
                          : () {
                              ref.read(navigationProvider.notifier).select(AppTab.create);
                              Navigator.pop(context);
                              showTiktokImportSheet(context);
                            },
                      child: const Text('Add stickers'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      key: const Key('add-to-whatsapp'),
                      onPressed: canExport && !_exporting
                          ? () => _addToWhatsApp(pack)
                          : null,
                      icon: _exporting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.chat_rounded),
                      label: Text(_exporting ? 'Adding…' : 'Add to WhatsApp'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addToWhatsApp(StickerPack pack) async {
    setState(() => _exporting = true);
    try {
      final result = await whatsAppExportService.exportToWhatsApp(pack);
      if (!mounted) return;
      _showFeedback(result.message);
    } on PackException catch (error) {
      if (!mounted) return;
      _showFeedback(error.message);
    } catch (error) {
      if (!mounted) return;
      _showFeedback('$error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    StickerPack pack,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete pack?'),
        content: Text('“${pack.name}” and its stickers will be removed from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(packsProvider.notifier).deletePack(pack.id);
    if (!context.mounted) return;
    Navigator.pop(context);
  }

  Future<void> _confirmRemoveSticker(
    BuildContext context,
    WidgetRef ref,
    StickerPack pack,
    StickerItem sticker,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove sticker?'),
        content: const Text('It will be deleted from this pack.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(packsProvider.notifier).removeSticker(
          packId: pack.id,
          stickerId: sticker.id,
        );
  }
}

class _TrayView extends StatelessWidget {
  const _TrayView({required this.path, required this.size});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: size,
        height: size,
        child: file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : ColoredBox(
                color: context.colors.accentSoft,
                child: Icon(Icons.auto_awesome_mosaic_rounded, color: context.colors.accent),
              ),
      ),
    );
  }
}

class _StickerImage extends StatelessWidget {
  const _StickerImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return const Center(child: Icon(Icons.broken_image_outlined));
    }
    return Image.file(file, fit: BoxFit.cover);
  }
}
