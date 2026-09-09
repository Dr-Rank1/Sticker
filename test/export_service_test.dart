import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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
    final bytes = _webpBytes();
    final sticker = File('${documents.path}${Platform.pathSeparator}s0.webp')
      ..writeAsBytesSync(bytes);
    final created = await repo.createPack(name: 'My Pack', author: 'Ian');
    await repo.updatePack(
      created.copyWith(trayIconBytes: const [137, 80, 78, 71]),
    );
    return repo.addSticker(packId: created.id, sourcePath: sticker.path);
  }

  File writeArchive({
    required String name,
    required List<List<int>> stickers,
    List<ArchiveFile> additionalEntries = const [],
  }) {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          ExportService.manifestFileName,
          jsonEncode({
            'name': 'Imported Pack',
            'publisher': 'Ian',
            'stickerCount': stickers.length,
          }),
        ),
      );
    for (var index = 0; index < stickers.length; index++) {
      archive.addFile(
        ArchiveFile.bytes('stickers/$index.webp', stickers[index]),
      );
    }
    for (final entry in additionalEntries) {
      archive.addFile(entry);
    }
    return File('${temporary.path}${Platform.pathSeparator}$name')
      ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
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
      expect(
        img.WebPDecoder().isValidFile(
          archive.findFile('stickers/0.webp')!.content,
        ),
        isTrue,
      );

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

  test('importPack rejects files above the compressed size limit', () async {
    final oversized =
        File('${temporary.path}${Platform.pathSeparator}oversized.stickr')
          ..writeAsBytesSync(
            List<int>.filled(ExportService.maxCompressedArchiveBytes + 1, 0),
          );
    final service = ExportService(
      repository: repo,
      temporaryDirectory: () async => temporary,
    );

    await expectLater(
      service.importPack(oversized.path),
      throwsA(isA<PackException>()),
    );
    expect(await repo.getAll(), isEmpty);
  });

  test(
    'importPack rejects archives that expand beyond the safe limit',
    () async {
      final bomb = writeArchive(
        name: 'expanded.stickr',
        stickers: const [],
        additionalEntries: [
          ArchiveFile.bytes(
            'tray.png',
            List<int>.filled(ExportService.maxUncompressedArchiveBytes + 1, 0),
          ),
        ],
      );
      expect(
        bomb.lengthSync(),
        lessThanOrEqualTo(ExportService.maxCompressedArchiveBytes),
      );
      final service = ExportService(
        repository: repo,
        temporaryDirectory: () async => temporary,
      );

      await expectLater(
        service.importPack(bomb.path),
        throwsA(isA<PackException>()),
      );
      expect(await repo.getAll(), isEmpty);
    },
  );

  test('importPack rejects a non-WebP payload with a webp extension', () async {
    final archive = writeArchive(
      name: 'wrong_format.stickr',
      stickers: [img.encodePng(img.Image(width: 512, height: 512))],
    );
    final service = ExportService(
      repository: repo,
      temporaryDirectory: () async => temporary,
    );

    await expectLater(
      service.importPack(archive.path),
      throwsA(isA<PackException>()),
    );
    expect(await repo.getAll(), isEmpty);
  });

  test('importPack rejects WebP stickers with invalid dimensions', () async {
    final archive = writeArchive(
      name: 'wrong_dimensions.stickr',
      stickers: [_webpBytes(width: 256, height: 512)],
    );
    final service = ExportService(
      repository: repo,
      temporaryDirectory: () async => temporary,
    );

    await expectLater(
      service.importPack(archive.path),
      throwsA(isA<PackException>()),
    );
    expect(await repo.getAll(), isEmpty);
  });

  test('importPack rejects entries whose checksum does not match', () async {
    final manifestBytes = utf8.encode(
      jsonEncode({
        'name': 'Imported Pack',
        'publisher': 'Ian',
        'stickerCount': 0,
      }),
    );
    final archive = Archive()
      ..addFile(
        ArchiveFile.noCompress(
          ExportService.manifestFileName,
          manifestBytes.length,
          manifestBytes,
        ),
      );
    final encoded = ZipEncoder().encodeBytes(archive);
    final payloadOffset = _indexOfSequence(
      encoded,
      utf8.encode('Imported Pack'),
    );
    expect(payloadOffset, isNonNegative);
    encoded[payloadOffset] = 'X'.codeUnitAt(0);
    final file = File(
      '${temporary.path}${Platform.pathSeparator}bad_checksum.stickr',
    )..writeAsBytesSync(encoded);
    final service = ExportService(
      repository: repo,
      temporaryDirectory: () async => temporary,
    );

    await expectLater(
      service.importPack(file.path),
      throwsA(isA<PackException>()),
    );
    expect(await repo.getAll(), isEmpty);
  });

  test('importPack rejects unsafe archive paths', () async {
    final archive = writeArchive(
      name: 'unsafe_path.stickr',
      stickers: const [],
      additionalEntries: [
        ArchiveFile.bytes('../stickers/0.webp', _webpBytes()),
      ],
    );
    final service = ExportService(
      repository: repo,
      temporaryDirectory: () async => temporary,
    );

    await expectLater(
      service.importPack(archive.path),
      throwsA(isA<PackException>()),
    );
    expect(await repo.getAll(), isEmpty);
  });

  test('importPack rejects symbolic links before decompression', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          ExportService.manifestFileName,
          jsonEncode({
            'name': 'Imported Pack',
            'publisher': 'Ian',
            'stickerCount': 1,
          }),
        ),
      )
      ..addFile(
        ArchiveFile.bytes('stickers/0.webp', utf8.encode('../../outside.webp'))
          ..mode = 0xa1ff,
      );
    final file = File(
      '${temporary.path}${Platform.pathSeparator}symlink.stickr',
    )..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    final service = ExportService(
      repository: repo,
      temporaryDirectory: () async => temporary,
    );

    await expectLater(
      service.importPack(file.path),
      throwsA(isA<PackException>()),
    );
    expect(await repo.getAll(), isEmpty);
  });

  test(
    'importPack rolls back the pack and staged files after midway failure',
    () async {
      final archive = writeArchive(
        name: 'rollback.stickr',
        stickers: [_webpBytes(), _webpBytes()],
      );
      final failingRepo = _FailingImportRepository(failOnAdd: 2);
      final service = ExportService(
        repository: failingRepo,
        temporaryDirectory: () async => temporary,
      );

      await expectLater(
        service.importPack(archive.path),
        throwsA(isA<PackException>()),
      );

      expect(await failingRepo.getAll(), isEmpty);
      expect(
        temporary.listSync().whereType<Directory>().where(
          (directory) => directory.path
              .split(Platform.pathSeparator)
              .last
              .startsWith('stickr_import_'),
        ),
        isEmpty,
      );
    },
  );

  test('archiveFileName uses the .stickr extension', () {
    expect(ExportService.archiveFileName('My Pack'), 'my_pack.stickr');
    expect(ExportService.archiveFileName('  '), 'pack.stickr');
  });
}

List<int> _webpBytes({int width = 512, int height = 512}) {
  return img.encodeWebP(img.Image(width: width, height: height));
}

int _indexOfSequence(List<int> bytes, List<int> sequence) {
  for (var offset = 0; offset <= bytes.length - sequence.length; offset++) {
    var matches = true;
    for (var index = 0; index < sequence.length; index++) {
      if (bytes[offset + index] != sequence[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return offset;
  }
  return -1;
}

class _FailingImportRepository extends InMemoryPackRepository {
  _FailingImportRepository({required this.failOnAdd});

  final int failOnAdd;
  int _addCount = 0;

  @override
  Future<StickerPack> addSticker({
    required String packId,
    required String sourcePath,
    bool animated = true,
    String accessibilityText = '',
  }) {
    _addCount++;
    if (_addCount == failOnAdd) {
      throw const PackException('Simulated import failure.');
    }
    return super.addSticker(
      packId: packId,
      sourcePath: sourcePath,
      animated: animated,
      accessibilityText: accessibilityText,
    );
  }
}
