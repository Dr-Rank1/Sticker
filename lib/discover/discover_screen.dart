import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../community/giphy_service.dart';
import '../images/sticker_grid_cache.dart';
import '../images/sticker_grid_image.dart';
import '../packs/save_to_pack_sheet.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<GiphySticker> _results = const [];
  final _downloadingIds = <String>{};
  bool _searching = false;
  bool _loadingPage = false;
  String? _activeQuery;
  int? _nextOffset;
  int _searchGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreIfNeeded);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _searching) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final generation = ++_searchGeneration;
    setState(() {
      _searching = true;
      _loadingPage = false;
      _activeQuery = query;
      _nextOffset = null;
      _results = const [];
      _error = null;
    });

    try {
      final page = await ref.read(giphyServiceProvider).search(query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = page.stickers;
        _nextOffset = page.nextOffset;
        _searching = false;
        if (page.stickers.isEmpty) {
          _error = 'No stickers found. Try another search.';
        }
      });
    } on GiphyException catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searching = false;
        _error = error.message;
      });
      _showMessage(error.message);
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      const message = 'Couldn’t search for stickers. Please try again.';
      setState(() {
        _searching = false;
        _error = message;
      });
      _showMessage(message);
    }
  }

  void _loadMoreIfNeeded() {
    if (_scrollController.position.extentAfter < 600) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    final query = _activeQuery;
    final offset = _nextOffset;
    if (query == null || offset == null || _searching || _loadingPage) {
      return;
    }
    final generation = _searchGeneration;
    setState(() => _loadingPage = true);
    try {
      final page = await ref
          .read(giphyServiceProvider)
          .search(query, offset: offset);
      if (!mounted ||
          generation != _searchGeneration ||
          query != _activeQuery) {
        return;
      }
      final existingIds = _results.map((sticker) => sticker.id).toSet();
      setState(() {
        _results = [
          ..._results,
          for (final sticker in page.stickers)
            if (existingIds.add(sticker.id)) sticker,
        ];
        _nextOffset = page.nextOffset;
        _loadingPage = false;
      });
    } on GiphyException catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _loadingPage = false);
      _showMessage(error.message);
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _loadingPage = false);
      _showMessage('Couldn’t load more stickers. Please try again.');
    }
  }

  Future<void> _downloadAndSave(GiphySticker sticker) async {
    if (_downloadingIds.contains(sticker.id)) return;
    setState(() => _downloadingIds.add(sticker.id));
    File? downloaded;
    try {
      downloaded = await ref
          .read(giphyServiceProvider)
          .downloadSticker(id: sticker.id, url: sticker.url);
      if (!mounted) return;
      final pack = await showSaveToPackSheet(
        context,
        stickerPath: downloaded.path,
        animated: sticker.animated,
      );
      if (!mounted || pack == null) return;
      _showMessage('Added to ${pack.name} (${pack.countLabel}).');
    } on GiphyException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage('Couldn’t save that sticker. Please try again.');
      }
    } finally {
      if (downloaded != null) {
        try {
          if (downloaded.existsSync()) downloaded.deleteSync();
        } on FileSystemException {
          // The OS may already have cleared the temporary file.
        }
      }
      if (mounted) {
        setState(() => _downloadingIds.remove(sticker.id));
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
    final giphy = ref.watch(giphyServiceProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Find stickers powered by Giphy.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const Key('discover-search-field'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Search reactions, cats, anime…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      key: const Key('discover-search-button'),
                      tooltip: 'Search',
                      onPressed: _searching ? null : _search,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : _results.isNotEmpty
                ? MasonryGridView.custom(
                    key: const Key('discover-masonry-grid'),
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                    gridDelegate:
                        const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                        ),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childrenDelegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == _results.length) {
                          return const Padding(
                            key: Key('discover-loading-more'),
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final sticker = _results[index];
                        return _StickerTile(
                          key: ValueKey(sticker.id),
                          sticker: sticker,
                          downloading: _downloadingIds.contains(sticker.id),
                          onTap: () => _downloadAndSave(sticker),
                        );
                      },
                      childCount: _results.length + (_loadingPage ? 1 : 0),
                      findChildIndexCallback: (key) =>
                          findStickerGridChildIndex(
                            key,
                            _results.map((sticker) => sticker.id),
                          ),
                    ),
                  )
                : _DiscoverEmptyState(
                    error: _error,
                    missingApiKey: !giphy.hasApiKey,
                  ),
          ),
        ],
      ),
    );
  }
}

class _StickerTile extends StatelessWidget {
  const _StickerTile({
    super.key,
    required this.sticker,
    required this.downloading,
    required this.onTap,
  });

  final GiphySticker sticker;
  final bool downloading;
  final VoidCallback onTap;

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
      child: InkWell(
        key: Key('discover-sticker-${sticker.id}'),
        onTap: downloading ? null : onTap,
        child: AspectRatio(
          aspectRatio: sticker.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: colors.surfaceMuted,
                child: StickerGridImage(imageUrl: sticker.url),
              ),
              if (downloading)
                ColoredBox(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              Positioned(
                right: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: colors.accentOn,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverEmptyState extends StatelessWidget {
  const _DiscoverEmptyState({required this.error, required this.missingApiKey});

  final String? error;
  final bool missingApiKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final message =
        error ??
        (missingApiKey
            ? 'Add a Giphy API key at build time to enable Discover.'
            : 'Search for a mood, reaction, or character.');
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                error == null
                    ? Icons.auto_awesome_rounded
                    : Icons.search_off_rounded,
                color: colors.accentDim,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error == null ? 'Ready to discover' : 'No stickers yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
