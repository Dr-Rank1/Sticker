import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

import '../logging/app_logger.dart';

/// Play Core immediate update (`AppUpdateType.immediate`). Used when a hotfix
/// must land before the user keeps using the app (for example Apify/TikTok).
Future<void> checkForImmediatePlayStoreUpdate({
  Future<AppUpdateInfo> Function()? checkForUpdate,
  Future<AppUpdateResult> Function()? startImmediateUpdate,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  final check = checkForUpdate ?? InAppUpdate.checkForUpdate;
  final startImmediate =
      startImmediateUpdate ?? InAppUpdate.performImmediateUpdate;

  try {
    final AppUpdateInfo info = await check();
    final updateAvailable =
        info.updateAvailability == UpdateAvailability.updateAvailable;
    if (!updateAvailable) {
      return;
    }

    appLogger.i(
      'Play Store update available; starting AppUpdateType.immediate flow',
    );
    await startImmediate();
  } catch (error, stack) {
    appLogger.w(
      'Play Store in-app update check failed',
      error: error,
      stackTrace: stack,
    );
  }
}
