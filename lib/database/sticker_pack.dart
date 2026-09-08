import 'package:isar/isar.dart';

part 'sticker_pack.g.dart';

/// Isar collection for locally owned sticker packs.
///
/// Stickers are stored as WebP file paths. The 96x96 tray icon is stored as a
/// byte array so the Library grid can render without a disk round-trip.
@collection
class StickerPack {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String identifier;

  late String name;

  late String publisher;

  late List<byte> trayIconBytes;

  late List<String> stickerPaths;
}
