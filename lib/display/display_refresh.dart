import 'package:flutter/foundation.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

import '../logging/app_logger.dart';

/// Selects the highest refresh rate the Android panel supports (90Hz, 120Hz).
Future<void> enableHighestDisplayMode({
  Future<List<DisplayMode>> Function()? supportedModes,
  Future<DisplayMode> Function()? activeMode,
  Future<void> Function(DisplayMode mode)? setPreferredMode,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final modes = List<DisplayMode>.from(
      supportedModes != null
          ? await supportedModes()
          : await FlutterDisplayMode.supported,
    );
    if (modes.isEmpty) return;

    DisplayMode? active;
    try {
      active = activeMode != null
          ? await activeMode()
          : await FlutterDisplayMode.active;
    } catch (_) {
      active = null;
    }

    var candidates = modes;
    if (active != null && active.width > 0 && active.height > 0) {
      final sameResolution = [
        for (final mode in modes)
          if (mode.width == active.width && mode.height == active.height) mode,
      ];
      if (sameResolution.isNotEmpty) candidates = sameResolution;
    }

    var best = candidates.first;
    for (final mode in candidates) {
      if (mode.refreshRate > best.refreshRate) best = mode;
    }
    if (setPreferredMode != null) {
      await setPreferredMode(best);
    } else {
      await FlutterDisplayMode.setPreferredMode(best);
    }
  } catch (error) {
    appLogger.d('Highest display mode unavailable: $error');
  }
}
