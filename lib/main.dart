import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

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
import 'tiktok/comment_sticker_sheet.dart';
import 'tiktok/tiktok_share_intent.dart';
import 'tiktok/tiktok_url.dart';
import 'widgets/main_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installAppErrorHandlers();

  await runZonedGuarded(
    () async {
      final repository = await HivePackRepository.open();
      final settings = await HiveSettingsStore.open();
      var initialShare = const <SharedMediaFile>[];
      try {
        initialShare = await ReceiveSharingIntent.instance.getInitialMedia();
        await ReceiveSharingIntent.instance.reset();
      } catch (error) {
        appLogger.d('Share intent initial media unavailable: $error');
      }
      runApp(
        ProviderScope(
          overrides: [
            packRepositoryProvider.overrideWithValue(repository),
            settingsStoreProvider.overrideWithValue(settings),
          ],
          child: StikkApp(initialSharedMedia: initialShare),
        ),
      );
    },
    (error, stack) {
      appLogger.e('App startup failed', error: error, stackTrace: stack);
      runApp(const _StartupErrorApp());
    },
  );
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

class StikkApp extends ConsumerStatefulWidget {
  const StikkApp({super.key, this.initialSharedMedia = const []});

  final List<SharedMediaFile> initialSharedMedia;

  @override
  ConsumerState<StikkApp> createState() => _StikkAppState();
}

class _StikkAppState extends ConsumerState<StikkApp> {
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  String? _sharedTikTokUrl;

  @override
  void initState() {
    super.initState();
    _sharedTikTokUrl = extractTikTokUrlFromSharedMedia(
      widget.initialSharedMedia,
    );
    if (_sharedTikTokUrl != null) unawaited(_consumeClipboard());
    _listenForSharedTikTokUrls();
  }

  void _listenForSharedTikTokUrls() {
    final shareIntent = ref.read(tikTokShareIntentProvider);
    // App already running in the background: new Share -> Stikk intents.
    _shareSub = shareIntent.getMediaStream().listen(
      _handleSharedMedia,
      onError: (Object error) {
        appLogger.d('Share intent stream unavailable: $error');
      },
    );

    // Cold start: the OS launched Stikk because the user shared a link.
    unawaited(_loadInitialSharedMedia(shareIntent));
  }

  Future<void> _loadInitialSharedMedia(TikTokShareIntent shareIntent) async {
    try {
      final files = await shareIntent.getInitialMedia();
      _handleSharedMedia(files);
      await shareIntent.reset();
    } catch (error) {
      appLogger.d('Share intent initial media unavailable: $error');
    }
  }

  void _handleSharedMedia(List<SharedMediaFile> files) {
    final url = extractTikTokUrlFromSharedMedia(files);
    if (url == null || url == _sharedTikTokUrl) return;
    unawaited(_consumeClipboard());
    if (!mounted) return;
    setState(() => _sharedTikTokUrl = url);
  }

  Future<void> _consumeClipboard() async {
    try {
      await Clipboard.setData(const ClipboardData(text: ''));
    } on PlatformException {
      // Clipboard access may be denied by the OS or device privacy settings.
    }
  }

  void _clearSharedTikTokUrl() {
    if (!mounted || _sharedTikTokUrl == null) return;
    setState(() => _sharedTikTokUrl = null);
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final onboardingComplete = ref.watch(onboardingCompleteProvider);
    final sharedUrl = _sharedTikTokUrl;

    final Widget home;
    if (sharedUrl != null && onboardingComplete) {
      home = SharedTikTokScanPage(
        key: ValueKey('share-$sharedUrl'),
        videoUrl: sharedUrl,
        onFinished: _clearSharedTikTokUrl,
      );
    } else if (onboardingComplete) {
      home = const MainScaffold(key: ValueKey('home'));
    } else {
      home = const OnboardingScreen(key: ValueKey('onboarding'));
    }

    return MaterialApp(
      title: 'Stikk',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: home,
      ),
    );
  }
}
