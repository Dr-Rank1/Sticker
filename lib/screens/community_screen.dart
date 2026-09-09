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
import '../l10n/l10n.dart';
import '../packs/batch_export_use_case.dart';
import '../packs/pack_models.dart';
import '../packs/pack_providers.dart';
import '../state/navigation_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

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
  int _exportCompleted = 0;
  int _exportTotal = 0;
  String? _error;
  ProviderSubscription<AppTab>? _tabSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreIfNeeded);
    _tabSubscription = ref.listenManual(navigationProvider, (_, tab) {
      if (tab == AppTab.community && _stickers.isEmpty) {
        _loadNextPage();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    _tabSubscription?.close();
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
        _error = context.l10n.couldNotLoadTrending;
        _loadingPage = false;
      });
    }
  }

  void _addToTray(CommunitySticker sticker) {
    if (_tray.any((item) => item.stableId == sticker.stableId)) return;
    if (_tray.length >= WhatsAppPackRules.maxStickers) {
      _showMessage(context.l10n.myPackCapacity);
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

    final selected = List<CommunitySticker>.of(_tray);
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
                  id: sticker.stableId,
                  accessibilityText: sticker.label,
                  download: () async => BatchExportDownload(
                    file: await ref
                        .read(giphyServiceProvider)
                        .downloadSticker(
                          id: sticker.stableId,
                          url: sticker.imageUrl,
                        ),
                  ),
                ),
            ],
            packName: context.l10n.myPack,
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
        _showExportError(context.l10n.couldNotExportMyPack);
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
                  context.l10n.community,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.communitySubtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Expanded(child: _buildFeed()),
          _StagingTray(
            stickers: _tray,
            exporting: _exporting,
            exportCompleted: _exportCompleted,
            exportTotal: _exportTotal,
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
              child: Text(context.l10n.retry),
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
                tooltip: added
                    ? context.l10n.addedToMyPack
                    : context.l10n.addToMyPack,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(context.l10n.animatedBadge),
      ),
    );
  }
}

class _StagingTray extends StatelessWidget {
  const _StagingTray({
    required this.stickers,
    required this.exporting,
    required this.exportCompleted,
    required this.exportTotal,
    required this.onRemove,
    required this.onExport,
  });

  final List<CommunitySticker> stickers;
  final bool exporting;
  final int exportCompleted;
  final int exportTotal;
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
                  context.l10n.myPackCount(stickers.length, 30),
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
                label: Text(
                  exporting && exportTotal > 0
                      ? context.l10n.exportProgress(
                          exportCompleted,
                          exportTotal,
                        )
                      : context.l10n.exportToWhatsApp,
                  key: const Key('community-export-progress'),
                ),
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
                      context.l10n.communityTrayHint,
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
