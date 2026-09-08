import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stikk/editor/editor_models.dart';
import 'package:stikk/editor/ffmpeg_sticker_service.dart';
import 'package:stikk/editor/ffmpeg_webp_builder.dart';

void main() {
  group('FFmpegWebpBuilder command generation', () {
    final builder = FFmpegWebpBuilder();

    test('trims to 3s, forces 15fps, pads 1:1, and overlays PNG', () {
      final args = builder.buildCommand(
        sourceMp4: 'clip.mp4',
        outputPath: 'sticker.webp',
        overlayPng: 'layers.png',
      );
      final filter = args[args.indexOf('-filter_complex') + 1];

      expect(args[args.indexOf('-ss') + 1], '00:00:00');
      expect(args[args.indexOf('-t') + 1], '00:00:03');
      expect(args, contains('clip.mp4'));
      expect(args, contains('layers.png'));
      expect(filter, contains('fps=15'));
      expect(
        filter,
        contains(
          'scale=512:512:force_original_aspect_ratio=decrease,pad=512:512:(ow-iw)/2:(oh-ih)/2:color=white@0.0',
        ),
      );
      expect(filter, contains('overlay=0:0'));
      expect(args[args.indexOf('-vcodec') + 1], 'libwebp');
      expect(args[args.indexOf('-lossless') + 1], '0');
      expect(args[args.indexOf('-compression_level') + 1], '4');
      expect(args[args.indexOf('-q:v') + 1], '50');
      expect(args[args.indexOf('-loop') + 1], '0');
      expect(args, contains('-an'));
      expect(args.last, 'sticker.webp');
    });

    test('omits overlay input when the PNG is absent', () {
      final graph = builder.buildFilterGraph(hasOverlay: false);
      expect(graph, isNot(contains('overlay=')));
      expect(graph, contains('fps=15'));
      final args = builder.buildCommand(
        sourceMp4: 'in.mp4',
        outputPath: 'out.webp',
      );
      expect(args.where((part) => part == '-i'), hasLength(1));
    });
  });

  group('FFmpegWebpBuilder memory management', () {
    test('failed encodes delete temporary webp files in finally', () async {
      final temp = await Directory.systemTemp.createTemp('stikk_webp_fail');
      addTearDown(() => temp.deleteSync(recursive: true));
      final input = File('${temp.path}${Platform.pathSeparator}in.mp4')
        ..writeAsBytesSync(const [1, 2, 3, 4]);

      final builder = FFmpegWebpBuilder(
        tempDirectory: () async => temp,
        runCommand: (args, onProgress) async {
          File(args.last).writeAsBytesSync(List<int>.filled(32, 1));
          throw Exception('simulated OOM');
        },
      );

      await expectLater(
        builder.assemble(sourceMp4: input.path),
        throwsA(isA<StickerExportException>()),
      );

      final leftover = temp.listSync().whereType<File>().where(
        (file) => file.path.endsWith('.webp'),
      );
      expect(leftover, isEmpty);
    });

    test('FFmpegKit.cancel hook drops in-progress output', () async {
      final temp = await Directory.systemTemp.createTemp('stikk_webp_cancel');
      addTearDown(() => temp.deleteSync(recursive: true));
      final input = File('${temp.path}${Platform.pathSeparator}in.mp4')
        ..writeAsBytesSync(const [1, 2, 3, 4]);

      late FFmpegWebpBuilder builder;
      builder = FFmpegWebpBuilder(
        tempDirectory: () async => temp,
        runCommand: (args, onProgress) async {
          File(args.last).writeAsBytesSync(List<int>.filled(64, 1));
          await builder.cancel();
          return 255;
        },
        cancelSessions: () async {},
      );

      await expectLater(
        builder.assemble(sourceMp4: input.path),
        throwsA(isA<StickerExportCancelled>()),
      );

      final leftover = temp.listSync().whereType<File>().where(
        (file) => file.path.endsWith('.webp'),
      );
      expect(leftover, isEmpty);
    });

    test('retries lower q:v until the file is under 500KB', () async {
      final temp = await Directory.systemTemp.createTemp('stikk_webp_ladder');
      addTearDown(() => temp.deleteSync(recursive: true));
      final input = File('${temp.path}${Platform.pathSeparator}in.mp4')
        ..writeAsBytesSync(const [1, 2, 3, 4]);

      var attempts = 0;
      final builder = FFmpegWebpBuilder(
        tempDirectory: () async => temp,
        runCommand: (args, onProgress) async {
          attempts += 1;
          expect(
            args[args.indexOf('-q:v') + 1],
            FFmpegWebpBuilder.qualityLadder[attempts - 1].toString(),
          );
          final output = File(args.last);
          final bytes = attempts < 3
              ? List<int>.filled(600 * 1024, 1)
              : List<int>.filled(120 * 1024, 1);
          await output.writeAsBytes(bytes);
          onProgress(1);
          return 0;
        },
      );

      final result = await builder.assemble(sourceMp4: input.path);
      expect(result.bytes, lessThanOrEqualTo(WhatsAppStickerSpec.maxBytes));
      expect(result.fps, 15);
      expect(attempts, 3);
      expect(
        temp.listSync().whereType<File>().where(
          (file) => file.path.endsWith('.webp'),
        ),
        hasLength(1),
      );
    });
  });
}
