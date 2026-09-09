import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:workmanager/workmanager.dart';

import 'config/app_environment.dart';
import 'crashlytics/crash_reporter.dart';
import 'display/display_refresh.dart';
import 'error/app_error_fallback.dart';
import 'error/app_error_handlers.dart';
import 'logging/app_logger.dart';
import 'onboarding/onboarding_controller.dart';
import 'onboarding/onboarding_screen.dart';
import 'packs/pack_models.dart';
import 'packs/pack_providers.dart';
import 'packs/sticker_repository.dart';
import 'packs/stickr_file_intent.dart';
import 'state/settings_store.dart';
import 'state/theme_controller.dart';
import 'store/play_store_update_service.dart';
import 'storage/cache_cleanup_worker.dart';
import 'theme/app_theme.dart';
import 'tiktok/comment_sticker_sheet.dart';
import 'tiktok/tiktok_app_links.dart';
import 'tiktok/tiktok_share_intent.dart';
import 'tiktok/tiktok_url.dart';
import 'widgets/main_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installAppErrorHandlers();

  try {
    AppEnvironment.validateRequired();
    final firebaseReady = await initializeFirebase();
    if (firebaseReady) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await enableHighestDisplayMode();
      await checkForImmediatePlayStoreUpdate();
      try {
        await Workmanager().initialize(callbackDispatcher);
        await Workmanager().registerPeriodicTask(
          cleanupTaskName,
          cleanupTaskName,
          frequency: const Duration(hours: 24),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
          constraints: Constraints(
            networkType: NetworkType.notRequired,
            requiresDeviceIdle: true,
          ),
        );
      } catch (error, stack) {
        appLogger.e(
          'Failed to schedule cache cleanup',
          error: error,
          stackTrace: stack,
        );
      }
    }
    final repository = await StickerRepository.open();
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
        child: StickrApp(initialSharedMedia: initialShare),
      ),
    );
  } catch (error, stack) {
    appLogger.e('App startup failed', error: error, stackTrace: stack);
    crashReporter.recordError(error, stack, fatal: true);
    runApp(const _StartupErrorApp());
  }
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

class StickrApp extends ConsumerStatefulWidget {
  const StickrApp({super.key, this.initialSharedMedia = const []});

  final List<SharedMediaFile> initialSharedMedia;

  @override
  ConsumerState<StickrApp> createState() => _StickrAppState();
}

class _StickrAppState extends ConsumerState<StickrApp> {
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  StreamSubscription<String>? _stickrSub;
  StreamSubscription<Uri>? _appLinksSub;
  String? _sharedTikTokUrl;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _sharedTikTokUrl = extractTikTokUrlFromSharedMedia(
      widget.initialSharedMedia,
    );
    if (_sharedTikTokUrl != null) unawaited(_consumeClipboard());
    _listenForSharedTikTokUrls();
    _listenForStickrFiles();
    _listenForTikTokAppLinks();
  }

  void _listenForSharedTikTokUrls() {
    final shareIntent = ref.read(tikTokShareIntentProvider);
    // App already running in the background: new Share -> Stickr intents.
    _shareSub = shareIntent.getMediaStream().listen(
      _handleSharedMedia,
      onError: (Object error) {
        appLogger.d('Share intent stream unavailable: $error');
      },
    );

    // Cold start: the OS launched Stickr because the user shared a link.
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
    final stickrPath = extractStickrPathFromSharedMedia(files);
    if (stickrPath != null) {
      unawaited(_importStickrFile(stickrPath));
      return;
    }
    final url = extractTikTokUrlFromSharedMedia(files);
    if (url == null || url == _sharedTikTokUrl) return;
    unawaited(_consumeClipboard());
    if (!mounted) return;
    setState(() => _sharedTikTokUrl = url);
  }

  void _listenForTikTokAppLinks() {
    final links = ref.read(tikTokAppLinksProvider);
    _appLinksSub = links.uriLinkStream().listen(
      _handleAppLink,
      onError: (Object error) {
        appLogger.d('App link stream unavailable: $error');
      },
    );
  }

  void _handleAppLink(Uri uri) {
    final url = extractTikTokUrlFromUri(uri);
    if (url == null || url == _sharedTikTokUrl) return;
    unawaited(_consumeClipboard());
    if (!mounted) return;
    setState(() => _sharedTikTokUrl = url);
  }

  void _listenForStickrFiles() {
    final intent = ref.read(stickrFileIntentProvider);
    _stickrSub = intent.fileStream().listen(
      _importStickrFile,
      onError: (Object error) {
        appLogger.d('Stickr file stream unavailable: $error');
      },
    );
    unawaited(_loadInitialStickrFile(intent));
  }

  Future<void> _loadInitialStickrFile(StickrFileIntent intent) async {
    try {
      final path = await intent.getInitialFile();
      if (path != null) await _importStickrFile(path);
    } catch (error) {
      appLogger.d('Stickr file intent unavailable: $error');
    }
  }

  Future<void> _importStickrFile(String path) async {
    try {
      final pack = await ref
          .read(packsProvider.notifier)
          .importStickrFile(path);
      _showMessage('Imported ${pack.name}.');
    } on PackException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      appLogger.e('Failed to import .stickr pack', error: error);
      _showMessage('Could not import this pack.');
    }
  }

  void _showMessage(String message) {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
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
    _stickrSub?.cancel();
    _appLinksSub?.cancel();
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
      title: 'Stickr',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      builder: AppTheme.appBuilder,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: home,
      ),
    );
  }
}
