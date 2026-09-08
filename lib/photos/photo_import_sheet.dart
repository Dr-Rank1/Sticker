import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/editor_screen.dart';
import '../permissions/media_permission_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'photo_import_controller.dart';

Future<void> showPhotoImportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const PhotoImportSheet(),
      );
    },
  );
}

class PhotoImportSheet extends ConsumerStatefulWidget {
  const PhotoImportSheet({super.key});

  @override
  ConsumerState<PhotoImportSheet> createState() => _PhotoImportSheetState();
}

class _PhotoImportSheetState extends ConsumerState<PhotoImportSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(photoImportProvider.notifier).reset();
    });
  }

  Future<void> _pickGallery() async {
    final allowed = await ensureMediaPermission(context, ref);
    if (!allowed || !mounted) return;
    await ref.read(photoImportProvider.notifier).importFromGallery();
  }

  Future<void> _pickCamera() async {
    final photos = await ensureMediaPermission(context, ref);
    if (!photos || !mounted) return;
    final camera = await ensureCameraPermission(context, ref);
    if (!camera || !mounted) return;
    await ref.read(photoImportProvider.notifier).importFromCamera();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final importState = ref.watch(photoImportProvider);

    ref.listen(photoImportProvider, (previous, next) {
      if (!mounted) return;
      if (next.phase == PhotoImportPhase.error &&
          next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
      if (next.phase == PhotoImportPhase.completed &&
          previous?.phase != PhotoImportPhase.completed &&
          next.preparedPath != null) {
        final navigator = Navigator.of(context, rootNavigator: true);
        final path = next.preparedPath!;
        navigator.pop();
        Future.microtask(() {
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => EditorScreen(imagePath: path),
            ),
          );
        });
      }
    });

    return PopScope(
      canPop: !importState.isBusy,
      child: Material(
        color: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXl),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('From a photo', style: textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Pick a picture. We’ll cut out the subject on this device, then you can add text and emojis.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                key: const Key('photo-auto-crop-toggle'),
                contentPadding: EdgeInsets.zero,
                value: importState.removeBackground,
                onChanged: importState.isBusy
                    ? null
                    : ref.read(photoImportProvider.notifier).setRemoveBackground,
                title: Text('Auto crop', style: textTheme.titleMedium),
                subtitle: Text(
                  'Remove the background with on-device AI.',
                  style: textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 8),
              _PhotoProgress(state: importState),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('photo-gallery-button'),
                  onPressed: importState.isBusy ? null : _pickGallery,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Choose from gallery'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('photo-camera-button'),
                  onPressed: importState.isBusy ? null : _pickCamera,
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Take a photo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoProgress extends StatelessWidget {
  const _PhotoProgress({required this.state});

  final PhotoImportState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final visible = state.isBusy;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: visible
          ? Column(
              key: const ValueKey('photo-progress'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.phase == PhotoImportPhase.picking
                      ? 'Opening photos...'
                      : state.removeBackground
                          ? 'Cutting out the subject...'
                          : 'Preparing your photo...',
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    key: const Key('photo-prepare-progress'),
                    minHeight: 8,
                    backgroundColor: colors.surfaceMuted,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}
