import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Incoming https App Links (TikTok URLs opened from SMS, Chrome, etc.).
abstract class TikTokAppLinks {
  Future<Uri?> getInitialLink();
  Stream<Uri> uriLinkStream();
}

class PluginTikTokAppLinks implements TikTokAppLinks {
  PluginTikTokAppLinks({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> uriLinkStream() => _appLinks.uriLinkStream;
}

class FakeTikTokAppLinks implements TikTokAppLinks {
  FakeTikTokAppLinks({this.initialUri, Stream<Uri>? uris})
    : _uris = uris ?? const Stream.empty();

  final Uri? initialUri;
  final Stream<Uri> _uris;

  @override
  Future<Uri?> getInitialLink() async => initialUri;

  @override
  Stream<Uri> uriLinkStream() {
    if (initialUri == null) return _uris;
    return Stream<Uri>.fromIterable([initialUri!]).asyncExpand((first) async* {
      yield first;
      yield* _uris;
    });
  }
}

final tikTokAppLinksProvider = Provider<TikTokAppLinks>((ref) {
  return PluginTikTokAppLinks();
});
