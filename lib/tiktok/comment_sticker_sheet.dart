import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../editor/ffmpeg_sticker_service.dart';
import '../packs/pack_models.dart';
import '../packs/pack_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'apify_service.dart';
import 'comment_sticker_formatter.dart';
import 'comment_sticker_isolate.dart';
import 'tiktok_comment_service.dart';

/// Overlay shown while Apify polls. The main scaffold stays underneath.
Future<void> showCommentScanDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const CommentScanLoadingDialog(),
  );
}

class CommentScanLoadingDialog extends StatelessWidget {
  const CommentScanLoadingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Scanning comments for stickers...'),
        ],
      ),
    );
  }
}

/// Runs Apify behind the loading dialog, then opens the sticker grid sheet.
Future<void> scanAndShowCommentStickers(
  BuildContext context,
  WidgetRef ref, {
  required String videoUrl,
}) async {
  showCommentScanDialog(context);

  List<CommentSticker> stickers = const [];
  String? errorMessage;
  try {
    stickers = await ref
        .read(apifyServiceProvider)
        .fetchCommentStickers(videoUrl);
  } on ApifyException catch (error) {
    errorMessage = error.message;
  } catch (_) {
    errorMessage = 'Couldn’t scan those comments. Please try again.';
  }

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  if (!context.mounted) return;
  if (errorMessage != null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    return;
  }

  await showCommentStickerSheet(
    context,
    stickers: stickers,
    prefetchDownloads: true,
  );
}

Future<void> showCommentStickerSheet(
  BuildContext context, {
  required List<CommentSticker> stickers,
  bool prefetchDownloads = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: CommentStickerSheet(
        stickers: stickers,
        prefetchDownloads: prefetchDownloads,
      ),
    ),
  );
}

final commentStickerCacheDirectoryProvider =
    Provider<Future<Directory> Function()>((ref) => getTemporaryDirectory);

class CommentStickerSheet extends ConsumerStatefulWidget {
  const CommentStickerSheet({
    super.key,
    required this.stickers,
    this.prefetchDownloads = false,
  });

  final List<CommentSticker> stickers;
  final bool prefetchDownloads;

  @override
  ConsumerState<CommentStickerSheet> createState() =>
      _CommentStickerSheetState();
}

class _CommentStickerSheetState extends ConsumerState<CommentStickerSheet> {
  String? _selectedId;
  final List<CommentSticker> _visible = [];
  var _downloaded = 0;
  var _total = 0;
  StreamSubscription<CommentStickerProgress>? _subscription;

  @override
  void initState() {
    super.initState();
    _total = widget.stickers.length;
    if (widget.prefetchDownloads && widget.stickers.isNotEmpty) {
      _startPrefetch();
    } else {
      _visible.addAll(widget.stickers);
      _downloaded = _visible.length;
    }
  }

  Future<void> _startPrefetch() async {
    final directory = await ref.read(commentStickerCacheDirectoryProvider)();
    if (!mounted) return;
    _subscription = ref
        .read(commentStickerPipelineProvider)
        .download(stickers: widget.stickers, directory: directory.path)
        .listen(_onProgress);
  }

  void _onProgress(CommentStickerProgress progress) {
    if (!mounted) return;
    setState(() {
      _downloaded = progress.downloaded;
      _total = progress.total;
      final sticker = progress.sticker;
      if (sticker != null &&
          !_visible.any((item) => item.imageUrl == sticker.imageUrl)) {
        _visible.add(sticker);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _select(CommentSticker sticker) async {
    if (_selectedId != null) return;
    setState(() => _selectedId = sticker.id);
    File? downloaded;
    File? ready;
    try {
      downloaded = sticker.localPath != null
          ? File(sticker.localPath!)
          : await ref
                .read(tikTokCommentServiceProvider)
                .downloadSticker(sticker);
      ready = await ref
          .read(commentStickerFormatterProvider)
          .makeWhatsAppReady(downloaded);
      if (!mounted) return;

      await ref
          .read(packsProvider.notifier)
          .saveStaticStickerToLibrary(ready.path);
      if (!mounted) return;

      HapticFeedback.mediumImpact();
      _showMessage('Sticker formatted and saved to Library!');
    } on TikTokCommentException catch (error) {
      if (mounted) _showMessage(error.message);
    } on StickerExportException catch (error) {
      if (mounted) _showMessage(error.message);
    } on PackException catch (error) {
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comment stickers',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (widget.prefetchDownloads && _total > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '$_downloaded / $_total',
                                key: const Key('comment-sticker-progress'),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.textSecondary),
                              ),
                            ),
                        ],
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
    if (_visible.isEmpty &&
        widget.prefetchDownloads &&
        _total > 0 &&
        _downloaded < _total) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_visible.isEmpty) {
      return const _MessageState(
        icon: Icons.search_off_rounded,
        message: 'No image stickers were found in the scanned comments.',
      );
    }

    return GridView.builder(
      key: const Key('comment-sticker-grid'),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _visible.length,
      itemBuilder: (context, index) {
        final sticker = _visible[index];
        final selected = _selectedId == sticker.id;
        return Material(
          color: colors.surfaceMuted,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            key: Key('comment-sticker-${sticker.id}'),
            onTap: _selectedId == null ? () => _select(sticker) : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: _StickerThumb(sticker: sticker),
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

class _StickerThumb extends StatelessWidget {
  const _StickerThumb({required this.sticker});

  final CommentSticker sticker;

  @override
  Widget build(BuildContext context) {
    final path = sticker.localPath;
    if (path != null && File(path).existsSync()) {
      return Image.file(
        File(path),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    }
    return CachedNetworkImage(
      imageUrl: sticker.imageUrl,
      fit: BoxFit.contain,
      placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
      errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message});

  final IconData icon;
  final String message;

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
          ],
        ),
      ),
    );
  }
}
