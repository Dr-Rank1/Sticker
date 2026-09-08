import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error/app_error_fallback.dart';
import 'error/app_error_handlers.dart';
import 'logging/app_logger.dart';
import 'onboarding/onboarding_controller.dart';
import 'onboarding/onboarding_screen.dart';
import 'packs/pack_providers.dart';
import 'packs/pack_repository.dart';
import 'state/settings_store.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/main_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installAppErrorHandlers();

  await runZonedGuarded(() async {
    final repository = await HivePackRepository.open();
    final settings = await HiveSettingsStore.open();
    runApp(
      ProviderScope(
        overrides: [
          packRepositoryProvider.overrideWithValue(repository),
          settingsStoreProvider.overrideWithValue(settings),
        ],
        child: const StikkApp(),
      ),
    );
  }, (error, stack) {
    appLogger.e('App startup failed', error: error, stackTrace: stack);
    runApp(const _StartupErrorApp());
  });
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppErrorFallback(),
    );
  }
}

class StikkApp extends ConsumerWidget {
  const StikkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final onboardingComplete = ref.watch(onboardingCompleteProvider);

    return MaterialApp(
      title: 'Stikk',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: onboardingComplete
            ? const MainScaffold(key: ValueKey('home'))
            : const OnboardingScreen(key: ValueKey('onboarding')),
      ),
    );
  }
}
