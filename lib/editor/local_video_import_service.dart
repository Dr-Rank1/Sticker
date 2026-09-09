import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../storage/storage_utility.dart';

typedef LocalVideoPicker = Future<XFile?> Function();
typedef LocalVideoMetadataReader = Future<LocalVideoMetadata> Function(
  String path,
);

class LocalVideoMetadata {
  const LocalVideoMetadata({
    required this.duration,
    required this.codec,
    required this.width,
    required this.height,
  });

  final Duration duration;
  final String codec;
  final int width;
  final int height;
}

class LocalVideoImportResult {
  const LocalVideoImportResult({required this.file, required this.metadata});

  final File file;
  final LocalVideoMetadata metadata;
}

class LocalVideoImportException implements Exception {
  const LocalVideoImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalVideoImportService {
  LocalVideoImportService(
    this._picker,
    this._metadataReader, {
    Future<Directory> Function()? temporaryDirectory,
  }) : _temporaryDirectory =
           temporaryDirectory ?? (() => getStickrTemporaryDirectory());

  static const maxFileBytes = 250 * 1024 * 1024;
  static const maxDuration = Duration(minutes: 10);
  static const minDimension = 16;
  static const maxDimension = 4096;
  static const supportedCodecs = {
    'h264',
    'hevc',
    'mpeg4',
    'mpeg2video',
    'vp8',
    'vp9',
    'av1',
    'mjpeg',
    'prores',
  };

  final LocalVideoPicker _picker;
  final LocalVideoMetadataReader _metadataReader;
  final Future<Directory> Function() _temporaryDirectory;

  Future<LocalVideoImportResult?> pickAndPrepare() async {
    final picked = await _picker();
    if (picked == null) return null;

    File? copied;
    try {
      final selectedBytes = await picked.length();
      if (selectedBytes <= 0) {
        throw const LocalVideoImportException(
          'The selected video is empty or unavailable.',
        );
      }
      if (selectedBytes > maxFileBytes) {
        throw const LocalVideoImportException(
          'Choose a video smaller than 250 MB.',
        );
      }

      final directory = await _temporaryDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      copied = File(
        '${directory.path}${Platform.pathSeparator}'
        'local_video_${DateTime.now().microsecondsSinceEpoch}'
        '${_safeExtension(picked.name)}',
      );
      await _copyWithLimit(picked, copied);
      final metadata = await _metadataReader(copied.path);
      validate(metadata, fileBytes: await copied.length());
      return LocalVideoImportResult(file: copied, metadata: metadata);
    } on LocalVideoImportException {
      await deleteTemporary(copied);
      rethrow;
    } catch (_) {
      await deleteTemporary(copied);
      throw const LocalVideoImportException(
        'Couldn’t inspect that video. Choose a different file.',
      );
    }
  }

  void validate(LocalVideoMetadata metadata, {required int fileBytes}) {
    if (fileBytes <= 0) {
      throw const LocalVideoImportException(
        'The selected video is empty or unavailable.',
      );
    }
    if (fileBytes > maxFileBytes) {
      throw const LocalVideoImportException(
        'Choose a video smaller than 250 MB.',
      );
    }
    if (metadata.duration <= Duration.zero) {
      throw const LocalVideoImportException(
        'The selected video has no readable duration.',
      );
    }
    if (metadata.duration > maxDuration) {
      throw const LocalVideoImportException(
        'Choose a video that is 10 minutes or shorter.',
      );
    }
    final codec = metadata.codec.trim().toLowerCase();
    if (!supportedCodecs.contains(codec)) {
      throw LocalVideoImportException(
        'The ${codec.isEmpty ? 'unknown' : codec.toUpperCase()} video codec is not supported.',
      );
    }
    if (metadata.width < minDimension || metadata.height < minDimension) {
      throw const LocalVideoImportException(
        'The selected video has invalid dimensions.',
      );
    }
    if (metadata.width > maxDimension || metadata.height > maxDimension) {
      throw const LocalVideoImportException(
        'Choose a video no larger than 4096 by 4096 pixels.',
      );
    }
  }

  Future<void> deleteTemporary(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // The editor may already have removed its temporary source file.
    }
  }

  Future<void> _copyWithLimit(XFile source, File destination) async {
    final sink = destination.openWrite();
    var copiedBytes = 0;
    try {
      await for (final chunk in source.openRead()) {
        copiedBytes += chunk.length;
        if (copiedBytes > maxFileBytes) {
          throw const LocalVideoImportException(
            'Choose a video smaller than 250 MB.',
          );
        }
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (copiedBytes == 0) {
      throw const LocalVideoImportException(
        'The selected video is empty or unavailable.',
      );
    }
  }

  static String _safeExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '.video';
    final extension = name.substring(dot).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension)
        ? extension
        : '.video';
  }
}

Future<LocalVideoMetadata> readLocalVideoMetadata(String path) async {
  final session = await FFprobeKit.getMediaInformation(path, 15000);
  final returnCode = await session.getReturnCode();
  final information = session.getMediaInformation();
  if (!ReturnCode.isSuccess(returnCode) || information == null) {
    throw const LocalVideoImportException(
      'The selected file is not a readable video.',
    );
  }

  final videoStreams = information
      .getStreams()
      .where((stream) => stream.getType() == 'video')
      .toList();
  if (videoStreams.isEmpty) {
    throw const LocalVideoImportException(
      'The selected file does not contain a video track.',
    );
  }
  final video = videoStreams.first;
  final durationSeconds =
      double.tryParse(information.getDuration() ?? '') ??
      double.tryParse(video.getStringProperty('duration') ?? '');
  if (durationSeconds == null || !durationSeconds.isFinite) {
    throw const LocalVideoImportException(
      'The selected video has no readable duration.',
    );
  }

  return LocalVideoMetadata(
    duration: Duration(
      microseconds: (durationSeconds * Duration.microsecondsPerSecond).round(),
    ),
    codec: video.getCodec() ?? '',
    width: video.getWidth() ?? 0,
    height: video.getHeight() ?? 0,
  );
}

final localVideoPickerProvider = Provider<LocalVideoPicker>((ref) {
  return () => ImagePicker().pickVideo(source: ImageSource.gallery);
});

final localVideoMetadataReaderProvider = Provider<LocalVideoMetadataReader>((
  ref,
) {
  return readLocalVideoMetadata;
});

final localVideoImportServiceProvider = Provider<LocalVideoImportService>((
  ref,
) {
  return LocalVideoImportService(
    ref.watch(localVideoPickerProvider),
    ref.watch(localVideoMetadataReaderProvider),
  );
});
