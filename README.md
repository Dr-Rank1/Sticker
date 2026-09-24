# Stickr

**Stickr** is an Android-first Flutter application for creating, organizing, sharing, and exporting WhatsApp sticker packs. It enables users to produce high-quality static and animated 512x512 WebP stickers from various media sources including photos, local videos, TikTok clips, meme templates, Giphy results, and TikTok comment images.

---

## Features

### Media Support & Editing
* **Static Stickers:** Create stickers from gallery photos or directly from the camera.
* **Intelligent Background Removal:** Leverages ML Kit selfie segmentation for on-device background removal.
* **Video Import:** Import local gallery videos with robust validation for size, duration, codec, and dimensions.
* **TikTok Integration:** Resolve TikTok videos via TikWM and edit downloaded clips on the fly.
* **Video Editing Tools:** Trim video clips, adjust playback speed, and overlay custom text or custom icons.

### Content Discovery
* **Giphy Search:** Search and discover Giphy stickers with seamless offset pagination.
* **Community Trending:** Browse live trending stickers and collect up to 30 items in a staging tray.
* **TikTok Comment Scraping:** Scan TikTok comments via Apify and batch-export images directly into stickers.
* **Meme Integration:** Access Imgflip meme templates for instant sticker creation.

### Pack Management & Export
* **Native WhatsApp Integration:** Create and edit local packs, then natively add them to WhatsApp via the Android content-provider integration.
* **Archive Sharing:** Export, share, and import hardened `.stickr` pack archives securely.
* **Local Persistence:** Uses Isar database for high-performance, structured local storage of packs and metadata.

*Note: Native WhatsApp export requires a minimum of Android 7.0 (API level 24).*

---

## Architecture

### Storage & Persistence
Stickr utilizes **Isar** as its primary persistence layer for sticker packs, completely avoiding Hive for core pack data. Each pack contains:
* Stable identifiers for packs and stickers.
* Creation and monotonic update timestamps.
* Embedded metadata (e.g., animation type, accessibility text).
* A generated 96x96 tray icon.
* Permanent WebP files managed under app-owned document storage.

Hive is reserved exclusively for lightweight application settings. 

The editor output is initially stored in a temporary cache (`stickr_temp`). Upon pack selection, ownership is transferred into the permanent pack storage to prevent duplicates.

### Network Services
Stickr relies on multiple robust services for content discovery and processing:
* **Giphy:** Powers trending and paginated search.
* **Apify:** Uses `api-ninja~tiktok-comments-scraper` to process up to 50 comments per run.
* **TikWM:** Resolves downloadable TikTok video media.
* **Imgflip:** Provides meme templates.
* **Google Fonts:** Offers customized fonts for the editor.

Network calls utilize a shared `Dio` client equipped with explicit timeouts, bounded safe-GET retries, `Retry-After` adherence, request cancellation, and normalized error handling.

### Media Processing
At the core of Stickr's media engine is `ffmpeg_kit_flutter_new`, a GPL-enabled FFmpeg Kit package complete with `libwebp` for top-tier static and animated WebP encoding. Photo segmentation is fully on-device. See [FFMPEG_GPL_NOTICE.md](LICENSES/FFMPEG_GPL_NOTICE.md) for detailed source and license information.

### The `.stickr` Archive Format
A `.stickr` file is a ZIP archive ensuring secure distribution. It contains:
* `manifest.json`
* `tray.png`
* `stickers/*.webp`

Imports are strictly validated (5 MB compressed / 20 MB expanded limit, CRC checks, dimension enforcement) to prevent malicious files and guarantee pack integrity.

---

## Repository Structure

* `lib/editor/`: Editor state, overlays, static export, FFmpeg processing, and background removal.
* `lib/packs/`: Isar persistence, validation, `.stickr` handling, and WhatsApp native export.
* `lib/community/`: Giphy models, service, and trending feed.
* `lib/discover/`: Paginated Giphy search user interface.
* `lib/tiktok/`: TikWM integration, Apify comment scraping, and parsing.
* `lib/photos/`: Camera and gallery photo workflows.
* `lib/memes/`: Imgflip templates integration.
* `lib/network/`: Shared Dio client and error normalization logic.
* `lib/analytics/` & `lib/crashlytics/`: Categorized, privacy-conscious health telemetry.
* `android/`: Native Android application, Gradle wrapper, content provider, and Fastlane automation.

---

## Getting Started

### Prerequisites
* **Flutter:** `3.47.2` (or compatible SDK using Dart `^3.13.2`)
* **Java:** `17`
* **Android:** Android Studio / Command-line tools supporting the configured compile SDK
* **Ruby & Bundler:** (Optional, required only for Fastlane)

Verify your environment:
```sh
flutter doctor
java -version
```

### Initial Setup
Clone the repository and install dependencies:
```sh
git clone https://github.com/Dr-Rank1/Sticker.git
cd Sticker
flutter pub get
flutter gen-l10n
```

### API Configuration
Required API keys must be provided as compile-time Dart defines (never commit live keys):
* `GIPHY_API_KEY`
* `APIFY_API_TOKEN`

Run the app:
```sh
flutter run \
  --dart-define=GIPHY_API_KEY=your_giphy_key \
  --dart-define=APIFY_API_TOKEN=your_apify_token
```

### Firebase Configuration
Before building for production, configure Firebase:
```sh
dart pub global activate flutterfire_cli
firebase login
flutterfire configure \
  --project=your-production-project \
  --platforms=android,ios \
  --android-package-name=com.stickr.stickr \
  --ios-bundle-id=com.stickr.stickr
```

*Note: Crashlytics and detailed telemetry are conditionally enabled for release builds to respect user privacy and development workflows.*

---

## Development & Testing

Run standard CI checks:
```sh
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Build a debug APK:
```sh
flutter build apk --debug
```

---

## Production Release

### 1. Configure Signing
```sh
cp android/key.properties.example android/key.properties
```
Edit `android/key.properties` with your keystore path and credentials.

### 2. Configure Release Defines
```sh
cp android/release-defines.example.json android/release-defines.json
```
Populate the JSON with your live API keys.

### 3. Build Release AppBundle
```sh
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --dart-define-from-file=android/release-defines.json
```

### 4. Fastlane Deployment
Generate lock file and deploy to Google Play Beta track:
```sh
cd android/fastlane
bundle install
bundle exec fastlane android beta
```

---

## Privacy & Legal

* All generated media is stored strictly in app-owned storage.
* Segmentation and processing are prioritized for on-device execution.
* Telemetry strips all personally identifiable information, media bytes, and exact overlay texts.
* This application utilizes a GPL-enabled FFmpeg distribution; redistribution must adhere to GNU General Public License terms.

---

## Limitations

* WhatsApp native export remains Android-only.
* The Community feed acts as a live Giphy stream rather than a curated pack marketplace.
* TikTok comment APIs might return missing media which the application handles gracefully.
