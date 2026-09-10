import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../editor/editor_models.dart';
import '../editor/ffmpeg_sticker_service.dart';
import '../editor/image_sticker_service.dart';
import '../l10n/l10n.dart';
import '../photos/photo_import_controller.dart';
import '../storage/storage_utility.dart';

/// Cuts out opaque comment photos, pads transparent sticker assets, and encodes
/// a static WebP that satisfies WhatsApp's 512×512 sticker requirements.
class CommentStickerFormatter {
  CommentStickerFormatter(
    this._imageService, {
    Future<Directory> Function()? temporaryDirectory,
  }) : _temporaryDirectory =
           temporaryDirectory ?? (() => getStickrTemporaryDirectory());

  final ImageStickerService _imageService;
  final Future<Directory> Function() _temporaryDirectory;

  Future<File> makeWhatsAppReady(File source) async {
    File? canvasPng;
    var deleteCanvas = false;
    try {
      final decoded = _imageService.decodePhoto(await source.readAsBytes());
      if (decoded == null) {
        throw StickerExportException(
          serviceLocalizations.commentStickerOpenFailed,
        );
      }

      final img.Image canvas;
      if (_hasUsefulTransparency(decoded)) {
        // Sticker-pack assets already have alpha — pad onto a clear canvas.
        canvas = _imageService.fitToStickerCanvas(decoded);
      } else {
        // Photo comments are opaque JPEGs — cut the subject out so the pack
        // gets stickers instead of rectangular screenshots.
        final prepared = await _imageService.prepareForEditor(
          source,
          removeBackground: true,
        );
        if (prepared.backgroundRemoved) {
          canvasPng = prepared.file;
          deleteCanvas = true;
          final preparedImage = _imageService.decodePhoto(
            await canvasPng.readAsBytes(),
          );
          if (preparedImage == null) {
            throw StickerExportException(
              serviceLocalizations.commentStickerOpenFailed,
            );
          }
          canvas = preparedImage;
        } else {
          // No subject mask available — still pad onto transparency instead of
          // shipping a full-bleed opaque rectangle.
          if (prepared.file.existsSync()) {
            try {
              prepared.file.deleteSync();
            } on FileSystemException {
              // Best-effort cleanup.
            }
          }
          canvas = _imageService.fitToStickerCanvas(decoded);
        }
      }

      if (canvas.width != WhatsAppStickerSpec.size ||
          canvas.height != WhatsAppStickerSpec.size) {
        throw StickerExportException(
          serviceLocalizations.stickerCanvasSizeFailed,
        );
      }

      final directory = await _temporaryDirectory();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final output = File(
        '${directory.path}${Platform.pathSeparator}whatsapp_ready_$stamp.webp',
      );

      final lossless = img.encodeWebP(canvas);
      if (lossless.length <= WhatsAppStickerSpec.maxStaticBytes) {
        await output.writeAsBytes(lossless, flush: true);
        return output;
      }

      canvasPng ??= File(
        '${directory.path}${Platform.pathSeparator}comment_canvas_$stamp.png',
      );
      if (!deleteCanvas) {
        await canvasPng.writeAsBytes(img.encodePng(canvas), flush: true);
        deleteCanvas = true;
      }
      final encoded = await _imageService.exportStaticSticker(
        imagePath: canvasPng.path,
      );
      if (encoded.bytes > WhatsAppStickerSpec.maxStaticBytes) {
        throw StickerExportException(
          serviceLocalizations.commentStickerTooLarge,
        );
      }
      if (output.existsSync()) output.deleteSync();
      await encoded.file.rename(output.path);
      return output;
    } finally {
      if (deleteCanvas && canvasPng?.existsSync() == true) {
        try {
          canvasPng!.deleteSync();
        } on FileSystemException {
          // Temp cleanup is best-effort.
        }
      }
    }
  }

  /// Samples corners and edges — sticker-pack assets keep clear alpha there;
  /// uploaded photo comments are fully opaque.
  static bool _hasUsefulTransparency(img.Image image) {
    if (image.numChannels < 4) return false;
    final points = <(int, int)>[
      (0, 0),
      (image.width - 1, 0),
      (0, image.height - 1),
      (image.width - 1, image.height - 1),
      (image.width ~/ 2, 0),
      (0, image.height ~/ 2),
    ];
    var transparent = 0;
    for (final (x, y) in points) {
      if (image.getPixel(x, y).a < 250) transparent++;
    }
    return transparent >= 2;
  }
}

final commentStickerFormatterProvider = Provider<CommentStickerFormatter>((
  ref,
) {
  return CommentStickerFormatter(ref.watch(imageStickerServiceProvider));
});
