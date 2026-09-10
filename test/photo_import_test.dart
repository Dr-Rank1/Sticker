import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:stickr/editor/image_sticker_service.dart';
import 'package:stickr/photos/photo_import_controller.dart';
import 'package:stickr/photos/photo_import_sheet.dart';
import 'package:stickr/screens/library_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Create photo card opens the import sheet', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LibraryScreen(),
            floatingActionButton: LibraryCreateFab(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-from-photo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('photo-gallery-button')), findsOneWidget);
    expect(find.byKey(const Key('photo-camera-button')), findsOneWidget);
    expect(
      find.byKey(const Key('photo-remove-background-toggle')),
      findsOneWidget,
    );
    expect(find.text('Remove Background'), findsOneWidget);
  });

  test('gallery pick prepares a 512 photo for the editor', () async {
    final temp = await Directory.systemTemp.createTemp('stickr_photo_ui');
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
          }) async => XFile(file.path),
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
    final prepared = img.decodeImage(
      File(state.preparedPath!).readAsBytesSync(),
    );
    expect(prepared!.width, 512);
    expect(prepared.height, 512);
  });

  testWidgets('shows an animated local scanner during background removal', (
    tester,
  ) async {
    final temporary = Directory(
      '${Directory.systemTemp.path}/stickr_scan_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    addTearDown(() {
      if (temporary.existsSync()) temporary.deleteSync(recursive: true);
    });
    final sourceFile = File('${temporary.path}/source.png')
      ..writeAsBytesSync([1, 2, 3]);
    final preparedFile = File('${temporary.path}/prepared.png')
      ..writeAsBytesSync([1, 2, 3]);
    final pending = Completer<ImagePrepareResult>();
    final container = ProviderContainer(
      overrides: [
        photoPickerProvider.overrideWithValue(
          ({
            required ImageSource source,
            double? maxWidth,
            int? imageQuality,
          }) async => XFile(sourceFile.path),
        ),
        imageStickerServiceProvider.overrideWithValue(
          _PendingImageService(temporary, pending),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: PhotoImportSheet())),
      ),
    );
    await tester.pump();

    final operation = container
        .read(photoImportProvider.notifier)
        .importFromGallery();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('background-removal-scanner')), findsOneWidget);
    expect(find.text('Scanning locally'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('background-removal-scanner')), findsOneWidget);

    pending.complete(
      ImagePrepareResult(
        file: preparedFile,
        backgroundRemoved: true,
        autoCropped: true,
      ),
    );
    await operation;
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}

class _PendingImageService extends ImageStickerService {
  _PendingImageService(Directory temporary, this.pending)
    : super(tempDirectory: () async => temporary);

  final Completer<ImagePrepareResult> pending;

  @override
  Future<ImagePrepareResult> prepareForEditor(
    File source, {
    bool removeBackground = true,
  }) {
    return pending.future;
  }
}

class _NullSegmenter implements SubjectSegmenter {
  const _NullSegmenter();

  @override
  Future<SubjectMask?> segment(File image) async => null;
}
