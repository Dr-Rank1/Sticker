import 'dart:async';

import 'pack_models.dart';

abstract class PackRepository {
  Stream<List<StickerPack>> watchAll();
  Future<List<StickerPack>> getAll();
  Future<StickerPack?> getById(String id);
  Future<StickerPack> createPack({
    required String name,
    required String author,
  });
  Future<StickerPack> updatePack(StickerPack pack);
  Future<StickerPack> addSticker({
    required String packId,
    required String sourcePath,
    bool animated = true,
  });
  Future<StickerPack> removeSticker({
    required String packId,
    required String stickerId,
  });
  Future<void> deletePack(String id);

  /// Persists a pack after enforcing WhatsApp sticker-count rules.
  ///
  /// Throws [ValidationException] when the pack has fewer than
  /// [WhatsAppPackRules.minStickers] or more than
  /// [WhatsAppPackRules.maxStickers] stickers.
  Future<StickerPack> save(StickerPack pack);
}

class InMemoryPackRepository implements PackRepository {
  InMemoryPackRepository({Map<String, StickerPack>? seed})
    : _packs = {...?seed};

  final Map<String, StickerPack> _packs;
  final _controller = StreamController<List<StickerPack>>.broadcast();
  var _seq = 0;

  List<StickerPack> _sorted() {
    return _packs.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  void _notify() {
    if (!_controller.isClosed) {
      _controller.add(_sorted());
    }
  }

  @override
  Stream<List<StickerPack>> watchAll() async* {
    yield _sorted();
    yield* _controller.stream;
  }

  @override
  Future<List<StickerPack>> getAll() async => _sorted();

  @override
  Future<StickerPack?> getById(String id) async => _packs[id];

  @override
  Future<StickerPack> createPack({
    required String name,
    required String author,
  }) async {
    if (name.trim().isEmpty) {
      throw const PackException('Give this pack a name.');
    }
    if (author.trim().isEmpty) {
      throw const PackException('Add an author name.');
    }
    _seq += 1;
    final now = DateTime.now();
    final pack = StickerPack(
      id: 'mem_$_seq',
      name: name.trim(),
      author: author.trim(),
      trayIconPath: 'tray_$_seq.png',
      stickers: const [],
      createdAt: now,
      updatedAt: now,
    );
    _packs[pack.id] = pack;
    _notify();
    return pack;
  }

  @override
  Future<StickerPack> updatePack(StickerPack pack) async {
    final current = _packs[pack.id];
    if (current == null) {
      throw const PackException('That pack no longer exists.');
    }
    _packs[pack.id] = pack.copyWith(updatedAt: _nextRevision(current));
    _notify();
    return _packs[pack.id]!;
  }

  @override
  Future<StickerPack> addSticker({
    required String packId,
    required String sourcePath,
    bool animated = true,
  }) async {
    final pack = _packs[packId];
    if (pack == null) {
      throw const PackException('That pack no longer exists.');
    }
    if (pack.isFull) {
      throw const PackException(
        'WhatsApp packs can hold at most ${WhatsAppPackRules.maxStickers} stickers.',
      );
    }
    if (!pack.acceptsSticker(animated: animated)) {
      throw PackException(
        animated
            ? 'This pack is for static stickers. Create a new pack for animated ones.'
            : 'This pack is for animated stickers. Create a new pack for photo stickers.',
      );
    }
    _seq += 1;
    final next = pack.copyWith(
      stickers: [
        ...pack.stickers,
        StickerItem(
          id: 'sticker_$_seq',
          filePath: sourcePath,
          createdAt: DateTime.now(),
          animated: animated,
        ),
      ],
      updatedAt: _nextRevision(pack),
    );
    _packs[packId] = next;
    _notify();
    return next;
  }

  @override
  Future<StickerPack> removeSticker({
    required String packId,
    required String stickerId,
  }) async {
    final pack = _packs[packId];
    if (pack == null) {
      throw const PackException('That pack no longer exists.');
    }
    final stickers = [
      for (final sticker in pack.stickers)
        if (sticker.id != stickerId) sticker,
    ];
    if (stickers.length == pack.stickers.length) return pack;
    final next = pack.copyWith(
      stickers: stickers,
      updatedAt: _nextRevision(pack),
    );
    _packs[packId] = next;
    _notify();
    return next;
  }

  @override
  Future<void> deletePack(String id) async {
    _packs.remove(id);
    _notify();
  }

  @override
  Future<StickerPack> save(StickerPack pack) async {
    final count = pack.stickers.length;
    if (count < WhatsAppPackRules.minStickers ||
        count > WhatsAppPackRules.maxStickers) {
      throw const ValidationException(
        'WhatsApp packs must contain between ${WhatsAppPackRules.minStickers} and ${WhatsAppPackRules.maxStickers} stickers.',
      );
    }
    if (pack.name.trim().isEmpty) {
      throw const PackException('Give this pack a name.');
    }
    if (pack.author.trim().isEmpty) {
      throw const PackException('Add an author name.');
    }
    final current = _packs[pack.id];
    final next = pack.copyWith(
      updatedAt: current == null ? _nextRevision(pack) : _nextRevision(current),
    );
    _packs[pack.id] = next;
    _notify();
    return next;
  }

  DateTime _nextRevision(StickerPack pack) {
    final now = DateTime.now();
    return now.isAfter(pack.updatedAt)
        ? now
        : pack.updatedAt.add(const Duration(milliseconds: 1));
  }
}
