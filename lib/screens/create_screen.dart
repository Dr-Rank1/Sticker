import 'package:flutter/material.dart';

import '../memes/meme_template_sheet.dart';
import '../photos/photo_import_sheet.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../tiktok/tiktok_import_sheet.dart';

class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                    'Create',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Turn any moment into a WhatsApp sticker.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          sliver: SliverList.list(
            children: [
              _CreateSourceCard(
                icon: Icons.photo_library_rounded,
                title: 'From a photo',
                subtitle: 'Auto crop, remove the background, add text.',
                onTap: () => showPhotoImportSheet(context),
              ),
              const SizedBox(height: 12),
              _CreateSourceCard(
                icon: Icons.add_photo_alternate_rounded,
                title: 'Start from Meme',
                subtitle: 'Pick a popular template and add your own text.',
                onTap: () => showMemeTemplateSheet(context),
              ),
              const SizedBox(height: 12),
              _CreateSourceCard(
                icon: Icons.videocam_rounded,
                title: 'From TikTok',
                subtitle: 'Paste a link and pick the perfect clip.',
                onTap: () => showTiktokImportSheet(context),
              ),
              const SizedBox(height: 12),
              _CreateSourceCard(
                icon: Icons.gif_box_rounded,
                title: 'From a video',
                subtitle: 'Make an animated sticker in seconds.',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'From a video is coming in the next phase.',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              const _FreeForeverNote(),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreateSourceCard extends StatelessWidget {
  const _CreateSourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: colors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, color: colors.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeForeverNote extends StatelessWidget {
  const _FreeForeverNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite_rounded, color: colors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Stikk is 100% free. No accounts, no paywalls.',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: colors.accentDim),
            ),
          ),
        ],
      ),
    );
  }
}
