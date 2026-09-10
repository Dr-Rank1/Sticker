import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stickr/create/manual_create.dart';
import 'package:stickr/editor/local_video_import_service.dart';
import 'package:stickr/screens/library_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stickr_video_test_');
  });
  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('copies a selected video and validates its metadata', () async {
    final external = File('${directory.path}/external.mp4');
    await external.writeAsString('video-bytes');
    final service = LocalVideoImportService(
      () async => XFile(external.path),
      (_) async => validMetadata,
      temporaryDirectory: () async => directory,
    );

    final result = await service.pickAndPrepare();

    expect(result, isNotNull);
    expect(result!.file.path, isNot(external.path));
    expect(await result.file.readAsString(), 'video-bytes');
    expect(result.metadata.codec, 'h264');
    await service.deleteTemporary(result.file);
    expect(await result.file.exists(), isFalse);
    expect(await external.exists(), isTrue);
  });

  test('picker cancellation does not create a temporary file', () async {
    final service = LocalVideoImportService(
      () async => null,
      (_) async => validMetadata,
      temporaryDirectory: () async => directory,
    );

    expect(await service.pickAndPrepare(), isNull);
    expect(directory.listSync(), isEmpty);
  });

  test('failed metadata validation removes the copied video', () async {
    final external = File('${directory.path}/unsupported.mkv');
    await external.writeAsString('video-bytes');
    final service = LocalVideoImportService(
      () async => XFile(external.path),
      (_) async => const LocalVideoMetadata(
        duration: Duration(seconds: 5),
        codec: 'unsupported',
        width: 1280,
        height: 720,
      ),
      temporaryDirectory: () async => directory,
    );

    await expectLater(
      service.pickAndPrepare(),
      throwsA(
        isA<LocalVideoImportException>().having(
          (error) => error.message,
          'message',
          contains('UNSUPPORTED video codec'),
        ),
      ),
    );
    expect(
      directory.listSync().whereType<File>().where(
        (file) => file.path.contains('local_video_'),
      ),
      isEmpty,
    );
    expect(await external.exists(), isTrue);
  });

  test('validates duration, dimensions, and file size limits', () {
    final service = LocalVideoImportService(
      () async => null,
      (_) async => validMetadata,
    );

    expect(
      () => service.validate(
        const LocalVideoMetadata(
          duration: Duration(minutes: 11),
          codec: 'h264',
          width: 1920,
          height: 1080,
        ),
        fileBytes: 1,
      ),
      throwsA(
        isA<LocalVideoImportException>().having(
          (error) => error.message,
          'message',
          contains('10 minutes or shorter'),
        ),
      ),
    );
    expect(
      () => service.validate(
        const LocalVideoMetadata(
          duration: Duration(seconds: 5),
          codec: 'h264',
          width: 7680,
          height: 4320,
        ),
        fileBytes: 1,
      ),
      throwsA(
        isA<LocalVideoImportException>().having(
          (error) => error.message,
          'message',
          contains('4096 by 4096'),
        ),
      ),
    );
    expect(
      () => service.validate(
        validMetadata,
        fileBytes: LocalVideoImportService.maxFileBytes + 1,
      ),
      throwsA(
        isA<LocalVideoImportException>().having(
          (error) => error.message,
          'message',
          contains('smaller than 250 MB'),
        ),
      ),
    );
  });

  testWidgets('Create opens the editor and deletes its copy after close', (
    tester,
  ) async {
    final copied = File('${directory.path}/copied.mp4');
    copied.writeAsStringSync('video-bytes');
    final service = _FakeLocalVideoImportService(copied);
    String? editorPath;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localVideoImportServiceProvider.overrideWithValue(service),
          localVideoEditorRouteProvider.overrideWithValue(
            (path) => MaterialPageRoute<Object?>(
              builder: (context) {
                editorPath = path;
                return Scaffold(
                  body: TextButton(
                    key: const Key('close-local-video-editor'),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close editor'),
                  ),
                );
              },
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LibraryScreen(),
            floatingActionButton: LibraryCreateFab(),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-from-video')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(editorPath, copied.path);
    expect(copied.existsSync(), isTrue);

    await tester.tap(find.byKey(const Key('close-local-video-editor')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(service.deletedPath, copied.path);
    expect(copied.existsSync(), isFalse);
  });
}

const validMetadata = LocalVideoMetadata(
  duration: Duration(seconds: 5),
  codec: 'h264',
  width: 1920,
  height: 1080,
);

class _FakeLocalVideoImportService extends LocalVideoImportService {
  _FakeLocalVideoImportService(this.copied)
    : super(() async => null, (_) async => validMetadata);

  final File copied;
  String? deletedPath;

  @override
  Future<LocalVideoImportResult?> pickAndPrepare() async {
    return LocalVideoImportResult(file: copied, metadata: validMetadata);
  }

  @override
  Future<void> deleteTemporary(File? file) async {
    deletedPath = file?.path;
    if (file?.existsSync() == true) file!.deleteSync();
  }
}
