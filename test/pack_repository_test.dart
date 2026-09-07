import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:stikk/packs/pack_models.dart';
import 'package:stikk/packs/pack_repository.dart';
import 'package:stikk/packs/whatsapp_export_service.dart';

void main() {
  group('WhatsApp pack rules', () {
    StickerPack pack({int stickers = 0, String name = 'Moods', String author = 'Ian'}) {
      return StickerPack(
        id: 'p1',
        name: name,
        author: author,
        trayIconPath: 'tray.png',
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

    test('blocks export below 3 stickers', () {
      final two = pack(stickers: 2);
      expect(two.canExportToWhatsApp, isFalse);
      expect(two.exportBlockReason, contains('minimum 3'));
    });

    test('allows export from 3 to 30 stickers', () {
      expect(pack(stickers: 3).canExportToWhatsApp, isTrue);
      expect(pack(stickers: 30).canExportToWhatsApp, isTrue);
    });

    test('blocks export above 30 stickers', () {
      final overflow = pack(stickers: 31);
      expect(overflow.canExportToWhatsApp, isFalse);
      expect(overflow.exportBlockReason, contains('maximum 30'));
    });

    test('WhatsAppExportService rejects invalid packs', () {
      expect(
        () => WhatsAppExportService().prepare(pack(stickers: 1)),
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
        await repo.addSticker(packId: created.id, sourcePath: 'sticker_$i.webp');
      }

      expect(
        () => repo.addSticker(packId: created.id, sourcePath: 'too_many.webp'),
        throwsA(isA<PackException>()),
      );
      final full = await repo.getById(created.id);
      expect(full!.stickers, hasLength(30));
    });
  });

  group('HivePackRepository', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });
    test('persists packs to a local Hive box', () async {
      final dir = await Directory.systemTemp.createTemp('stikk_hive');
      addTearDown(() async {
        await Hive.close();
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      final source = File('${dir.path}${Platform.pathSeparator}clip.webp')
        ..writeAsBytesSync(const [1, 2, 3, 4]);

      final repo = await HivePackRepository.open(
        hivePath: dir.path,
        documents: () async => dir,
      );
      final pack = await repo.createPack(name: 'Gym', author: 'Lift Club');
      expect(File(pack.trayIconPath).existsSync(), isTrue);

      final withSticker = await repo.addSticker(
        packId: pack.id,
        sourcePath: source.path,
      );
      expect(withSticker.stickers, hasLength(1));

      final loaded = await repo.getById(pack.id);
      expect(loaded?.name, 'Gym');
      expect(loaded?.stickers, hasLength(1));
      expect(File(loaded!.stickers.first.filePath).existsSync(), isTrue);
    });
  });
}
