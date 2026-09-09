import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:stickr/store/play_store_update_service.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('main.dart checks AppUpdateInfo and starts an immediate update', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    expect(mainSource, contains('checkForImmediatePlayStoreUpdate()'));
    final serviceSource = File('lib/store/play_store_update_service.dart')
        .readAsStringSync();
    expect(serviceSource, contains('InAppUpdate.checkForUpdate'));
    expect(serviceSource, contains('InAppUpdate.performImmediateUpdate'));
    expect(serviceSource, contains('AppUpdateType.immediate'));
  });

  test(
    'starts AppUpdateType.immediate when a Play Store update is available',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var immediateStarts = 0;

      await checkForImmediatePlayStoreUpdate(
        checkForUpdate: () async => _info(UpdateAvailability.updateAvailable),
        startImmediateUpdate: () async {
          immediateStarts += 1;
          return AppUpdateResult.success;
        },
      );

      expect(immediateStarts, 1);
    },
  );

  test('does not force an update when Play reports none available', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var immediateStarts = 0;

    await checkForImmediatePlayStoreUpdate(
      checkForUpdate: () async => _info(UpdateAvailability.updateNotAvailable),
      startImmediateUpdate: () async {
        immediateStarts += 1;
        return AppUpdateResult.success;
      },
    );

    expect(immediateStarts, 0);
  });

  test('swallows Play Store plugin failures so startup can continue', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await checkForImmediatePlayStoreUpdate(
      checkForUpdate: () async => throw StateError('Play Core unavailable'),
      startImmediateUpdate: () async =>
          fail('immediate update should not start'),
    );
  });
}

AppUpdateInfo _info(UpdateAvailability availability) {
  return AppUpdateInfo(
    updateAvailability: availability,
    immediateUpdateAllowed: true,
    immediateAllowedPreconditions: const [],
    flexibleUpdateAllowed: false,
    flexibleAllowedPreconditions: const [],
    availableVersionCode: 2,
    installStatus: InstallStatus.unknown,
    packageName: 'com.stikk.stikk',
    clientVersionStalenessDays: 0,
    updatePriority: 5,
  );
}
