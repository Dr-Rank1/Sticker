import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:stickr/tiktok/tiktok_url.dart';

void main() {
  test('extracts standard TikTok links from clipboard text', () {
    expect(
      extractTikTokClipboardUrl(
        'Try this https://www.tiktok.com/@creator/video/7393468652906925317!',
      ),
      'https://www.tiktok.com/@creator/video/7393468652906925317',
    );
  });

  test('extracts vm.tiktok.com share links', () {
    expect(
      extractTikTokClipboardUrl(
        'https://vm.tiktok.com/ZMexample/ Shared via TikTok',
      ),
      'https://vm.tiktok.com/ZMexample/',
    );
  });

  test('ignores non-TikTok clipboard content', () {
    expect(extractTikTokClipboardUrl('https://example.com/video/123'), isNull);
    expect(extractTikTokClipboardUrl(null), isNull);
  });

  test('extracts TikTok URLs from shared media payloads', () {
    expect(
      extractTikTokUrlFromSharedMedia([
        SharedMediaFile(
          path: 'Check this https://vm.tiktok.com/ZMshare/ out',
          type: SharedMediaType.text,
          mimeType: 'text/plain',
        ),
      ]),
      'https://vm.tiktok.com/ZMshare/',
    );
    expect(
      extractTikTokUrlFromSharedMedia([
        SharedMediaFile(
          path: 'https://example.com/not-tiktok',
          type: SharedMediaType.text,
        ),
      ]),
      isNull,
    );
  });

  test('extracts TikTok URLs from Android App Link URIs', () {
    expect(
      extractTikTokUrlFromUri(
        Uri.parse('https://www.tiktok.com/@creator/video/7393468652906925317'),
      ),
      'https://www.tiktok.com/@creator/video/7393468652906925317',
    );
    expect(
      extractTikTokUrlFromUri(Uri.parse('https://vm.tiktok.com/ZMappLink/')),
      'https://vm.tiktok.com/ZMappLink/',
    );
    expect(
      extractTikTokUrlFromUri(Uri.parse('https://example.com/video/1')),
      isNull,
    );
  });
}
