import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../editor/ffmpeg_sticker_service.dart';
import '../editor/image_sticker_service.dart';

enum PhotoImportPhase { idle, picking, processing, completed, error }

class PhotoImportState {
  const PhotoImportState({
    this.phase = PhotoImportPhase.idle,
    this.removeBackground = true,
    this.errorMessage,
    this.preparedPath,
    this.backgroundRemoved = false,
  });

  final PhotoImportPhase phase;
  final bool removeBackground;
  final String? errorMessage;
  final String? preparedPath;
  final bool backgroundRemoved;

  bool get isBusy =>
      phase == PhotoImportPhase.picking || phase == PhotoImportPhase.processing;

  PhotoImportState copyWith({
    PhotoImportPhase? phase,
    bool? removeBackground,
    String? errorMessage,
    String? preparedPath,
    bool? backgroundRemoved,
    bool clearError = false,
  }) {
    return PhotoImportState(
      phase: phase ?? this.phase,
      removeBackground: removeBackground ?? this.removeBackground,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      preparedPath: preparedPath ?? this.preparedPath,
      backgroundRemoved: backgroundRemoved ?? this.backgroundRemoved,
    );
  }
}

typedef PhotoPickFn = Future<XFile?> Function({
  required ImageSource source,
  double? maxWidth,
  int? imageQuality,
});

final imageStickerServiceProvider = Provider<ImageStickerService>((ref) {
  return ImageStickerService();
});

final photoPickerProvider = Provider<PhotoPickFn>((ref) {
  return ({
    required ImageSource source,
    double? maxWidth,
    int? imageQuality,
  }) {
    return ImagePicker().pickImage(
      source: source,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
  };
});

final photoImportProvider =
    NotifierProvider<PhotoImportController, PhotoImportState>(
  PhotoImportController.new,
);

class PhotoImportController extends Notifier<PhotoImportState> {
  @override
  PhotoImportState build() => const PhotoImportState();

  ImageStickerService get _service => ref.read(imageStickerServiceProvider);

  void reset() => state = PhotoImportState(removeBackground: state.removeBackground);

  void setRemoveBackground(bool value) {
    if (state.isBusy) return;
    state = state.copyWith(removeBackground: value);
  }

  Future<void> importFromGallery() => import(ImageSource.gallery);

  Future<void> importFromCamera() => import(ImageSource.camera);

  Future<void> import(ImageSource source) async {
    if (state.isBusy) return;

    state = state.copyWith(
      phase: PhotoImportPhase.picking,
      clearError: true,
    );

    try {
      final picker = ref.read(photoPickerProvider);
      final picked = await picker(
        source: source,
        maxWidth: 2048,
        imageQuality: 95,
      );

      if (!ref.mounted) return;
      if (picked == null) {
        state = state.copyWith(phase: PhotoImportPhase.idle);
        return;
      }

      state = state.copyWith(phase: PhotoImportPhase.processing);

      final result = await _service.prepareForEditor(
        File(picked.path),
        removeBackground: state.removeBackground,
      );

      if (!ref.mounted) return;
      state = PhotoImportState(
        phase: PhotoImportPhase.completed,
        removeBackground: state.removeBackground,
        preparedPath: result.file.path,
        backgroundRemoved: result.backgroundRemoved,
      );
    } catch (error) {
      if (!ref.mounted) return;
      final message = error is StickerExportException
          ? error.message
          : 'Couldn’t prepare that photo. Please try another one.';
      state = state.copyWith(
        phase: PhotoImportPhase.error,
        errorMessage: message,
      );
    }
  }
}
