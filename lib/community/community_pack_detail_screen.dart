import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/navigation_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'community_catalog.dart';
import 'community_models.dart';
import 'community_widgets.dart';

class CommunityPackDetailScreen extends ConsumerStatefulWidget {
  const CommunityPackDetailScreen({super.key, required this.packId});

  final String packId;

  @override
  ConsumerState<CommunityPackDetailScreen> createState() =>
      _CommunityPackDetailScreenState();
}

class _CommunityPackDetailScreenState extends ConsumerState<CommunityPackDetailScreen> {
  var _downloading = false;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(communityCatalogProvider).value;
    final pack = catalog?.byId(widget.packId);
    if (pack == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pack')),
        body: const Center(child: Text('This pack is no longer available.')),
      );
    }

    final colors = context.colors;
    final downloaded = ref.watch(downloadedCommunityIdsProvider).contains(pack.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            title: Text(pack.name),
            flexibleSpace: FlexibleSpaceBar(
              background: CommunityNetworkImage(url: pack.coverUrl),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pack.name, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: colors.accentSoft,
                        child: Text(
                          pack.author[0].toUpperCase(),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: colors.accentDim,
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(pack.author, style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      Icon(Icons.download_rounded, size: 18, color: colors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        '${pack.downloadLabel} downloads',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(pack.blurb, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in pack.tags) CommunityTagChip(label: tag),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${pack.stickers.length} stickers',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final sticker = pack.stickers[index];
                  return Tooltip(
                    message: sticker.label,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: CommunityNetworkImage(
                        url: sticker.imageUrl,
                        icon: Icons.emoji_emotions_outlined,
                      ),
                    ),
                  );
                },
                childCount: pack.stickers.length,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
            key: const Key('download-community-pack'),
            onPressed: downloaded
                ? null
                : _downloading
                    ? () {}
                    : () => _download(pack),
            icon: _downloading
                ? SizedBox(
                    key: const Key('download-community-pack-loading'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : Icon(downloaded ? Icons.check_rounded : Icons.download_rounded),
            label: Text(
              _downloading
                  ? 'Downloading…'
                  : downloaded
                      ? 'In library'
                      : 'Download Pack',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _download(CommunityPack pack) async {
    setState(() => _downloading = true);
    try {
      final saved = await ref.read(downloadedCommunityIdsProvider.notifier).download(pack);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${saved.name} saved to Library. Add stickers to export it.'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                ref.read(navigationProvider.notifier).select(AppTab.library);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }
}
