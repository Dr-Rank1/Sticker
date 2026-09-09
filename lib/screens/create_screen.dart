import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accessibility/accessible_tap.dart';
import '../editor/editor_screen.dart';
import '../editor/local_video_import_service.dart';
import '../memes/meme_template_sheet.dart';
import '../photos/photo_import_sheet.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../tiktok/tiktok_import_sheet.dart';

typedef LocalVideoEditorRoute = Route<Object?> Function(String videoPath);

final localVideoEditorRouteProvider = Provider<LocalVideoEditorRoute>((ref) {
  return (videoPath) => MaterialPageRoute<Object?>(
    builder: (_) => EditorScreen(videoPath: videoPath),
  );
});

class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  var _importingVideo = false;

  Future<void> _importLocalVideo() async {
    if (_importingVideo) return;
    setState(() => _importingVideo = true);

    LocalVideoImportResult? result;
    try {
      final service = ref.read(localVideoImportServiceProvider);
      result = await service.pickAndPrepare();
      if (result == null) return;
      if (!mounted) {
        await service.deleteTemporary(result.file);
        return;
      }

      try {
        final route = ref.read(localVideoEditorRouteProvider)(result.file.path);
        await Navigator.of(context, rootNavigator: true).push(route);
      } finally {
        await service.deleteTemporary(result.file);
      }
    } on LocalVideoImportException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _importingVideo = false);
    }
  }

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
                key: const Key('create-local-video'),
                icon: Icons.gif_box_rounded,
                title: 'From a video',
                subtitle: 'Make an animated sticker in seconds.',
                onTap: _importLocalVideo,
                trailing: _importingVideo
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
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
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: colors.border),
      ),
      child: AccessibleTap(
        label: title,
        hint: subtitle,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
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
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              trailing ??
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
              'Stickr is 100% free. No accounts, no paywalls.',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: colors.accentDim),
            ),
          ),
        ],
      ),
    );
  }
}
