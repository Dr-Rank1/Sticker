import 'package:flutter_test/flutter_test.dart';
import 'package:stikk/storage/cache_cleanup_worker.dart';

void main() {
  test('cleanup task uses the scheduled Workmanager name', () {
    expect(cleanupTaskName, 'cleanup_task');
    expect(callbackDispatcher, isA<Function>());
  });
}
