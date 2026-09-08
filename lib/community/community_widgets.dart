import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CommunityNetworkImage extends StatelessWidget {
  const CommunityNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.icon = Icons.auto_awesome_mosaic_rounded,
  });

  final String url;
  final BoxFit fit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.surfaceMuted,
      child: Image.network(
        url,
        fit: fit,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Center(
          child: Icon(icon, color: colors.accent, size: 36),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accent,
                value: progress.expectedTotalBytes == null
                    ? null
                    : progress.cumulativeBytesLoaded / progress.expectedTotalBytes!,
              ),
            ),
          );
        },
      ),
    );
  }
}

class CommunityTagChip extends StatelessWidget {
  const CommunityTagChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '#$label',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.accentDim,
            ),
      ),
    );
  }
}
