import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../haptics/haptic_service.dart';
import '../l10n/l10n.dart';
import '../images/sticker_grid_cache.dart';
import '../images/sticker_grid_image.dart';
import '../logging/app_logger.dart';
import '../state/navigation_controller.dart';
import '../store/review_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'pack_form_sheet.dart';
import 'pack_models.dart';
import 'pack_providers.dart';
import 'pack_tray_image.dart';
import 'whatsapp_export_service.dart';

class PackDetailScreen extends ConsumerStatefulWidget {
  const PackDetailScreen({super.key, required this.packId});

  final String packId;

  @override
  ConsumerState<PackDetailScreen> createState() => _PackDetailScreenState();
}

class _PackDetailScreenState extends ConsumerState<PackDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _exporting = false;
  bool _sharing = false;
  late final AnimationController _shakeController;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shake = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 10, end: -7), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -7, end: 7), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 7, end: 0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pack = ref.watch(packByIdProvider(widget.packId));
    if (pack == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.pack)),
        body: Center(child: Text(context.l10n.packDeleted)),
      );
    }

    final colors = context.colors;
    final canExport = pack.canExportToWhatsApp;

    return Scaffold(
      appBar: AppBar(
        title: Text(pack.name),
        actions: [
          IconButton(
            key: const Key('share-pack'),
            tooltip: context.l10n.sharePack,
            onPressed: _sharing
                ? null
                : () {
                    hapticService.buttonTap();
                    _sharePack(pack);
                  },
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: context.l10n.editPack,
            onPressed: () {
              hapticService.buttonTap();
              showCreatePackSheet(context, existing: pack);
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: context.l10n.deletePack,
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
                PackTrayImage(pack: pack, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.author,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.packDetailSummary(pack.countLabel),
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
                      context.l10n.noStickersInPack,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : GridView.builder(
                    key: const Key('pack-sticker-grid'),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: pack.stickers.length,
                    findChildIndexCallback: (key) => findStickerGridChildIndex(
                      key,
                      pack.stickers.map((sticker) => sticker.id),
                    ),
                    itemBuilder: (context, index) {
                      final sticker = pack.stickers[index];
                      return Material(
                        key: ValueKey(sticker.id),
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        clipBehavior: Clip.antiAlias,
                        child: Semantics(
                          button: true,
                          label: context.l10n.stickerInPack(pack.name),
                          hint: context.l10n.removeStickerHint,
                          child: InkWell(
                            onLongPress: () {
                              hapticService.buttonTap();
                              _confirmRemoveSticker(
                                context,
                                ref,
                                pack,
                                sticker,
                              );
                            },
                            child: StickerGridImage(
                              filePath: sticker.filePath,
                              fit: BoxFit.cover,
                            ),
                          ),
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
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.textSecondary),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: pack.isFull
                          ? null
                          : () {
                              hapticService.buttonTap();
                              ref
                                  .read(navigationProvider.notifier)
                                  .select(AppTab.scanner);
                              Navigator.pop(context);
                            },
                      child: Text(context.l10n.addStickers),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: AnimatedBuilder(
                      animation: _shake,
                      builder: (context, child) => Transform.translate(
                        key: const Key('whatsapp-export-shake'),
                        offset: Offset(_shake.value, 0),
                        child: child,
                      ),
                      child: FilledButton.icon(
                        key: const Key('add-to-whatsapp'),
                        onPressed: _exporting
                            ? null
                            : () => _handleExportTap(pack),
                        style: canExport
                            ? null
                            : FilledButton.styleFrom(
                                backgroundColor: colors.surfaceMuted,
                                foregroundColor: colors.textTertiary,
                              ),
                        icon: _exporting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary,
                                ),
                              )
                            : const Icon(Icons.chat_rounded),
                        label: Text(
                          _exporting
                              ? context.l10n.adding
                              : context.l10n.addToWhatsApp,
                        ),
                      ),
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

  void _handleExportTap(StickerPack pack) {
    hapticService.buttonTap();
    if (!pack.meetsMinimum) {
      hapticService.error();
      _shakeController.forward(from: 0);
      _showFeedback(
        context.l10n.whatsAppMinimumStickers(
          WhatsAppPackRules.minStickers - pack.stickers.length,
        ),
      );
      return;
    }
    if (!pack.canExportToWhatsApp) {
      hapticService.error();
      _showFeedback(pack.exportBlockReason);
      return;
    }
    _addToWhatsApp(pack);
  }

  Future<void> _sharePack(StickerPack pack) async {
    setState(() => _sharing = true);
    try {
      await ref.read(packsProvider.notifier).sharePack(pack.id);
      if (!mounted) return;
      hapticService.success();
    } on PackException catch (error) {
      if (!mounted) return;
      hapticService.error();
      _showFeedback(error.message);
    } catch (error) {
      if (!mounted) return;
      hapticService.error();
      _showFeedback(context.l10n.couldNotSharePack);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _addToWhatsApp(StickerPack pack) async {
    setState(() => _exporting = true);
    try {
      final saved = await ref.read(packsProvider.notifier).savePack(pack);
      final result = await ref
          .read(whatsAppExportServiceProvider)
          .exportToWhatsApp(saved);
      if (!mounted) return;
      hapticService.success();
      _showFeedback(result.message);
      try {
        await ref
            .read(reviewServiceProvider)
            .recordSuccessfulWhatsAppExport(packId: saved.id);
      } catch (error, stack) {
        appLogger.w(
          'In-app review prompt failed',
          error: error,
          stackTrace: stack,
        );
      }
    } on WhatsAppNotInstalledException {
      if (!mounted) return;
      hapticService.error();
      setState(() => _exporting = false);
      await _showWhatsAppInstallSheet();
    } on PackException catch (error) {
      if (!mounted) return;
      hapticService.error();
      _showFeedback(error.message);
    } catch (error) {
      if (!mounted) return;
      hapticService.error();
      _showFeedback('$error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _showWhatsAppInstallSheet() {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final colors = context.colors;
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    color: colors.accentDim,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.whatsAppNotInstalled,
                  key: const Key('whatsapp-not-installed-title'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.installWhatsAppDescription,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('install-whatsapp'),
                    onPressed: () => _openStore(
                      'https://play.google.com/store/apps/details?id=com.whatsapp',
                    ),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(context.l10n.installWhatsApp),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('install-whatsapp-business'),
                    onPressed: () => _openStore(
                      'https://play.google.com/store/apps/details?id=com.whatsapp.w4b',
                    ),
                    icon: const Icon(Icons.business_center_rounded),
                    label: Text(context.l10n.installWhatsAppBusiness),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openStore(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showFeedback(context.l10n.couldNotOpenAppStore);
    }
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
        title: Text(context.l10n.deletePackQuestion),
        content: Text(context.l10n.deletePackDescription(pack.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
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
        title: Text(context.l10n.removeStickerQuestion),
        content: Text(context.l10n.removeStickerDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.remove),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref
        .read(packsProvider.notifier)
        .removeSticker(packId: pack.id, stickerId: sticker.id);
  }
}
