import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/haptics/haptic_service.dart';

void main() {
  test(
    'maps editor, button, and outcome feedback to the Play haptic APIs',
    () async {
      var light = 0;
      var medium = 0;
      var vibrate = 0;
      final service = HapticService(
        lightImpact: () async => light += 1,
        mediumImpact: () async => medium += 1,
        vibrate: () async => vibrate += 1,
      );

      await service.stickerMoved();
      await service.buttonTap();
      await service.success();
      await service.error();

      expect(light, 1);
      expect(medium, 1);
      expect(vibrate, 2);
    },
  );

  test('RecordingHapticService captures engine events', () async {
    final recorder = RecordingHapticService();
    await recorder.lightImpact();
    await recorder.mediumImpact();
    await recorder.vibrate();
    expect(recorder.events, ['lightImpact', 'mediumImpact', 'vibrate']);
  });
}
