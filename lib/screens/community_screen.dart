import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _filter = 0;

  static const _filters = ['For you', 'New', 'Popular'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
                    'Packs from people who make stickers like you.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var i = 0; i < _filters.length; i++)
                        ChoiceChip(
                          label: Text(_filters[i]),
                          selected: _filter == i,
                          onSelected: (_) => setState(() => _filter = i),
                          showCheckmark: false,
                          selectedColor: colors.accentSoft,
                          labelStyle: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: _filter == i
                                    ? colors.accentDim
                                    : colors.textSecondary,
                              ),
                          backgroundColor: colors.surface,
                          side: BorderSide(
                            color: _filter == i ? colors.accentSoft : colors.border,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          sliver: SliverList.separated(
            itemCount: _placeholderPacks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _CommunityPackCard(pack: _placeholderPacks[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _CommunityPack {
  const _CommunityPack({
    required this.title,
    required this.creator,
    required this.stickers,
    required this.tint,
  });

  final String title;
  final String creator;
  final List<String> stickers;
  final Color tint;
}

const _placeholderPacks = [
  _CommunityPack(
    title: 'Monday moods',
    creator: 'nina.makes',
    stickers: ['😴', '☕', '🫠', '💀'],
    tint: Color(0xFFB8E6FF),
  ),
  _CommunityPack(
    title: 'Pet chaos',
    creator: 'pixelpaws',
    stickers: ['🐶', '🐱', '🐾', '🦴'],
    tint: Color(0xFFFFD9B8),
  ),
  _CommunityPack(
    title: 'Gym replies',
    creator: 'liftclub',
    stickers: ['💪', '🔥', '😤', '🏆'],
    tint: Color(0xFFD7F7EB),
  ),
  _CommunityPack(
    title: 'Soft launch',
    creator: 'studio.mae',
    stickers: ['🌸', '✨', '💌', '🌙'],
    tint: Color(0xFFF3D4F7),
  ),
];

class _CommunityPackCard extends StatelessWidget {
  const _CommunityPackCard({required this.pack});

  final _CommunityPack pack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: pack.tint,
                child: Text(
                  pack.creator[0].toUpperCase(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pack.title, style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      pack.creator,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_box_outlined, color: colors.accent),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final sticker in pack.stickers) ...[
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: pack.tint.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Center(
                        child: Text(sticker, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                  ),
                ),
                if (sticker != pack.stickers.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
