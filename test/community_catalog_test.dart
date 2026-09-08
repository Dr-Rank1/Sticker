import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stikk/community/community_catalog.dart';
import 'package:stikk/community/community_models.dart';

CommunityCatalog loadBundledCatalog() {
  return CommunityCatalog.fromJsonString(
    File('assets/community/packs.json').readAsStringSync(),
  );
}

void main() {
  test('bundled catalog has 10 offline mock packs', () {
    final catalog = loadBundledCatalog();

    expect(catalog.packs, hasLength(10));
    expect(catalog.byId('comm_monday_moods')?.name, 'Monday moods');
    expect(catalog.byId('comm_monday_moods')?.author, 'nina.makes');
    expect(catalog.byId('comm_monday_moods')?.tags, containsAll(['funny', 'relatable']));
    expect(
      catalog.packs.every((pack) => pack.coverUrl.startsWith('https://')),
      isTrue,
    );
    expect(
      catalog.packs.every((pack) => pack.stickers.isNotEmpty),
      isTrue,
    );
  });

  test('download labels compact large counts', () {
    expect(
      CommunityPack(
        id: 'x',
        name: 'x',
        author: 'a',
        coverUrl: 'https://example.com/cover.png',
        downloads: 128400,
        tags: ['funny'],
        createdAt: DateTime(2026, 1, 1),
        blurb: '',
        stickers: [],
      ).downloadLabel,
      '128.4k',
    );
  });

  test('feed sorts trending by downloads and newest by date', () {
    final catalog = loadBundledCatalog();
    final trending = catalog.feed(CommunityFeedFilter.trending);
    final newest = catalog.feed(CommunityFeedFilter.newest);

    expect(trending.first.name, 'Anime reactions');
    expect(trending.first.downloads, greaterThan(trending.last.downloads));
    expect(newest.first.name, 'Weekend plans');
    expect(newest.first.createdAt.isAfter(newest.last.createdAt), isTrue);
  });
}
