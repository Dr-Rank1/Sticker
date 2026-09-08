import 'package:flutter/foundation.dart';

class WhatsAppPackRules {
  static const int minStickers = 3;
  static const int maxStickers = 30;
  static const int traySize = 96;
  static const int maxNameLength = 128;
  static const int maxAuthorLength = 128;
}

@immutable
class StickerItem {
  const StickerItem({
    required this.id,
    required this.filePath,
    required this.createdAt,
    this.animated = true,
  });

  final String id;
  final String filePath;
  final DateTime createdAt;
  final bool animated;

  Map<String, dynamic> toMap() => {
        'id': id,
        'filePath': filePath,
        'createdAt': createdAt.toIso8601String(),
        'animated': animated,
      };

  factory StickerItem.fromMap(Map<dynamic, dynamic> map) {
    return StickerItem(
      id: map['id'] as String,
      filePath: map['filePath'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      animated: map['animated'] as bool? ?? true,
    );
  }
}

@immutable
class StickerPack {
  const StickerPack({
    required this.id,
    required this.name,
    required this.author,
    required this.trayIconPath,
    required this.stickers,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String author;
  final String trayIconPath;
  final List<StickerItem> stickers;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFull => stickers.length >= WhatsAppPackRules.maxStickers;

  bool get meetsMinimum => stickers.length >= WhatsAppPackRules.minStickers;

  /// WhatsApp packs are either all static or all animated.
  bool? get animatedKind {
    if (stickers.isEmpty) return null;
    return stickers.any((sticker) => sticker.animated);
  }

  bool acceptsSticker({required bool animated}) {
    final kind = animatedKind;
    return kind == null || kind == animated;
  }

  bool get canExportToWhatsApp {
    return name.trim().isNotEmpty &&
        author.trim().isNotEmpty &&
        trayIconPath.trim().isNotEmpty &&
        stickers.length >= WhatsAppPackRules.minStickers &&
        stickers.length <= WhatsAppPackRules.maxStickers;
  }

  String get exportBlockReason {
    if (name.trim().isEmpty) return 'Give this pack a name.';
    if (author.trim().isEmpty) return 'Add an author name.';
    if (trayIconPath.trim().isEmpty) {
      return 'Add a ${WhatsAppPackRules.traySize}×${WhatsAppPackRules.traySize} tray icon.';
    }
    final count = stickers.length;
    if (count < WhatsAppPackRules.minStickers) {
      final need = WhatsAppPackRules.minStickers - count;
      return 'Add $need more sticker${need == 1 ? '' : 's'} to export (minimum ${WhatsAppPackRules.minStickers}).';
    }
    if (count > WhatsAppPackRules.maxStickers) {
      final extra = count - WhatsAppPackRules.maxStickers;
      return 'Remove $extra sticker${extra == 1 ? '' : 's'} to export (maximum ${WhatsAppPackRules.maxStickers}).';
    }
    return '';
  }

  String get countLabel {
    final n = stickers.length;
    return '$n / ${WhatsAppPackRules.maxStickers}';
  }

  /// WhatsApp pack identifiers must be alphanumeric with `.`, `_`, or `-`.
  String get whatsAppIdentifier {
    final cleaned = id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'pack' : cleaned;
  }

  StickerPack copyWith({
    String? name,
    String? author,
    String? trayIconPath,
    List<StickerItem>? stickers,
    DateTime? updatedAt,
  }) {
    return StickerPack(
      id: id,
      name: name ?? this.name,
      author: author ?? this.author,
      trayIconPath: trayIconPath ?? this.trayIconPath,
      stickers: stickers ?? this.stickers,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'author': author,
        'trayIconPath': trayIconPath,
        'stickers': stickers.map((s) => s.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StickerPack.fromMap(Map<dynamic, dynamic> map) {
    final rawStickers = map['stickers'] as List<dynamic>? ?? const [];
    return StickerPack(
      id: map['id'] as String,
      name: map['name'] as String,
      author: map['author'] as String,
      trayIconPath: map['trayIconPath'] as String? ?? '',
      stickers: [
        for (final item in rawStickers)
          StickerItem.fromMap(Map<dynamic, dynamic>.from(item as Map)),
      ],
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

class PackException implements Exception {
  const PackException(this.message);
  final String message;
  @override
  String toString() => message;
}
