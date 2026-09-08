import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../packs/pack_models.dart';
import '../packs/pack_providers.dart';
import 'community_models.dart';

/// Offline mock catalog for the Community tab. Packs live in
/// `assets/community/packs.json` so the feed needs no backend.
class CommunityCatalog {
  const CommunityCatalog(this.packs);

  static const assetPath = 'assets/community/packs.json';

  final List<CommunityPack> packs;

  factory CommunityCatalog.fromJson(Map<String, dynamic> json) {
    final raw = json['packs'] as List<dynamic>? ?? const [];
    return CommunityCatalog([
      for (final item in raw)
        CommunityPack.fromJson(Map<String, dynamic>.from(item as Map)),
    ]);
  }

  factory CommunityCatalog.fromJsonString(String raw) {
    return CommunityCatalog.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  static Future<CommunityCatalog> loadFromAsset({AssetBundle? bundle}) async {
    final source = bundle ?? rootBundle;
    final raw = await source.loadString(assetPath);
    return CommunityCatalog.fromJsonString(raw);
  }

  CommunityPack? byId(String id) {
    for (final pack in packs) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  List<CommunityPack> feed(CommunityFeedFilter filter) {
    final copy = [...packs];
    switch (filter) {
      case CommunityFeedFilter.trending:
      case CommunityFeedFilter.popular:
        copy.sort((a, b) => b.downloads.compareTo(a.downloads));
      case CommunityFeedFilter.newest:
        copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return copy;
  }
}

final communityCatalogProvider = FutureProvider<CommunityCatalog>((ref) {
  return CommunityCatalog.loadFromAsset();
});

final communityDownloadDelayProvider = Provider<Duration>((ref) {
  return const Duration(milliseconds: 1100);
});

final downloadedCommunityIdsProvider =
    NotifierProvider<CommunityDownloadController, Set<String>>(
  CommunityDownloadController.new,
);

class CommunityDownloadController extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  bool isDownloaded(String packId) => state.contains(packId);

  Future<StickerPack> download(CommunityPack pack) async {
    if (state.contains(pack.id)) {
      final existing = await ref.read(packsProvider.future);
      for (final item in existing) {
        if (item.name == pack.name && item.author == pack.author) {
          return item;
        }
      }
    }

    await Future<void>.delayed(ref.read(communityDownloadDelayProvider));
    final created = await ref.read(packsProvider.notifier).createPack(
          name: pack.name,
          author: pack.author,
        );
    state = {...state, pack.id};
    return created;
  }
}
