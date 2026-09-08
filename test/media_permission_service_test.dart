import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stikk/permissions/media_permission_service.dart';

void main() {
  group('MediaPermissionService', () {
    test('uses photos and videos on Android 13+', () {
      final service = MediaPermissionService(platform: TargetPlatform.android);
      expect(
        service.permissionsFor(androidSdk: 33),
        [Permission.photos, Permission.videos],
      );
      expect(
        service.permissionsFor(androidSdk: 36),
        [Permission.photos, Permission.videos],
      );
    });

    test('uses storage on Android 12 and below', () {
      final service = MediaPermissionService(platform: TargetPlatform.android);
      expect(
        service.permissionsFor(androidSdk: 32),
        [Permission.storage],
      );
      expect(
        service.permissionsFor(androidSdk: 29),
        [Permission.storage],
      );
    });

    test('uses photos on iOS', () {
      final service = MediaPermissionService(platform: TargetPlatform.iOS);
      expect(service.permissionsFor(), [Permission.photos]);
    });

    test('skips runtime prompts on desktop', () {
      final service = MediaPermissionService(platform: TargetPlatform.linux);
      expect(service.needsRuntimePrompt, isFalse);
      expect(service.permissionsFor(androidSdk: 34), isEmpty);
    });

    test('hasAccess is true when every required permission is usable', () async {
      final service = MediaPermissionService(
        platform: TargetPlatform.android,
        androidSdkInt: () async => 34,
        readStatus: (permission) async => permission == Permission.photos
            ? PermissionStatus.limited
            : PermissionStatus.granted,
      );
      expect(await service.hasAccess(), isTrue);
    });

    test('requestMedia reports a grant on Android 13+', () async {
      final requested = <Permission>[];
      final service = MediaPermissionService(
        platform: TargetPlatform.android,
        androidSdkInt: () async => 33,
        readStatus: (_) async => PermissionStatus.denied,
        requestPermissions: (permissions) async {
          requested.addAll(permissions);
          return {
            for (final permission in permissions)
              permission: PermissionStatus.granted,
          };
        },
      );

      final result = await service.requestMedia();
      expect(requested, [Permission.photos, Permission.videos]);
      expect(result.hasAccess, isTrue);
      expect(result.permanentlyDenied, isFalse);
    });

    test('requestMedia uses storage on legacy Android', () async {
      late List<Permission> requested;
      final service = MediaPermissionService(
        platform: TargetPlatform.android,
        androidSdkInt: () async => 31,
        readStatus: (_) async => PermissionStatus.denied,
        requestPermissions: (permissions) async {
          requested = permissions;
          return {Permission.storage: PermissionStatus.denied};
        },
      );

      final result = await service.requestMedia();
      expect(requested, [Permission.storage]);
      expect(result.hasAccess, isFalse);
    });

    test('treats permanently denied as blocked', () async {
      final service = MediaPermissionService(
        platform: TargetPlatform.android,
        androidSdkInt: () async => 34,
        readStatus: (_) async => PermissionStatus.permanentlyDenied,
        requestPermissions: (permissions) async => {
          for (final permission in permissions)
            permission: PermissionStatus.permanentlyDenied,
        },
      );

      expect(await service.isPermanentlyDenied(), isTrue);
      final result = await service.requestMedia();
      expect(result.hasAccess, isFalse);
      expect(result.permanentlyDenied, isTrue);
    });
  });
}
