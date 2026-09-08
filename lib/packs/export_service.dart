import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'pack_models.dart';
import 'pack_repository.dart';

/// Custom Stikk pack archive (`application/vnd.stikk.pack`).
class ExportService {
  ExportService({
    required PackRepository repository,
    Future<Directory> Function()? temporaryDirectory,
    Future<void> Function(String filePath, String fileName)? shareFile,
  }) : _repository = repository,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _shareFile = shareFile;

  static const fileExtension = '.stikk';
  static const mimeType = 'application/vnd.stikk.pack';
  static const manifestFileName = 'manifest.json';
  static const trayFileName = 'tray.png';
  static const stickersDirectory = 'stickers';

  final PackRepository _repository;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<void> Function(String filePath, String fileName)? _shareFile;

  /// Builds a `.stikk` zip for [packId] containing `manifest.json`, the tray
  /// icon, and every associated `.webp` sticker.
  Future<File> exportPack(String packId) async {
    final pack = await _repository.getById(packId);
    if (pack == null) {
      throw const PackException('That pack no longer exists.');
    }

    final trayBytes = await _trayBytes(pack);
    if (trayBytes.isEmpty) {
      throw const PackException('This pack is missing a tray icon.');
    }

    final stickerFiles = <({String name, List<int> bytes})>[];
    for (var i = 0; i < pack.stickers.length; i++) {
      final sticker = pack.stickers[i];
      final file = File(sticker.filePath);
      if (!file.existsSync()) {
        throw const PackException('A sticker file is missing from this pack.');
      }
      stickerFiles.add((
        name: '$stickersDirectory/$i.webp',
        bytes: file.readAsBytesSync(),
      ));
    }

    final manifest = <String, Object?>{
      'name': pack.name,
      'publisher': pack.publisher,
      'stickerCount': pack.stickers.length,
    };
    final archive = Archive()
      ..addFile(ArchiveFile.string(manifestFileName, jsonEncode(manifest)))
      ..addFile(ArchiveFile.bytes(trayFileName, trayBytes));
    for (final sticker in stickerFiles) {
      archive.addFile(ArchiveFile.bytes(sticker.name, sticker.bytes));
    }

    final zipBytes = ZipEncoder().encodeBytes(archive);
    final temp = await _temporaryDirectory();
    if (!temp.existsSync()) {
      temp.createSync(recursive: true);
    }
    final out = File(
      '${temp.path}${Platform.pathSeparator}${archiveFileName(pack.name)}',
    );
    await out.writeAsBytes(zipBytes, flush: true);
    return out;
  }

  /// Exports [packId] and opens the native share sheet with the `.stikk` file.
  Future<File> sharePack(String packId) async {
    final file = await exportPack(packId);
    final name = file.uri.pathSegments.isEmpty
        ? archiveFileName('pack')
        : file.uri.pathSegments.last;
    final share = _shareFile;
    if (share != null) {
      await share(file.path, name);
    } else {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mimeType, name: name)],
          title: name,
        ),
      );
    }
    return file;
  }

  /// Extracts a `.stikk` archive into local pack storage (Isar in production).
  Future<StickerPack> importPack(String archivePath) async {
    final source = File(archivePath);
    if (!source.existsSync()) {
      throw const PackException('The .stikk file could not be found.');
    }

    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(source.readAsBytesSync());
    } catch (_) {
      throw const PackException('This is not a valid .stikk pack.');
    }

    final manifestEntry = archive.findFile(manifestFileName);
    if (manifestEntry == null) {
      throw const PackException('This is not a valid .stikk pack.');
    }
    final manifest = _readManifest(manifestEntry.content);
    final trayEntry = archive.findFile(trayFileName);
    final trayBytes = trayEntry == null
        ? <int>[]
        : List<int>.from(trayEntry.content);
    final webpEntries = [
      for (final entry in archive)
        if (entry.isFile && entry.name.toLowerCase().endsWith('.webp')) entry,
    ]..sort((a, b) => a.name.compareTo(b.name));

    final created = await _repository.createPack(
      name: manifest.name,
      author: manifest.publisher,
    );
    if (trayBytes.isNotEmpty) {
      await _repository.updatePack(created.copyWith(trayIconBytes: trayBytes));
    }

    final temp = await _temporaryDirectory();
    if (!temp.existsSync()) {
      temp.createSync(recursive: true);
    }
    var imported = created;
    for (var i = 0; i < webpEntries.length; i++) {
      if (imported.isFull) break;
      final bytes = webpEntries[i].content;
      final extracted = File(
        '${temp.path}${Platform.pathSeparator}stikk_import_$i.webp',
      );
      await extracted.writeAsBytes(bytes, flush: true);
      try {
        imported = await _repository.addSticker(
          packId: created.id,
          sourcePath: extracted.path,
          animated: _webpLooksAnimated(extracted.path),
        );
        final storedPath = imported.stickers.last.filePath;
        if (storedPath != extracted.path && extracted.existsSync()) {
          extracted.deleteSync();
        }
      } on PackException {
        if (extracted.existsSync()) {
          extracted.deleteSync();
        }
        break;
      }
    }
    return (await _repository.getById(created.id)) ?? imported;
  }

  static String archiveFileName(String packName) {
    final cleaned = packName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final base = cleaned.isEmpty ? 'pack' : cleaned;
    return '$base$fileExtension';
  }

  Future<List<int>> _trayBytes(StickerPack pack) async {
    if (pack.trayIconBytes.isNotEmpty) {
      return List<int>.from(pack.trayIconBytes);
    }
    if (pack.trayIconPath.trim().isEmpty) return const [];
    final file = File(pack.trayIconPath);
    if (!file.existsSync()) return const [];
    return file.readAsBytesSync();
  }

  _StikkManifest _readManifest(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const PackException('This is not a valid .stikk pack.');
      }
      final name = (decoded['name'] as String?)?.trim() ?? '';
      final publisher = (decoded['publisher'] as String?)?.trim() ?? '';
      if (name.isEmpty || publisher.isEmpty) {
        throw const PackException('This pack is missing a name or publisher.');
      }
      return _StikkManifest(name: name, publisher: publisher);
    } on PackException {
      rethrow;
    } catch (_) {
      throw const PackException('This is not a valid .stikk pack.');
    }
  }

  static bool _webpLooksAnimated(String path) {
    try {
      final bytes = File(path).readAsBytesSync();
      if (bytes.length < 21) return false;
      final fourcc = String.fromCharCodes(bytes.sublist(12, 16));
      if (fourcc != 'VP8X') return false;
      return (bytes[20] & 0x02) != 0;
    } catch (_) {
      return false;
    }
  }
}

class _StikkManifest {
  const _StikkManifest({required this.name, required this.publisher});
  final String name;
  final String publisher;
}
