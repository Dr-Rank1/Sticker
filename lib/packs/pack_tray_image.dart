import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pack_models.dart';

/// Renders a pack tray from in-database bytes, falling back to the on-disk PNG.
class PackTrayImage extends StatelessWidget {
  const PackTrayImage({
    super.key,
    required this.pack,
    required this.size,
    this.borderRadius = 16,
  });

  final StickerPack pack;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (pack.trayIconBytes.isNotEmpty) {
      child = Image.memory(
        Uint8List.fromList(pack.trayIconBytes),
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } else {
      final file = File(pack.trayIconPath);
      if (pack.trayIconPath.isNotEmpty && file.existsSync()) {
        child = Image.file(file, width: size, height: size, fit: BoxFit.cover);
      } else {
        child = ColoredBox(
          color: context.colors.surfaceMuted,
          child: Icon(
            Icons.auto_awesome_mosaic_rounded,
            color: context.colors.accent,
            size: size * 0.42,
          ),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}
