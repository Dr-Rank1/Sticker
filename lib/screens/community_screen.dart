import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../community/community_catalog.dart';
import '../community/community_models.dart';
import '../community/community_pack_detail_screen.dart';
import '../community/community_widgets.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  var _filter = CommunityFeedFilter.trending;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final catalog = ref.watch(communityCatalogProvider);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Community',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Trending sticker packs, free and offline. No account.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final filter in CommunityFeedFilter.values)
                        ChoiceChip(
                          key: Key('community-filter-${filter.name}'),
                          label: Text(filter.label),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                          showCheckmark: false,
                          selectedColor: colors.accentSoft,
                          labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: _filter == filter
                                    ? colors.accentDim
                                    : colors.textSecondary,
                              ),
                          backgroundColor: colors.surface,
                          side: BorderSide(
                            color: _filter == filter ? colors.accentSoft : colors.border,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        ...catalog.when(
          loading: () => [
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (error, _) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('$error')),
            ),
          ],
          data: (data) {
            final packs = data.feed(_filter);
            return [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                sliver: SliverList.separated(
                  itemCount: packs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    return _TrendingPackCard(
                      pack: packs[index],
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CommunityPackDetailScreen(packId: packs[index].id),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ];
          },
        ),
      ],
    );
  }
}

class _TrendingPackCard extends StatelessWidget {
  const _TrendingPackCard({required this.pack, required this.onTap});

  final CommunityPack pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: colors.border),
      ),
      child: InkWell(
        key: Key('community-pack-${pack.id}'),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: CommunityNetworkImage(url: pack.coverUrl),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pack.name, style: textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: colors.accentSoft,
                        child: Text(
                          pack.author[0].toUpperCase(),
                          style: textTheme.labelMedium?.copyWith(color: colors.accentDim),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pack.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ),
                      Icon(Icons.download_rounded, size: 16, color: colors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        pack.downloadLabel,
                        style: textTheme.labelMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in pack.tags) CommunityTagChip(label: tag),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
