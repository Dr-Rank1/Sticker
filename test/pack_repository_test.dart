import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:stickr/database/sticker_pack.dart' as isar_db;
import 'package:stickr/packs/pack_models.dart';
import 'package:stickr/packs/pack_repository.dart';
import 'package:stickr/packs/sticker_repository.dart';
import 'package:stickr/packs/whatsapp_export_service.dart';

StickerPack _pack({
  int stickers = 0,
  String name = 'Moods',
  String author = 'Ian',
  List<int> trayIconBytes = const [1, 2, 3],
}) {
  return StickerPack(
    id: 'p1',
    name: name,
    author: author,
    trayIconPath: 'tray.png',
    trayIconBytes: trayIconBytes,
    stickers: [
      for (var i = 0; i < stickers; i++)
        StickerItem(
          id: 's$i',
          filePath: 's$i.webp',
          createdAt: DateTime(2026, 1, 1),
        ),
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('WhatsApp pack rules', () {
    test('blocks export below 3 stickers', () {
      final two = _pack(stickers: 2);
      expect(two.canExportToWhatsApp, isFalse);
      expect(two.exportBlockReason, contains('minimum 3'));
    });

    test('allows export from 3 to 30 stickers', () {
      expect(_pack(stickers: 3).canExportToWhatsApp, isTrue);
      expect(_pack(stickers: 30).canExportToWhatsApp, isTrue);
    });

    test('blocks export above 30 stickers', () {
      final overflow = _pack(stickers: 31);
      expect(overflow.canExportToWhatsApp, isFalse);
      expect(overflow.exportBlockReason, contains('maximum 30'));
    });

    test('WhatsAppExportService rejects invalid packs', () {
      expect(
        () => WhatsAppExportService().prepare(_pack(stickers: 1)),
        throwsA(isA<PackException>()),
      );
    });
  });

  group('InMemoryPackRepository', () {
    test('creates a pack and refuses a 31st sticker', () async {
      final repo = InMemoryPackRepository();
      final created = await repo.createPack(name: 'Pets', author: 'Ian');
      expect(created.trayIconPath, isNotEmpty);

      for (var i = 0; i < WhatsAppPackRules.maxStickers; i++) {
        await repo.addSticker(
          packId: created.id,
          sourcePath: 'sticker_$i.webp',
        );
      }

      expect(
        () => repo.addSticker(packId: created.id, sourcePath: 'too_many.webp'),
        throwsA(isA<PackException>()),
      );
      final full = await repo.getById(created.id);
      expect(full!.stickers, hasLength(30));
    });

    test('refuses mixing static and animated stickers', () async {
      final repo = InMemoryPackRepository();
      final created = await repo.createPack(name: 'Mix', author: 'Ian');
      await repo.addSticker(packId: created.id, sourcePath: 'clip.webp');

      expect(
        () => repo.addSticker(
          packId: created.id,
          sourcePath: 'photo.webp',
          animated: false,
        ),
        throwsA(isA<PackException>()),
      );
    });

    test(
      'save throws ValidationException below 3 and above 30 stickers',
      () async {
        final repo = InMemoryPackRepository();

        await expectLater(
          repo.save(_pack(stickers: 2)),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repo.save(_pack(stickers: 31)),
          throwsA(isA<ValidationException>()),
        );

        final saved = await repo.save(_pack(stickers: 3));
        expect(saved.stickers, hasLength(3));
        final maxed = await repo.save(_pack(stickers: 30));
        expect(maxed.stickers, hasLength(30));
        expect(maxed.updatedAt.isAfter(saved.updatedAt), isTrue);
      },
    );

    test('watchAll emits when a sticker is added', () async {
      final repo = InMemoryPackRepository();
      final events = <List<StickerPack>>[];
      final sub = repo.watchAll().listen(events.add);
      addTearDown(sub.cancel);

      await pumpEventQueue();
      expect(events, isNotEmpty);
      expect(events.last, isEmpty);

      final created = await repo.createPack(name: 'Pets', author: 'Ian');
      await repo.addSticker(packId: created.id, sourcePath: 'sticker.webp');
      await pumpEventQueue();

      expect(events.last, hasLength(1));
      expect(events.last.single.stickers, hasLength(1));
    });

    test(
      'every pack mutation strictly increases the update revision',
      () async {
        final repo = InMemoryPackRepository();
        final created = await repo.createPack(name: 'Pets', author: 'Ian');
        final renamed = await repo.updatePack(
          created.copyWith(name: 'Favorite pets'),
        );
        final added = await repo.addSticker(
          packId: created.id,
          sourcePath: 'sticker.webp',
        );
        final removed = await repo.removeSticker(
          packId: created.id,
          stickerId: added.stickers.single.id,
        );

        expect(renamed.updatedAt.isAfter(created.updatedAt), isTrue);
        expect(added.updatedAt.isAfter(renamed.updatedAt), isTrue);
        expect(removed.updatedAt.isAfter(added.updatedAt), isTrue);
        expect(
          int.parse(removed.imageDataVersion),
          removed.updatedAt.millisecondsSinceEpoch,
        );
      },
    );
  });

  group('StickerRepository', () {
    StickerRepository? repo;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      try {
        await Isar.initializeIsarCore(download: true);
      } catch (_) {
        // Flutter plugin binaries may already be loaded.
      }
    });

    tearDown(() async {
      await repo?.close(deleteFromDisk: true);
      repo = null;
    });

    Future<StickerRepository?> openRepo() async {
      final dir = await Directory.systemTemp.createTemp('stickr_isar');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      try {
        repo = await StickerRepository.open(
          directory: dir.path,
          name: 'stickr_packs_${dir.path.hashCode}',
          documents: () async => dir,
        );
        return repo;
      } catch (error) {
        markTestSkipped('Isar native libraries are unavailable: $error');
        return null;
      }
    }

    test(
      'save enforces WhatsApp sticker counts and watchAll updates',
      () async {
        final opened = await openRepo();
        if (opened == null) {
          return;
        }

        await expectLater(
          opened.save(_pack(stickers: 2)),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          opened.save(_pack(stickers: 31)),
          throwsA(isA<ValidationException>()),
        );

        final events = <List<StickerPack>>[];
        final sub = opened.watchAll().listen(events.add);
        addTearDown(sub.cancel);

        final saved = await opened.save(_pack(stickers: 3));
        expect(saved.id, 'p1');
        expect(saved.stickers, hasLength(3));
        expect(saved.trayIconBytes, isNotEmpty);
        expect(File(saved.trayIconPath).existsSync(), isTrue);
        final firstRow = await opened.isar.stickerPacks.getByIdentifier('p1');
        expect(firstRow, isNotNull);
        expect(firstRow!.createdAtMillis, greaterThan(0));
        expect(firstRow.updatedAtMillis, greaterThan(firstRow.createdAtMillis));
        expect(firstRow.stickerPaths, isEmpty);
        expect(firstRow.stickers, hasLength(3));
        expect(firstRow.stickers.first.id, 's0');
        expect(firstRow.stickers.first.animated, isTrue);
        expect(firstRow.stickers.first.accessibilityText, isEmpty);

        final firstRevision = firstRow.updatedAtMillis;
        final savedAgain = await opened.save(saved);
        final secondRow = await opened.isar.stickerPacks.getByIdentifier('p1');
        expect(secondRow!.createdAtMillis, firstRow.createdAtMillis);
        expect(secondRow.updatedAtMillis, greaterThan(firstRevision));
        expect(
          savedAgain.updatedAt.millisecondsSinceEpoch,
          secondRow.updatedAtMillis,
        );

        await pumpEventQueue();
        expect(events.where((packs) => packs.isNotEmpty), isNotEmpty);
        expect(events.last.single.stickers, hasLength(3));
      },
    );
  });
}
