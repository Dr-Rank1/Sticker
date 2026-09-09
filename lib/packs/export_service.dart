import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../storage/storage_utility.dart';
import 'pack_models.dart';
import 'pack_repository.dart';

/// Custom Stickr pack archive (`application/vnd.stickr.pack`).
class ExportService {
  ExportService({
    required this.repository,
    Future<Directory> Function()? temporaryDirectory,
    this.shareFile,
  }) : _temporaryDirectory =
           temporaryDirectory ?? (() => getStickrTemporaryDirectory());

  static const fileExtension = '.stickr';
  static const mimeType = 'application/vnd.stickr.pack';
  static const manifestFileName = 'manifest.json';
  static const trayFileName = 'tray.png';
  static const stickersDirectory = 'stickers';

  final PackRepository repository;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<void> Function(String filePath, String fileName)? shareFile;

  /// Builds a `.stickr` zip for [packId] containing `manifest.json`, the tray
  /// icon, and every associated `.webp` sticker.
  Future<File> exportPack(String packId) async {
    final pack = await repository.getById(packId);
    if (pack == null) {
      throw PackException(serviceLocalizations.packNoLongerExists);
    }

    final trayBytes = await _trayBytes(pack);
    if (trayBytes.isEmpty) {
      throw PackException(serviceLocalizations.packMissingTrayIcon);
    }

    final stickerFiles = <({String name, List<int> bytes})>[];
    for (var i = 0; i < pack.stickers.length; i++) {
      final sticker = pack.stickers[i];
      final file = File(sticker.filePath);
      if (!file.existsSync()) {
        throw PackException(serviceLocalizations.packStickerFileMissing);
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

  /// Exports [packId] and opens the native share sheet with the `.stickr` file.
  Future<File> sharePack(String packId) async {
    final file = await exportPack(packId);
    final name = file.uri.pathSegments.isEmpty
        ? archiveFileName('pack')
        : file.uri.pathSegments.last;
    final share = shareFile;
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

  /// Extracts a `.stickr` archive into local pack storage (Isar in production).
  Future<StickerPack> importPack(String archivePath) async {
    final source = File(archivePath);
    if (!source.existsSync()) {
      throw PackException(serviceLocalizations.stickrFileNotFound);
    }

    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(source.readAsBytesSync());
    } catch (_) {
      throw PackException(serviceLocalizations.invalidStickrPack);
    }

    final manifestEntry = archive.findFile(manifestFileName);
    if (manifestEntry == null) {
      throw PackException(serviceLocalizations.invalidStickrPack);
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

    final created = await repository.createPack(
      name: manifest.name,
      author: manifest.publisher,
    );
    if (trayBytes.isNotEmpty) {
      await repository.updatePack(created.copyWith(trayIconBytes: trayBytes));
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
        '${temp.path}${Platform.pathSeparator}stickr_import_$i.webp',
      );
      await extracted.writeAsBytes(bytes, flush: true);
      try {
        imported = await repository.addSticker(
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
    return (await repository.getById(created.id)) ?? imported;
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

  _StickrManifest _readManifest(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw PackException(serviceLocalizations.invalidStickrPack);
      }
      final name = (decoded['name'] as String?)?.trim() ?? '';
      final publisher = (decoded['publisher'] as String?)?.trim() ?? '';
      if (name.isEmpty || publisher.isEmpty) {
        throw PackException(serviceLocalizations.packMissingNameOrPublisher);
      }
      return _StickrManifest(name: name, publisher: publisher);
    } on PackException {
      rethrow;
    } catch (_) {
      throw PackException(serviceLocalizations.invalidStickrPack);
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

class _StickrManifest {
  const _StickrManifest({required this.name, required this.publisher});
  final String name;
  final String publisher;
}
