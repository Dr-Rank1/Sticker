import 'package:flutter/foundation.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikk/display/display_refresh.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('picks the highest refresh rate at the current resolution', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    DisplayMode? applied;
    const active = DisplayMode(
      id: 1,
      width: 1080,
      height: 2400,
      refreshRate: 60,
    );

    await enableHighestDisplayMode(
      supportedModes: () async => const [
        DisplayMode(id: 1, width: 1080, height: 2400, refreshRate: 60),
        DisplayMode(id: 2, width: 1080, height: 2400, refreshRate: 120),
        DisplayMode(id: 3, width: 1080, height: 2400, refreshRate: 90),
        DisplayMode(id: 4, width: 1440, height: 3200, refreshRate: 144),
      ],
      activeMode: () async => active,
      setPreferredMode: (mode) async => applied = mode,
    );

    expect(applied?.refreshRate, 120);
    expect(applied?.width, 1080);
    expect(applied?.height, 2400);
  });

  test('does not change display mode off Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var called = false;
    await enableHighestDisplayMode(
      supportedModes: () async => const [
        DisplayMode(id: 2, width: 1080, height: 2400, refreshRate: 120),
      ],
      setPreferredMode: (_) async => called = true,
    );
    expect(called, isFalse);
  });
}
