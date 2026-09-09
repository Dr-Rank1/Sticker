import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';

/// Tracks successful WhatsApp exports and shows the Play in-app review sheet
/// once, after the third pack is added.
class ReviewService {
  ReviewService({
    this.preferences,
    Future<SharedPreferences> Function()? loadPreferences,
    Future<bool> Function()? isReviewAvailable,
    Future<void> Function()? requestReview,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance,
       _isReviewAvailable = isReviewAvailable ?? _playReviewAvailable,
       _requestReview = requestReview ?? _playRequestReview;

  static Future<bool> _playReviewAvailable() {
    return InAppReview.instance.isAvailable();
  }

  static Future<void> _playRequestReview() {
    return InAppReview.instance.requestReview();
  }

  static const exportCountKey = 'whatsapp_successful_export_count';
  static const exportedPackIdsKey = 'whatsapp_exported_pack_ids';
  static const reviewPromptedKey = 'play_in_app_review_prompted';
  static const promptAfterSuccessfulExports = 3;

  SharedPreferences? preferences;
  final Future<SharedPreferences> Function() _loadPreferences;
  final Future<bool> Function() _isReviewAvailable;
  final Future<void> Function() _requestReview;

  Future<SharedPreferences> _prefs() async {
    return preferences ??= await _loadPreferences();
  }

  Future<int> successfulExportCount() async {
    final prefs = await _prefs();
    return prefs.getInt(exportCountKey) ?? 0;
  }

  Future<bool> hasPromptedReview() async {
    final prefs = await _prefs();
    return prefs.getBool(reviewPromptedKey) ?? false;
  }

  /// Records a pack that WhatsApp accepted. On the third distinct pack, requests
  /// the native Google Play review sheet exactly once.
  Future<bool> recordSuccessfulWhatsAppExport({required String packId}) async {
    final prefs = await _prefs();
    final ids = List<String>.from(
      prefs.getStringList(exportedPackIdsKey) ?? const <String>[],
    );
    if (packId.isNotEmpty && !ids.contains(packId)) {
      ids.add(packId);
      await prefs.setStringList(exportedPackIdsKey, ids);
    }
    await prefs.setInt(exportCountKey, ids.length);

    if (prefs.getBool(reviewPromptedKey) ?? false) {
      return false;
    }
    if (ids.length < promptAfterSuccessfulExports) {
      return false;
    }

    await prefs.setBool(reviewPromptedKey, true);
    try {
      if (await _isReviewAvailable()) {
        await _requestReview();
        return true;
      }
    } catch (error, stack) {
      appLogger.w(
        'Play in-app review request failed',
        error: error,
        stackTrace: stack,
      );
    }
    return false;
  }
}

final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService();
});
