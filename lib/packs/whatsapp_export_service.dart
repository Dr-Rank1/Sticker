import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pack_models.dart';

class WhatsAppExportResult {
  const WhatsAppExportResult({required this.pack, required this.message});

  final StickerPack pack;
  final String message;
}

class WhatsAppNotInstalledException extends PackException {
  const WhatsAppNotInstalledException()
    : super('WhatsApp isn’t installed on this device.');
}

class WhatsAppExportService {
  WhatsAppExportService({
    MethodChannel? channel,
    Future<bool> Function(Uri url)? canLaunch,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _canLaunch = canLaunch ?? canLaunchUrl;

  static const channelName = 'com.stickerapp/whatsapp_export';
  static const addStickerPackMethod = 'addStickerPack';
  static final whatsAppUri = Uri.parse('whatsapp://send');

  final MethodChannel _channel;
  final Future<bool> Function(Uri url) _canLaunch;

  WhatsAppExportResult prepare(StickerPack pack) {
    if (!pack.canExportToWhatsApp) {
      throw PackException(pack.exportBlockReason);
    }
    return WhatsAppExportResult(
      pack: pack,
      message:
          kIsWeb ||
              defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.macOS
          ? 'This pack is WhatsApp-ready (${pack.stickers.length} stickers, 96×96 tray). Add to WhatsApp from an Android or iOS build.'
          : 'This pack meets WhatsApp’s rules. Connect it from a device build with WhatsApp installed.',
    );
  }

  Future<WhatsAppExportResult> exportToWhatsApp(StickerPack pack) async {
    prepare(pack);

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const PackException(
        'Add to WhatsApp is available on Android with WhatsApp installed.',
      );
    }

    if (!await isWhatsAppInstalled()) {
      throw const WhatsAppNotInstalledException();
    }

    try {
      await _channel.invokeMethod<void>(addStickerPackMethod, {
        'identifier': pack.whatsAppIdentifier,
        'name': pack.name.trim(),
        'publisher': pack.author.trim(),
        'trayIconPath': pack.trayIconPath,
        'stickerPaths': [for (final sticker in pack.stickers) sticker.filePath],
        'imageDataVersion': pack.updatedAt.millisecondsSinceEpoch.toString(),
        'animated': pack.stickers.any((sticker) => sticker.animated),
      });
      return WhatsAppExportResult(pack: pack, message: 'Added to WhatsApp.');
    } on PlatformException catch (error) {
      throw PackException(_messageFor(error));
    } on MissingPluginException {
      throw const PackException(
        'Couldn’t reach the WhatsApp export on this device.',
      );
    }
  }

  /// The `whatsapp://` scheme is handled by either consumer WhatsApp or
  /// WhatsApp Business, so one check covers both Android packages.
  Future<bool> isWhatsAppInstalled() async {
    try {
      return await _canLaunch(whatsAppUri);
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  String _messageFor(PlatformException error) {
    switch (error.code) {
      case 'WHATSAPP_NOT_INSTALLED':
        throw const WhatsAppNotInstalledException();
      case 'CANCELLED':
        return 'WhatsApp didn’t add the pack.';
      case 'VALIDATION_ERROR':
        final detail = error.message?.trim();
        return (detail == null || detail.isEmpty)
            ? 'WhatsApp rejected this pack.'
            : detail;
      case 'FILE_COPY_FAILED':
        return error.message ?? 'Couldn’t prepare sticker files for WhatsApp.';
      case 'ALREADY_IN_PROGRESS':
        return 'An export is already in progress.';
      case 'INVALID_ARGUMENTS':
        return 'This pack is missing data WhatsApp needs.';
      default:
        return error.message ?? 'Couldn’t add this pack to WhatsApp.';
    }
  }
}

final whatsAppExportServiceProvider = Provider<WhatsAppExportService>((ref) {
  return WhatsAppExportService();
});
