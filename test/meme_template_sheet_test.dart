import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stickr/editor/editor_screen.dart';
import 'package:stickr/editor/image_sticker_service.dart';
import 'package:stickr/memes/meme_service.dart';
import 'package:stickr/memes/meme_template_sheet.dart';
import 'package:stickr/photos/photo_import_controller.dart';

void main() {
  testWidgets('meme picker loads templates and hands a square image to editor', (
    tester,
  ) async {
    final temporary = Directory(
      '${Directory.systemTemp.path}/stickr_meme_ui_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    addTearDown(() {
      try {
        if (temporary.existsSync()) temporary.deleteSync(recursive: true);
      } on FileSystemException {
        // The editor can keep the prepared PNG open on Windows until dispose.
      }
    });
    final memeService = _FakeMemeService(temporary);
    final imageService = _FakeImageService(temporary);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memeServiceProvider.overrideWithValue(memeService),
          imageStickerServiceProvider.overrideWithValue(imageService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  key: const Key('open-meme-sheet'),
                  onPressed: () => showMemeTemplateSheet(context),
                  child: const Text('Start from Meme'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Start from Meme'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-meme-sheet')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byKey(const Key('meme-template-grid')), findsOneWidget);
    expect(find.text('Drake Hotline Bling'), findsOneWidget);

    await tester.tap(find.byKey(const Key('meme-template-drake')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(imageService.prepared, isTrue);
    expect(imageService.removeBackground, isFalse);
    expect(memeService.downloaded?.existsSync(), isFalse);
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Speed'), findsNothing);
  });
}

class _FakeMemeService extends MemeService {
  _FakeMemeService(this.temporary);

  final Directory temporary;
  File? downloaded;

  static const template = MemeTemplate(
    id: 'drake',
    name: 'Drake Hotline Bling',
    imageUrl: 'https://i.imgflip.com/30b1gx.jpg',
    width: 1200,
    height: 1200,
  );

  @override
  Future<List<MemeTemplate>> getTemplates() async => const [template];

  @override
  Future<File> downloadTemplate(
    MemeTemplate template, {
    void Function(double? progress)? onProgress,
  }) async {
    downloaded = File('${temporary.path}/stickr_meme_drake.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    return downloaded!;
  }
}

class _FakeImageService extends ImageStickerService {
  _FakeImageService(this.temporary)
    : super(tempDirectory: () async => temporary);

  final Directory temporary;
  bool prepared = false;
  bool? removeBackground;

  @override
  Future<ImagePrepareResult> prepareForEditor(
    File source, {
    bool removeBackground = true,
  }) async {
    prepared = true;
    this.removeBackground = removeBackground;
    final image = img.Image(width: 512, height: 512, numChannels: 4);
    final output = File('${temporary.path}/stickr_photo_meme.png')
      ..writeAsBytesSync(img.encodePng(image));
    return ImagePrepareResult(
      file: output,
      backgroundRemoved: false,
      autoCropped: true,
    );
  }
}
