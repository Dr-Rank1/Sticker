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
