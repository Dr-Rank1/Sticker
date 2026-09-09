import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
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
  static const maxCompressedArchiveBytes = 5 * 1024 * 1024;
  static const maxUncompressedArchiveBytes = 20 * 1024 * 1024;
  static const maxArchiveEntries = 64;
  static const maxManifestBytes = 64 * 1024;
  static const maxTrayBytes = 512 * 1024;
  static const maxStickerBytes = 1024 * 1024;
  static const requiredStickerDimension = 512;
  static const maxWebpFrames = 300;

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
    final int compressedSize;
    try {
      compressedSize = source.lengthSync();
    } on FileSystemException {
      throw PackException(serviceLocalizations.invalidStickrPack);
    }
    if (compressedSize <= 0 || compressedSize > maxCompressedArchiveBytes) {
      throw PackException(serviceLocalizations.stickrArchiveTooLarge);
    }

    Directory? stagingDirectory;
    String? createdPackId;
    try {
      final compressedBytes = source.readAsBytesSync();
      _preflightZip(compressedBytes);
      final archive = ZipDecoder().decodeBytes(compressedBytes, verify: true);
      final entries = _validateArchiveStructure(archive);
      final budget = _ArchiveBudget(maxUncompressedArchiveBytes);
      final manifestBytes = _readEntry(
        entries.manifest,
        budget,
        entryLimit: maxManifestBytes,
      );
      final manifest = _readManifest(manifestBytes);
      final trayBytes = entries.tray == null
          ? <int>[]
          : _readEntry(entries.tray!, budget, entryLimit: maxTrayBytes);
      final validatedStickers = <_ValidatedSticker>[];
      for (final entry in entries.stickers) {
        final bytes = _readEntry(entry, budget, entryLimit: maxStickerBytes);
        validatedStickers.add(_validateWebp(entry.name, bytes));
      }
      if (manifest.stickerCount != null &&
          manifest.stickerCount != validatedStickers.length) {
        throw PackException(serviceLocalizations.invalidStickrPack);
      }

      final temp = await _temporaryDirectory();
      temp.createSync(recursive: true);
      stagingDirectory = Directory(
        '${temp.path}${Platform.pathSeparator}'
        'stickr_import_${DateTime.now().microsecondsSinceEpoch}_$pid',
      )..createSync();
      final stagedFiles = <File>[];
      for (var i = 0; i < validatedStickers.length; i++) {
        final staged = File(
          '${stagingDirectory.path}${Platform.pathSeparator}$i.webp',
        );
        await staged.writeAsBytes(validatedStickers[i].bytes, flush: true);
        stagedFiles.add(staged);
      }

      final created = await repository.createPack(
        name: manifest.name,
        author: manifest.publisher,
      );
      createdPackId = created.id;
      var imported = created;
      if (trayBytes.isNotEmpty) {
        imported = await repository.updatePack(
          imported.copyWith(trayIconBytes: trayBytes),
        );
      }
      for (var i = 0; i < stagedFiles.length; i++) {
        imported = await repository.addSticker(
          packId: created.id,
          sourcePath: stagedFiles[i].path,
          animated: validatedStickers[i].animated,
        );
      }
      final result = (await repository.getById(created.id)) ?? imported;
      _deleteUnretainedStaging(stagingDirectory, result);
      return result;
    } on PackException {
      await _rollbackImport(createdPackId, stagingDirectory);
      rethrow;
    } catch (_) {
      await _rollbackImport(createdPackId, stagingDirectory);
      throw PackException(serviceLocalizations.invalidStickrPack);
    }
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
      final stickerCount = decoded['stickerCount'];
      if (stickerCount != null &&
          (stickerCount is! int ||
              stickerCount < 0 ||
              stickerCount > WhatsAppPackRules.maxStickers)) {
        throw PackException(serviceLocalizations.invalidStickrPack);
      }
      return _StickrManifest(
        name: name,
        publisher: publisher,
        stickerCount: stickerCount as int?,
      );
    } on PackException {
      rethrow;
    } catch (_) {
      throw PackException(serviceLocalizations.invalidStickrPack);
    }
  }

  _ArchiveEntries _validateArchiveStructure(Archive archive) {
    if (archive.isEmpty || archive.length > maxArchiveEntries) {
      throw PackException(serviceLocalizations.invalidStickrPack);
    }
    var declaredSize = 0;
    final names = <String>{};
    ArchiveFile? manifest;
    ArchiveFile? tray;
    final stickers = <ArchiveFile>[];

    for (final entry in archive) {
      final name = entry.name.replaceAll('\\', '/');
      if (!_isSafeArchivePath(name) ||
          entry.isSymbolicLink ||
          !names.add(name.toLowerCase()) ||
          entry.size < 0) {
        throw PackException(serviceLocalizations.invalidStickrPack);
      }
      if (!entry.isFile) {
        if (name != '$stickersDirectory/') {
          throw PackException(serviceLocalizations.invalidStickrPack);
        }
        continue;
      }
      declaredSize += entry.size;
      if (declaredSize > maxUncompressedArchiveBytes) {
        throw PackException(serviceLocalizations.stickrArchiveExpandedTooLarge);
      }
      if (name == manifestFileName) {
        manifest = entry;
      } else if (name == trayFileName) {
        tray = entry;
      } else if (RegExp(
        r'^stickers/[^/]+\.webp$',
        caseSensitive: false,
      ).hasMatch(name)) {
        stickers.add(entry);
      } else {
        throw PackException(serviceLocalizations.invalidStickrPack);
      }
    }
    if (manifest == null || stickers.length > WhatsAppPackRules.maxStickers) {
      throw PackException(serviceLocalizations.invalidStickrPack);
    }
    stickers.sort((a, b) => a.name.compareTo(b.name));
    return _ArchiveEntries(manifest: manifest, tray: tray, stickers: stickers);
  }

  void _preflightZip(List<int> bytes) {
    const endOfCentralDirectorySignature = 0x06054b50;
    const centralDirectorySignature = 0x02014b50;
    const minimumEndRecordSize = 22;
    const maximumCommentSize = 0xffff;
    if (bytes.length < minimumEndRecordSize) {
      throw PackException(serviceLocalizations.invalidStickrPack);
    }

    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final minimumOffset = max(
      0,
      bytes.length - minimumEndRecordSize - maximumCommentSize,
    );
    int? endOffset;
    for (
      var offset = bytes.length - minimumEndRecordSize;
      offset >= minimumOffset;
      offset--
    ) {
      if (_uint32(data, offset) == endOfCentralDirectorySignature) {
        final commentLength = _uint16(data, offset + 20);
        if (offset + minimumEndRecordSize + commentLength == bytes.length) {
          endOffset = offset;
          break;
        }
      }
    }
    if (endOffset == null) {
      throw PackException(serviceLocalizations.invalidStickrPack);
    }

    final diskNumber = _uint16(data, endOffset + 4);
    final centralDisk = _uint16(data, endOffset + 6);
    final entriesOnDisk = _uint16(data, endOffset + 8);
    final entryCount = _uint16(data, endOffset + 10);
    final centralSize = _uint32(data, endOffset + 12);
    final centralOffset = _uint32(data, endOffset + 16);
    if (diskNumber != 0 ||
        centralDisk != 0 ||
        entriesOnDisk != entryCount ||
        entryCount == 0 ||
        entryCount > maxArchiveEntries ||
        centralSize == 0xffffffff ||
        centralOffset == 0xffffffff ||
        centralOffset + centralSize != endOffset) {
      throw PackException(serviceLocalizations.invalidStickrPack);
    }

    var cursor = centralOffset;
    var uncompressedSize = 0;
    for (var index = 0; index < entryCount; index++) {
      if (cursor < 0 ||
          cursor + 46 > endOffset ||
          _uint32(data, cursor) != centralDirectorySignature) {
        throw PackException(serviceLocalizations.invalidStickrPack);
      }
      final versionMadeBy = _uint16(data, cursor + 4);
      final flags = _uint16(data, cursor + 8);
      final compression = _uint16(data, cursor + 10);
      final compressedEntrySize = _uint32(data, cursor + 20);
      final uncompressedEntrySize = _uint32(data, cursor + 24);
      final nameLength = _uint16(data, cursor + 28);
      final extraLength = _uint16(data, cursor + 30);
      final commentLength = _uint16(data, cursor + 32);
      final diskStart = _uint16(data, cursor + 34);
      final externalAttributes = _uint32(data, cursor + 38);
      final next = cursor + 46 + nameLength + extraLength + commentLength;
      if (next > endOffset ||
          flags & 0x1 != 0 ||
          (compression != 0 && compression != 8) ||
          compressedEntrySize == 0xffffffff ||
          uncompressedEntrySize == 0xffffffff ||
          diskStart != 0) {
        throw PackException(serviceLocalizations.invalidStickrPack);
      }

      final creatorSystem = versionMadeBy >> 8;
      final unixMode = externalAttributes >> 16;
      if (creatorSystem == 3 && unixMode & 0xf000 == 0xa000) {
        throw PackException(serviceLocalizations.invalidStickrPack);
      }
      uncompressedSize += uncompressedEntrySize;
      if (uncompressedSize > maxUncompressedArchiveBytes) {
        throw PackException(serviceLocalizations.stickrArchiveExpandedTooLarge);
      }
      cursor = next;
    }
    if (cursor != endOffset) {
      throw PackException(serviceLocalizations.invalidStickrPack);
    }
  }

  static int _uint16(ByteData data, int offset) {
    if (offset < 0 || offset + 2 > data.lengthInBytes) {
      throw const FormatException('Invalid ZIP metadata offset.');
    }
    return data.getUint16(offset, Endian.little);
  }

  static int _uint32(ByteData data, int offset) {
    if (offset < 0 || offset + 4 > data.lengthInBytes) {
      throw const FormatException('Invalid ZIP metadata offset.');
    }
    return data.getUint32(offset, Endian.little);
  }

  List<int> _readEntry(
    ArchiveFile entry,
    _ArchiveBudget budget, {
    int? entryLimit,
  }) {
    final allowed = min(
      budget.remaining,
      entryLimit ?? maxUncompressedArchiveBytes,
    );
    if (entry.size > allowed) {
      throw PackException(
        entryLimit == null
            ? serviceLocalizations.stickrArchiveExpandedTooLarge
            : serviceLocalizations.invalidStickrPack,
      );
    }
    final output = _BoundedOutputMemoryStream(
      maxBytes: allowed,
      initialSize: min(entry.size, 64 * 1024),
    );
    try {
      entry.decompress(output);
      final bytes = output.getBytes();
      if (bytes.length != entry.size ||
          (entry.crc32 != null && getCrc32(bytes) != entry.crc32)) {
        throw PackException(serviceLocalizations.invalidStickrPack);
      }
      budget.consume(bytes.length);
      return List<int>.from(bytes);
    } on _ArchiveSizeLimitException {
      throw PackException(serviceLocalizations.stickrArchiveExpandedTooLarge);
    } finally {
      output.closeSync();
      entry.closeSync();
    }
  }

  _ValidatedSticker _validateWebp(String name, List<int> bytes) {
    try {
      final decoder = img.WebPDecoder();
      if (!decoder.isValidFile(bytes)) {
        throw PackException(serviceLocalizations.invalidStickerWebp);
      }
      final info = decoder.startDecode(bytes);
      if (info == null) {
        throw PackException(serviceLocalizations.invalidStickerWebp);
      }
      if (info.width != requiredStickerDimension ||
          info.height != requiredStickerDimension) {
        throw PackException(
          serviceLocalizations.invalidStickerDimensions(
            name,
            requiredStickerDimension,
            requiredStickerDimension,
          ),
        );
      }
      if (info.numFrames > maxWebpFrames) {
        throw PackException(serviceLocalizations.invalidStickerWebp);
      }
      final frameCount = max(1, info.numFrames);
      for (var frame = 0; frame < frameCount; frame++) {
        final image = decoder.decodeFrame(frame);
        if (image == null) {
          throw PackException(serviceLocalizations.invalidStickerWebp);
        }
        if (image.width != requiredStickerDimension ||
            image.height != requiredStickerDimension) {
          throw PackException(
            serviceLocalizations.invalidStickerDimensions(
              name,
              requiredStickerDimension,
              requiredStickerDimension,
            ),
          );
        }
      }
      return _ValidatedSticker(
        bytes: bytes,
        animated: _webpBytesLookAnimated(bytes),
      );
    } on PackException {
      rethrow;
    } catch (_) {
      throw PackException(serviceLocalizations.invalidStickerWebp);
    }
  }

  static bool _isSafeArchivePath(String name) {
    if (name.isEmpty ||
        name.startsWith('/') ||
        name.startsWith('\\') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(name)) {
      return false;
    }
    final segments = name.split('/');
    return !segments.any(
      (segment) =>
          segment.isEmpty && segment != segments.last ||
          segment == '.' ||
          segment == '..',
    );
  }

  static bool _webpBytesLookAnimated(List<int> bytes) {
    if (bytes.length < 21) return false;
    final fourcc = String.fromCharCodes(bytes.sublist(12, 16));
    return fourcc == 'VP8X' && (bytes[20] & 0x02) != 0;
  }

  Future<void> _rollbackImport(
    String? packId,
    Directory? stagingDirectory,
  ) async {
    if (packId != null) {
      try {
        await repository.deletePack(packId);
      } catch (_) {
        // Rollback continues so temporary files are still removed.
      }
    }
    _deleteDirectory(stagingDirectory);
  }

  void _deleteUnretainedStaging(
    Directory? stagingDirectory,
    StickerPack imported,
  ) {
    if (stagingDirectory == null || !stagingDirectory.existsSync()) return;
    final retained = imported.stickers
        .map((sticker) => File(sticker.filePath).absolute.path)
        .toSet();
    for (final entity in stagingDirectory.listSync()) {
      if (entity is File && !retained.contains(entity.absolute.path)) {
        entity.deleteSync();
      }
    }
    if (stagingDirectory.listSync().isEmpty) {
      stagingDirectory.deleteSync();
    }
  }

  static void _deleteDirectory(Directory? directory) {
    if (directory == null || !directory.existsSync()) return;
    try {
      directory.deleteSync(recursive: true);
    } on FileSystemException {
      // Cleanup is best effort after a failed import.
    }
  }
}

class _StickrManifest {
  const _StickrManifest({
    required this.name,
    required this.publisher,
    required this.stickerCount,
  });
  final String name;
  final String publisher;
  final int? stickerCount;
}

class _ArchiveEntries {
  const _ArchiveEntries({
    required this.manifest,
    required this.tray,
    required this.stickers,
  });

  final ArchiveFile manifest;
  final ArchiveFile? tray;
  final List<ArchiveFile> stickers;
}

class _ValidatedSticker {
  const _ValidatedSticker({required this.bytes, required this.animated});

  final List<int> bytes;
  final bool animated;
}

class _ArchiveBudget {
  _ArchiveBudget(this.maximum);

  final int maximum;
  int used = 0;

  int get remaining => maximum - used;

  void consume(int bytes) {
    if (bytes < 0 || bytes > remaining) {
      throw const _ArchiveSizeLimitException();
    }
    used += bytes;
  }
}

class _BoundedOutputMemoryStream extends OutputMemoryStream {
  _BoundedOutputMemoryStream({required this.maxBytes, required int initialSize})
    : super(size: initialSize);

  final int maxBytes;

  void _ensureCapacity(int additionalBytes) {
    if (additionalBytes < 0 || length + additionalBytes > maxBytes) {
      throw const _ArchiveSizeLimitException();
    }
  }

  @override
  void writeByte(int value) {
    _ensureCapacity(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final count = length ?? bytes.length;
    _ensureCapacity(count);
    super.writeBytes(bytes, length: count);
  }

  @override
  void writeStream(InputStream stream) {
    _ensureCapacity(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    _ensureCapacity(count);
    super.writeBackReference(distance, count);
  }
}

class _ArchiveSizeLimitException implements Exception {
  const _ArchiveSizeLimitException();
}
