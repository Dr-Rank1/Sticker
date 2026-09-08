<p align="center">
  <img src="assets/branding/app_icon.png" width="128" alt="Stikk app icon">
</p>

<h1 align="center">Stikk</h1>

<p align="center">
  A polished Flutter app for creating, organizing, and exporting custom
  WhatsApp sticker packs.
</p>

Stikk turns photos, TikTok clips, popular meme templates, and transparent
stickers into WhatsApp-ready WebP files. It includes an editor for trimming
video, adding text and emoji overlays, selecting downloadable fonts, and
removing photo backgrounds on-device.

The app stores packs locally, enforces WhatsApp's sticker requirements, and
exports complete packs to WhatsApp on Android.

## What can Stikk do?

### Create from a photo

- Pick an image from the gallery or capture one with the camera.
- Remove the background locally with ML Kit selfie segmentation.
- Automatically crop the subject and place it on a transparent canvas.
- Add text or emoji overlays.
- Export a static 512×512 WebP sticker.

Photo segmentation happens on the device. The selected photo is not sent to a
background-removal service.

### Create from TikTok

- Paste a full or shortened TikTok URL.
- Resolve the video through the TikWM REST API.
- Download the watermark-free MP4 returned by TikWM.
- Preview and trim the clip.
- Change playback speed and add overlays.
- Convert the result into an animated WhatsApp WebP sticker with FFmpeg.

### Detect TikTok links from the clipboard

When the app enters the foreground, it checks the clipboard for supported
TikTok links, including `tiktok.com`, `vm.tiktok.com`, and related mobile share
hosts. A consumed link is cleared to prevent the same scan from opening
repeatedly.

If comment scanning is configured, Stikk can request comments, keep only
comments that expose actual image attachments, and present the images in a
selectable grid. Selected images are padded on a transparent 512×512 canvas,
encoded as static WebP, and can be saved to a local pack.

The comment-sticker grid runs Apify Actor `X6ACJnuJVBUsBocfe`, polls until the
run succeeds, and keeps only dataset items that include a sticker or image URL.

### Start from a meme

- Load current meme templates from Imgflip.
- Search and browse templates in a grid.
- Download a selected template.
- Prepare it at 512×512 and continue editing it in Stikk.
- Add custom text before saving it as a static sticker.

### Discover transparent stickers

- Search Tenor from the Discover tab.
- Request sticker-only, transparent WebP results.
- Browse results in a masonry grid.
- Download a sticker directly into one of your packs.

Stikk sends `searchfilter=sticker` and
`media_filter=webp_transparent` to Tenor so regular GIF results are excluded.

### Edit stickers

The editor supports:

- Video trim controls and looping preview.
- Playback-speed changes.
- Text and emoji overlays.
- Dragging, rotating, and scaling overlays.
- Dynamic Google Fonts such as Anton, Bangers, Pacifico, Permanent Marker,
  and Roboto.
- Font preloading before rasterization so exported text matches the preview.
- Progress feedback during FFmpeg and static-image encoding.

### Manage local packs

- Create packs with a name, author, and generated tray icon.
- Keep static and animated stickers in separate packs.
- Add, remove, and inspect stickers.
- Persist pack metadata locally with Hive.
- Retain completed stickers in app-owned document storage.
- Measure app storage and clear disposable cache files without deleting packs.

### Export to WhatsApp

On Android, Stikk checks whether consumer WhatsApp or WhatsApp Business can
handle the export before launching the native pack flow. If WhatsApp is
missing, the app displays a friendly installation guide.

Pack validation follows the important WhatsApp rules:

- A pack must contain between 3 and 30 stickers.
- A pack cannot mix static and animated stickers.
- Stickers are encoded at exactly 512×512 pixels.
- Static stickers are exported as WebP.
- A 96×96 tray icon is generated for each pack.

Trying to export an undersized pack produces visual feedback and explains the
three-sticker minimum.

### Browse the Community demo

The Community tab demonstrates a browsable pack feed backed by
`assets/community/packs.json`. It is intentionally an offline sample catalog,
not a live marketplace or account-based service.

## Typical workflow

1. Open **Create** and choose a photo, TikTok clip, or meme template.
2. Trim or prepare the source image.
3. Add text and emoji overlays in the editor.
4. Save the generated WebP to a new or existing pack.
5. Add at least three stickers of the same type.
6. Open the pack from **Library** and export it to WhatsApp.

Alternatively, search **Discover** and save an existing transparent sticker
directly to a pack.

## Platform support

Stikk is developed primarily for Android.

- Android 7.0 / API 24 or newer is the configured minimum.
- Native WhatsApp pack export is implemented for Android.
- The Flutter UI can be developed on other Flutter targets, but WhatsApp export
  reports that an Android device is required.
- Splash and launcher icon configuration is present for Android and iOS.

Camera, internet, and photo-library storage permissions are declared in the
Android project. The camera is optional hardware. WhatsApp reads packs through
an exported ContentProvider documented in `AndroidManifest.xml`.

## Technology

The project uses:

- Flutter and Dart for the application.
- Riverpod for application state and dependency injection.
- Hive for local pack and settings persistence.
- Dio for TikWM, Tenor, Imgflip, ScrapeBadger, Apify, and file downloads.
- FFmpeg Kit Full-GPL (`ffmpeg_kit_flutter_new`, including `libwebp`) for animated and static WebP encoding.
- ML Kit selfie segmentation for on-device background removal.
- `image` for pixel processing, transparent canvases, resize, crop, and padding.
- Google Fonts for dynamically downloaded editor fonts.
- `video_player` for clip preview.
- `cached_network_image` for remote sticker previews.
- Android method channels and a content provider for WhatsApp pack export.

## Project structure

Important directories under `lib/`:

- `editor/` — editor state, overlay rendering, fonts, FFmpeg, static export, and
  background removal.
- `packs/` — pack models, persistence, tray icons, validation, and WhatsApp
  export.
- `tiktok/` — TikWM import, clipboard comment scanning, ScrapeBadger parsing,
  Apify Actor polling, and comment-sticker formatting.
- `photos/` — camera/gallery import flow.
- `memes/` — Imgflip template API and picker.
- `discover/` — Tenor search and transparent WebP downloads.
- `community/` — offline example catalog and pack-detail UI.
- `onboarding/`, `permissions/`, and `settings/` — first-run experience,
  permission guidance, appearance, and storage management.
- `theme/` and `widgets/` — visual system and shared navigation.

Tests live in `test/` and cover API parsing, editor behavior, file formatting,
pack persistence, export validation, clipboard recognition, permissions,
storage cleanup, and key user flows.

## Requirements

Before running the project, install:

- A Flutter SDK compatible with Dart `^3.13.2`.
- Android Studio or the Android command-line SDK.
- Java 17 for the Android build.
- An Android emulator or physical device using API 24 or newer.

Confirm the toolchain:

```sh
flutter doctor
```

## Quick start

Clone and enter the project:

```sh
git clone https://github.com/stewiriffin/Sticker.git
cd Sticker
```

Install dependencies:

```sh
flutter pub get
```

Run the app without optional network integrations:

```sh
flutter run
```

Photo creation, local packs, Imgflip templates, and TikWM imports do not use the
optional Tenor, ScrapeBadger, or Apify keys described below.

## API configuration

Secrets are intentionally not committed. Build-time values are read with
`String.fromEnvironment`, so pass them through `--dart-define`.

### Tenor

Tenor powers the Discover search.

1. Follow the [Tenor API quickstart](https://developers.google.com/tenor/guides/quickstart).
2. Create an API key.
3. Run with:

```sh
flutter run --dart-define=TENOR_API_KEY=your_tenor_key
```

Without this key, the rest of the app remains usable and Discover displays a
configuration message.

### Apify

Clipboard comment scanning uses `ApifyService` and Actor `X6ACJnuJVBUsBocfe`:

1. `POST /v2/acts/{actorId}/runs?token=...` with the pasted TikTok URL.
2. Poll `GET /v2/acts/{actorId}/runs/{runId}?token=...` every three seconds
   until the run status is `SUCCEEDED`.
3. `GET /v2/datasets/{datasetId}/items` and keep only rows with a sticker or
   image URL.

Configure it with:

```sh
flutter run --dart-define=APIFY_API_TOKEN=your_apify_token
```

### ScrapeBadger

ScrapeBadger remains available as an alternate comment client. It reads at most
two 50-comment pages, discards text-only comments, and inspects replies.

```sh
flutter run \
  --dart-define=SCRAPEBADGER_API_KEY=your_scrapebadger_key
```

### Run with all optional integrations

```sh
flutter run \
  --dart-define=TENOR_API_KEY=your_tenor_key \
  --dart-define=SCRAPEBADGER_API_KEY=your_scrapebadger_key \
  --dart-define=APIFY_API_TOKEN=your_apify_token
```

TikWM and Imgflip do not require keys in this project.

## Security and privacy notes

- Local photos and generated packs remain in app-owned device storage.
- ML Kit background segmentation runs locally.
- Temporary source and conversion files are cleaned up after successful saves
  and can also be cleared from Settings.
- TikTok import sends the pasted public video URL to TikWM.
- Meme browsing contacts Imgflip.
- Discover contacts Tenor.
- Comment scanning contacts Apify Actor `X6ACJnuJVBUsBocfe`.
- Google Fonts may download selected font files over the network.

An API token embedded in a distributed mobile application can be extracted,
even when supplied through `--dart-define` or sent in an authorization header.
For a public production release, route paid or privileged APIs through a
backend that applies authentication, quotas, and abuse protection. The current
direct clients are suitable for personal builds, prototypes, and controlled
distribution.

## Build and release

Build a debug APK:

```sh
flutter build apk --debug
```

Build a release APK with optional integrations:

```sh
flutter build apk --release \
  --dart-define=TENOR_API_KEY=your_tenor_key \
  --dart-define=SCRAPEBADGER_API_KEY=your_scrapebadger_key \
  --dart-define=APIFY_API_TOKEN=your_apify_token
```

The Android project currently uses debug signing for release builds. Configure
a private release keystore before publishing to an app store.

## Branding assets

Source branding files live in `assets/branding/`.

Regenerate launcher icons:

```sh
dart run flutter_launcher_icons
```

Regenerate light and dark splash screens:

```sh
dart run flutter_native_splash:create
```

The corresponding settings are in `flutter_launcher_icons.yaml` and
`flutter_native_splash.yaml`.

## Quality checks

Format the code:

```sh
dart format .
```

Run static analysis:

```sh
flutter analyze
```

Run the complete test suite:

```sh
flutter test
```

Run an individual test:

```sh
flutter test test/apify_service_test.dart
```

## Current limitations

- Native WhatsApp export is Android-only.
- The **From a video** source shown in Create is a placeholder; TikTok video
  import is implemented.
- The Community tab uses bundled demonstration data.
- Network-backed features depend on third-party availability, quotas, terms,
  and response formats.
- TikTok web comment APIs often expose only a `[Sticker]` text placeholder.
  Stikk can import a comment sticker only when the selected provider returns a
  real image URL.
- Dynamic fonts require network access the first time a font is requested.
- A production signing configuration has not yet been added.

## Contributing

Contributions are welcome:

1. Create a branch for the change.
2. Keep platform-specific behavior covered by tests where practical.
3. Run formatting, analysis, and the full test suite.
4. Open a pull request describing the user-visible behavior and any new
   service configuration.

When adding an external API, do not commit credentials. Document its privacy,
quota, and failure behavior, and expose configuration through build-time or
runtime settings.
