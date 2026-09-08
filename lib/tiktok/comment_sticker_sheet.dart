import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/ffmpeg_sticker_service.dart';
import '../packs/save_to_pack_sheet.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'comment_sticker_formatter.dart';
import 'tiktok_comment_service.dart';

Future<void> showCommentStickerSheet(
  BuildContext context, {
  required String videoUrl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: CommentStickerSheet(videoUrl: videoUrl),
    ),
  );
}

class CommentStickerSheet extends ConsumerStatefulWidget {
  const CommentStickerSheet({super.key, required this.videoUrl});

  final String videoUrl;

  @override
  ConsumerState<CommentStickerSheet> createState() =>
      _CommentStickerSheetState();
}

class _CommentStickerSheetState extends ConsumerState<CommentStickerSheet> {
  List<CommentSticker> _stickers = const [];
  bool _loading = true;
  String? _error;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_scan);
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stickers = await ref
          .read(tikTokCommentServiceProvider)
          .fetchStickers(widget.videoUrl);
      if (!mounted) return;
      setState(() {
        _stickers = stickers;
        _loading = false;
      });
    } on TikTokCommentException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Couldn’t scan those comments. Please try again.';
      });
    }
  }

  Future<void> _select(CommentSticker sticker) async {
    if (_selectedId != null) return;
    setState(() => _selectedId = sticker.id);
    File? downloaded;
    File? ready;
    try {
      downloaded = await ref
          .read(tikTokCommentServiceProvider)
          .downloadSticker(sticker);
      ready = await ref
          .read(commentStickerFormatterProvider)
          .makeWhatsAppReady(downloaded);
      if (!mounted) return;

      final pack = await showSaveToPackSheet(
        context,
        stickerPath: ready.path,
        animated: false,
      );
      if (!mounted) return;
      if (pack != null) {
        await HapticFeedback.mediumImpact();
        if (!mounted) return;
        _showMessage('Saved to Pack');
      }
    } on TikTokCommentException catch (error) {
      if (mounted) _showMessage(error.message);
    } on StickerExportException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage('Couldn’t save that sticker. Please try another one.');
      }
    } finally {
      _delete(downloaded);
      _delete(ready);
      if (mounted) setState(() => _selectedId = null);
    }
  }

  void _delete(File? file) {
    try {
      if (file?.existsSync() == true) file!.deleteSync();
    } on FileSystemException {
      // Temporary files can already have been reclaimed by the OS.
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
                      child: Text(
                        'Comment stickers',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
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
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final colors = context.colors;
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning comments for stickers...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        message: _error!,
        actionLabel: 'Try again',
        onAction: _scan,
      );
    }

    if (_stickers.isEmpty) {
      return const _MessageState(
        icon: Icons.search_off_rounded,
        message: 'No image stickers were found in the scanned comments.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _stickers.length,
      itemBuilder: (context, index) {
        final sticker = _stickers[index];
        final selected = _selectedId == sticker.id;
        return Material(
          color: colors.surfaceMuted,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            onTap: _selectedId == null ? () => _select(sticker) : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: CachedNetworkImage(
                    imageUrl: sticker.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, _) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
                if (selected)
                  ColoredBox(
                    color: colors.surface.withValues(alpha: 0.72),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: context.colors.textTertiary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel ?? 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
