import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/settings_store.dart';

final onboardingCompleteProvider = NotifierProvider<OnboardingController, bool>(
  OnboardingController.new,
);

class OnboardingController extends Notifier<bool> {
  @override
  bool build() => ref.read(settingsStoreProvider).onboardingComplete;

  Future<void> complete() async {
    await ref.read(settingsStoreProvider).setOnboardingComplete();
    state = true;
  }
}
