import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/analytics/analytics_service.dart';

void main() {
  test('records the four required structured event names', () async {
    final analytics = RecordingAnalyticsService();

    await analytics.importStarted(
      source: ImportSourceCategory.localGallery,
      media: EncodeMediaCategory.animated,
    );
    await analytics.encodeAttempt(
      media: EncodeMediaCategory.animated,
      attempt: 2,
      quality: 65,
    );
    await analytics.packValidationFailed(
      category: PackValidationCategory.tooFewStickers,
      stickerCount: 2,
    );
    await analytics.exportWhatsAppResult(
      outcome: WhatsAppExportOutcome.success,
      stickerCount: 12,
      animated: true,
    );

    expect(analytics.events.map((event) => event.name), [
      'import_started',
      'encode_attempt',
      'pack_validation_failed',
      'export_whatsapp_result',
    ]);
    expect(analytics.events[0].parameters, {
      'source_category': 'local_gallery_source',
      'media_category': 'animated',
    });
    expect(analytics.events[1].parameters['quality_bucket'], 'medium');
    expect(
      analytics.events[2].parameters['sticker_count_bucket'],
      'below_minimum',
    );
    expect(analytics.events[3].parameters['sticker_count_bucket'], '11_to_20');
  });

  test('telemetry APIs expose categories instead of private strings', () {
    final analyticsSource = File('lib/analytics/analytics_service.dart')
        .readAsStringSync();
    final crashSource = File('lib/crashlytics/crash_reporter.dart')
        .readAsStringSync();
    final apifySource = File('lib/tiktok/apify_service.dart')
        .readAsStringSync();

    expect(analyticsSource, isNot(contains('filePath')));
    expect(analyticsSource, isNot(contains('overlayText')));
    expect(analyticsSource, isNot(contains('rawBytes')));
    expect(crashSource, isNot(contains('void log(String')));
    expect(crashSource, isNot(contains('setCustomKey(String')));
    expect(apifySource, isNot(contains("'apify_post_url'")));
  });
}
