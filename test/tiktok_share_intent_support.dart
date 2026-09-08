import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void mockShareIntent({
  List<SharedMediaFile> initialMedia = const [],
  Stream<List<SharedMediaFile>>? mediaStream,
}) {
  ReceiveSharingIntent.setMockValues(
    initialMedia: initialMedia,
    mediaStream: mediaStream ?? const Stream.empty(),
  );
}
