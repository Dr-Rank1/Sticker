import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stikk/editor/background_removal_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renders the ML foreground onto a transparent PNG canvas', () async {
    final temporary = await Directory.systemTemp.createTemp('stikk_bg_remove_');
    addTearDown(() => temporary.deleteSync(recursive: true));
    final source = img.Image(width: 16, height: 12, numChannels: 4);
    for (final pixel in source) {
      pixel.setRgba(220, 40, 40, 255);
    }
    final sourceFile = File('${temporary.path}/source.png')
      ..writeAsBytesSync(img.encodePng(source));
    final mask = SubjectMask(
      width: 16,
      height: 12,
      confidences: [
        for (var y = 0; y < 12; y++)
          for (var x = 0; x < 16; x++) x < 8 ? 0.0 : 1.0,
      ],
    );
    final service = BackgroundRemovalService(
      segmenter: _FixedSegmenter(mask),
      temporaryDirectory: () async => temporary,
    );

    final result = await service.removeBackground(sourceFile);

    expect(result, isNotNull);
    expect(result!.file.path, endsWith('.png'));
    final rendered = img.decodePng(result.file.readAsBytesSync())!;
    expect(rendered.width, 16);
    expect(rendered.height, 12);
    expect(rendered.getPixel(2, 6).a, 0);
    expect(rendered.getPixel(13, 6).a, greaterThan(240));
    expect(rendered.getPixel(13, 6).r, 220);
  });

  test(
    'returns null when ML Kit cannot identify a foreground subject',
    () async {
      final temporary = await Directory.systemTemp.createTemp('stikk_bg_none_');
      addTearDown(() => temporary.deleteSync(recursive: true));
      final sourceFile = File('${temporary.path}/source.png')
        ..writeAsBytesSync(
          img.encodePng(img.Image(width: 8, height: 8, numChannels: 4)),
        );
      final service = BackgroundRemovalService(
        segmenter: const _NullSegmenter(),
        temporaryDirectory: () async => temporary,
      );

      expect(await service.removeBackground(sourceFile), isNull);
    },
  );
}

class _FixedSegmenter implements SubjectSegmenter {
  const _FixedSegmenter(this.mask);

  final SubjectMask mask;

  @override
  Future<SubjectMask?> segment(File image) async => mask;
}

class _NullSegmenter implements SubjectSegmenter {
  const _NullSegmenter();

  @override
  Future<SubjectMask?> segment(File image) async => null;
}
