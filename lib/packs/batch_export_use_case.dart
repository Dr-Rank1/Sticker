import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_utility.dart';
import '../tiktok/comment_sticker_formatter.dart';
import 'pack_models.dart';
import 'pack_providers.dart';
import 'pack_repository.dart';
import 'tray_icon_service.dart';
import 'whatsapp_export_service.dart';

enum BatchExportStage {
  downloading,
  converting,
  itemReady,
  launchingWhatsApp,
  savingPack,
  complete,
}

class BatchExportDownload {
  const BatchExportDownload({required this.file, this.deleteAfterUse = true});

  final File file;
  final bool deleteAfterUse;
}

class BatchExportItem {
  const BatchExportItem({
    required this.id,
    required this.download,
    this.accessibilityText = '',
  });

  final String id;
  final Future<BatchExportDownload> Function() download;
  final String accessibilityText;
}

class BatchExportResult {
  const BatchExportResult({required this.pack, required this.message});

  final StickerPack pack;
  final String message;
}

class BatchExportProgress {
  const BatchExportProgress({
    required this.stage,
    required this.completedItems,
    required this.totalItems,
    this.itemId,
    this.itemIndex,
    this.result,
  });

  final BatchExportStage stage;
  final int completedItems;
  final int totalItems;
  final String? itemId;
  final int? itemIndex;
  final BatchExportResult? result;
}

class BatchExportUseCase {
  BatchExportUseCase(
    this._repository,
    this._whatsApp,
    this._formatter, {
    TrayIconService? trayIcons,
    Future<Directory> Function()? temporaryDirectory,
    DateTime Function()? clock,
    String Function()? identifierGenerator,
    this.maxConcurrentItems = 2,
  }) : _trayIcons = trayIcons ?? TrayIconService(),
       _temporaryDirectory =
           temporaryDirectory ?? (() => getStickrTemporaryDirectory()),
       _clock = clock ?? DateTime.now,
       _identifierGenerator = identifierGenerator ?? _newIdentifier {
    if (maxConcurrentItems < 1) {
      throw ArgumentError.value(
        maxConcurrentItems,
        'maxConcurrentItems',
        'Must be at least 1.',
      );
    }
  }

  final PackRepository _repository;
  final WhatsAppExportService _whatsApp;
  final CommentStickerFormatter _formatter;
  final TrayIconService _trayIcons;
  final Future<Directory> Function() _temporaryDirectory;
  final DateTime Function() _clock;
  final String Function() _identifierGenerator;
  final int maxConcurrentItems;

  Stream<BatchExportProgress> export({
    required List<BatchExportItem> items,
    required String packName,
    required String author,
  }) {
    late StreamController<BatchExportProgress> controller;
    controller = StreamController<BatchExportProgress>(
      onListen: () {
        unawaited(
          _run(
            controller,
            items: List<BatchExportItem>.unmodifiable(items),
            packName: packName,
            author: author,
          ),
        );
      },
    );
    return controller.stream;
  }

  Future<void> _run(
    StreamController<BatchExportProgress> controller, {
    required List<BatchExportItem> items,
    required String packName,
    required String author,
  }) async {
    final count = items.length;
    final cleanupFiles = <String, File>{};
    Directory? workspace;
    try {
      if (count < WhatsAppPackRules.minStickers ||
          count > WhatsAppPackRules.maxStickers) {
        throw const ValidationException(
          'WhatsApp packs must contain between ${WhatsAppPackRules.minStickers} and ${WhatsAppPackRules.maxStickers} stickers.',
        );
      }

      final readyFiles = List<File?>.filled(count, null);
      var nextIndex = 0;
      var completedItems = 0;

      Future<void> worker() async {
        while (nextIndex < count) {
          final index = nextIndex++;
          final item = items[index];
          _addProgress(
            controller,
            BatchExportProgress(
              stage: BatchExportStage.downloading,
              itemId: item.id,
              itemIndex: index,
              completedItems: completedItems,
              totalItems: count,
            ),
          );
          final downloaded = await item.download();
          if (downloaded.deleteAfterUse) {
            cleanupFiles[downloaded.file.path] = downloaded.file;
          }
          _addProgress(
            controller,
            BatchExportProgress(
              stage: BatchExportStage.converting,
              itemId: item.id,
              itemIndex: index,
              completedItems: completedItems,
              totalItems: count,
            ),
          );
          final ready = await _formatter.makeWhatsAppReady(downloaded.file);
          readyFiles[index] = ready;
          if (ready.path != downloaded.file.path || downloaded.deleteAfterUse) {
            cleanupFiles[ready.path] = ready;
          }
          completedItems += 1;
          _addProgress(
            controller,
            BatchExportProgress(
              stage: BatchExportStage.itemReady,
              itemId: item.id,
              itemIndex: index,
              completedItems: completedItems,
              totalItems: count,
            ),
          );
        }
      }

      final workerCount = min(maxConcurrentItems, count);
      await Future.wait(List.generate(workerCount, (_) => worker()));
      final completedFiles = readyFiles.cast<File>();
      final now = _clock();
      final identifier = _identifierGenerator();
      final temporary = await _temporaryDirectory();
      workspace = await Directory(
        '${temporary.path}${Platform.pathSeparator}stickr_batch_$identifier',
      ).create(recursive: true);
      final tray = await _trayIcons.createDefault(
        directory: workspace,
        packId: identifier,
        name: packName,
      );
      final trayBytes = await tray.readAsBytes();
      final draft = StickerPack(
        id: identifier,
        name: packName,
        author: author,
        trayIconPath: tray.path,
        trayIconBytes: trayBytes,
        stickers: [
          for (var index = 0; index < items.length; index++)
            StickerItem(
              id: _stableItemId(items[index].id, index),
              filePath: completedFiles[index].path,
              createdAt: now,
              animated: false,
              accessibilityText: items[index].accessibilityText,
            ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      _addProgress(
        controller,
        BatchExportProgress(
          stage: BatchExportStage.launchingWhatsApp,
          completedItems: count,
          totalItems: count,
        ),
      );
      final whatsAppResult = await _whatsApp.exportToWhatsApp(draft);

      _addProgress(
        controller,
        BatchExportProgress(
          stage: BatchExportStage.savingPack,
          completedItems: count,
          totalItems: count,
        ),
      );
      final saved = await _finalizePack(
        identifier: identifier,
        name: packName,
        author: author,
        files: completedFiles,
        items: items,
      );
      final result = BatchExportResult(
        pack: saved,
        message: whatsAppResult.message,
      );
      _addProgress(
        controller,
        BatchExportProgress(
          stage: BatchExportStage.complete,
          completedItems: count,
          totalItems: count,
          result: result,
        ),
      );
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    } finally {
      for (final file in cleanupFiles.values) {
        await _deleteFile(file);
      }
      if (workspace != null) {
        await _deleteDirectory(workspace);
      }
      await controller.close();
    }
  }

  Future<StickerPack> _finalizePack({
    required String identifier,
    required String name,
    required String author,
    required List<File> files,
    required List<BatchExportItem> items,
  }) async {
    final created = await _repository.createPack(
      name: name,
      author: author,
      identifier: identifier,
    );
    try {
      var current = created;
      for (var index = 0; index < files.length; index++) {
        current = await _repository.addSticker(
          packId: identifier,
          sourcePath: files[index].path,
          animated: false,
          accessibilityText: items[index].accessibilityText,
        );
      }
      return await _repository.save(current);
    } catch (_) {
      await _repository.deletePack(identifier);
      rethrow;
    }
  }

  void _addProgress(
    StreamController<BatchExportProgress> controller,
    BatchExportProgress progress,
  ) {
    if (!controller.isClosed) controller.add(progress);
  }

  Future<void> _deleteFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Temporary files may already have been reclaimed by the OS.
    }
  }

  Future<void> _deleteDirectory(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException {
      // Temporary files may already have been reclaimed by the OS.
    }
  }

  static String _stableItemId(String id, int index) {
    final cleaned = id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'sticker_$index' : cleaned;
  }

  static String _newIdentifier() {
    final random = Random.secure().nextInt(1 << 32);
    return 'batch_${DateTime.now().microsecondsSinceEpoch}_$random';
  }
}

final batchExportUseCaseProvider = Provider<BatchExportUseCase>((ref) {
  return BatchExportUseCase(
    ref.watch(packRepositoryProvider),
    ref.watch(whatsAppExportServiceProvider),
    ref.watch(commentStickerFormatterProvider),
  );
});
