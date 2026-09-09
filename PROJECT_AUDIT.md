# Stickr Project Audit

**Assessment date:** 9 September 2026  
**Repository state assessed:** `main` working tree after the Stickr rebrand  
**Primary platform:** Android  
**Framework:** Flutter and Dart

## 1. Purpose of this document

This document records what Stickr currently accomplishes, how the application is structured, what remains incomplete or risky, and which improvements would provide the greatest product and engineering value.

The assessment is based on:

- A review of the Flutter application, native Android and iOS code, persistence layer, networking services, media-processing pipeline, tests, and release configuration.
- `flutter analyze`.
- The complete `flutter test` suite.
- `flutter pub outdated --no-dev-dependencies`.
- A review of the current README and recent implementation history.

This is a point-in-time assessment. Third-party API behavior, WhatsApp requirements, Flutter packages, and mobile platform policies can change.

## 2. Executive summary

Stickr is already a substantial Android-first sticker creation application rather than an early visual prototype. It can create static stickers from photos and memes, create animated stickers from TikTok clips, edit content, organize stickers into local packs, import and share its own `.stickr` archives, and invoke WhatsApp's native sticker-pack flow on Android.

The project also contains two sticker-discovery paths:

- Discover uses Tenor search for transparent sticker WebP files.
- Community uses Giphy's live trending sticker endpoint, a masonry grid, a staging tray, and batch export.

TikTok comment-sticker scanning is implemented through Apify's synchronous dataset endpoint, including multi-selection and batch export.

The strongest parts of the project are its breadth of implemented user flows, local media-processing pipeline, Android WhatsApp integration, Riverpod-based dependency injection, and broad automated test coverage.

The project is not yet production-ready. The most important blockers are:

1. The previously committed Giphy API key must still be rotated because it remains exposed in Git history.
2. There is no continuous-integration workflow.
3. Release builds silently fall back to debug signing if no release keystore exists.
4. Firebase configuration is still placeholder-only, so Crashlytics is not production-configured.
5. The README describes an older architecture and several removed behaviors.
6. Discover still depends on Tenor even though the product direction has moved to Giphy.
7. Pack persistence does not store enough metadata and derives update timestamps incorrectly.
8. Native WhatsApp export is Android-only and has not been validated by an automated device-level contract test.

The recommended strategy is to stabilize and secure the existing Android product before adding more creation sources or marketplace features.

## 3. What has been accomplished

### 3.1 Application shell and navigation

Implemented:

- A four-tab application shell for Library, Create, Discover, and Community.
- Riverpod state for selected navigation tab.
- A custom bottom navigation bar.
- Light, dark, and system theme modes.
- A reusable design system with color extensions, spacing, shape, typography, and responsive scaling.
- Startup fallback UI when application initialization fails.
- High-refresh-rate support on supported Android devices.

Primary files:

- `lib/main.dart`
- `lib/widgets/main_scaffold.dart`
- `lib/state/navigation_controller.dart`
- `lib/state/theme_controller.dart`
- `lib/theme/app_theme.dart`
- `lib/theme/app_colors.dart`
- `lib/error/app_error_fallback.dart`

### 3.2 Onboarding and permissions

Implemented:

- A three-page onboarding flow.
- Skip, next, and get-started actions.
- Persistent onboarding completion state.
- Android-version-aware photo permission selection.
- Camera permission handling.
- Permanently-denied permission handling with a route to system settings.
- iOS photo and camera usage descriptions.

Storage choices:

- Hive stores onboarding and appearance settings.
- An in-memory settings implementation is used in tests.

Primary files:

- `lib/onboarding/onboarding_screen.dart`
- `lib/onboarding/onboarding_controller.dart`
- `lib/permissions/media_permission_service.dart`
- `lib/permissions/media_permission_dialog.dart`
- `lib/state/settings_store.dart`

### 3.3 Photo sticker creation

Implemented:

- Gallery and camera image selection.
- EXIF orientation correction.
- Static sticker canvas preparation.
- On-device ML Kit selfie segmentation.
- Alpha-mask application with feathered edges.
- Transparent PNG intermediate output.
- Static WebP output sized for WhatsApp.
- Save-to-pack flow after editing.

Privacy advantage:

- Background segmentation runs on-device rather than uploading personal photos to a remote background-removal service.

Primary files:

- `lib/photos/photo_import_sheet.dart`
- `lib/photos/photo_import_controller.dart`
- `lib/editor/image_sticker_service.dart`
- `lib/editor/background_removal_service.dart`

### 3.4 TikTok video import and animated sticker creation

Implemented:

- TikTok URL extraction and validation for full and shortened URLs.
- TikWM API resolution.
- Watermark-free MP4 download.
- Download progress reporting.
- Video preview and looping.
- Trim start and end controls.
- Playback-speed control.
- FFmpeg-based animated WebP export.
- Compression retries to meet WhatsApp's animated sticker size limit.
- Cancellation support for active exports.

Current limitation:

- TikWM caption metadata is fetched and passed into `EditorScreen`, but the editor does not display or use it.

Primary files:

- `lib/tiktok/tiktok_import_sheet.dart`
- `lib/tiktok/tiktok_import_controller.dart`
- `lib/tiktok/tiktok_import_service.dart`
- `lib/editor/ffmpeg_sticker_service.dart`
- `lib/editor/ffmpeg_webp_builder.dart`

### 3.5 Sticker editor

Implemented:

- A shared editor for static images and video.
- Text overlays.
- An emoji overlay picker.
- Font selection and Google Fonts loading.
- Overlay dragging, rotation, and scaling.
- Trim timeline and playback controls.
- Overlay capture through a repaint boundary.
- A fallback overlay compositor.
- Save progress and error states.
- Automatic transition to the Library after adding a sticker to a pack.

Primary files:

- `lib/editor/editor_screen.dart`
- `lib/editor/editor_controller.dart`
- `lib/editor/editor_models.dart`
- `lib/editor/widgets/overlay_canvas.dart`
- `lib/editor/widgets/editor_toolbar.dart`
- `lib/editor/widgets/trim_timeline.dart`
- `lib/editor/widgets/text_font_picker.dart`
- `lib/editor/canvas_exporter.dart`
- `lib/editor/overlay_composer.dart`

### 3.6 Meme template creation

Implemented:

- Imgflip template retrieval.
- Template browsing.
- Download and handoff into the static editor.
- Friendly API and download errors.

Primary files:

- `lib/memes/meme_service.dart`
- `lib/memes/meme_template_sheet.dart`

### 3.7 Local sticker packs

Implemented:

- Pack creation, renaming, deletion, and observation.
- Sticker addition and removal.
- Automatic tray-icon generation.
- Enforcement of the 3-to-30 sticker export range.
- Prevention of static and animated sticker mixing.
- App-owned file storage for completed stickers.
- Isar-backed production repository.
- In-memory repository for unit and widget tests.
- Library pack grid and pack detail screen.

Primary files:

- `lib/packs/pack_models.dart`
- `lib/packs/pack_repository.dart`
- `lib/packs/sticker_repository.dart`
- `lib/packs/pack_providers.dart`
- `lib/packs/tray_icon_service.dart`
- `lib/screens/library_screen.dart`
- `lib/packs/pack_detail_screen.dart`
- `lib/database/sticker_pack.dart`

### 3.8 WhatsApp export on Android

Implemented:

- Dart-side pack validation.
- WhatsApp installation check.
- Flutter method-channel call to native Android.
- Native staging of tray and sticker files.
- WhatsApp `ENABLE_STICKER_PACK` intent.
- Consumer WhatsApp and WhatsApp Business fallback.
- An exported Android `ContentProvider` implementing WhatsApp's metadata, sticker listing, and asset endpoints.
- Canonical-path and safe-name checks for provider asset resolution.
- Result handling for accepted, cancelled, invalid, missing-app, and in-progress exports.

Primary files:

- `lib/packs/whatsapp_export_service.dart`
- `android/app/src/main/kotlin/com/stikk/stikk/MainActivity.kt`
- `android/app/src/main/kotlin/com/stikk/stikk/StickerContentProvider.kt`
- `android/app/src/main/kotlin/com/stikk/stikk/StickerPackStore.kt`
- `android/app/src/main/AndroidManifest.xml`

### 3.9 Pack sharing and import

Implemented:

- A custom `.stickr` archive format.
- Manifest, tray icon, and WebP file packaging.
- Native share-sheet integration.
- Opening and receiving `.stickr` files on Android.
- Archive validation and local import.
- A cap at WhatsApp's 30-sticker maximum during import.

Primary files:

- `lib/packs/export_service.dart`
- `lib/packs/stickr_file_intent.dart`
- Android intent filters in `android/app/src/main/AndroidManifest.xml`
- Android file reception in `MainActivity.kt`

### 3.10 TikTok clipboard, share, and app-link handling

Implemented:

- Clipboard detection when the app enters the foreground.
- TikTok URL extraction from shared text.
- Cold-start and background share-intent handling.
- TikTok app-link handling.
- Clipboard consumption to reduce repeated scans.
- A dedicated scan page while shared links are processed.

Primary files:

- `lib/main.dart`
- `lib/widgets/main_scaffold.dart`
- `lib/tiktok/tiktok_url.dart`
- `lib/tiktok/tiktok_share_intent.dart`
- `lib/tiktok/tiktok_app_links.dart`

### 3.11 Apify comment-sticker flow

Implemented:

- Apify's synchronous actor dataset endpoint.
- A 60-second Dio connect, send, and receive timeout.
- Actor-specific request input.
- A 50-comment request target.
- Parsing of top-level, nested `data`, and nested raw image fields.
- URL validation and deduplication.
- Filtering of comments without actual image URLs.
- Friendly timeout, connectivity, authentication, and rate-limit errors.
- Background-isolate conversion of dataset rows.
- Multi-selection in the comment-sticker sheet.
- Selection overlay and checkmark.
- Export validation for 3 to 30 selected stickers.
- Download and static WebP normalization of selected items.
- Creation of a new local pack and WhatsApp export.

Primary files:

- `lib/tiktok/apify_service.dart`
- `lib/tiktok/comment_sticker_sheet.dart`
- `lib/tiktok/comment_sticker_formatter.dart`
- `lib/tiktok/comment_sticker_isolate.dart`

### 3.12 Discover

Implemented:

- Transparent sticker search through Tenor.
- Sticker-only media filtering.
- Masonry result grid.
- Cached thumbnails.
- Download into a selected local pack.
- API key, network, timeout, and empty-state handling.

Primary files:

- `lib/discover/discover_screen.dart`
- `lib/discover/tenor_repository.dart`

Important status:

- This feature remains technically implemented, but it conflicts with the newer product direction that moved Community from Tenor to Giphy because Tenor is no longer accepting new clients.
- `TenorRepository` parses the next-page cursor, but `DiscoverScreen` never requests subsequent pages, so each search is limited to its first response.

### 3.13 Community

Implemented:

- Live Giphy trending sticker retrieval.
- `limit=50` and `rating=g`.
- Parsing of `images.fixed_height.url`, with `images.original.url` fallback.
- Offset pagination.
- Masonry layout.
- `CachedNetworkImage` rendering with bounded in-memory decode size.
- A persistent `My Pack` staging tray.
- Add and remove actions.
- A 30-sticker tray cap.
- Export button enabled only from 3 through 30 items.
- Retry state for API failures and rate limits.
- Batch download, static WebP normalization, Isar pack creation, and WhatsApp export.
- Lazy loading when the Community tab is selected.

Primary files:

- `lib/community/giphy_service.dart`
- `lib/community/community_sticker_feed.dart`
- `lib/community/community_models.dart`
- `lib/screens/community_screen.dart`

### 3.14 Storage, cache, updates, reviews, and diagnostics

Implemented:

- Storage measurement for documents and cache.
- User-triggered cache clearing that preserves completed packs.
- Daily WorkManager cleanup task on Android.
- Central application logging.
- Global Flutter and platform error handlers.
- Optional Firebase Crashlytics integration.
- Immediate Play Store update checks.
- A one-time in-app review prompt after three distinct successful WhatsApp exports.
- Central haptic feedback service.

Current cache-accounting limitation:

- User-triggered cache usage and clearing primarily recognize top-level names beginning with `stickr_`. Temporary files using prefixes such as `giphy_`, `comment_`, `whatsapp_ready_`, and native `import_` can be omitted from the displayed total and normal cache clearing.

Primary files:

- `lib/storage/storage_utility.dart`
- `lib/storage/cache_cleanup_worker.dart`
- `lib/logging/app_logger.dart`
- `lib/error/app_error_handlers.dart`
- `lib/crashlytics/crash_reporter.dart`
- `lib/store/play_store_update_service.dart`
- `lib/store/review_service.dart`
- `lib/haptics/haptic_service.dart`

### 3.15 Accessibility

Implemented:

- A reusable accessible tap target.
- TalkBack labels and hints on important cards and pack interactions.
- Scaled dimensions and text-aware layout helpers.
- Widget tests for selected accessibility behavior.

Primary files:

- `lib/accessibility/accessible_tap.dart`
- `test/accessibility_test.dart`

## 4. Architecture assessment

### 4.1 Current architecture

The project follows a practical feature-folder structure:

- Presentation is organized under `screens/` and feature-specific widget files.
- Riverpod providers expose repositories and services.
- Domain models and validation are concentrated in the pack layer.
- Platform-specific WhatsApp behavior is isolated in Android Kotlin.
- Heavy media processing is split between Dart image processing, Flutter canvas rendering, ML Kit, and FFmpeg.
- Production persistence is injected at startup, allowing tests to replace it with in-memory implementations.

This structure is appropriate for the current application size and has enabled broad test coverage.

### 4.2 Architectural strengths

- Service constructors accept injected HTTP functions, directories, channels, or repositories, making network and file behavior testable.
- Pack rules have a central model-level representation.
- The WhatsApp native bridge is separated from Flutter UI code.
- Static and animated media pipelines are distinct.
- Temporary media cleanup is treated as a first-class concern.
- The Android content provider applies path sanitization and sandbox checks.
- Isolates are used for selected parsing and download work.
- Error types are generally feature-specific and converted into user-facing messages.

### 4.3 Architectural weaknesses

- There is no unified network layer for timeouts, retry policy, cancellation, headers, telemetry, and rate-limit behavior.
- Giphy, Apify, and Tenor now use consistent build-time environment configuration, but client-side values remain extractable from distributed binaries.
- Several screens directly coordinate networking, file conversion, persistence, and navigation. Community export and editor save are examples of workflows that would benefit from dedicated use-case classes.
- Pack metadata exists in multiple forms: Flutter domain models, Isar rows, Android staging JSON, and `.stickr` manifests. These representations are not versioned together.
- The Isar schema stores sticker paths but not sticker IDs, creation times, animation flags, accessibility labels, source provenance, or update timestamps.
- Several expensive file operations are synchronous.
- There is no formal migration strategy for the Isar schema or `.stickr` archive format.
- Product strings are embedded throughout widgets and services instead of using localization resources.

## 5. Verification and quality status

### 5.1 Automated test inventory

The repository contains 45 Dart test files covering:

- Pack rules and repositories.
- Isar persistence.
- WhatsApp export service behavior.
- Android content-provider constants.
- Static and animated WebP builders.
- Editor state and UI.
- Photo import and background removal.
- TikTok parsing, import, clipboard, app links, and share intents.
- Apify parsing and errors.
- Giphy parsing and errors.
- Community staging and export.
- Tenor search.
- Meme templates.
- Storage cleanup.
- Permissions.
- Onboarding.
- Accessibility.
- Crash reporting.
- Play Store update and review behavior.

This is a strong foundation for an application of this size.

### 5.2 Complete test-suite result

The full `flutter test` run now passes:

- 184 tests passed.
- 1 platform-dependent Isar test was skipped.
- No tests failed.

The previously failing `background share stream bypasses home and starts scanning` test now allows the `AnimatedSwitcher` transition to complete before asserting that the old `MainScaffold` has been removed.

### 5.3 Static analysis result

`flutter analyze` now exits successfully with no issues.

The rebrand maintenance phase resolved the previous 17 findings:

- Deprecated matrix translation and scaling APIs were replaced with their typed alternatives.
- Constructor-style lint findings were removed.
- The null-aware collection suggestion was applied.
- Unnecessary imports and underscore usage were removed from tests.
- The unused optional test parameter was removed.

### 5.4 Dependency status

`flutter pub outdated --no-dev-dependencies` reports:

- 9 direct dependencies behind their latest versions.
- 20 dependencies constrained below a currently resolvable version.
- 7 dependencies locked below their currently upgradable version.
- A discontinued transitive `js` package.
- Discontinued build-related transitive packages.

Major-version upgrades are available for app links, cached network images, device information, Firebase, in-app updates, permissions, sharing, and page indicators.

These upgrades should be handled in small groups with platform smoke tests because several change Android and iOS integration contracts.

### 5.5 Critical media correctness findings

The editor timing and framing contract is now aligned with animated WebP export.

#### Playback speed is applied during export

The editor stores and previews 0.5x, 1x, 1.5x, and 2x speeds. `FfmpegStickerService` now passes the selected speed to `FFmpegWebpBuilder`, which applies `setpts` before frame-rate conversion, containment scaling, padding, and overlay composition.

Slow playback also reduces the maximum selectable source range so the final timed output remains within three seconds. FFmpeg progress now uses the actual speed-adjusted output duration rather than a fixed denominator.

#### Fractional trim positions are preserved

`FFmpegWebpBuilder.formatTimestamp` now emits `HH:MM:SS.mmm` timestamps rounded to millisecond precision. Unit tests cover fractional start and duration values.

#### Preview and export framing match

Video preview now uses aspect-ratio containment inside the square editor canvas. This matches FFmpeg's 512x512 containment scale and centered transparent padding instead of cropping with `BoxFit.cover`.

#### Export limits are visible and enforced

The trim timeline displays the current selected duration and maximum. Timeline gestures and editor state both cap the source selection at three seconds, with a speed-aware 1.5-second source cap at 0.5x so slowed output remains no longer than three seconds.

Remaining media hardening:

- Add golden or frame-comparison tests for preview/export parity.
- Disable or intercept editor dismissal while encoding, and ensure closing the editor cancels active media work.

## 6. What still needs to be done

### 6.1 Critical security work

#### Rotate the formerly committed Giphy key

The live Giphy key has been removed from `lib/community/giphy_service.dart`.
Giphy, Apify, and Tenor now read build-time environment values, startup validates
all three, `.env` is ignored, and `.env.example` documents the required names.

Remaining risk:

- The previous Giphy key remains visible in Git history and must be treated as compromised.
- Build-time values remain extractable from a distributed application binary.
- It can be copied and used outside the app.
- Abuse can exhaust quota or cause the Giphy application to be suspended.

Required action:

1. Rotate the current key in Giphy.
2. Remove the old key from repository history if exposure policy requires it.
3. Move privileged API access behind a backend or edge function.
4. At minimum, use build-time configuration and enforce quota and origin restrictions where the provider supports them.

Build-time injection alone does not make a mobile API key secret; it only prevents accidental source control exposure.

#### Protect Apify usage

Apify uses a build-time token, which is better than a committed literal but still extractable from an APK.

Recommended production design:

- Send the TikTok URL to a Stickr backend.
- Keep the Apify token server-side.
- Authenticate app requests.
- Apply per-device or per-account quotas.
- Validate accepted TikTok hosts server-side.
- Record actor latency, failure type, and cost.

Current privacy concern:

- `ApifyService` logs the full TikTok URL and sets it as a Crashlytics custom key. Redact or hash the video identifier before enabling production telemetry, and document the retention and consent policy.

### 6.2 Preserve reliable share-intent transitions

The background share-intent transition test now passes after allowing the old `AnimatedSwitcher` child to finish exiting. The behavior should remain covered before release.

Acceptance criteria:

- A TikTok link shared while the app is running consistently transitions to the scan UI.
- The old home UI is not interactive while scanning.
- Repeated share events do not open duplicate scans.
- Non-TikTok shared text remains on the home screen.
- Cold start and background delive7ry work on a physical Android device.
- The test passes reliably under both isolated and full-suite execution.

### 6.3 Add continuous integration

No `.github/workflows` files are present.

Minimum pull-request workflow:

- Install the pinned Flutter version.
- Restore Pub and Gradle caches.
- Run `dart format --output=none --set-exit-if-changed .`.
- Run `flutter analyze`.
- Run `flutter test`.
- Build an Android debug APK.
- Optionally run Kotlin lint and Android unit tests.

Release workflow:

- Require protected environment secrets.
- Build an Android App Bundle.
- Sign with a release keystore.
- Upload symbols and mapping files.
- Upload to an internal Play track.
- Retain build artifacts and checksums.

### 6.4 Make release signing fail safely

`android/app/build.gradle.kts` falls back to the debug signing configuration when `key.properties` is absent.

This is convenient locally but unsafe for release automation because a release task can appear successful while producing a debug-signed artifact.

Recommended change:

- Fail release builds with a clear Gradle error when release signing values are missing.
- Keep debug signing only for debug/profile variants.
- Store keystore material in CI secrets.
- Document key rotation, backup, and Play App Signing ownership.

### 6.5 Complete Firebase configuration

`lib/firebase_options.dart` contains placeholder API and application IDs, and no Firebase platform configuration files are present.

Current effect:

- Crashlytics initialization is designed to fail gracefully.
- Production crash reporting is not actually configured.

Required action:

- Run `flutterfire configure`.
- Add environment-specific Firebase projects.
- Keep service files out of source control if that is the selected policy, but inject them during CI builds.
- Verify non-fatal and fatal reports from internal builds.
- Upload Android obfuscation and native symbols for release builds.

### 6.6 Update or replace Discover

Discover still depends on Tenor and requires `TENOR_API_KEY`.

Given the decision to use Giphy because Tenor is no longer accepting new clients, Discover should be migrated rather than left as an effectively unavailable tab.

Recommended options:

1. Add Giphy sticker search to `GiphyService` and migrate Discover.
2. Merge Discover and Community into one Giphy-backed experience with search and trending sections.
3. Remove Discover until a supported search provider is available.

Maintaining two providers increases UI inconsistency, networking code, documentation burden, and failure modes.

### 6.7 Correct and expand pack persistence

The current Isar row stores:

- Identifier.
- Name.
- Publisher.
- Tray bytes.
- Sticker paths.

Missing data:

- Pack creation and update timestamps.
- Per-sticker ID.
- Per-sticker creation time.
- Static or animated flag.
- Sticker accessibility text.
- Source/provider attribution.
- Source URL or import provenance.
- Pack schema version.

Current implementation concerns:

- `StickerRepository._toDomain` derives both `createdAt` and `updatedAt` from the Isar row ID.
- Updating a pack does not create a meaningful new `updatedAt`.
- WhatsApp's `imageDataVersion` is derived from this domain timestamp, so an edited pack can retain a stale cache version.
- Animation is inferred by synchronously reading WebP bytes whenever rows are mapped.

Recommended schema migration:

- Add persisted `createdAtMillis` and `updatedAtMillis`.
- Store sticker records as embedded Isar objects.
- Persist `animated`, stable sticker ID, creation time, and accessibility text.
- Increment `updatedAtMillis` for every content or metadata change.
- Use a monotonic content revision for WhatsApp `imageDataVersion`.
- Add migration tests using a copy of the previous schema.

Pack readiness also needs file-level validation. `canExportToWhatsApp` currently validates metadata and sticker count, but does not verify that every file exists, decodes as WebP, is 512 by 512, meets its byte limit, or matches the pack's animation type. Discover currently copies Tenor results directly into packs, making this validation gap especially important.

### 6.8 Improve batch export workflows

Community and comment-sticker exports currently perform substantial orchestration in widget state:

- Download each selected file.
- Convert each file.
- Create a pack.
- Save every sticker.
- Invoke WhatsApp.
- Delete temporary files.

Recommended improvement:

- Move this sequence into a dedicated batch-export use case.
- Expose item-level progress, current stage, cancellation, and retry.
- Use bounded concurrency for downloads.
- Keep conversion concurrency low to avoid memory pressure.
- Preserve successfully downloaded intermediates during recoverable retries.
- Prevent duplicate pack creation if WhatsApp launch fails after persistence.
- Add an export operation ID for diagnostics.

Lifecycle concerns:

- Community and comment export create the local pack before WhatsApp accepts it. A cancelled or failed native export therefore leaves a pack in Library.
- Successful comment-sticker export does not close the sheet or clear its selection, making accidental duplicate pack creation possible.

### 6.9 Clarify Community animation behavior

Giphy's sticker feed is treated as animated in the Community model, but selected files are passed through `CommentStickerFormatter`, which produces static WebP output.

The UI can therefore present an animated source while exporting a static first-frame result.

Choose and communicate one behavior:

- Preserve animation and export animated packs.
- Explicitly label Community exports as static snapshots.
- Let users choose animated or static mode.

If animation is preserved, enforce pack-type consistency and WhatsApp's animated file-size limit.

### 6.10 Harden network behavior

Network configuration varies by service.

Recommended shared standards:

- Explicit connect, send, and receive timeouts for every client.
- Request cancellation when screens are disposed.
- Limited retry with jitter for safe GET requests.
- Respect for `Retry-After`.
- Structured error categories.
- Consistent user-facing offline and rate-limit messages.
- Request IDs and timing metrics without logging secrets or personal content.
- TLS-only URLs in production.

Specific issues:

- Giphy currently constructs a default Dio client without explicit timeouts.
- Several downloads do not expose cancellation.
- Third-party response compatibility is protected mainly by unit fixtures, not contract monitoring.
- The selected Apify actor's published schema currently documents a minimum of 100 for `commentsPerUrl`, while the app sends 50. Confirm the live actor accepts 50 or use dataset-output limiting to avoid production request rejection.

### 6.11 Introduce localization

The app does not currently use Flutter localization resources. User-facing strings are embedded in widgets and services.

Recommended work:

- Add `flutter_localizations` and ARB files.
- Move button labels, errors, onboarding content, and accessibility strings into localization resources.
- Add locale-aware tests.
- Define a fallback locale.
- Review text expansion in German, French, Spanish, and other target languages.

### 6.12 Complete the generic video source

The Create tab displays `From a video`, but tapping it only shows a future-phase message.

Recommended work:

- Use the media picker for local video.
- Validate duration, codec, dimensions, and file size.
- Reuse the existing editor and FFmpeg path.
- Copy external content URIs into app-owned temporary storage.
- Add permission and cancellation handling.
- Add integration tests for common Android gallery providers.

### 6.13 Decide iOS scope

The Flutter UI and photo permissions include iOS support, but WhatsApp pack export is explicitly Android-only and `AppDelegate.swift` contains no equivalent native bridge.

Choose one:

- Clearly position and distribute Stickr as Android-only.
- Implement and maintain the official iOS sticker-pack integration.

If iOS remains supported:

- Add real iOS build verification.
- Complete Firebase iOS configuration.
- Verify photo, camera, share, and deep-link flows.
- Review App Store privacy declarations.

### 6.14 Update documentation

The README is materially stale.

Examples:

- It says packs are persisted with Hive; production packs now use Isar.
- It describes the removed offline Community catalog.
- It describes the old asynchronous Apify polling actor.
- It does not document the live Giphy Community architecture accurately.
- It must continue to explain that build-time configuration prevents accidental commits but does not make mobile client values secret.
- It still presents Tenor as the active transparent-sticker strategy.
- It says meme templates are searchable, but the current picker has no search input.

The README should be updated after the configuration and provider decisions are finalized.

Additional documents needed:

- Privacy policy.
- Third-party services and data-flow disclosure.
- Release runbook.
- API key and incident-response runbook.
- Isar migration policy.
- `.stickr` format specification and versioning policy.

### 6.15 Harden archive import

The `.stickr` importer validates basic structure and controls extracted file names, which is a good start.

Further protections:

- Reject archives above a compressed-size limit.
- Reject excessive uncompressed size to prevent decompression bombs.
- Reject sticker files above per-item limits.
- Validate WebP dimensions and decodability before persistence.
- Validate tray dimensions and format.
- Add an explicit archive format version.
- Roll back the newly created pack if import fails midway.
- Report skipped or invalid stickers instead of silently stopping at the first `PackException`.

### 6.16 Improve accessibility coverage

Existing accessibility helpers and tests are valuable, but dynamic editor and staging interactions need deeper coverage.

Recommended checks:

- Semantic labels for Community add, remove, selection count, and export progress.
- Announcements when a sticker is added or removed.
- Focus order in modal sheets.
- Minimum touch target verification.
- High text-scale testing.
- Contrast testing in light and dark themes.
- Reduced-motion behavior.
- Accessible descriptions for imported stickers.

### 6.17 Improve observability

Current logging and optional Crashlytics provide a foundation.

Add structured events for:

- Import started, resolved, downloaded, and failed.
- Encode attempts, durations, output size, and compression fallback count.
- Pack validation failures.
- WhatsApp export launch and native result.
- API latency and rate-limit events.
- Cache cleanup results.

Do not record:

- API keys or tokens.
- Full private file paths.
- User-entered overlay text.
- Full TikTok URLs if they are considered personal activity data.
- Raw photos or sticker bytes.

### 6.18 Fix temporary-file ownership

`StorageUtility.cleanupTemporaryMedia` recursively deletes every `.mp4` and `.png` under the directory returned by `getTemporaryDirectory`, without checking a Stickr-specific prefix or owned subdirectory.

Risks:

- Unrelated temporary files can be deleted if the directory is shared by plugins or platform code.
- Stickr temporary GIF, IMG, and WebP files can be missed.

Recommended change:

- Put every temporary artifact under one Stickr-owned temporary directory.
- Delete only within that canonical directory.
- Track operation-specific subdirectories.
- Remove a complete operation directory after success or cancellation.
- Add tests proving unrelated files are retained.

### 6.19 Eliminate duplicate and unreachable editor output

The editor copies each finished WebP into `documents/stickers` before opening the pack chooser. The repository then copies it again into the selected pack.

If the chooser is dismissed, the UI says the sticker can be added later from Library, but Library has no loose-sticker browser or import action.

Recommended options:

- Keep generated output temporary until a pack is selected, then let the repository take ownership.
- Or implement a visible drafts/loose-stickers area in Library.

Whichever option is selected, add orphan cleanup and avoid storing two permanent copies.

### 6.20 Make native staging crash-safe

`StickerPackStore.stagePack` deletes an existing staged directory before the replacement has succeeded, and writes `contents.json` directly.

Risks:

- A crash or storage failure can remove the last valid staged pack.
- A partial JSON write can make all staged metadata unreadable.
- There is no recovery path for malformed staging data.

Recommended change:

- Stage files in a new temporary directory.
- Verify all copied files.
- Write metadata to a temporary file and flush it.
- Atomically rename the directory and metadata into place.
- Keep a recoverable previous version until replacement succeeds.

### 6.21 Resolve interaction and state inconsistencies

Current inconsistencies include:

- Selecting the Create tab immediately opens the TikTok import sheet even though the Create screen offers multiple source choices.
- The visible `From a video` source is still a placeholder.
- `TikTokAppLinks.getInitialLink` exists but production code only subscribes to the URI stream.
- Android requests `autoVerify` for TikTok-owned domains, but Stickr cannot control TikTok's domain association files.
- Theme choice is held in Riverpod memory and resets to system mode after restart.
- Community is a Giphy collection experience rather than a user community with accounts, publishing, profiles, or interactions.

Recommended action:

- Let Create open as a normal source chooser.
- Remove or implement placeholder actions.
- Handle initial app links explicitly.
- Remove impossible domain verification claims or introduce an app-owned redirect domain.
- Persist theme mode in the settings store.
- Rename Community if a true community system is not planned.

### 6.22 Repair release tooling and compliance

Additional release blockers were found:

- `android/.gitignore` excludes `gradlew`, `gradlew.bat`, and `gradle-wrapper.jar`, preventing reproducible Android builds from a clean checkout.
- Fastlane dependencies are not locked with `Gemfile.lock`.
- Obfuscation symbols are generated but there is no verified retention or upload process.
- The project uses a Full-GPL FFmpeg package but has no repository license, notices, dependency license inventory, or documented corresponding-source process.
- There is no `integration_test/` suite.
- iOS native tests remain template-level, and no iOS privacy manifest is present.

Required action:

- Track and verify the Gradle wrapper.
- Pin Ruby tooling.
- Retain mapping and symbol artifacts.
- Obtain legal review for FFmpeg distribution obligations and add required licensing material.
- Add Android instrumentation and Flutter integration tests.

### 6.23 Make persistence tests mandatory

The production Isar test path can call `markTestSkipped` when the native library cannot be opened. This allows a test run to pass without exercising production persistence.

Recommended change:

- Add a dedicated CI job with supported Isar native binaries.
- Fail the job if Isar cannot initialize.
- Test CRUD, concurrent writes, migration, file/database consistency, rollback, and corruption recovery.

## 7. Product improvement suggestions

### 7.1 Simplify discovery

Combine trending and search into one Giphy-backed destination:

- Trending feed by default.
- Search field at the top.
- Category chips.
- Recent searches stored locally.
- Source attribution required by Giphy's terms.
- A single consistent staging tray.

This removes the unsupported Tenor dependency and avoids teaching users two different collection flows.

### 7.2 Make pack building a first-class workspace

The `My Pack` tray is useful but currently temporary widget state.

Improvements:

- Persist the draft tray across tab changes and process death.
- Allow pack naming and author entry before export.
- Support reorder by drag and drop.
- Show static or animated pack type.
- Show per-sticker size and validation.
- Allow replacing the tray icon.
- Warn before clearing a non-empty draft.

### 7.3 Add transparent quality controls

Useful editor additions:

- Edge feather slider.
- Background mask refine and erase brushes.
- Outline or stroke controls.
- Shadow controls.
- Canvas background preview modes.
- Before-and-after preview.
- Crop and subject-position controls.

### 7.4 Add local video import

This is the clearest missing creation source because the UI already advertises it and the media pipeline already supports most required behavior.

### 7.5 Improve export confidence

Before launching WhatsApp, show:

- Sticker count.
- Pack type.
- Invalid item warnings.
- Estimated total size.
- Tray preview.
- Exact progress during preparation.

After returning from WhatsApp, provide a clear success or recovery path.

### 7.6 Add offline and resilience features

- Persist Community pagination and cached metadata.
- Allow retrying failed item downloads.
- Preserve a staging draft offline.
- Detect connectivity before expensive operations.
- Avoid losing an export selection when the app backgrounds.

### 7.7 Add attribution and policy surfaces

The app contacts several third parties. Add an About or Privacy screen listing:

- Giphy.
- TikWM.
- Imgflip.
- Apify.
- Google Fonts.
- Firebase, when configured.

Include provider attribution, terms links, privacy links, and an explanation of what data is sent.

### 7.8 Improve naming consistency

The product display name, Dart package, method-channel feature names, archive extension, MIME type, documentation, and Fastlane configuration now use Stickr consistently.

The Android application ID remains `com.stikk.stikk` intentionally. Changing an existing application ID would create a different Play Store application and break upgrades for installed builds.

Remaining naming work:

- Confirm whether the placeholder Firebase project IDs will retain their current legacy value when Firebase is configured.
- Document the stable Android ID so it is not mistaken for an unfinished rebrand.

## 8. Recommended delivery roadmap

### Phase 0: Stabilize the current branch

Target: a trustworthy development baseline.

- Keep the corrected share-intent transition test stable.
- Maintain the new zero-issue analyzer baseline.
- Update README claims that are already incorrect.
- Add CI for formatting, analysis, tests, and debug APK build.
- Make release signing fail when credentials are missing.

Exit criteria:

- `flutter analyze` exits successfully.
- `flutter test` exits successfully with no unexpected skips.
- A clean clone can build a debug APK from documented instructions.

### Phase 1: Secure external services

Target: prevent quota abuse and accidental credential exposure.

- Rotate the Giphy key.
- Remove the previous key from Git history as appropriate.
- Put Apify behind a controlled backend.
- Decide whether Giphy also requires a proxy based on quota and terms.
- Add request quotas, monitoring, and provider attribution.
- Configure Firebase correctly.

Exit criteria:

- No privileged credential is committed or directly shipped without an accepted risk decision.
- Rate limits and provider failures are visible in monitoring.
- Privacy documentation matches actual data flows.

### Phase 2: Consolidate discovery

Target: one supported sticker-browsing experience.

- Add Giphy search.
- Migrate or remove Discover's Tenor code.
- Share models, image widgets, pagination, errors, downloads, and staging.
- Persist the draft tray.

Exit criteria:

- No user-facing feature requires a provider that cannot issue new credentials.
- Trending and search have consistent behavior.

### Phase 3: Strengthen pack data and export

Target: durable, versioned, diagnosable packs.

- Migrate Isar to explicit pack and sticker metadata.
- Correct creation and update timestamps.
- Add a reliable content revision.
- Add `.stickr` schema versioning and import limits.
- Move batch export into a dedicated service with progress and cancellation.
- Add Android device-level WhatsApp validation.

Exit criteria:

- Pack edits invalidate WhatsApp cache correctly.
- Existing user packs migrate without data loss.
- Import and export failures roll back cleanly.

### Phase 4: Complete creation and platform scope

Target: close the largest product gaps.

- Implement local video import.
- Decide and document iOS support.
- Add localization.
- Improve mask editing and pack customization.
- Add integration and golden tests.

## 9. Suggested technical backlog

### Highest priority

- Rotate the previously committed Giphy key.
- Preserve the corrected FFmpeg timing, speed, and preview framing contract.
- Restrict temporary cleanup to Stickr-owned files.
- Add CI.
- Track the Android Gradle wrapper.
- Fail unsigned release builds.
- Configure Firebase or remove claims that Crashlytics is active.
- Replace or remove Tenor Discover.
- Update README.

### High priority

- Add explicit Isar timestamps and embedded sticker metadata.
- Correct WhatsApp `imageDataVersion`.
- Make Android export staging atomic.
- Add Giphy timeouts, cancellation, and retry policy.
- Extract batch export from widget state.
- Add archive size and validation limits.
- Add device-level Android WhatsApp export tests.
- Resolve FFmpeg license and distribution obligations.
- Add privacy and third-party attribution screens.

### Medium priority

- Persist Community draft trays.
- Implement local video import.
- Add localization.
- Add Community search and categories.
- Add item-level export progress.
- Add accessibility announcements and large-text tests.
- Upgrade dependencies in controlled batches.

### Longer-term

- iOS WhatsApp integration or formal Android-only positioning.
- Editable segmentation masks.
- Pack cloud backup or optional account sync.
- Shareable Community packs with moderation and abuse controls.
- Analytics dashboards for conversion and failure funnels.

## 10. Definition of production-ready

Stickr should be considered ready for a controlled Android release when:

- The full test suite and analyzer are green.
- A CI pipeline enforces both.
- Release signing cannot silently use a debug key.
- Firebase or another production diagnostic system is configured and verified.
- API credentials have an approved security model.
- Privacy policy and provider attribution are published.
- WhatsApp export passes physical-device tests on supported Android versions and both WhatsApp variants.
- Pack persistence has a tested migration and correct content revisions.
- README and release instructions match the current implementation.
- Unsupported or placeholder features are removed, hidden, or completed.

## 11. Final assessment

Stickr has a strong functional base and unusually broad automated coverage for its stage. The media creation, pack management, and Android WhatsApp integration demonstrate that the core product is viable.

The next milestone should not be another large feature. The highest return will come from security, reliability, documentation, release engineering, and data-model work. Completing those areas will turn the current feature-rich prototype into a maintainable Android product that can be distributed with much greater confidence.
