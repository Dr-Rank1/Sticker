import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/editor_screen.dart';
import '../editor/ffmpeg_sticker_service.dart';
import '../images/sticker_grid_cache.dart';
import '../l10n/l10n.dart';
import '../photos/photo_import_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'meme_service.dart';

Future<void> showMemeTemplateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.9,
      child: MemeTemplateSheet(),
    ),
  );
}

class MemeTemplateSheet extends ConsumerStatefulWidget {
  const MemeTemplateSheet({super.key});

  @override
  ConsumerState<MemeTemplateSheet> createState() => _MemeTemplateSheetState();
}

class _MemeTemplateSheetState extends ConsumerState<MemeTemplateSheet> {
  List<MemeTemplate> _templates = const [];
  bool _loading = true;
  String? _error;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadTemplates);
  }

  Future<void> _loadTemplates() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final templates = await ref.read(memeServiceProvider).getTemplates();
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _loading = false;
        if (templates.isEmpty) {
          _error = context.l10n.noMemeTemplates;
        }
      });
    } on MemeServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      final message = context.l10n.memeTemplatesLoadFailed;
      setState(() {
        _loading = false;
        _error = message;
      });
      _showMessage(message);
    }
  }

  Future<void> _selectTemplate(MemeTemplate template) async {
    if (_selectedId != null) return;
    setState(() => _selectedId = template.id);
    File? source;
    try {
      source = await ref.read(memeServiceProvider).downloadTemplate(template);
      final prepared = await ref
          .read(imageStickerServiceProvider)
          .prepareForEditor(source, removeBackground: false);
      if (!mounted) return;

      final navigator = Navigator.of(context, rootNavigator: true);
      navigator.pop();
      Future.microtask(() {
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => EditorScreen(imagePath: prepared.file.path),
          ),
        );
      });
    } on MemeServiceException catch (error) {
      if (!mounted) return;
      setState(() => _selectedId = null);
      _showMessage(error.message);
    } on StickerExportException catch (error) {
      if (!mounted) return;
      setState(() => _selectedId = null);
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _selectedId = null);
      _showMessage(context.l10n.couldNotPrepareMeme);
    } finally {
      if (source != null) {
        try {
          if (source.existsSync()) source.deleteSync();
        } on FileSystemException {
          // The OS may already have cleared the downloaded template.
        }
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.startFromMemeSheet,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.memeSheetSubtitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.close,
                      onPressed: _selectedId == null
                          ? () => Navigator.pop(context)
                          : null,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Expanded(child: _buildContent(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Row(
              children: [
                Icon(
                  Icons.crop_square_rounded,
                  size: 18,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.memeCropDescription,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = context.colors;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: colors.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                key: const Key('retry-meme-templates'),
                onPressed: _loadTemplates,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.l10n.tryAgain),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      key: const Key('meme-template-grid'),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: _templates.length,
      findChildIndexCallback: (key) => findStickerGridChildIndex(
        key,
        _templates.map((template) => template.id),
      ),
      itemBuilder: (context, index) {
        final template = _templates[index];
        final selected = _selectedId == template.id;
        return Material(
          key: ValueKey(template.id),
          color: colors.surfaceMuted,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: BorderSide(color: colors.border),
          ),
          child: InkWell(
            key: Key('meme-template-${template.id}'),
            onTap: _selectedId == null ? () => _selectTemplate(template) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        template.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.broken_image_outlined,
                          color: colors.textTertiary,
                        ),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                      ),
                      if (selected)
                        ColoredBox(
                          color: Colors.black.withValues(alpha: 0.45),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    template.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
