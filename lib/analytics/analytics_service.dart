import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

enum ImportSourceCategory {
  tiktok('tiktok_source'),
  localGallery('local_gallery_source'),
  photoGallery('photo_gallery_source'),
  camera('camera_source'),
  giphy('giphy_source'),
  commentSticker('comment_sticker_source'),
  memeTemplate('meme_template_source');

  const ImportSourceCategory(this.value);
  final String value;
}

enum EncodeMediaCategory {
  animated('animated'),
  staticImage('static');

  const EncodeMediaCategory(this.value);
  final String value;
}

enum PackValidationCategory {
  tooFewStickers('too_few_stickers'),
  tooManyStickers('too_many_stickers'),
  mixedAnimationTypes('mixed_animation_types'),
  missingMedia('missing_media'),
  invalidMetadata('invalid_metadata'),
  unknown('unknown');

  const PackValidationCategory(this.value);
  final String value;
}

enum WhatsAppExportOutcome {
  success('success'),
  notInstalled('not_installed'),
  cancelled('cancelled'),
  validationFailed('validation_failed'),
  platformUnavailable('platform_unavailable'),
  failed('failed');

  const WhatsAppExportOutcome(this.value);
  final String value;
}

abstract class AnalyticsService {
  Future<void> importStarted({
    required ImportSourceCategory source,
    required EncodeMediaCategory media,
  });

  Future<void> encodeAttempt({
    required EncodeMediaCategory media,
    required int attempt,
    required int quality,
  });

  Future<void> packValidationFailed({
    required PackValidationCategory category,
    required int stickerCount,
  });

  Future<void> exportWhatsAppResult({
    required WhatsAppExportOutcome outcome,
    required int stickerCount,
    required bool animated,
  });
}

class NoOpAnalyticsService implements AnalyticsService {
  const NoOpAnalyticsService();

  @override
  Future<void> importStarted({
    required ImportSourceCategory source,
    required EncodeMediaCategory media,
  }) async {}

  @override
  Future<void> encodeAttempt({
    required EncodeMediaCategory media,
    required int attempt,
    required int quality,
  }) async {}

  @override
  Future<void> packValidationFailed({
    required PackValidationCategory category,
    required int stickerCount,
  }) async {}

  @override
  Future<void> exportWhatsAppResult({
    required WhatsAppExportOutcome outcome,
    required int stickerCount,
    required bool animated,
  }) async {}
}

class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  bool get _ready => Firebase.apps.isNotEmpty;

  @override
  Future<void> importStarted({
    required ImportSourceCategory source,
    required EncodeMediaCategory media,
  }) {
    return _log('import_started', {
      'source_category': source.value,
      'media_category': media.value,
    });
  }

  @override
  Future<void> encodeAttempt({
    required EncodeMediaCategory media,
    required int attempt,
    required int quality,
  }) {
    return _log('encode_attempt', {
      'media_category': media.value,
      'attempt': attempt.clamp(1, 20),
      'quality_bucket': _qualityBucket(quality),
    });
  }

  @override
  Future<void> packValidationFailed({
    required PackValidationCategory category,
    required int stickerCount,
  }) {
    return _log('pack_validation_failed', {
      'failure_category': category.value,
      'sticker_count_bucket': _stickerCountBucket(stickerCount),
    });
  }

  @override
  Future<void> exportWhatsAppResult({
    required WhatsAppExportOutcome outcome,
    required int stickerCount,
    required bool animated,
  }) {
    return _log('export_whatsapp_result', {
      'outcome': outcome.value,
      'sticker_count_bucket': _stickerCountBucket(stickerCount),
      'animated': animated ? 1 : 0,
    });
  }

  Future<void> _log(String name, Map<String, Object> parameters) async {
    if (!_ready) return;
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (_) {
      // Health telemetry must never interrupt an application workflow.
    }
  }
}

class RecordingAnalyticsService implements AnalyticsService {
  final events = <AnalyticsEvent>[];

  @override
  Future<void> importStarted({
    required ImportSourceCategory source,
    required EncodeMediaCategory media,
  }) async {
    events.add(
      AnalyticsEvent('import_started', {
        'source_category': source.value,
        'media_category': media.value,
      }),
    );
  }

  @override
  Future<void> encodeAttempt({
    required EncodeMediaCategory media,
    required int attempt,
    required int quality,
  }) async {
    events.add(
      AnalyticsEvent('encode_attempt', {
        'media_category': media.value,
        'attempt': attempt.clamp(1, 20),
        'quality_bucket': _qualityBucket(quality),
      }),
    );
  }

  @override
  Future<void> packValidationFailed({
    required PackValidationCategory category,
    required int stickerCount,
  }) async {
    events.add(
      AnalyticsEvent('pack_validation_failed', {
        'failure_category': category.value,
        'sticker_count_bucket': _stickerCountBucket(stickerCount),
      }),
    );
  }

  @override
  Future<void> exportWhatsAppResult({
    required WhatsAppExportOutcome outcome,
    required int stickerCount,
    required bool animated,
  }) async {
    events.add(
      AnalyticsEvent('export_whatsapp_result', {
        'outcome': outcome.value,
        'sticker_count_bucket': _stickerCountBucket(stickerCount),
        'animated': animated ? 1 : 0,
      }),
    );
  }
}

class AnalyticsEvent {
  const AnalyticsEvent(this.name, this.parameters);

  final String name;
  final Map<String, Object> parameters;
}

String _qualityBucket(int quality) {
  if (quality >= 70) return 'high';
  if (quality >= 40) return 'medium';
  return 'low';
}

String _stickerCountBucket(int count) {
  if (count < 3) return 'below_minimum';
  if (count <= 10) return '3_to_10';
  if (count <= 20) return '11_to_20';
  if (count <= 30) return '21_to_30';
  return 'above_maximum';
}

AnalyticsService analyticsService = const NoOpAnalyticsService();
