import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/editor_screen.dart';
import '../editor/local_video_import_service.dart';
import '../photos/photo_import_sheet.dart';

typedef LocalVideoEditorRoute = Route<Object?> Function(String videoPath);

final localVideoEditorRouteProvider = Provider<LocalVideoEditorRoute>((ref) {
  return (videoPath) => MaterialPageRoute<Object?>(
    builder: (_) => EditorScreen(videoPath: videoPath),
  );
});

Future<void> openPhotoCreateFlow(BuildContext context) {
  return showPhotoImportSheet(context);
}

Future<void> openLocalVideoCreateFlow({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  LocalVideoImportResult? result;
  try {
    final service = ref.read(localVideoImportServiceProvider);
    result = await service.pickAndPrepare();
    if (result == null) return;
    if (!context.mounted) {
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
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
