import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikk/packs/pack_models.dart';
import 'package:stikk/packs/whatsapp_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(WhatsAppExportService.channelName);

  StickerPack pack({String id = 'pack_123', int stickers = 3}) {
    final now = DateTime(2026, 1, 1);
    return StickerPack(
      id: id,
      name: 'Moods',
      author: 'Ian',
      trayIconPath: 'tray.png',
      stickers: [
        for (var i = 0; i < stickers; i++)
          StickerItem(id: 's$i', filePath: 's$i.webp', createdAt: now),
      ],
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sanitizes WhatsApp pack identifiers', () {
    expect(pack().whatsAppIdentifier, 'pack_123');
    expect(pack(id: 'pack/unsafe id!').whatsAppIdentifier, 'pack_unsafe_id_');
  });

  test('blocks export on non-Android platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      () => WhatsAppExportService().exportToWhatsApp(pack()),
      throwsA(
        isA<PackException>().having(
          (error) => error.message,
          'message',
          contains('Android'),
        ),
      ),
    );
  });

  test('maps WhatsApp not installed to a pack error', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, WhatsAppExportService.addStickerPackMethod);
          expect(call.arguments['identifier'], 'pack_123');
          throw PlatformException(code: 'WHATSAPP_NOT_INSTALLED');
        });

    expect(
      () =>
          WhatsAppExportService(canLaunch: (_) async => true)
              .exportToWhatsApp(pack()),
      throwsA(
        isA<WhatsAppNotInstalledException>().having(
          (error) => error.message,
          'message',
          'WhatsApp isn’t installed on this device.',
        ),
      ),
    );
  });

  test('checks for WhatsApp before invoking the native export', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var nativeInvoked = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeInvoked = true;
          return true;
        });

    final service = WhatsAppExportService(
      canLaunch: (uri) async {
        expect(uri, WhatsAppExportService.whatsAppUri);
        return false;
      },
    );

    await expectLater(
      service.exportToWhatsApp(pack()),
      throwsA(isA<WhatsAppNotInstalledException>()),
    );
    expect(nativeInvoked, isFalse);
  });

  test('reports success when the native channel completes', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, WhatsAppExportService.addStickerPackMethod);
          expect(call.arguments['identifier'], 'pack_123');
          expect(call.arguments['name'], 'Moods');
          expect(call.arguments['publisher'], 'Ian');
          expect(call.arguments['stickerPaths'], [
            's0.webp',
            's1.webp',
            's2.webp',
          ]);
          expect(call.arguments['trayIconPath'], 'tray.png');
          expect(call.arguments['animated'], isTrue);
          return true;
        });

    final result = await WhatsAppExportService(canLaunch: (_) async => true)
        .exportToWhatsApp(pack());
    expect(result.message, 'Added to WhatsApp.');
  });
}
