import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Incoming `.stikk` archives from ACTION_VIEW / ACTION_SEND.
abstract class StikkFileIntent {
  Future<String?> getInitialFile();
  Stream<String> fileStream();
}

class PluginStikkFileIntent implements StikkFileIntent {
  PluginStikkFileIntent({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static const channelName = 'com.stikk.stikk/stikk_files';
  static const getInitialMethod = 'getInitialStikkFile';
  static const onFileMethod = 'onStikkFile';

  final MethodChannel _channel;
  final _files = StreamController<String>.broadcast();

  @override
  Future<String?> getInitialFile() {
    return _channel.invokeMethod<String>(getInitialMethod);
  }

  @override
  Stream<String> fileStream() => _files.stream;

  Future<void> _onNativeCall(MethodCall call) async {
    if (call.method != onFileMethod) return;
    final path = call.arguments as String?;
    if (path == null || path.isEmpty) return;
    _files.add(path);
  }
}

class FakeStikkFileIntent implements StikkFileIntent {
  FakeStikkFileIntent({this.initialFile, Stream<String>? files})
    : _fileStream = files ?? const Stream.empty();

  final String? initialFile;
  final Stream<String> _fileStream;

  @override
  Future<String?> getInitialFile() async => initialFile;

  @override
  Stream<String> fileStream() => _fileStream;
}

final stikkFileIntentProvider = Provider<StikkFileIntent>((ref) {
  return PluginStikkFileIntent();
});

String? extractStikkPathFromSharedMedia(List<SharedMediaFile> files) {
  for (final file in files) {
    final path = file.path;
    if (path.toLowerCase().endsWith('.stikk')) return path;
  }
  return null;
}
