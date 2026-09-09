import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../editor/editor_models.dart';
import '../editor/ffmpeg_sticker_service.dart';
import '../editor/image_sticker_service.dart';
import '../l10n/l10n.dart';
import '../photos/photo_import_controller.dart';
import '../storage/storage_utility.dart';

/// Pads a downloaded comment image on transparency and encodes a static WebP
/// that satisfies WhatsApp's 512×512 sticker requirements.
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
    try {
      final decoded = _imageService.decodePhoto(await source.readAsBytes());
      if (decoded == null) {
        throw StickerExportException(
          serviceLocalizations.commentStickerOpenFailed,
        );
      }

      final canvas = _imageService.fitToStickerCanvas(decoded);
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

      canvasPng = File(
        '${directory.path}${Platform.pathSeparator}comment_canvas_$stamp.png',
      );
      await canvasPng.writeAsBytes(img.encodePng(canvas), flush: true);
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
      if (canvasPng?.existsSync() == true) canvasPng!.deleteSync();
    }
  }
}

final commentStickerFormatterProvider = Provider<CommentStickerFormatter>((
  ref,
) {
  return CommentStickerFormatter(ref.watch(imageStickerServiceProvider));
});
