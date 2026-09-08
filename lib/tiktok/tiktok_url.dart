import 'package:receive_sharing_intent/receive_sharing_intent.dart';

final tikTokUrlPattern = RegExp(
  r'https?://(?:(?:www|m|vm|vt)\.)?tiktok\.com/[^\s]+',
  caseSensitive: false,
);

final _trailingPunctuation = RegExp(r'''[.,!?;:'")\]}]+$''');

/// Pulls a TikTok URL out of clipboard text, share-sheet text, or captions.
String? extractTikTokUrl(String? text) {
  if (text == null) return null;
  final match = tikTokUrlPattern.firstMatch(text.trim())?.group(0);
  return match?.replaceFirst(_trailingPunctuation, '');
}

/// Backward-compatible alias used by the clipboard auto-scan flow.
String? extractTikTokClipboardUrl(String? text) => extractTikTokUrl(text);

/// Reads TikTok links out of [receive_sharing_intent] payloads.
String? extractTikTokUrlFromSharedMedia(List<SharedMediaFile> files) {
  for (final file in files) {
    final url = extractTikTokUrl(file.message) ?? extractTikTokUrl(file.path);
    if (url != null) return url;
  }
  return null;
}
