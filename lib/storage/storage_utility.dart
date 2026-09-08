import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class StorageUsage {
  const StorageUsage({required this.documentsBytes, required this.cacheBytes});

  final int documentsBytes;
  final int cacheBytes;

  int get totalBytes => documentsBytes + cacheBytes;
}

class CacheClearResult {
  const CacheClearResult({
    required this.bytesFreed,
    required this.filesDeleted,
  });

  final int bytesFreed;
  final int filesDeleted;
}

/// Measures app-owned storage and removes Stikk's disposable working files.
///
/// Pack stickers under the documents directory are never treated as cache.
class StorageUtility {
  StorageUtility({
    Future<Directory> Function()? documentsDirectory,
    Future<Directory> Function()? temporaryDirectory,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final Future<Directory> Function() _documentsDirectory;
  final Future<Directory> Function() _temporaryDirectory;

  Future<StorageUsage> getUsage() async {
    final documents = await _documentsDirectory();
    final temporary = await _temporaryDirectory();
    return StorageUsage(
      documentsBytes: await directorySize(documents),
      cacheBytes: await _stikkCacheSize(temporary),
    );
  }

  Future<int> directorySize(Directory directory) async {
    if (!await directory.exists()) return 0;

    var bytes = 0;
    try {
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            bytes += await entity.length();
          } on FileSystemException {
            // A file can disappear while the directory is being measured.
          }
        }
      }
    } on FileSystemException {
      // Return the bytes measured so far if the OS revokes an entry.
    }
    return bytes;
  }

  /// Recursively deletes disposable `.mp4` and `.png` files from the OS
  /// temporary directory. Final `.webp` stickers in documents are not scanned.
  Future<CacheClearResult> cleanupTemporaryMedia() async {
    final temporary = await _temporaryDirectory();
    if (!await temporary.exists()) {
      return const CacheClearResult(bytesFreed: 0, filesDeleted: 0);
    }

    var bytesFreed = 0;
    var filesDeleted = 0;
    try {
      await for (final entity in temporary.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        if (!isTemporaryMediaFile(entity.path)) continue;
        try {
          final bytes = await entity.length();
          await entity.delete();
          bytesFreed += bytes;
          filesDeleted += 1;
        } on FileSystemException {
          // A file can disappear or stay locked while cleanup is running.
        }
      }
    } on FileSystemException {
      // Return the deletions completed before the OS revoked an entry.
    }
    return CacheClearResult(bytesFreed: bytesFreed, filesDeleted: filesDeleted);
  }

  /// Working video and overlay files written under the temporary directory.
  static bool isTemporaryMediaFile(String path) {
    final name = path.split(Platform.pathSeparator).last.toLowerCase();
    return name.endsWith('.mp4') || name.endsWith('.png');
  }

  Future<CacheClearResult> clearCache() async {
    final temporary = await _temporaryDirectory();
    if (!await temporary.exists()) {
      return const CacheClearResult(bytesFreed: 0, filesDeleted: 0);
    }

    var bytesFreed = 0;
    var filesDeleted = 0;
    await for (final entity in temporary.list(followLinks: false)) {
      if (!_isStikkEntity(entity)) continue;
      final result = await _deleteEntity(entity);
      bytesFreed += result.bytesFreed;
      filesDeleted += result.filesDeleted;
    }
    return CacheClearResult(bytesFreed: bytesFreed, filesDeleted: filesDeleted);
  }

  /// Removes known raw and intermediate files after the final WebP is copied
  /// to permanent app storage. Paths outside Stikk's temp directory are ignored.
  Future<CacheClearResult> cleanupAfterStickerSaved(
    Iterable<String?> paths,
  ) async {
    final temporary = await _temporaryDirectory();
    final root = _withSeparator(temporary.absolute.path);
    var bytesFreed = 0;
    var filesDeleted = 0;

    for (final path in paths.whereType<String>().toSet()) {
      final entity = File(path);
      final absolutePath = entity.absolute.path;
      if (!absolutePath.startsWith(root) || !_isStikkEntity(entity)) continue;
      final result = await _deleteEntity(entity);
      bytesFreed += result.bytesFreed;
      filesDeleted += result.filesDeleted;
    }

    return CacheClearResult(bytesFreed: bytesFreed, filesDeleted: filesDeleted);
  }

  Future<int> _stikkCacheSize(Directory temporary) async {
    if (!await temporary.exists()) return 0;
    var bytes = 0;
    await for (final entity in temporary.list(followLinks: false)) {
      if (_isStikkEntity(entity)) {
        bytes += entity is Directory
            ? await directorySize(entity)
            : await _fileSize(entity);
      }
    }
    return bytes;
  }

  bool _isStikkEntity(FileSystemEntity entity) {
    final name = entity.path.split(Platform.pathSeparator).last;
    return name.startsWith('stikk_');
  }

  Future<CacheClearResult> _deleteEntity(FileSystemEntity entity) async {
    try {
      if (!await entity.exists()) {
        return const CacheClearResult(bytesFreed: 0, filesDeleted: 0);
      }
      final bytes = entity is Directory
          ? await directorySize(entity)
          : await _fileSize(entity);
      final count = entity is Directory ? await _fileCount(entity) : 1;
      await entity.delete(recursive: true);
      return CacheClearResult(bytesFreed: bytes, filesDeleted: count);
    } on FileSystemException {
      return const CacheClearResult(bytesFreed: 0, filesDeleted: 0);
    }
  }

  Future<int> _fileSize(FileSystemEntity entity) async {
    try {
      return entity is File ? await entity.length() : 0;
    } on FileSystemException {
      return 0;
    }
  }

  Future<int> _fileCount(Directory directory) async {
    var count = 0;
    try {
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) count++;
      }
    } on FileSystemException {
      // Report the count gathered before the inaccessible entry.
    }
    return count;
  }

  String _withSeparator(String path) {
    return path.endsWith(Platform.pathSeparator)
        ? path
        : '$path${Platform.pathSeparator}';
  }
}

String formatStorageBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  final megabytes = kilobytes / 1024;
  if (megabytes < 1024) return '${megabytes.toStringAsFixed(1)} MB';
  return '${(megabytes / 1024).toStringAsFixed(1)} GB';
}

final storageUtilityProvider = Provider<StorageUtility>((ref) {
  return StorageUtility();
});

final storageUsageProvider = FutureProvider<StorageUsage>((ref) {
  return ref.read(storageUtilityProvider).getUsage();
});
