import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikk/editor/editor_controller.dart';
import 'package:stikk/editor/editor_models.dart';
import 'package:stikk/editor/ffmpeg_sticker_service.dart';

void main() {
  group('EditorController undo/redo', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      container.read(editorProvider.notifier).hydrateDuration(8);
    });

    tearDown(() => container.dispose());

    test('undo and redo text overlays', () {
      final editor = container.read(editorProvider.notifier);

      editor.addText('Hello');
      expect(container.read(editorProvider).document.overlays, hasLength(1));
      expect(container.read(editorProvider).canUndo, isTrue);

      editor.undo();
      expect(container.read(editorProvider).document.overlays, isEmpty);
      expect(container.read(editorProvider).canRedo, isTrue);

      editor.redo();
      expect(
        container.read(editorProvider).document.overlays.single.content,
        'Hello',
      );
    });

    test('speed changes are undoable', () {
      final editor = container.read(editorProvider.notifier);
      editor.setSpeed(2);
      editor.undo();
      expect(container.read(editorProvider).document.speed, 1);
    });

    test('font changes update the selected text overlay and are undoable', () {
      final editor = container.read(editorProvider.notifier);
      editor.addText('Hello');

      editor.setSelectedTextFont('Anton');
      expect(
        container.read(editorProvider).document.selected?.fontName,
        'Anton',
      );

      editor.undo();
      expect(
        container.read(editorProvider).document.selected?.fontName,
        'Roboto',
      );
    });

    test('image layers join the z-ordered overlay list', () {
      final editor = container.read(editorProvider.notifier);
      editor.addText('Hello');
      editor.addImage('overlay.png');

      final overlays = container.read(editorProvider).document.overlays;
      expect(overlays, hasLength(2));
      expect(overlays.last.kind, OverlayKind.image);
      expect(overlays.last.widget, isA<ImageLayerWidget>());
    });
  });

  group('FfmpegStickerService', () {
    test('command is 512x512, infinite loop, webp', () {
      final service = FfmpegStickerService();
      final args = service.buildArguments(
        inputPath: 'in.mp4',
        outputPath: 'out.webp',
        startSeconds: 0,
        durationSeconds: 3,
        speed: 1,
        fps: 15,
        quality: 50,
        overlayPngPath: 'overlay.png',
      );

      expect(args[args.indexOf('-ss') + 1], '00:00:00');
      expect(args[args.indexOf('-t') + 1], '00:00:03');
      expect(args[args.indexOf('-loop') + 1], '0');
      expect(args[args.indexOf('-q:v') + 1], '50');
      expect(args[args.indexOf('-compression_level') + 1], '4');
      expect(args, contains('libwebp'));
      expect(args, contains('overlay.png'));
      expect(args, contains('-an'));
      expect(
        service.buildFilterGraph(speed: 1, fps: 15, hasOverlay: true),
        contains(
          'scale=512:512:force_original_aspect_ratio=decrease,pad=512:512:(ow-iw)/2:(oh-ih)/2:color=white@0.0',
        ),
      );
      expect(
        service.buildFilterGraph(speed: 1, fps: 15, hasOverlay: true),
        contains('overlay=0:0'),
      );
    });

    test('retries until the file is under 500KB', () async {
      final temp = await Directory.systemTemp.createTemp('stikk_ffmpeg');
      addTearDown(() => temp.deleteSync(recursive: true));
      final input = File('${temp.path}${Platform.pathSeparator}in.mp4')
        ..writeAsBytesSync(const [1, 2, 3, 4]);

      var attempts = 0;
      final service = FfmpegStickerService(
        tempDirectory: () async => temp,
        runCommand: (args, onProgress) async {
          attempts += 1;
          final output = File(args.last);
          final bytes = attempts < 3
              ? List<int>.filled(600 * 1024, 1)
              : List<int>.filled(120 * 1024, 1);
          await output.writeAsBytes(bytes);
          onProgress(1);
          return 0;
        },
      );

      final result = await service.exportSticker(
        inputPath: input.path,
        document: const EditorDocument(videoDuration: 3, trimEnd: 3),
      );

      expect(result.bytes, lessThanOrEqualTo(WhatsAppStickerSpec.maxBytes));
      expect(attempts, 3);
      final generated = temp
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.webp'))
          .toList();
      expect(generated, hasLength(1));
      expect(generated.single.path, result.file.path);
    });
  });
}
