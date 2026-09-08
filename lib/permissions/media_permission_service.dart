import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

typedef PermissionStatusLookup = Future<PermissionStatus> Function(
  Permission permission,
);
typedef PermissionRequestFn = Future<Map<Permission, PermissionStatus>> Function(
  List<Permission> permissions,
);

class MediaPermissionResult {
  const MediaPermissionResult({
    required this.hasAccess,
    required this.permanentlyDenied,
  });

  final bool hasAccess;
  final bool permanentlyDenied;
}

/// Resolves and requests the media permissions Stikk needs to pick photos
/// and videos, using Android 13+ granular access on API 33+.
class MediaPermissionService {
  MediaPermissionService({
    TargetPlatform? platform,
    Future<int> Function()? androidSdkInt,
    PermissionStatusLookup? readStatus,
    PermissionRequestFn? requestPermissions,
    Future<bool> Function()? openSettings,
  })  : _platform = platform ?? defaultTargetPlatform,
        // ignore: prefer_initializing_formals
        _androidSdkInt = androidSdkInt,
        _readStatus = readStatus ?? ((permission) => permission.status),
        _requestPermissions =
            requestPermissions ?? ((permissions) => permissions.request()),
        _openSettings = openSettings ?? openAppSettings;

  static const android13 = 33;

  final TargetPlatform _platform;
  final Future<int> Function()? _androidSdkInt;
  final PermissionStatusLookup _readStatus;
  final PermissionRequestFn _requestPermissions;
  final Future<bool> Function() _openSettings;

  bool get needsRuntimePrompt {
    if (kIsWeb) return false;
    return _platform == TargetPlatform.android || _platform == TargetPlatform.iOS;
  }

  /// Permissions to request for the current OS / SDK.
  List<Permission> permissionsFor({int? androidSdk}) {
    if (!needsRuntimePrompt) return const [];
    if (_platform == TargetPlatform.iOS) {
      return const [Permission.photos];
    }
    final sdk = androidSdk ?? 0;
    if (sdk >= android13) {
      return const [Permission.photos, Permission.videos];
    }
    return const [Permission.storage];
  }

  Future<List<Permission>> requiredPermissions() async {
    if (!needsRuntimePrompt) return const [];
    if (_platform != TargetPlatform.android) {
      return permissionsFor();
    }
    return permissionsFor(androidSdk: await _resolveAndroidSdk());
  }

  Future<bool> hasAccess() async {
    final permissions = await requiredPermissions();
    if (permissions.isEmpty) return true;

    for (final permission in permissions) {
      final status = await _readStatus(permission);
      if (!isUsable(status)) return false;
    }
    return true;
  }

  Future<bool> isPermanentlyDenied() async {
    final permissions = await requiredPermissions();
    if (permissions.isEmpty) return false;
    for (final permission in permissions) {
      final status = await _readStatus(permission);
      if (status.isPermanentlyDenied) return true;
    }
    return false;
  }

  Future<MediaPermissionResult> requestMedia() async {
    final permissions = await requiredPermissions();
    if (permissions.isEmpty) {
      return const MediaPermissionResult(
        hasAccess: true,
        permanentlyDenied: false,
      );
    }

    final statuses = await _requestPermissions(permissions);
    var hasAccess = true;
    var permanentlyDenied = false;
    for (final permission in permissions) {
      final status = statuses[permission] ?? await _readStatus(permission);
      if (!isUsable(status)) hasAccess = false;
      if (status.isPermanentlyDenied) permanentlyDenied = true;
    }
    return MediaPermissionResult(
      hasAccess: hasAccess,
      permanentlyDenied: permanentlyDenied,
    );
  }

  Future<bool> requestCamera() async {
    if (!needsRuntimePrompt) return true;
    final statuses = await _requestPermissions(const [Permission.camera]);
    final status =
        statuses[Permission.camera] ?? await _readStatus(Permission.camera);
    return isUsable(status);
  }

  Future<bool> openSettings() => _openSettings();

  Future<int> _resolveAndroidSdk() async {
    final override = _androidSdkInt;
    if (override != null) return override();
    if (kIsWeb || _platform != TargetPlatform.android) return 0;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return android13;
    }
  }

  static bool isUsable(PermissionStatus status) {
    return status.isGranted || status.isLimited || status.isProvisional;
  }
}

final mediaPermissionServiceProvider = Provider<MediaPermissionService>((ref) {
  return MediaPermissionService();
});
