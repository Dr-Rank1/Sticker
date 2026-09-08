import 'package:workmanager/workmanager.dart';

import '../logging/app_logger.dart';
import 'storage_utility.dart';

/// Unique Workmanager task name for daily temporary-media cleanup.
const cleanupTaskName = 'cleanup_task';

/// Entry point invoked by Workmanager in a background isolate.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != cleanupTaskName) {
      return true;
    }
    try {
      final result = await StorageUtility().cleanupTemporaryMedia();
      appLogger.d(
        'Cache cleanup removed ${result.filesDeleted} files '
        '(${result.bytesFreed} bytes).',
      );
      return true;
    } catch (error, stackTrace) {
      appLogger.e(
        'Cache cleanup task failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  });
}
