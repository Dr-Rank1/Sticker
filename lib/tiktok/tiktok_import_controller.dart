import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tiktok_import_service.dart';

enum TiktokImportPhase { idle, resolving, downloading, completed, error }

class TiktokImportState {
  const TiktokImportState({
    this.phase = TiktokImportPhase.idle,
    this.progress,
    this.errorMessage,
    this.savedFilePath,
    this.caption,
  });

  final TiktokImportPhase phase;
  final double? progress;
  final String? errorMessage;
  final String? savedFilePath;
  final String? caption;

  bool get isBusy =>
      phase == TiktokImportPhase.resolving ||
      phase == TiktokImportPhase.downloading;

  TiktokImportState copyWith({
    TiktokImportPhase? phase,
    double? progress,
    String? errorMessage,
    String? savedFilePath,
    String? caption,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return TiktokImportState(
      phase: phase ?? this.phase,
      progress: clearProgress ? null : progress ?? this.progress,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      savedFilePath: savedFilePath ?? this.savedFilePath,
      caption: caption ?? this.caption,
    );
  }
}

final tiktokImportServiceProvider = Provider<TiktokImportService>((ref) {
  return TiktokImportService();
});

final tiktokImportProvider =
    NotifierProvider<TiktokImportController, TiktokImportState>(
  TiktokImportController.new,
);

class TiktokImportController extends Notifier<TiktokImportState> {
  @override
  TiktokImportState build() => const TiktokImportState();

  TiktokImportService get _service => ref.read(tiktokImportServiceProvider);

  void reset() => state = const TiktokImportState();

  Future<void> importFromLink(String rawLink) async {
    if (state.isBusy) return;

    if (!_service.isValidTikTokUrl(rawLink)) {
      state = const TiktokImportState(
        phase: TiktokImportPhase.error,
        errorMessage:
            'That doesn\'t look like a TikTok link. Paste a video URL and try again.',
      );
      return;
    }

    state = const TiktokImportState(
      phase: TiktokImportPhase.resolving,
      progress: null,
    );

    try {
      final result = await _service.import(
        rawLink: rawLink,
        onProgress: (update) {
          if (!ref.mounted) return;
          switch (update.stage) {
            case TiktokImportStage.resolving:
              state = const TiktokImportState(
                phase: TiktokImportPhase.resolving,
              );
            case TiktokImportStage.downloading:
              state = TiktokImportState(
                phase: TiktokImportPhase.downloading,
                progress: update.fraction,
              );
          }
        },
      );

      if (!ref.mounted) return;
      state = TiktokImportState(
        phase: TiktokImportPhase.completed,
        progress: 1,
        savedFilePath: result.file.path,
        caption: result.caption,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = TiktokImportState(
        phase: TiktokImportPhase.error,
        errorMessage: _service.describeError(error),
      );
    }
  }
}
