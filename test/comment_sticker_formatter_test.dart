import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stickr/editor/background_removal_service.dart';
import 'package:stickr/editor/editor_models.dart';
import 'package:stickr/editor/image_sticker_service.dart';
import 'package:stickr/tiktok/comment_sticker_formatter.dart';

class _NoSubjectSegmenter implements SubjectSegmenter {
  @override
  Future<SubjectMask?> segment(File image) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  img.Image solid({
    required int width,
    required int height,
    required int r,
    required int g,
    required int b,
    int a = 255,
  }) {
    final image = img.Image(width: width, height: height, numChannels: 4);
    for (final pixel in image) {
      pixel.setRgba(r, g, b, a);
    }
    return image;
  }

  test(
    'pads a rectangular image to a transparent 512 WebP under 100KB',
    () async {
      final temp = await Directory.systemTemp.createTemp('comment_format');
      addTearDown(() => temp.deleteSync(recursive: true));

      final source = File('${temp.path}${Platform.pathSeparator}source.png')
        ..writeAsBytesSync(
          img.encodePng(solid(width: 80, height: 40, r: 20, g: 180, b: 90)),
        );

      final formatter = CommentStickerFormatter(
        ImageStickerService(
          segmenter: _NoSubjectSegmenter(),
          tempDirectory: () async => temp,
        ),
        temporaryDirectory: () async => temp,
      );

      final ready = await formatter.makeWhatsAppReady(source);
      expect(ready.path.toLowerCase(), endsWith('.webp'));
      expect(
        ready.lengthSync(),
        lessThanOrEqualTo(WhatsAppStickerSpec.maxStaticBytes),
      );

      final decoded = img.decodeImage(await ready.readAsBytes());
      expect(decoded, isNotNull);
      expect(decoded!.width, WhatsAppStickerSpec.size);
      expect(decoded.height, WhatsAppStickerSpec.size);
      expect(decoded.getPixel(0, 0).a, 0);
      expect(decoded.getPixel(256, 256).a, greaterThan(0));
    },
  );

  test('keeps existing transparency without forcing a photo cut-out', () async {
    final temp = await Directory.systemTemp.createTemp('comment_format_alpha');
    addTearDown(() => temp.deleteSync(recursive: true));

    final sticker = solid(width: 100, height: 100, r: 255, g: 80, b: 40);
    // Clear corners so the formatter treats this as a sticker asset.
    for (final (x, y) in [(0, 0), (99, 0), (0, 99), (99, 99)]) {
      sticker.getPixel(x, y).setRgba(0, 0, 0, 0);
    }

    final source = File('${temp.path}${Platform.pathSeparator}sticker.png')
      ..writeAsBytesSync(img.encodePng(sticker));

    final formatter = CommentStickerFormatter(
      ImageStickerService(
        segmenter: _NoSubjectSegmenter(),
        tempDirectory: () async => temp,
      ),
      temporaryDirectory: () async => temp,
    );

    final ready = await formatter.makeWhatsAppReady(source);
    final decoded = img.decodeImage(await ready.readAsBytes());
    expect(decoded, isNotNull);
    expect(decoded!.getPixel(0, 0).a, 0);
    expect(decoded.getPixel(256, 256).a, greaterThan(0));
  });
}
