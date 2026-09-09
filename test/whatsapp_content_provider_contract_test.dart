import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/packs/whatsapp_export_service.dart';

void main() {
  test('WhatsApp ContentProvider authority is applicationId.stickercontentprovider', () {
    expect(
      WhatsAppExportService.contentProviderAuthority,
      'com.stikk.stikk.stickercontentprovider',
    );
    expect(
      WhatsAppExportService.contentProviderAuthority,
      startsWith('com.stikk.stikk.'),
    );
    expect(
      WhatsAppExportService.enableStickerPackAction,
      'com.whatsapp.intent.action.ENABLE_STICKER_PACK',
    );
  });

  test('export channel matches the native MethodChannel', () {
    expect(WhatsAppExportService.channelName, 'com.stickerapp/whatsapp_export');
    expect(WhatsAppExportService.addStickerPackMethod, 'addStickerPack');
  });
}
