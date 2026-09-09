import 'package:isar/isar.dart';

part 'sticker_pack.g.dart';

/// Isar collection for locally owned sticker packs.
///
/// The 96x96 tray icon is stored as a byte array so the Library grid can render
/// without a disk round-trip.
@collection
class StickerPack {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String identifier;

  late String name;

  late String publisher;

  List<byte> trayIconBytes = [];

  int createdAtMillis = 0;

  int updatedAtMillis = 0;

  List<StickerRecord> stickers = [];

  /// Retained for one schema migration so existing path-only rows can be read.
  List<String> stickerPaths = [];
}

@embedded
class StickerRecord {
  String id = '';

  String filePath = '';

  int createdAtMillis = 0;

  bool animated = true;

  String accessibilityText = '';
}
