import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/packs/export_service.dart';
import 'package:stickr/packs/pack_models.dart';
import 'package:stickr/packs/pack_repository.dart';

void main() {
  late Directory root;
  late Directory documents;
  late Directory temporary;
  late InMemoryPackRepository repo;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('stickr_export_');
    documents = Directory('${root.path}${Platform.pathSeparator}documents')
      ..createSync();
    temporary = Directory('${root.path}${Platform.pathSeparator}temporary')
      ..createSync();
    repo = InMemoryPackRepository();
  });

  tearDown(() async {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<StickerPack> seedPack() async {
    final sticker = File('${documents.path}${Platform.pathSeparator}s0.webp')
      ..writeAsBytesSync(const [1, 2, 3, 4]);
    final created = await repo.createPack(name: 'My Pack', author: 'Ian');
    await repo.updatePack(
      created.copyWith(trayIconBytes: const [137, 80, 78, 71]),
    );
    return repo.addSticker(packId: created.id, sourcePath: sticker.path);
  }

  test(
    'exportPack writes a .stickr zip with manifest, tray, and webp files',
    () async {
      final pack = await seedPack();
      String? sharedPath;
      String? sharedName;
      final service = ExportService(
        repository: repo,
        temporaryDirectory: () async => temporary,
        shareFile: (path, name) async {
          sharedPath = path;
          sharedName = name;
        },
      );

      final file = await service.exportPack(pack.id);

      expect(file.path, endsWith('.stickr'));
      expect(file.path, endsWith('my_pack.stickr'));
      expect(file.existsSync(), isTrue);

      final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
      final manifestFile = archive.findFile('manifest.json');
      expect(manifestFile, isNotNull);
      final manifest = jsonDecode(
        utf8.decode(manifestFile!.content),
      ) as Map<String, dynamic>;
      expect(manifest['name'], 'My Pack');
      expect(manifest['publisher'], 'Ian');
      expect(manifest['stickerCount'], 1);
      expect(archive.findFile('tray.png'), isNotNull);
      expect(archive.findFile('stickers/0.webp'), isNotNull);
      expect(archive.findFile('stickers/0.webp')!.content, [1, 2, 3, 4]);

      await service.sharePack(pack.id);
      expect(sharedPath, isNotNull);
      expect(sharedPath, endsWith('.stickr'));
      expect(sharedName, 'my_pack.stickr');
    },
  );

  test(
    'importPack restores metadata and stickers into the repository',
    () async {
      final pack = await seedPack();
      final service = ExportService(
        repository: repo,
        temporaryDirectory: () async => temporary,
        shareFile: (_, _) async {},
      );
      final archiveFile = await service.exportPack(pack.id);

      final destRepo = InMemoryPackRepository();
      final importer = ExportService(
        repository: destRepo,
        temporaryDirectory: () async => temporary,
      );
      final imported = await importer.importPack(archiveFile.path);

      expect(imported.name, 'My Pack');
      expect(imported.publisher, 'Ian');
      expect(imported.trayIconBytes, isNotEmpty);
      expect(imported.stickers, hasLength(1));
      expect(File(imported.stickers.single.filePath).existsSync(), isTrue);
    },
  );

  test('importPack rejects archives without a manifest', () async {
    final bogus = File('${temporary.path}${Platform.pathSeparator}bad.stickr')
      ..writeAsBytesSync(const [0, 1, 2, 3, 4, 5, 6, 7]);
    final service = ExportService(
      repository: repo,
      temporaryDirectory: () async => temporary,
    );

    await expectLater(
      service.importPack(bogus.path),
      throwsA(isA<PackException>()),
    );
  });

  test('importPack rejects a zip that has no manifest.json', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('stickers/0.webp', const [1, 2, 3, 4]));
    final missingManifest = File(
      '${temporary.path}${Platform.pathSeparator}no_manifest.stickr',
    )..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    final service = ExportService(
      repository: repo,
      temporaryDirectory: () async => temporary,
    );

    await expectLater(
      service.importPack(missingManifest.path),
      throwsA(isA<PackException>()),
    );
  });

  test('archiveFileName uses the .stickr extension', () {
    expect(ExportService.archiveFileName('My Pack'), 'my_pack.stickr');
    expect(ExportService.archiveFileName('  '), 'pack.stickr');
  });
}
