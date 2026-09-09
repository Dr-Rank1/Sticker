import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firebase options contain only explicit placeholder project values', () {
    final options = File('lib/firebase_options.dart').readAsStringSync();

    expect(options, contains('stickr-production-placeholder'));
    expect(options, contains('REPLACE_WITH_ANDROID_API_KEY'));
    expect(options, contains('REPLACE_WITH_IOS_API_KEY'));
    expect(options, isNot(contains('stikk.appspot.com')));
    expect(options, contains("iosBundleId: 'com.stickr.stickr'"));
  });

  test('Android release enables Crashlytics mapping and native symbols', () {
    final rootGradle = File('android/build.gradle.kts').readAsStringSync();
    final appGradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(
      rootGradle,
      contains('id("com.google.firebase.crashlytics") apply false'),
    );
    expect(appGradle, contains('id("com.google.firebase.crashlytics")'));
    expect(appGradle, contains('mappingFileUploadEnabled = true'));
    expect(appGradle, contains('nativeSymbolUploadEnabled = true'));
  });

  test('debug Google Services configuration uses the mock project', () {
    final file = File('android/app/src/debug/google-services.json');
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final project = data['project_info'] as Map<String, dynamic>;
    final clients = data['client'] as List<dynamic>;
    final client = clients.single as Map<String, dynamic>;
    final clientInfo = client['client_info'] as Map<String, dynamic>;
    final androidInfo =
        clientInfo['android_client_info'] as Map<String, dynamic>;

    expect(project['project_id'], 'stickr-production-placeholder');
    expect(androidInfo['package_name'], 'com.stickr.stickr');
  });
}
