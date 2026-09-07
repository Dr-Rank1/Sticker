import 'package:flutter_test/flutter_test.dart';
import 'package:stikk/tiktok/tiktok_import_service.dart';

void main() {
  late TiktokImportService service;

  setUp(() {
    service = TiktokImportService();
  });

  group('extractTikTokUrl', () {
    test('reads a standard video URL', () {
      expect(
        service.extractTikTokUrl(
          'https://www.tiktok.com/@studio/video/7393468652906925317',
        ),
        'https://www.tiktok.com/@studio/video/7393468652906925317',
      );
    });

    test('reads a short vm.tiktok.com link from messy text', () {
      expect(
        service.extractTikTokUrl(
          'watch this https://vm.tiktok.com/ZMh9k2xYz/ 🔥',
        ),
        'https://vm.tiktok.com/ZMh9k2xYz/',
      );
    });

    test('adds https to a bare tiktok host', () {
      expect(
        service.extractTikTokUrl('vt.tiktok.com/ZS8abcde/'),
        'https://vt.tiktok.com/ZS8abcde/',
      );
    });

    test('returns null for empty or unrelated text', () {
      expect(service.extractTikTokUrl(''), isNull);
      expect(service.extractTikTokUrl('https://youtube.com/watch?v=1'), isNull);
    });
  });

  group('isValidTikTokUrl', () {
    test('accepts video and short links', () {
      expect(
        service.isValidTikTokUrl(
          'https://www.tiktok.com/@user/video/1234567890123456789',
        ),
        isTrue,
      );
      expect(service.isValidTikTokUrl('https://vm.tiktok.com/ZMabc123/'), isTrue);
    });

    test('rejects non-TikTok URLs', () {
      expect(service.isValidTikTokUrl('https://example.com/video/1'), isFalse);
      expect(service.isValidTikTokUrl('not a link'), isFalse);
    });
  });

  group('describeError', () {
    test('maps import and socket-style errors to friendly copy', () {
      expect(
        service.describeError(
          const TiktokImportException('Paste a video URL and try again.'),
        ),
        'Paste a video URL and try again.',
      );
    });
  });
}
