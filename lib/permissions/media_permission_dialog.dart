import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'media_permission_service.dart';

/// Explains why Stickr needs photos and videos, then requests them.
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
              context.l10n.allowPhotosVideos,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.mediaPermissionDescription,
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
                child: Text(context.l10n.allowAccess),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('permission-not-now'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                context.l10n.notNow,
                style: textTheme.titleSmall?.copyWith(
                  color: colors.textSecondary,
                ),
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
        title: Text(context.l10n.permissionTurnedOff),
        content: Text(context.l10n.permissionSettingsDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('permission-open-settings'),
            onPressed: () async {
              Navigator.pop(context);
              await (service ?? MediaPermissionService()).openSettings();
            },
            child: Text(context.l10n.openSettings),
          ),
        ],
      );
    },
  );
}

/// Shows the rationale when needed, then requests media access.
Future<bool> ensureMediaPermission(BuildContext context, WidgetRef ref) async {
  final media = ref.read(mediaPermissionServiceProvider);
  if (await media.hasAccess()) return true;
  if (!context.mounted) return false;
  return showMediaPermissionDialog(context, service: media);
}

Future<bool> ensureCameraPermission(BuildContext context, WidgetRef ref) async {
  final media = ref.read(mediaPermissionServiceProvider);
  if (!media.needsRuntimePrompt) return true;
  if (!context.mounted) return false;

  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = context.colors;
      return AlertDialog(
        title: Text(context.l10n.useCamera),
        content: Text(context.l10n.cameraPermissionDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: colors.accent),
            child: Text(context.l10n.continueLabel),
          ),
        ],
      );
    },
  );
  if (proceed != true) return false;
  return media.requestCamera();
}
