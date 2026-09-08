import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

abstract class SettingsStore {
  bool get onboardingComplete;
  Future<void> setOnboardingComplete();
}

class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore({bool onboardingComplete = false})
      // ignore: prefer_initializing_formals
      : _onboardingComplete = onboardingComplete;

  bool _onboardingComplete;

  @override
  bool get onboardingComplete => _onboardingComplete;

  @override
  Future<void> setOnboardingComplete() async {
    _onboardingComplete = true;
  }
}

class HiveSettingsStore implements SettingsStore {
  HiveSettingsStore(this.box);

  static const boxName = 'app_settings';
  static const onboardingKey = 'onboardingComplete';

  final Box<dynamic> box;

  static Future<HiveSettingsStore> open({String? hivePath}) async {
    if (hivePath != null) {
      Hive.init(hivePath);
    }
    final box = Hive.isBoxOpen(boxName)
        ? Hive.box<dynamic>(boxName)
        : await Hive.openBox<dynamic>(boxName);
    return HiveSettingsStore(box);
  }

  @override
  bool get onboardingComplete =>
      box.get(onboardingKey, defaultValue: false) == true;

  @override
  Future<void> setOnboardingComplete() async {
    await box.put(onboardingKey, true);
  }
}

final settingsStoreProvider = Provider<SettingsStore>((ref) {
  return InMemorySettingsStore();
});
