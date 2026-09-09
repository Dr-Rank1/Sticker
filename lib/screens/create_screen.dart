import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accessibility/accessible_tap.dart';
import '../editor/editor_screen.dart';
import '../editor/local_video_import_service.dart';
import '../l10n/l10n.dart';
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
    final l10n = context.l10n;
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
                    l10n.create,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.createSubtitle,
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
                title: l10n.fromPhoto,
                subtitle: l10n.fromPhotoSubtitle,
                onTap: () => showPhotoImportSheet(context),
              ),
              const SizedBox(height: 12),
              _CreateSourceCard(
                icon: Icons.add_photo_alternate_rounded,
                title: l10n.startFromMeme,
                subtitle: l10n.startFromMemeSubtitle,
                onTap: () => showMemeTemplateSheet(context),
              ),
              const SizedBox(height: 12),
              _CreateSourceCard(
                icon: Icons.videocam_rounded,
                title: l10n.fromTikTok,
                subtitle: l10n.fromTikTokSubtitle,
                onTap: () => showTiktokImportSheet(context),
              ),
              const SizedBox(height: 12),
              _CreateSourceCard(
                key: const Key('create-local-video'),
                icon: Icons.gif_box_rounded,
                title: l10n.fromVideo,
                subtitle: l10n.fromVideoSubtitle,
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
              context.l10n.freeForeverNote,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: colors.accentDim),
            ),
          ),
        ],
      ),
    );
  }
}
