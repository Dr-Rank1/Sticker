import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repoRoot = Directory.current.path;

  test(
    'manifest verifies https App Links for tiktok.com and vm.tiktok.com',
    () {
      final manifest = File(
        '$repoRoot/android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:autoVerify="true"'));
      expect(manifest, contains('android:host="tiktok.com"'));
      expect(manifest, contains('android:host="www.tiktok.com"'));
      expect(manifest, contains('android:host="vm.tiktok.com"'));
      expect(manifest, contains('android.intent.action.VIEW'));
      expect(manifest, contains('android.intent.category.BROWSABLE'));
    },
  );

  test(
    'assetlinks.json names the app package and a SHA256 fingerprint slot',
    () {
      final json = jsonDecode(
        File('$repoRoot/.well-known/assetlinks.json').readAsStringSync(),
      ) as List<dynamic>;
      expect(json, isNotEmpty);
      final target = (json.first as Map)['target'] as Map;
      expect(target['namespace'], 'android_app');
      expect(target['package_name'], 'com.stickr.stickr');
      expect(target['sha256_cert_fingerprints'], isA<List>());
      expect((target['sha256_cert_fingerprints'] as List), isNotEmpty);
    },
  );
}
