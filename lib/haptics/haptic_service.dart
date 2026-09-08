import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Central haptic engine for tactile editor, library, and export feedback.
class HapticService {
  const HapticService({
    Future<void> Function()? lightImpact,
    Future<void> Function()? mediumImpact,
    Future<void> Function()? vibrate,
  }) : _lightImpact = lightImpact ?? HapticFeedback.lightImpact,
       _mediumImpact = mediumImpact ?? HapticFeedback.mediumImpact,
       _vibrate = vibrate ?? HapticFeedback.vibrate;

  final Future<void> Function() _lightImpact;
  final Future<void> Function() _mediumImpact;
  final Future<void> Function() _vibrate;

  /// Moving or transforming a sticker on the Matrix4 canvas.
  Future<void> lightImpact() => _lightImpact();

  /// Standard button taps in Library, Editor, and Export.
  Future<void> mediumImpact() => _mediumImpact();

  /// Success and error outcomes, such as saving a pack.
  Future<void> vibrate() => _vibrate();

  Future<void> stickerMoved() => lightImpact();

  Future<void> buttonTap() => mediumImpact();

  Future<void> success() => vibrate();

  Future<void> error() => vibrate();
}

/// In-memory recorder for widget and unit tests.
class RecordingHapticService extends HapticService {
  RecordingHapticService()
    : events = <String>[],
      super(
        lightImpact: () async {},
        mediumImpact: () async {},
        vibrate: () async {},
      );

  final List<String> events;

  @override
  Future<void> lightImpact() async => events.add('lightImpact');

  @override
  Future<void> mediumImpact() async => events.add('mediumImpact');

  @override
  Future<void> vibrate() async => events.add('vibrate');
}

HapticService hapticService = const HapticService();

final hapticServiceProvider = Provider<HapticService>((ref) {
  return hapticService;
});
