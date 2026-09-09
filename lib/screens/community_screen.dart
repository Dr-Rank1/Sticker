import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../community/community_models.dart';
import '../community/community_sticker_feed.dart';
import '../community/giphy_service.dart';
import '../editor/ffmpeg_sticker_service.dart';
import '../haptics/haptic_service.dart';
import '../images/sticker_grid_cache.dart';
import '../images/sticker_grid_image.dart';
import '../packs/pack_models.dart';
import '../packs/pack_providers.dart';
import '../packs/whatsapp_export_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../tiktok/comment_sticker_formatter.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _scrollController = ScrollController();
  final List<CommunitySticker> _stickers = [];
  final List<CommunitySticker> _tray = [];
  String? _nextCursor;
  bool _loadingPage = false;
  bool _hasMore = true;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreIfNeeded);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNextPage());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    super.dispose();
  }

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 700) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_loadingPage || !_hasMore) return;
    setState(() {
      _loadingPage = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(communityStickerFeedProvider)
          .loadPage(cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _stickers.addAll(page.stickers);
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _loadingPage = false;
      });
    } on GiphyException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loadingPage = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load trending stickers. Please retry.';
        _loadingPage = false;
      });
    }
  }

  void _addToTray(CommunitySticker sticker) {
    if (_tray.any((item) => item.stableId == sticker.stableId)) return;
    if (_tray.length >= WhatsAppPackRules.maxStickers) {
      _showMessage('My Pack can hold up to 30 stickers.');
      return;
    }
    setState(() => _tray.add(sticker));
  }

  void _removeFromTray(CommunitySticker sticker) {
    if (_exporting) return;
    setState(() {
      _tray.removeWhere((item) => item.stableId == sticker.stableId);
    });
  }

  Future<void> _exportTray() async {
    if (_exporting ||
        _tray.length < WhatsAppPackRules.minStickers ||
        _tray.length > WhatsAppPackRules.maxStickers) {
      return;
    }

    setState(() => _exporting = true);
    final downloads = <File>[];
    final formatted = <File>[];
    try {
      for (final sticker in List<CommunitySticker>.of(_tray)) {
        final downloaded = await ref
            .read(giphyServiceProvider)
            .downloadSticker(id: sticker.stableId, url: sticker.imageUrl);
        downloads.add(downloaded);
        final ready = await ref
            .read(commentStickerFormatterProvider)
            .makeWhatsAppReady(downloaded);
        formatted.add(ready);
      }
      if (!mounted) return;

      final pack = await ref
          .read(packsProvider.notifier)
          .createStaticStickerPack(
            [for (final file in formatted) file.path],
            name: 'My Pack',
            author: commentPackAuthor,
          );
      final result = await ref
          .read(whatsAppExportServiceProvider)
          .exportToWhatsApp(pack);
      if (!mounted) return;
      setState(_tray.clear);
      hapticService.success();
      _showMessage(result.message);
    } on GiphyException catch (error) {
      if (mounted) _showExportError(error.message);
    } on StickerExportException catch (error) {
      if (mounted) _showExportError(error.message);
    } on PackException catch (error) {
      if (mounted) _showExportError(error.message);
    } catch (_) {
      if (mounted) {
        _showExportError('Couldn’t export My Pack. Please try again.');
      }
    } finally {
      for (final file in [...downloads, ...formatted]) {
        _delete(file);
      }
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showExportError(String message) {
    hapticService.error();
    _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _delete(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Temporary files may already have been reclaimed by the OS.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Collect trending stickers and build your next pack.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Expanded(child: _buildFeed()),
          _StagingTray(
            stickers: _tray,
            exporting: _exporting,
            onRemove: _removeFromTray,
            onExport: _exportTray,
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    if (_stickers.isEmpty && _loadingPage) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_stickers.isEmpty && _error != null) {
      return _CommunityFeedError(message: _error!, onRetry: _loadNextPage);
    }

    return MasonryGridView.custom(
      key: const Key('community-masonry-grid'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childrenDelegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == _stickers.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final sticker = _stickers[index];
          return _CommunityStickerTile(
            key: ValueKey(sticker.stableId),
            sticker: sticker,
            added: _tray.any((item) => item.stableId == sticker.stableId),
            onAdd: () => _addToTray(sticker),
          );
        },
        childCount: _stickers.length + (_loadingPage ? 1 : 0),
        findChildIndexCallback: (key) => findStickerGridChildIndex(
          key,
          _stickers.map((sticker) => sticker.stableId),
        ),
      ),
    );
  }
}

class _CommunityFeedError extends StatelessWidget {
  const _CommunityFeedError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: context.colors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('community-retry'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityStickerTile extends StatelessWidget {
  const _CommunityStickerTile({
    super.key,
    required this.sticker,
    required this.added,
    required this.onAdd,
  });

  final CommunitySticker sticker;
  final bool added;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: colors.border),
      ),
      child: AspectRatio(
        aspectRatio: sticker.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: CachedNetworkImage(
                imageUrl: sticker.imageUrl,
                cacheManager: StickerGridCacheManager.instance,
                memCacheWidth: StickerGridCacheManager.maxDecodeExtent,
                memCacheHeight: StickerGridCacheManager.maxDecodeExtent,
                fit: BoxFit.contain,
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined),
              ),
            ),
            if (sticker.animated)
              Positioned(
                left: 8,
                top: 8,
                child: _AnimatedBadge(colors: colors),
              ),
            Positioned(
              right: 8,
              bottom: 8,
              child: IconButton.filled(
                key: Key('community-add-${sticker.stableId}'),
                tooltip: added ? 'Added to My Pack' : 'Add to My Pack',
                onPressed: added ? null : onAdd,
                icon: Icon(
                  added ? Icons.check_rounded : Icons.add_rounded,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBadge extends StatelessWidget {
  const _AnimatedBadge({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text('GIF'),
      ),
    );
  }
}

class _StagingTray extends StatelessWidget {
  const _StagingTray({
    required this.stickers,
    required this.exporting,
    required this.onRemove,
    required this.onExport,
  });

  final List<CommunitySticker> stickers;
  final bool exporting;
  final ValueChanged<CommunitySticker> onRemove;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canExport =
        !exporting &&
        stickers.length >= WhatsAppPackRules.minStickers &&
        stickers.length <= WhatsAppPackRules.maxStickers;
    return Container(
      key: const Key('community-staging-tray'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'My Pack  ${stickers.length}/30',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                key: const Key('community-export-pack'),
                onPressed: canExport ? onExport : null,
                icon: exporting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Export to WhatsApp'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 58,
            child: stickers.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tap + on at least 3 stickers to start a pack.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.separated(
                    key: const Key('community-tray-list'),
                    scrollDirection: Axis.horizontal,
                    itemCount: stickers.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final sticker = stickers[index];
                      return Stack(
                        children: [
                          Container(
                            width: 58,
                            decoration: BoxDecoration(
                              color: colors.surfaceMuted,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: StickerGridImage(imageUrl: sticker.imageUrl),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              key: Key('community-remove-${sticker.stableId}'),
                              onTap: exporting ? null : () => onRemove(sticker),
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
