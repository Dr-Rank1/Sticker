import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pack_models.dart';
import 'pack_repository.dart';

final packRepositoryProvider = Provider<PackRepository>((ref) {
  return InMemoryPackRepository();
});

final packsProvider = AsyncNotifierProvider<PacksController, List<StickerPack>>(
  PacksController.new,
);

final packByIdProvider = Provider.family<StickerPack?, String>((ref, id) {
  final packs = ref.watch(packsProvider).value;
  if (packs == null) return null;
  for (final pack in packs) {
    if (pack.id == id) return pack;
  }
  return null;
});

class PacksController extends AsyncNotifier<List<StickerPack>> {
  PackRepository get _repo => ref.read(packRepositoryProvider);

  @override
  Future<List<StickerPack>> build() {
    return _repo.getAll();
  }

  Future<void> refresh() async {
    state = AsyncData(await _repo.getAll());
  }

  Future<StickerPack> createPack({
    required String name,
    required String author,
  }) async {
    final pack = await _repo.createPack(name: name, author: author);
    await refresh();
    return pack;
  }

  Future<StickerPack> renamePack({
    required String packId,
    required String name,
    required String author,
  }) async {
    final current = await _repo.getById(packId);
    if (current == null) {
      throw const PackException('That pack no longer exists.');
    }
    final updated = await _repo.updatePack(
      current.copyWith(name: name, author: author),
    );
    await refresh();
    return updated;
  }

  Future<StickerPack> addSticker({
    required String packId,
    required String sourcePath,
    bool animated = true,
  }) async {
    final pack = await _repo.addSticker(
      packId: packId,
      sourcePath: sourcePath,
      animated: animated,
    );
    await refresh();
    return pack;
  }

  Future<void> removeSticker({
    required String packId,
    required String stickerId,
  }) async {
    await _repo.removeSticker(packId: packId, stickerId: stickerId);
    await refresh();
  }

  Future<void> deletePack(String id) async {
    await _repo.deletePack(id);
    await refresh();
  }

  /// Finds or creates the static "Comment stickers" pack and adds a WebP.
  Future<StickerPack> saveStaticStickerToLibrary(String sourcePath) async {
    final packs = await _repo.getAll();
    StickerPack? target;
    for (final pack in packs) {
      if (pack.name == commentPackName &&
          pack.acceptsSticker(animated: false) &&
          !pack.isFull) {
        target = pack;
        break;
      }
    }
    target ??= await _repo.createPack(
      name: commentPackName,
      author: commentPackAuthor,
    );
    final updated = await _repo.addSticker(
      packId: target.id,
      sourcePath: sourcePath,
      animated: false,
    );
    await refresh();
    return updated;
  }
}

const commentPackName = 'Comment stickers';
const commentPackAuthor = 'Stikk';
