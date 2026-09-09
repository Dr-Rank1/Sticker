import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/editor/image_sticker_service.dart';
import 'package:stickr/packs/batch_export_use_case.dart';
import 'package:stickr/packs/pack_models.dart';
import 'package:stickr/packs/pack_repository.dart';
import 'package:stickr/packs/tray_icon_service.dart';
import 'package:stickr/packs/whatsapp_export_service.dart';
import 'package:stickr/tiktok/comment_sticker_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stickr_batch_test_');
  });
  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test(
    'bounds concurrent work and saves only after WhatsApp confirms',
    () async {
      final repository = InMemoryPackRepository();
      final whatsApp = _ControlledWhatsAppExportService();
      var activeDownloads = 0;
      var maximumActiveDownloads = 0;
      final downloads = <File>[];
      final useCase = BatchExportUseCase(
        repository,
        whatsApp,
        _CopyingFormatter(directory),
        trayIcons: _FakeTrayIconService(),
        temporaryDirectory: () async => directory,
        identifierGenerator: () => 'batch_test',
        maxConcurrentItems: 2,
      );

      final eventsFuture = useCase
          .export(
            items: [
              for (var index = 0; index < 5; index++)
                BatchExportItem(
                  id: 'item_$index',
                  accessibilityText: 'Sticker $index',
                  download: () async {
                    activeDownloads += 1;
                    if (activeDownloads > maximumActiveDownloads) {
                      maximumActiveDownloads = activeDownloads;
                    }
                    await Future<void>.delayed(
                      const Duration(milliseconds: 10),
                    );
                    final file = File('${directory.path}/download_$index.gif');
                    await file.writeAsString('source-$index');
                    downloads.add(file);
                    activeDownloads -= 1;
                    return BatchExportDownload(file: file);
                  },
                ),
            ],
            packName: 'Batch Pack',
            author: 'Stickr',
          )
          .toList();

      await whatsApp.called.future;
      expect(await repository.getAll(), isEmpty);
      whatsApp.confirm.complete();

      final events = await eventsFuture;
      final packs = await repository.getAll();
      expect(maximumActiveDownloads, 2);
      expect(
        events.where((event) => event.stage == BatchExportStage.itemReady),
        hasLength(5),
      );
      expect(events.last.stage, BatchExportStage.complete);
      expect(events.last.result?.pack.id, 'batch_test');
      expect(packs, hasLength(1));
      expect(packs.single.id, whatsApp.exportedPack?.id);
      expect(packs.single.stickers, hasLength(5));
      expect(
        packs.single.stickers.map((sticker) => sticker.accessibilityText),
        ['Sticker 0', 'Sticker 1', 'Sticker 2', 'Sticker 3', 'Sticker 4'],
      );
      expect(downloads.every((file) => !file.existsSync()), isTrue);
    },
  );

  test('failed WhatsApp launch does not create a local pack', () async {
    final repository = InMemoryPackRepository();
    final useCase = BatchExportUseCase(
      repository,
      _FailingWhatsAppExportService(),
      _CopyingFormatter(directory),
      trayIcons: _FakeTrayIconService(),
      temporaryDirectory: () async => directory,
      identifierGenerator: () => 'failed_batch',
    );
    final items = <BatchExportItem>[];
    for (var index = 0; index < 3; index++) {
      final source = File('${directory.path}/source_$index.gif');
      await source.writeAsString('source-$index');
      items.add(
        BatchExportItem(
          id: 'item_$index',
          download: () async =>
              BatchExportDownload(file: source, deleteAfterUse: false),
        ),
      );
    }

    Object? error;
    try {
      await useCase
          .export(items: items, packName: 'Failed', author: 'Stickr')
          .drain<void>();
    } catch (caught) {
      error = caught;
    }

    expect(error, isA<PackException>());
    expect(await repository.getAll(), isEmpty);
    expect(items, hasLength(3));
  });
}

class _CopyingFormatter extends CommentStickerFormatter {
  _CopyingFormatter(this.directory) : super(ImageStickerService());

  final Directory directory;
  var sequence = 0;

  @override
  Future<File> makeWhatsAppReady(File source) async {
    final output = File('${directory.path}/ready_${sequence++}.webp');
    await source.copy(output.path);
    return output;
  }
}

class _FakeTrayIconService extends TrayIconService {
  @override
  Future<File> createDefault({
    required Directory directory,
    required String packId,
    required String name,
    Color background = const Color(0xFF00C48C),
  }) async {
    final file = File('${directory.path}/tray.png');
    await file.writeAsBytes([1, 2, 3]);
    return file;
  }
}

class _ControlledWhatsAppExportService extends WhatsAppExportService {
  final called = Completer<void>();
  final confirm = Completer<void>();
  StickerPack? exportedPack;

  @override
  Future<WhatsAppExportResult> exportToWhatsApp(StickerPack pack) async {
    exportedPack = pack;
    called.complete();
    await confirm.future;
    return WhatsAppExportResult(pack: pack, message: 'Added to WhatsApp.');
  }
}

class _FailingWhatsAppExportService extends WhatsAppExportService {
  @override
  Future<WhatsAppExportResult> exportToWhatsApp(StickerPack pack) {
    throw const PackException('WhatsApp rejected the pack.');
  }
}
