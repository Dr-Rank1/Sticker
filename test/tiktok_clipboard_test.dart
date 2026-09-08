import 'package:flutter_test/flutter_test.dart';
import 'package:stikk/widgets/main_scaffold.dart';

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
}
