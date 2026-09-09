import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repoRoot = Directory.current.path;

  test('Appfile uses the Play package and service account key path', () {
    final appfile = File('$repoRoot/android/fastlane/Appfile')
        .readAsStringSync();
    expect(appfile, contains('package_name("com.stickr.stickr")'));
    expect(
      appfile,
      contains('File.expand_path("play-store-credentials.json", __dir__)'),
    );
  });

  test('beta lane cleans, bumps versionCode, builds an obfuscated AAB, and uploads internally', () {
    final fastfile = File('$repoRoot/android/fastlane/Fastfile')
        .readAsStringSync();
    expect(fastfile, contains('lane :beta'));
    expect(fastfile, contains('flutter", "clean'));
    expect(fastfile, contains('increment_flutter_version_code'));
    expect(fastfile, contains('"appbundle"'));
    expect(fastfile, contains('"--release"'));
    expect(fastfile, contains('"--obfuscate"'));
    expect(fastfile, contains('--split-debug-info='));
    expect(fastfile, contains('--dart-define-from-file='));
    expect(fastfile, contains('upload_to_play_store'));
    expect(fastfile, contains('track: "internal"'));
    expect(fastfile, contains('app-release.aab'));
  });

  test('release signing requires a keystore file or environment values', () {
    final gradle = File('$repoRoot/android/app/build.gradle.kts')
        .readAsStringSync();
    expect(gradle, contains('rootProject.file("key.properties")'));
    expect(gradle, contains('"ANDROID_KEY_ALIAS"'));
    expect(gradle, contains('"ANDROID_KEY_PASSWORD"'));
    expect(gradle, contains('"ANDROID_STORE_PASSWORD"'));
    expect(gradle, contains('"ANDROID_STORE_FILE"'));
    expect(gradle, contains('throw GradleException('));
    expect(gradle, contains('signingConfigs.getByName("release")'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(
      File('$repoRoot/android/key.properties.example').existsSync(),
      isTrue,
    );
  });

  test('Fastlane package matches the Android application ID', () {
    final appfile = File('$repoRoot/android/fastlane/Appfile')
        .readAsStringSync();
    final gradle = File('$repoRoot/android/app/build.gradle.kts')
        .readAsStringSync();

    expect(appfile, contains('package_name("com.stickr.stickr")'));
    expect(gradle, contains('applicationId = appId'));
    expect(gradle, contains('val appId = "com.stickr.stickr"'));
  });

  test('Play Store credentials and the keystore are gitignored', () {
    final gitignore = File('$repoRoot/android/.gitignore').readAsStringSync();
    expect(gitignore, contains('key.properties'));
    expect(gitignore, contains('**/*.jks'));
    expect(gitignore, contains('fastlane/play-store-credentials.json'));
    expect(gitignore, contains('/release-defines.json'));
  });

  test('Gradle wrapper executables and jar are tracked by policy', () {
    final gitignore = File('$repoRoot/android/.gitignore').readAsStringSync();

    expect(gitignore, isNot(contains('/gradlew')));
    expect(gitignore, isNot(contains('/gradlew.bat')));
    expect(gitignore, isNot(contains('gradle-wrapper.jar')));
    expect(File('$repoRoot/android/gradlew').existsSync(), isTrue);
    expect(File('$repoRoot/android/gradlew.bat').existsSync(), isTrue);
    expect(
      File('$repoRoot/android/gradle/wrapper/gradle-wrapper.jar').existsSync(),
      isTrue,
    );
  });

  test('Fastlane Gemfile pins the release dependency', () {
    final gemfile = File('$repoRoot/android/fastlane/Gemfile')
        .readAsStringSync();
    final readme = File('$repoRoot/README.md').readAsStringSync();

    expect(gemfile, contains('gem "fastlane", "= 2.228.0"'));
    expect(readme, contains('bundle lock'));
    expect(readme, contains('bundle exec fastlane android beta'));
  });

  test('pubspec version is in the x.y.z+build form Fastlane increments', () {
    final pubspec = File('$repoRoot/pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      matches(RegExp(r'^version:\s*\d+\.\d+\.\d+\+\d+\s*$', multiLine: true)),
    );
  });
}
