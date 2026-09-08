import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikk/packs/pack_providers.dart';
import 'package:stikk/packs/pack_repository.dart';

void main() {
  test('saves formatted comment stickers into a Library pack', () async {
    final repo = InMemoryPackRepository();
    final container = ProviderContainer(
      overrides: [packRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container.read(packsProvider.future);
    final first = await container
        .read(packsProvider.notifier)
        .saveStaticStickerToLibrary('first.webp');

    expect(first.name, commentPackName);
    expect(first.author, commentPackAuthor);
    expect(first.stickers, hasLength(1));
    expect(first.stickers.single.animated, isFalse);
    expect(first.stickers.single.filePath, 'first.webp');

    await container
        .read(packsProvider.notifier)
        .saveStaticStickerToLibrary('second.webp');
    final packs = container.read(packsProvider).value!;
    expect(packs, hasLength(1));
    expect(packs.single.stickers, hasLength(2));
  });
}
