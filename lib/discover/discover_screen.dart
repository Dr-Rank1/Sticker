import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../packs/save_to_pack_sheet.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'tenor_repository.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();
  List<TenorSticker> _results = const [];
  final _downloadingIds = <String>{};
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _searching) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final page = await ref.read(tenorRepositoryProvider).search(query);
      if (!mounted) return;
      setState(() {
        _results = page.results;
        _searching = false;
        if (page.results.isEmpty) {
          _error = 'No transparent stickers found. Try another search.';
        }
      });
    } on TenorException catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = error.message;
      });
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Couldn’t search for stickers. Please try again.';
      setState(() {
        _searching = false;
        _error = message;
      });
      _showMessage(message);
    }
  }

  Future<void> _downloadAndSave(TenorSticker sticker) async {
    if (_downloadingIds.contains(sticker.id)) return;
    setState(() => _downloadingIds.add(sticker.id));
    File? downloaded;
    try {
      downloaded = await ref
          .read(tenorRepositoryProvider)
          .downloadSticker(sticker);
      if (!mounted) return;
      final pack = await showSaveToPackSheet(
        context,
        stickerPath: downloaded.path,
        animated: sticker.animated,
      );
      if (!mounted || pack == null) return;
      _showMessage('Added to ${pack.name} (${pack.countLabel}).');
    } on TenorException catch (error) {
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
    final repository = ref.watch(tenorRepositoryProvider);

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
                  'Find transparent stickers powered by Tenor.',
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
                ? MasonryGridView.count(
                    key: const Key('discover-masonry-grid'),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final sticker = _results[index];
                      return _StickerTile(
                        sticker: sticker,
                        downloading: _downloadingIds.contains(sticker.id),
                        onTap: () => _downloadAndSave(sticker),
                      );
                    },
                  )
                : _DiscoverEmptyState(
                    error: _error,
                    missingApiKey: !repository.hasApiKey,
                  ),
          ),
        ],
      ),
    );
  }
}

class _StickerTile extends StatelessWidget {
  const _StickerTile({
    required this.sticker,
    required this.downloading,
    required this.onTap,
  });

  final TenorSticker sticker;
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
                child: Image.network(
                  sticker.webpUrl,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
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
            ? 'Add a Tenor API key at build time to enable Discover.'
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
