import 'package:flutter/foundation.dart';

@immutable
class CommunitySticker {
  const CommunitySticker({
    this.id = '',
    required this.label,
    required this.imageUrl,
    this.width = 512,
    this.height = 512,
    this.animated = false,
  });

  final String id;
  final String label;
  final String imageUrl;
  final int width;
  final int height;
  final bool animated;

  String get stableId => id.isEmpty ? imageUrl : id;

  double get aspectRatio {
    if (width <= 0 || height <= 0) return 1;
    return (width / height).clamp(0.72, 1.35);
  }

  factory CommunitySticker.fromJson(Map<String, dynamic> json) {
    return CommunitySticker(
      id: json['id']?.toString() ?? '',
      label: json['label'] as String,
      imageUrl: json['imageUrl'] as String,
      width: json['width'] as int? ?? 512,
      height: json['height'] as int? ?? 512,
      animated: json['animated'] as bool? ?? false,
    );
  }
}

@immutable
class CommunityPack {
  const CommunityPack({
    required this.id,
    required this.name,
    required this.author,
    required this.coverUrl,
    required this.downloads,
    required this.tags,
    required this.createdAt,
    required this.blurb,
    required this.stickers,
  });

  final String id;
  final String name;
  final String author;
  final String coverUrl;
  final int downloads;
  final List<String> tags;
  final DateTime createdAt;
  final String blurb;
  final List<CommunitySticker> stickers;

  String get downloadLabel {
    if (downloads >= 1000000) {
      return '${_compactCount(downloads / 1000000)}M';
    }
    if (downloads >= 1000) {
      return '${_compactCount(downloads / 1000)}k';
    }
    return '$downloads';
  }

  static String _compactCount(double value) {
    return value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  }

  factory CommunityPack.fromJson(Map<String, dynamic> json) {
    final tags = (json['tags'] as List<dynamic>? ?? const [])
        .map((tag) => tag.toString())
        .toList();
    final stickers = (json['stickers'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              CommunitySticker.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    return CommunityPack(
      id: json['id'] as String,
      name: json['name'] as String,
      author: json['author'] as String,
      coverUrl: json['coverUrl'] as String,
      downloads: json['downloads'] as int? ?? 0,
      tags: tags,
      createdAt: DateTime.parse(json['createdAt'] as String),
      blurb: json['blurb'] as String? ?? '',
      stickers: stickers,
    );
  }
}

enum CommunityFeedFilter { trending, newest, popular }

extension CommunityFeedFilterX on CommunityFeedFilter {
  String get label => switch (this) {
    CommunityFeedFilter.trending => 'Trending',
    CommunityFeedFilter.newest => 'New',
    CommunityFeedFilter.popular => 'Popular',
  };
}
