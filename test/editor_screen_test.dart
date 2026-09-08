import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stikk/editor/editor_screen.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
  });

  testWidgets('editor shows looping canvas and toolbars', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: EditorScreen(videoPath: 'clip.mp4'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Emojis'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('static photo editor hides speed and trim', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: EditorScreen(imagePath: 'missing-sticker.png'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Speed'), findsNothing);
  });
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final _events = <int, Stream<VideoEvent>>{};
  var _nextId = 1;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    final id = _nextId++;
    _events[id] = Stream<VideoEvent>.value(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 5),
        size: const Size(720, 1280),
      ),
    );
    return id;
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) {
    return create(options.dataSource);
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return _events[playerId] ?? const Stream.empty();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildView(int playerId) => const SizedBox();

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
