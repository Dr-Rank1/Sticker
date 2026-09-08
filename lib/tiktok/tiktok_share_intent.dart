import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Abstraction over [ReceiveSharingIntent] so widget tests can inject shares.
abstract class TikTokShareIntent {
  Future<List<SharedMediaFile>> getInitialMedia();
  Stream<List<SharedMediaFile>> getMediaStream();
  Future<void> reset();
}

/// Production client: Android Share -> Stikk via `receive_sharing_intent`.
class PluginTikTokShareIntent implements TikTokShareIntent {
  const PluginTikTokShareIntent();

  @override
  Future<List<SharedMediaFile>> getInitialMedia() {
    return ReceiveSharingIntent.instance.getInitialMedia();
  }

  @override
  Stream<List<SharedMediaFile>> getMediaStream() {
    return ReceiveSharingIntent.instance.getMediaStream();
  }

  @override
  Future<void> reset() => ReceiveSharingIntent.instance.reset();
}

/// In-memory share source for tests.
class FakeTikTokShareIntent implements TikTokShareIntent {
  FakeTikTokShareIntent({
    this.initialMedia = const [],
    Stream<List<SharedMediaFile>>? mediaStream,
  }) : _mediaStream = mediaStream ?? const Stream.empty();

  final List<SharedMediaFile> initialMedia;
  final Stream<List<SharedMediaFile>> _mediaStream;

  @override
  Future<List<SharedMediaFile>> getInitialMedia() async => initialMedia;

  @override
  Stream<List<SharedMediaFile>> getMediaStream() => _mediaStream;

  @override
  Future<void> reset() async {}
}

final tikTokShareIntentProvider = Provider<TikTokShareIntent>((ref) {
  return const PluginTikTokShareIntent();
});
