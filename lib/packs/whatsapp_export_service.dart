import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../analytics/analytics_service.dart';
import '../l10n/l10n.dart';
import 'pack_models.dart';

class WhatsAppExportResult {
  const WhatsAppExportResult({required this.pack, required this.message});

  final StickerPack pack;
  final String message;
}

class WhatsAppNotInstalledException extends PackException {
  WhatsAppNotInstalledException()
    : super(serviceLocalizations.whatsAppNotInstalledDevice);
}

class WhatsAppExportService {
  WhatsAppExportService({
    MethodChannel? channel,
    Future<bool> Function(Uri url)? canLaunch,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _canLaunch = canLaunch ?? canLaunchUrl;

  static const channelName = 'com.stickerapp/whatsapp_export';
  static const addStickerPackMethod = 'addStickerPack';
  static const contentProviderAuthority =
      'com.stickr.stickr.stickercontentprovider';
  static const enableStickerPackAction =
      'com.whatsapp.intent.action.ENABLE_STICKER_PACK';
  static final whatsAppUri = Uri.parse('whatsapp://send');

  final MethodChannel _channel;
  final Future<bool> Function(Uri url) _canLaunch;

  WhatsAppExportResult prepare(StickerPack pack) {
    if (!pack.canExportToWhatsApp) {
      unawaited(
        analyticsService.packValidationFailed(
          category: _validationCategory(pack),
          stickerCount: pack.stickers.length,
        ),
      );
      throw PackException(pack.exportBlockReason);
    }
    return WhatsAppExportResult(
      pack: pack,
      message:
          kIsWeb ||
              defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.macOS
          ? serviceLocalizations.whatsAppReadyDesktop(pack.stickers.length)
          : serviceLocalizations.whatsAppReadyDevice,
    );
  }

  Future<WhatsAppExportResult> exportToWhatsApp(StickerPack pack) async {
    try {
      prepare(pack);
    } on PackException {
      await _logExportResult(pack, WhatsAppExportOutcome.validationFailed);
      rethrow;
    }

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      await _logExportResult(pack, WhatsAppExportOutcome.platformUnavailable);
      throw PackException(serviceLocalizations.whatsAppAndroidOnly);
    }

    if (!await isWhatsAppInstalled()) {
      await _logExportResult(pack, WhatsAppExportOutcome.notInstalled);
      throw WhatsAppNotInstalledException();
    }

    try {
      await _channel.invokeMethod<void>(addStickerPackMethod, {
        'identifier': pack.whatsAppIdentifier,
        'name': pack.name.trim(),
        'publisher': pack.author.trim(),
        'trayIconPath': pack.trayIconPath,
        'stickerPaths': [for (final sticker in pack.stickers) sticker.filePath],
        'imageDataVersion': pack.imageDataVersion,
        'animated': pack.stickers.any((sticker) => sticker.animated),
      });
      await _logExportResult(pack, WhatsAppExportOutcome.success);
      return WhatsAppExportResult(
        pack: pack,
        message: serviceLocalizations.addedToWhatsApp,
      );
    } on PlatformException catch (error) {
      await _logExportResult(
        pack,
        error.code == 'CANCELLED'
            ? WhatsAppExportOutcome.cancelled
            : error.code == 'VALIDATION_ERROR'
            ? WhatsAppExportOutcome.validationFailed
            : WhatsAppExportOutcome.failed,
      );
      throw PackException(_messageFor(error));
    } on MissingPluginException {
      await _logExportResult(pack, WhatsAppExportOutcome.platformUnavailable);
      throw PackException(serviceLocalizations.couldNotReachWhatsAppExport);
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
        throw WhatsAppNotInstalledException();
      case 'CANCELLED':
        return serviceLocalizations.whatsAppDidNotAddPack;
      case 'VALIDATION_ERROR':
        final detail = error.message?.trim();
        return (detail == null || detail.isEmpty)
            ? serviceLocalizations.whatsAppRejectedPack
            : detail;
      case 'FILE_COPY_FAILED':
        return error.message ??
            serviceLocalizations.couldNotPrepareWhatsAppFiles;
      case 'ALREADY_IN_PROGRESS':
        return serviceLocalizations.exportAlreadyInProgress;
      case 'INVALID_ARGUMENTS':
        return serviceLocalizations.packMissingWhatsAppData;
      default:
        return error.message ?? serviceLocalizations.couldNotAddPackToWhatsApp;
    }
  }

  Future<void> _logExportResult(
    StickerPack pack,
    WhatsAppExportOutcome outcome,
  ) {
    return analyticsService.exportWhatsAppResult(
      outcome: outcome,
      stickerCount: pack.stickers.length,
      animated: pack.stickers.any((sticker) => sticker.animated),
    );
  }

  PackValidationCategory _validationCategory(StickerPack pack) {
    if (pack.stickers.length < WhatsAppPackRules.minStickers) {
      return PackValidationCategory.tooFewStickers;
    }
    if (pack.stickers.length > WhatsAppPackRules.maxStickers) {
      return PackValidationCategory.tooManyStickers;
    }
    return PackValidationCategory.invalidMetadata;
  }
}

final whatsAppExportServiceProvider = Provider<WhatsAppExportService>((ref) {
  return WhatsAppExportService();
});
