import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'media_permission_service.dart';

/// Explains why Stikk needs photos and videos, then requests them.
Future<bool> showMediaPermissionDialog(
  BuildContext context, {
  MediaPermissionService? service,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => MediaPermissionDialog(service: service),
  ).then((value) => value ?? false);
}

class MediaPermissionDialog extends ConsumerWidget {
  const MediaPermissionDialog({super.key, this.service});

  final MediaPermissionService? service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final MediaPermissionService media =
        service ?? ref.read(mediaPermissionServiceProvider);

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(
                Icons.photo_library_rounded,
                color: colors.accent,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Allow access to photos & videos',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Stikk only reads files you pick so you can cut out stickers and export them to WhatsApp. Nothing is uploaded.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('permission-allow'),
                onPressed: () async {
                  final result = await media.requestMedia();
                  if (!context.mounted) return;
                  if (result.permanentlyDenied && !result.hasAccess) {
                    Navigator.pop(context, false);
                    await showOpenSettingsDialog(context, service: media);
                    return;
                  }
                  Navigator.pop(context, result.hasAccess);
                },
                child: const Text('Allow access'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('permission-not-now'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Not now',
                style: textTheme.titleSmall?.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showOpenSettingsDialog(
  BuildContext context, {
  MediaPermissionService? service,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Permission turned off'),
        content: const Text(
          'To pick photos and videos, allow access in system settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('permission-open-settings'),
            onPressed: () async {
              Navigator.pop(context);
              await (service ?? MediaPermissionService()).openSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      );
    },
  );
}

/// Shows the rationale when needed, then requests media access.
Future<bool> ensureMediaPermission(
  BuildContext context,
  WidgetRef ref,
) async {
  final media = ref.read(mediaPermissionServiceProvider);
  if (await media.hasAccess()) return true;
  if (!context.mounted) return false;
  return showMediaPermissionDialog(context, service: media);
}

Future<bool> ensureCameraPermission(
  BuildContext context,
  WidgetRef ref,
) async {
  final media = ref.read(mediaPermissionServiceProvider);
  if (!media.needsRuntimePrompt) return true;
  if (!context.mounted) return false;

  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = context.colors;
      return AlertDialog(
        title: const Text('Use your camera'),
        content: const Text(
          'Stikk uses the camera so you can snap a photo and turn it into a sticker.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: colors.accent),
            child: const Text('Continue'),
          ),
        ],
      );
    },
  );
  if (proceed != true) return false;
  return media.requestCamera();
}
