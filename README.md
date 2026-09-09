# Stickr

Stickr is an Android-first Flutter application for creating, organizing,
sharing, and exporting WhatsApp sticker packs. It produces static and animated
512 by 512 WebP stickers from photos, local videos, TikTok clips, meme
templates, Giphy results, and TikTok comment images.

## Product capabilities

- Create static stickers from gallery photos or the camera.
- Remove photo backgrounds on-device with ML Kit selfie segmentation.
- Import local gallery videos after validating size, duration, codec, and
  dimensions.
- Resolve TikTok videos through TikWM and edit the downloaded clip.
- Trim video, change playback speed, and add text or emoji overlays.
- Search Giphy stickers with offset pagination in Discover.
- Browse live Giphy trending stickers in Community and collect 3 to 30 items
  in the staging tray.
- Scan TikTok comments through Apify and batch-export selected image comments.
- Create and edit local packs, then add them to WhatsApp through the Android
  content-provider integration.
- Share and import hardened `.stickr` pack archives.

Native WhatsApp export is currently Android-only. The configured minimum is
Android 7.0, API level 24.

## Architecture and storage

### Persistence

Sticker packs use Isar, not Hive. Each persisted pack includes:

- Stable pack and sticker identifiers.
- Explicit creation and monotonic update timestamps.
- Embedded sticker metadata, including animation type and accessibility text.
- A generated 96 by 96 tray icon.
- Permanent sticker files under app-owned document storage.

Hive is used only for lightweight application settings. It is not the pack
database.

Editor output remains in the app-owned `stickr_temp` cache until the user
selects a pack. `StickerRepository` then transfers ownership directly into the
selected pack, avoiding duplicate permanent files. Dismissing the chooser
deletes the temporary WebP.

### Network services

- Giphy powers trending Community content and paginated Discover search.
- Apify uses
  `api-ninja~tiktok-comments-scraper/run-sync-get-dataset-items` with a
  50-comment input limit.
- TikWM resolves downloadable TikTok video media.
- Imgflip supplies meme templates.
- Google Fonts supplies optional editor fonts.

Giphy, Apify, and TikWM use the shared Dio client with explicit timeouts,
bounded safe-GET retries, `Retry-After` support, cancellation, and normalized
errors.

### Media processing

The editor uses `ffmpeg_kit_flutter_new`, a GPL-enabled FFmpeg Kit package with
`libwebp`, for static and animated WebP encoding. Photo segmentation runs
locally. Temporary media is restricted to `stickr_temp`.

See [FFMPEG_GPL_NOTICE.md](LICENSES/FFMPEG_GPL_NOTICE.md) and the in-app
Settings > About & licenses screen for source and license information.

### `.stickr` archives

A `.stickr` file is a ZIP archive containing:

- `manifest.json`
- `tray.png`
- `stickers/*.webp`

Imports enforce a 5 MB compressed limit, a 20 MB expanded limit, bounded
per-entry decompression, CRC checks, safe relative paths, duplicate-name and
symbolic-link rejection, WebP decoding, and exact 512 by 512 dimensions.
Failures roll back the pack row and all extracted files.

## Repository layout

- `lib/editor/`: editor state, overlays, static export, FFmpeg, and background
  removal.
- `lib/packs/`: Isar persistence, pack validation, `.stickr` archives, and
  WhatsApp export.
- `lib/community/`: Giphy models, service, and trending feed.
- `lib/discover/`: paginated Giphy search UI.
- `lib/tiktok/`: TikWM import, Apify comment scraping, and comment formatting.
- `lib/photos/`: camera and gallery photo workflow.
- `lib/memes/`: Imgflip templates.
- `lib/network/`: shared Dio behavior and normalized failures.
- `lib/analytics/` and `lib/crashlytics/`: categorized, privacy-restricted
  health telemetry.
- `android/`: Android application, Gradle wrapper, content provider, and
  Fastlane release tooling.

## Prerequisites

Install:

- Flutter 3.47.2 or a compatible SDK using Dart `^3.13.2`.
- Java 17.
- Android Studio or Android command-line tools.
- An Android SDK supporting the configured compile SDK.
- Ruby and Bundler only when using Fastlane.

Verify the local toolchain:

```sh
flutter doctor
java -version
```

## Initial setup

```sh
git clone https://github.com/Dr-Rank1/Sticker.git
cd Sticker
flutter pub get
flutter gen-l10n
```

The repository tracks `android/gradlew`, `android/gradlew.bat`, and
`android/gradle/wrapper/gradle-wrapper.jar`. CI and local Android builds should
use this checked-in wrapper.

## API configuration

The application reads required API values from compile-time Dart defines.
Never commit live values.

Required:

- `GIPHY_API_KEY`
- `APIFY_API_TOKEN`

Run the app:

```sh
flutter run \
  --dart-define=GIPHY_API_KEY=your_giphy_key \
  --dart-define=APIFY_API_TOKEN=your_apify_token
```

TikWM and Imgflip do not require keys.

## Firebase configuration

Committed Firebase values are mock debug placeholders. Authenticate and
replace them before a production build:

```sh
dart pub global activate flutterfire_cli
firebase login
flutterfire configure \
  --project=your-production-project \
  --platforms=android,ios \
  --android-package-name=com.stickr.stickr \
  --ios-bundle-id=com.stickr.stickr
```

Production `android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist` are ignored. Provision them locally or
through protected CI secrets.

Crashlytics collection is enabled only in release builds. Release Gradle tasks
upload R8 mapping information and enable native symbol processing. Analytics
records fixed categories and buckets; it does not accept full file paths,
TikTok URLs, overlay text, or media bytes.

## Development checks

Run the same checks used by pull-request CI:

```sh
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Build a debug APK:

```sh
flutter build apk --debug
```

The output is `build/app/outputs/flutter-apk/app-debug.apk`.

## Android release build

### 1. Configure signing

Copy the example:

```sh
cp android/key.properties.example android/key.properties
```

Populate `android/key.properties`:

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=replace_with_store_password
keyAlias=replace_with_key_alias
keyPassword=replace_with_key_password
```

Alternatively provide `ANDROID_STORE_FILE`, `ANDROID_STORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`. Release builds fail rather
than falling back to debug signing when these values are missing.

### 2. Configure release Dart defines

```sh
cp android/release-defines.example.json android/release-defines.json
```

Replace both placeholder values. The destination file is ignored.

### 3. Configure production Firebase

Place the real Android service file at:

```text
android/app/google-services.json
```

### 4. Build

```sh
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --dart-define-from-file=android/release-defines.json
```

The output is `build/app/outputs/bundle/release/app-release.aab`. Retain
`build/debug-info` for Dart crash deobfuscation.

## Fastlane dependency locking and release

Fastlane dependencies are declared in `android/fastlane/Gemfile` with an exact
Fastlane version. Generate and commit its lock file on a Ruby-enabled release
machine:

```sh
cd android/fastlane
gem install bundler --no-document
bundle lock
bundle config set --local path vendor/bundle
bundle install
git add Gemfile Gemfile.lock
```

Before running the lane, complete the signing, release-define, Firebase, and
Google Play service-account setup described above. Then run:

```sh
cd android/fastlane
bundle exec fastlane android beta
```

The beta lane cleans the project, increments the Flutter build number, creates
an obfuscated release AAB with split debug information, and uploads it to the
Google Play internal track.

## Privacy and legal notes

- Photos and generated packs remain in app-owned storage.
- Photo segmentation runs on-device.
- TikTok URLs are sent to TikWM for video resolution.
- TikTok comment URLs are sent to the configured Apify actor.
- Giphy, Imgflip, Firebase, and Google Fonts receive requests when their
  corresponding features are used.
- Crash reports strip exception messages, private paths, and URLs.
- The application uses a GPL-enabled FFmpeg distribution. Release owners must
  preserve upstream notices, provide corresponding source or a valid written
  offer, and verify the exact binary license set before distribution.

## Current limitations

- WhatsApp pack export is Android-only.
- Firebase production identifiers and service files must be supplied by the
  release owner.
- The Community tab is a live Giphy feed, not an account-based marketplace.
- TikTok comment APIs can return text placeholders without image media; only
  comments containing actual image URLs can become stickers.
- Production Isar tests require compatible native libraries and may be skipped
  when those libraries are unavailable.
