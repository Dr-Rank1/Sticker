import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/ffmpeg_sticker_service.dart';
import '../haptics/haptic_service.dart';
import '../images/sticker_grid_cache.dart';
import '../images/sticker_grid_image.dart';
import '../l10n/l10n.dart';
import '../packs/batch_export_use_case.dart';
import '../packs/pack_models.dart';
import '../packs/pack_providers.dart';
import '../storage/storage_utility.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'apify_service.dart';
import 'comment_sticker_isolate.dart';
import 'tiktok_comment_service.dart';

/// Overlay shown while Apify polls. The main scaffold stays underneath.
Future<void> showCommentScanDialog(
  BuildContext context, {
  CancelToken? cancelToken,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CommentScanLoadingDialog(cancelToken: cancelToken),
  );
}

class CommentScanLoadingDialog extends StatefulWidget {
  const CommentScanLoadingDialog({super.key, this.cancelToken});

  final CancelToken? cancelToken;

  @override
  State<CommentScanLoadingDialog> createState() =>
      _CommentScanLoadingDialogState();
}

class _CommentScanLoadingDialogState extends State<CommentScanLoadingDialog> {
  @override
  void dispose() {
    widget.cancelToken?.cancel('The comment scan screen was closed.');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(context.l10n.scanningComments),
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
  bool showLoadingDialog = true,
  CancelToken? cancelToken,
}) async {
  final l10n = context.l10n;
  final requestCancelToken = cancelToken ?? CancelToken();
  if (showLoadingDialog) {
    unawaited(showCommentScanDialog(context, cancelToken: requestCancelToken));
  }

  List<CommentSticker> stickers = const [];
  String? errorMessage;
  try {
    stickers = await ref
        .read(apifyServiceProvider)
        .fetchCommentStickers(videoUrl, cancelToken: requestCancelToken);
  } on ApifyException catch (error) {
    if (requestCancelToken.isCancelled) return;
    errorMessage = error.message;
  } catch (_) {
    if (requestCancelToken.isCancelled) return;
    errorMessage = l10n.couldNotScanComments;
  }

  if (!context.mounted) return;
  if (showLoadingDialog) {
    Navigator.of(context, rootNavigator: true).pop();
  }

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

  await showCommentStickerSheet(context, stickers: stickers);
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
    Provider<Future<Directory> Function()>(
      (ref) => getStickrTemporaryDirectory,
    );

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
  final List<String> _selectedUrls = [];
  final List<CommentSticker> _visible = [];
  var _exporting = false;
  var _exportCompleted = 0;
  var _exportTotal = 0;
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

  void _toggleSelection(String imageUrl) {
    if (_exporting) return;
    setState(() {
      if (_selectedUrls.contains(imageUrl)) {
        _selectedUrls.remove(imageUrl);
      } else {
        _selectedUrls.add(imageUrl);
      }
    });
  }

  Future<void> _exportSelected() async {
    final count = _selectedUrls.length;
    if (_exporting ||
        count < WhatsAppPackRules.minStickers ||
        count > WhatsAppPackRules.maxStickers) {
      return;
    }

    final selected = [
      for (final imageUrl in List<String>.of(_selectedUrls))
        _visible.firstWhere((item) => item.imageUrl == imageUrl),
    ];
    setState(() {
      _exporting = true;
      _exportCompleted = 0;
      _exportTotal = selected.length;
    });
    try {
      BatchExportResult? result;
      final stream = ref
          .read(batchExportUseCaseProvider)
          .export(
            items: [
              for (final sticker in selected)
                BatchExportItem(
                  id: sticker.id,
                  accessibilityText: sticker.author,
                  download: () async {
                    final localPath = sticker.localPath;
                    if (localPath != null) {
                      return BatchExportDownload(
                        file: File(localPath),
                        deleteAfterUse: false,
                      );
                    }
                    return BatchExportDownload(
                      file: await ref
                          .read(tikTokCommentServiceProvider)
                          .downloadSticker(sticker),
                    );
                  },
                ),
            ],
            packName: commentPackName,
            author: commentPackAuthor,
          );
      await for (final progress in stream) {
        if (mounted) {
          setState(() {
            _exportCompleted = progress.completedItems;
            _exportTotal = progress.totalItems;
          });
        }
        result = progress.result ?? result;
      }
      if (result == null) {
        throw PackException(context.l10n.batchExportIncomplete);
      }
      if (!mounted) return;

      hapticService.success();
      _showMessage(result.message);
    } on TikTokCommentException catch (error) {
      if (mounted) {
        hapticService.error();
        _showMessage(error.message);
      }
    } on StickerExportException catch (error) {
      if (mounted) {
        hapticService.error();
        _showMessage(error.message);
      }
    } on PackException catch (error) {
      if (mounted) {
        hapticService.error();
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        hapticService.error();
        _showMessage(context.l10n.couldNotExportStickers);
      }
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
          _exportCompleted = 0;
          _exportTotal = 0;
        });
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
                            context.l10n.commentStickers,
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
                      tooltip: context.l10n.close,
                      onPressed: !_exporting
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
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FloatingActionButton.extended(
              key: const Key('comment-sticker-export'),
              heroTag: null,
              onPressed:
                  !_exporting &&
                      _selectedUrls.length >= WhatsAppPackRules.minStickers &&
                      _selectedUrls.length <= WhatsAppPackRules.maxStickers
                  ? _exportSelected
                  : null,
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded),
              label: Text(
                _exporting && _exportTotal > 0
                    ? context.l10n.exportProgress(
                        _exportCompleted,
                        _exportTotal,
                      )
                    : context.l10n.exportSelection(
                        _selectedUrls.length,
                        WhatsAppPackRules.maxStickers,
                      ),
                key: const Key('comment-sticker-export-progress'),
              ),
            ),
          ),
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
      return _MessageState(
        icon: Icons.search_off_rounded,
        message: context.l10n.noCommentStickers,
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
      findChildIndexCallback: (key) =>
          findStickerGridChildIndex(key, _visible.map((sticker) => sticker.id)),
      itemBuilder: (context, index) {
        final sticker = _visible[index];
        final selected = _selectedUrls.contains(sticker.imageUrl);
        return Material(
          key: ValueKey(sticker.id),
          color: colors.surfaceMuted,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            key: Key('comment-sticker-${sticker.id}'),
            onTap: _exporting ? null : () => _toggleSelection(sticker.imageUrl),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: StickerGridImage(
                    filePath: sticker.localPath,
                    imageUrl: sticker.imageUrl,
                  ),
                ),
                if (selected)
                  ColoredBox(color: Colors.black.withValues(alpha: 0.48)),
                if (selected)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 26,
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

/// Full-screen Apify scan shown when a TikTok URL arrives from Android Share.
class SharedTikTokScanPage extends ConsumerStatefulWidget {
  const SharedTikTokScanPage({
    super.key,
    required this.videoUrl,
    this.onFinished,
    this.animateProgress = true,
  });

  final String videoUrl;
  final VoidCallback? onFinished;
  final bool animateProgress;

  @override
  ConsumerState<SharedTikTokScanPage> createState() =>
      _SharedTikTokScanPageState();
}

class _SharedTikTokScanPageState extends ConsumerState<SharedTikTokScanPage> {
  final _cancelToken = CancelToken();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    if (!mounted) return;
    await scanAndShowCommentStickers(
      context,
      ref,
      videoUrl: widget.videoUrl,
      showLoadingDialog: false,
      cancelToken: _cancelToken,
    );
    if (!mounted) return;
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _cancelToken.cancel('The shared comment scan screen was closed.');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('shared-tiktok-scan-page'),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TickerMode(
              enabled: widget.animateProgress,
              child: const CircularProgressIndicator(),
            ),
            const SizedBox(height: 16),
            Text(context.l10n.scanningComments),
          ],
        ),
      ),
    );
  }
}
