import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:stikk/editor/image_sticker_service.dart';
import 'package:stikk/photos/photo_import_controller.dart';
import 'package:stikk/screens/create_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Create photo card opens the import sheet', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: CreateScreen())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('From a photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('photo-gallery-button')), findsOneWidget);
    expect(find.byKey(const Key('photo-camera-button')), findsOneWidget);
    expect(find.byKey(const Key('photo-auto-crop-toggle')), findsOneWidget);
    expect(find.text('Auto crop'), findsOneWidget);
  });

  test('gallery pick prepares a 512 photo for the editor', () async {
    final temp = await Directory.systemTemp.createTemp('stikk_photo_ui');
    addTearDown(() => temp.deleteSync(recursive: true));

    final source = img.Image(width: 64, height: 48, numChannels: 4);
    for (final pixel in source) {
      pixel.setRgba(30, 140, 90, 255);
    }
    final file = File('${temp.path}${Platform.pathSeparator}shot.png')
      ..writeAsBytesSync(img.encodePng(source));

    final container = ProviderContainer(
      overrides: [
        photoPickerProvider.overrideWithValue(
          ({
            required ImageSource source,
            double? maxWidth,
            int? imageQuality,
          }) async =>
              XFile(file.path),
        ),
        imageStickerServiceProvider.overrideWithValue(
          ImageStickerService(
            segmenter: const _NullSegmenter(),
            tempDirectory: () async => temp,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(photoImportProvider.notifier).importFromGallery();
    final state = container.read(photoImportProvider);

    expect(state.phase, PhotoImportPhase.completed);
    expect(state.preparedPath, isNotNull);
    final prepared = img.decodeImage(File(state.preparedPath!).readAsBytesSync());
    expect(prepared!.width, 512);
    expect(prepared.height, 512);
  });
}

class _NullSegmenter implements SubjectSegmenter {
  const _NullSegmenter();

  @override
  Future<SubjectMask?> segment(File image) async => null;
}
