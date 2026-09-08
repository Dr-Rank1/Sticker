import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stikk/store/review_service.dart';

void main() {
  late ReviewService service;
  var reviewRequested = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    reviewRequested = 0;
    service = ReviewService(
      preferences: await SharedPreferences.getInstance(),
      isReviewAvailable: () async => true,
      requestReview: () async {
        reviewRequested += 1;
      },
    );
  });

  test('production path uses InAppReview.instance.requestReview', () {
    final reviewSource = File('lib/store/review_service.dart')
        .readAsStringSync();
    expect(reviewSource, contains('InAppReview.instance.requestReview()'));
    final detailSource = File('lib/packs/pack_detail_screen.dart')
        .readAsStringSync();
    expect(
      detailSource,
      contains('recordSuccessfulWhatsAppExport(packId: saved.id)'),
    );
  });

  test(
    'does not request a review before the third distinct pack export',
    () async {
      expect(
        await service.recordSuccessfulWhatsAppExport(packId: 'pack-1'),
        isFalse,
      );
      expect(
        await service.recordSuccessfulWhatsAppExport(packId: 'pack-2'),
        isFalse,
      );
      expect(
        await service.recordSuccessfulWhatsAppExport(packId: 'pack-1'),
        isFalse,
      );

      expect(await service.successfulExportCount(), 2);
      expect(await service.hasPromptedReview(), isFalse);
      expect(reviewRequested, 0);
    },
  );

  test(
    'requests the native review sheet on the third successful pack export',
    () async {
      await service.recordSuccessfulWhatsAppExport(packId: 'pack-1');
      await service.recordSuccessfulWhatsAppExport(packId: 'pack-2');
      final prompted = await service.recordSuccessfulWhatsAppExport(
        packId: 'pack-3',
      );

      expect(prompted, isTrue);
      expect(await service.successfulExportCount(), 3);
      expect(await service.hasPromptedReview(), isTrue);
      expect(reviewRequested, 1);
    },
  );

  test('never requests a review again after the first prompt', () async {
    await service.recordSuccessfulWhatsAppExport(packId: 'pack-1');
    await service.recordSuccessfulWhatsAppExport(packId: 'pack-2');
    await service.recordSuccessfulWhatsAppExport(packId: 'pack-3');
    await service.recordSuccessfulWhatsAppExport(packId: 'pack-4');
    final promptedAgain = await service.recordSuccessfulWhatsAppExport(
      packId: 'pack-5',
    );

    expect(promptedAgain, isFalse);
    expect(await service.successfulExportCount(), 5);
    expect(reviewRequested, 1);
  });

  test(
    'skips the Play sheet when reviews are unavailable but still prompts once',
    () async {
      service = ReviewService(
        preferences: await SharedPreferences.getInstance(),
        isReviewAvailable: () async => false,
        requestReview: () async {
          reviewRequested += 1;
        },
      );

      await service.recordSuccessfulWhatsAppExport(packId: 'pack-1');
      await service.recordSuccessfulWhatsAppExport(packId: 'pack-2');
      expect(
        await service.recordSuccessfulWhatsAppExport(packId: 'pack-3'),
        isFalse,
      );
      expect(
        await service.recordSuccessfulWhatsAppExport(packId: 'pack-4'),
        isFalse,
      );

      expect(await service.hasPromptedReview(), isTrue);
      expect(reviewRequested, 0);
    },
  );
}
