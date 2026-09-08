import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repoRoot = Directory.current.path;

  test('Appfile uses the Play package placeholder and service account key path', () {
    final appfile = File('$repoRoot/android/fastlane/Appfile').readAsStringSync();
    expect(appfile, contains('package_name("com.yourdomain.stikk")'));
    expect(
      appfile,
      contains('json_key_file("fastlane/play-store-credentials.json")'),
    );
  });

  test('beta lane cleans, bumps versionCode, builds an obfuscated AAB, and uploads internally', () {
    final fastfile = File('$repoRoot/android/fastlane/Fastfile').readAsStringSync();
    expect(fastfile, contains('lane :beta'));
    expect(fastfile, contains('flutter", "clean'));
    expect(fastfile, contains('increment_flutter_version_code'));
    expect(fastfile, contains('"appbundle"'));
    expect(fastfile, contains('"--release"'));
    expect(fastfile, contains('"--obfuscate"'));
    expect(fastfile, contains('--split-debug-info='));
    expect(fastfile, contains('upload_to_play_store'));
    expect(fastfile, contains('track: "internal"'));
    expect(fastfile, contains('app-release.aab'));
  });

  test('release signing reads credentials from key.properties', () {
    final gradle = File(
      '$repoRoot/android/app/build.gradle.kts',
    ).readAsStringSync();
    expect(gradle, contains('rootProject.file("key.properties")'));
    expect(gradle, contains('keystoreProperties.getProperty("keyAlias")'));
    expect(gradle, contains('keystoreProperties.getProperty("storeFile")'));
    expect(gradle, contains('signingConfigs.getByName("release")'));
    expect(
      File('$repoRoot/android/key.properties.example').existsSync(),
      isTrue,
    );
  });

  test('Play Store credentials and the keystore are gitignored', () {
    final gitignore = File('$repoRoot/android/.gitignore').readAsStringSync();
    expect(gitignore, contains('key.properties'));
    expect(gitignore, contains('**/*.jks'));
    expect(gitignore, contains('fastlane/play-store-credentials.json'));
  });

  test('pubspec version is in the x.y.z+build form Fastlane increments', () {
    final pubspec = File('$repoRoot/pubspec.yaml').readAsStringSync();
    expect(pubspec, matches(RegExp(r'^version:\s*\d+\.\d+\.\d+\+\d+\s*$', multiLine: true)));
  });
}
