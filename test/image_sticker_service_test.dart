import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stikk/editor/editor_models.dart';
import 'package:stikk/editor/image_sticker_service.dart';

void main() {
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

  group('ImageStickerService', () {
    test('applySubjectMask punches out low-confidence pixels', () {
      final service = ImageStickerService(segmenter: const _NullSegmenter());
      final source = solid(width: 8, height: 8, r: 255, g: 0, b: 0);
      final mask = SubjectMask(
        width: 8,
        height: 8,
        confidences: [
          for (var y = 0; y < 8; y++)
            for (var x = 0; x < 8; x++) x < 4 ? 0.0 : 1.0,
        ],
      );

      final cut = service.applySubjectMask(source, mask);
      expect(cut.getPixel(1, 4).a, 0);
      expect(cut.getPixel(6, 4).a, greaterThan(200));
      expect(cut.getPixel(6, 4).r, 255);
    });

    test('autoCropToSubject tightens to the opaque subject', () {
      final service = ImageStickerService(segmenter: const _NullSegmenter());
      final source = solid(width: 40, height: 40, r: 0, g: 0, b: 0, a: 0);
      for (var y = 10; y < 18; y++) {
        for (var x = 12; x < 20; x++) {
          source.setPixelRgba(x, y, 0, 180, 90, 255);
        }
      }

      final cropped = service.autoCropToSubject(source, paddingFraction: 0);
      expect(cropped, isNotNull);
      expect(cropped!.width, 8);
      expect(cropped.height, 8);
    });

    test('fitToStickerCanvas is 512×512 with the subject contained', () {
      final service = ImageStickerService(segmenter: const _NullSegmenter());
      final source = solid(width: 80, height: 40, r: 10, g: 20, b: 30);
      final canvas = service.fitToStickerCanvas(source);

      expect(canvas.width, WhatsAppStickerSpec.size);
      expect(canvas.height, WhatsAppStickerSpec.size);
      expect(canvas.getPixel(0, 0).a, 0);
      expect(canvas.getPixel(256, 256).a, greaterThan(0));
    });

    test('coverSquare crops the center', () {
      final service = ImageStickerService(segmenter: const _NullSegmenter());
      final source = solid(width: 30, height: 10, r: 1, g: 2, b: 3);
      final square = service.coverSquare(source);
      expect(square.width, 10);
      expect(square.height, 10);
    });

    test('static FFmpeg args are a single 512 WebP frame', () {
      final service = ImageStickerService(segmenter: const _NullSegmenter());
      final args = service.buildStaticArguments(
        inputPath: 'in.png',
        outputPath: 'out.webp',
        quality: 65,
      );

      expect(args, contains('libwebp'));
      expect(args[args.indexOf('-s') + 1], '512x512');
      expect(args[args.indexOf('-vframes') + 1], '1');
      expect(args, isNot(contains('-loop')));
      expect(args[args.indexOf('-quality') + 1], '65');
    });

    test('prepareForEditor writes a 512 PNG without a person mask', () async {
      final temp = await Directory.systemTemp.createTemp('stikk_photo');
      addTearDown(() => temp.deleteSync(recursive: true));
      final sourceFile = File('${temp.path}${Platform.pathSeparator}in.png')
        ..writeAsBytesSync(
          img.encodePng(solid(width: 120, height: 80, r: 20, g: 40, b: 80)),
        );

      final service = ImageStickerService(
        segmenter: const _NullSegmenter(),
        tempDirectory: () async => temp,
      );
      final prepared = await service.prepareForEditor(
        sourceFile,
        removeBackground: true,
      );

      expect(prepared.backgroundRemoved, isFalse);
      expect(prepared.autoCropped, isFalse);
      final decoded = img.decodeImage(prepared.file.readAsBytesSync());
      expect(decoded!.width, 512);
      expect(decoded.height, 512);
    });

    test('prepareForEditor cuts out and auto-crops a masked subject', () async {
      final temp = await Directory.systemTemp.createTemp('stikk_cut');
      addTearDown(() => temp.deleteSync(recursive: true));
      final source = solid(width: 32, height: 32, r: 200, g: 40, b: 40);
      final sourceFile = File('${temp.path}${Platform.pathSeparator}in.png')
        ..writeAsBytesSync(img.encodePng(source));

      final mask = SubjectMask(
        width: 32,
        height: 32,
        confidences: [
          for (var y = 0; y < 32; y++)
            for (var x = 0; x < 32; x++)
              (x >= 8 && x < 20 && y >= 8 && y < 20) ? 1.0 : 0.0,
        ],
      );

      final service = ImageStickerService(
        segmenter: _FixedSegmenter(mask),
        tempDirectory: () async => temp,
      );
      final prepared = await service.prepareForEditor(sourceFile);

      expect(prepared.backgroundRemoved, isTrue);
      expect(prepared.autoCropped, isTrue);
      final decoded = img.decodeImage(prepared.file.readAsBytesSync())!;
      expect(decoded.width, 512);
      expect(decoded.getPixel(0, 0).a, 0);
    });

    test('retries until the static sticker is under 100KB', () async {
      final temp = await Directory.systemTemp.createTemp('stikk_static');
      addTearDown(() => temp.deleteSync(recursive: true));
      final input = File('${temp.path}${Platform.pathSeparator}in.png')
        ..writeAsBytesSync(
          img.encodePng(solid(width: 512, height: 512, r: 8, g: 8, b: 8)),
        );

      var attempts = 0;
      final service = ImageStickerService(
        segmenter: const _NullSegmenter(),
        tempDirectory: () async => temp,
        runCommand: (args, onProgress) async {
          attempts += 1;
          final output = File(args.last);
          final bytes = attempts < 3
              ? List<int>.filled(160 * 1024, 1)
              : List<int>.filled(40 * 1024, 1);
          await output.writeAsBytes(bytes);
          onProgress(1);
          return 0;
        },
      );

      final result = await service.exportStaticSticker(imagePath: input.path);
      expect(
        result.bytes,
        lessThanOrEqualTo(WhatsAppStickerSpec.maxStaticBytes),
      );
      expect(attempts, 3);
      final generated = temp
          .listSync()
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.webp') ||
                file.path.contains('stikk_static_'),
          )
          .toList();
      expect(generated, hasLength(1));
      expect(generated.single.path, result.file.path);
    });
  });
}

class _NullSegmenter implements SubjectSegmenter {
  const _NullSegmenter();

  @override
  Future<SubjectMask?> segment(File image) async => null;
}

class _FixedSegmenter implements SubjectSegmenter {
  const _FixedSegmenter(this.mask);

  final SubjectMask mask;

  @override
  Future<SubjectMask?> segment(File image) async => mask;
}
