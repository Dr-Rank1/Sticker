import 'dart:io';

class StickerFileStore {
  const StickerFileStore({required this.temporaryPath});

  final String temporaryPath;

  Future<StickerFilePlacement> place({
    required File source,
    required File destination,
  }) async {
    final transferOwnership = await _isOwnedTemporaryFile(source);
    if (!transferOwnership) {
      await source.copy(destination.path);
      return StickerFilePlacement(
        source: source,
        destination: destination,
        transferredOwnership: false,
      );
    }

    try {
      await source.rename(destination.path);
    } on FileSystemException {
      await source.copy(destination.path);
      try {
        await source.delete();
      } catch (_) {
        if (await destination.exists()) {
          await destination.delete();
        }
        rethrow;
      }
    }
    return StickerFilePlacement(
      source: source,
      destination: destination,
      transferredOwnership: true,
    );
  }

  Future<bool> _isOwnedTemporaryFile(File source) async {
    try {
      final root = await Directory(temporaryPath).resolveSymbolicLinks();
      final candidate = await source.resolveSymbolicLinks();
      return candidate.startsWith(_withSeparator(root));
    } on FileSystemException {
      return false;
    }
  }

  static String _withSeparator(String path) {
    return path.endsWith(Platform.pathSeparator)
        ? path
        : '$path${Platform.pathSeparator}';
  }
}

class StickerFilePlacement {
  const StickerFilePlacement({
    required this.source,
    required this.destination,
    required this.transferredOwnership,
  });

  final File source;
  final File destination;
  final bool transferredOwnership;

  Future<void> rollback() async {
    if (!await destination.exists()) return;
    if (!transferredOwnership || await source.exists()) {
      await destination.delete();
      return;
    }
    try {
      await destination.rename(source.path);
    } on FileSystemException {
      await destination.copy(source.path);
      await destination.delete();
    }
  }
}
