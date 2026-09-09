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

- Discover uses Giphy sticker search with offset pagination and a masonry grid.
- Community uses Giphy's live trending sticker endpoint, a masonry grid, a staging tray, and batch export.

TikTok comment-sticker scanning is implemented through Apify's synchronous dataset endpoint, including multi-selection and batch export.

The strongest parts of the project are its breadth of implemented user flows, local media-processing pipeline, Android WhatsApp integration, Riverpod-based dependency injection, and broad automated test coverage.

The project is not yet production-ready. The most important blockers are:

1. The previously committed Giphy API key must still be rotated because it remains exposed in Git history.
2. Firebase configuration is still placeholder-only, so Crashlytics is not production-configured.
3. Native WhatsApp export is Android-only and has not been validated by an automated device-level contract test.
4. GPL notices and source links are present, but the exact release binary and
   corresponding-source process still require legal review.

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
- Explicit pack creation and monotonic update timestamps.
- Embedded sticker metadata with stable IDs and accessibility text.
- Automatic migration from the legacy path-only schema.
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
- `lib/database/sticker_pack_schema_migration.dart`

### 3.8 WhatsApp export on Android

Implemented:

- Dart-side pack validation.
- WhatsApp installation check.
- Flutter method-channel call to native Android.
- Crash-safe native staging of tray and sticker files through synchronized
  temporary files, atomic renames, rollback, and startup recovery.
- WhatsApp `ENABLE_STICKER_PACK` intent.
- Consumer WhatsApp and WhatsApp Business fallback.
- An exported Android `ContentProvider` implementing WhatsApp's metadata, sticker listing, and asset endpoints.
- Canonical-path and safe-name checks for provider asset resolution.
- Result handling for accepted, cancelled, invalid, missing-app, and in-progress exports.

Primary files:

- `lib/packs/whatsapp_export_service.dart`
- `android/app/src/main/kotlin/com/stickr/stickr/MainActivity.kt`
- `android/app/src/main/kotlin/com/stickr/stickr/StickerContentProvider.kt`
- `android/app/src/main/kotlin/com/stickr/stickr/StickerPackStore.kt`
- `android/app/src/main/AndroidManifest.xml`

### 3.9 Pack sharing and import

Implemented:

- A custom `.stickr` archive format.
- Manifest, tray icon, and WebP file packaging.
- Native share-sheet integration.
- Opening and receiving `.stickr` files on Android.
- Pre-decompression ZIP metadata checks, compressed and expanded size limits,
  safe-path enforcement, and symbolic-link rejection.
- Bounded per-entry decompression and a cap at WhatsApp's 30-sticker maximum.
- Full WebP decoding with exact 512 by 512 dimension validation before
  persistence.
- Atomic rollback of the pack row, copied sticker files, and staging directory
  when any import step fails.

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

- Sticker search through Giphy.
- Offset-based infinite pagination.
- Masonry result grid.
- Cached thumbnails.
- Download into a selected local pack.
- API key, network, timeout, and empty-state handling.

Primary files:

- `lib/discover/discover_screen.dart`
- `lib/community/giphy_service.dart`

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

- The unified network layer currently covers Giphy, Apify, and TikWM; Imgflip,
  ScrapeBadger, image downloads, and dynamic fonts still use separate clients.
- Giphy and Apify use consistent build-time environment configuration, but client-side values remain extractable from distributed binaries.
- Several screens directly coordinate networking, file conversion, persistence, and navigation. Community export and editor save are examples of workflows that would benefit from dedicated use-case classes.
- Pack metadata exists in multiple forms: Flutter domain models, Isar rows, Android staging JSON, and `.stickr` manifests. These representations are not versioned together.
- The Isar schema now stores sticker IDs, creation times, animation flags, accessibility labels, and pack timestamps, but still lacks source provenance.
- Several expensive file operations are synchronous.
- The Isar upgrade now has a migration path, but the `.stickr` archive format still has no formal versioned migration strategy.
- English is the only translated locale currently shipped; additional ARB
  files and text-expansion reviews are still required for broader rollout.

## 5. Verification and quality status

### 5.1 Automated test inventory

The repository contains 49 Dart test files covering:

- Pack rules and repositories.
- Isar persistence.
- WhatsApp export service behavior.
- Android content-provider constants.
- Static and animated WebP builders.
- Editor state and UI.
- Photo import and background removal.
- TikTok parsing, import, clipboard, app links, and share intents.
- Apify parsing and errors.
- Giphy trending, search, pagination, parsing, and errors.
- Community staging and export.
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

- 236 tests passed.
- 2 platform-dependent Isar tests were skipped.
- No tests failed.

The previously failing `background share stream bypasses home and starts scanning` test now routes state before asynchronous clipboard cleanup and uses `pumpAndSettle()` to let the `AnimatedSwitcher` remove the old `MainScaffold` before asserting its absence.

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
Giphy and Apify now read build-time environment values, startup validates both,
`.env` is ignored, and `.env.example` documents the required names.

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

The background share-intent handler now commits the scan route before starting asynchronous clipboard cleanup. The transition test disables only the indefinite scan progress animation, then uses `pumpAndSettle()` to wait for the old `AnimatedSwitcher` child to exit.

Acceptance criteria:

- A TikTok link shared while the app is running consistently transitions to the scan UI.
- The old home UI is not interactive while scanning.
- Repeated share events do not open duplicate scans.
- Non-TikTok shared text remains on the home screen.
- Cold start and background delivery work on a physical Android device.
- The test passes reliably under both isolated and full-suite execution.

### 6.3 Add continuous integration

`.github/workflows/pr_validation.yml` now validates every pull request with:

- A pinned Flutter installation.
- Dependency installation and caching.
- Repository-wide Dart formatting enforcement.
- Static analysis.
- The complete Flutter test suite.

Future release workflow:

- Require protected environment secrets.
- Build an Android App Bundle.
- Sign with a release keystore.
- Upload symbols and mapping files.
- Upload to an internal Play track.
- Retain build artifacts and checksums.

### 6.4 Make release signing fail safely

`android/app/build.gradle.kts` no longer falls back to debug signing. Release tasks require complete credentials from `android/key.properties` or the `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`, and `ANDROID_STORE_FILE` environment variables.

Release configuration now fails with a clear Gradle exception when a value or keystore file is missing. Debug and profile development remain independent of release credentials.

Remaining operational work:

- Store keystore material in protected CI secrets.
- Document key rotation, backup, and Play App Signing ownership.

### 6.5 Complete Firebase configuration

Implemented:

- Installed and invoked the FlutterFire CLI with a placeholder production
  project ID. The command could not query Firebase because this environment has
  no authenticated Firebase account, so no external project was created.
- Preserved FlutterFire-compatible Android and iOS options with explicit mock
  project and application values for local replacement.
- Added a mock debug-only `google-services.json` so development and CI builds
  can validate the Gradle plugins without containing production configuration.
- Applied Google Services and Crashlytics through the Android plugin DSL.
- Enabled release mapping upload and native symbol extraction/upload
  configuration.
- Confirmed the release mapping upload and native symbol extraction Gradle
  tasks are registered.

Remaining:

- Authenticate the Firebase CLI and rerun `flutterfire configure` against the
  real production project.
- Supply the ignored production Android and iOS service files through local or
  CI secret provisioning.
- Verify non-fatal and fatal reports from internal builds.

### 6.6 Preserve supported Discover search

Discover now uses Giphy's sticker search endpoint and loads subsequent result pages with API offsets. The unsupported provider repository, environment requirement, and tests have been removed.

Remaining consolidation opportunity:

- Share more grid, download, error, and pagination behavior between Discover and Community.
- Add Giphy attribution required by the provider's terms.
- Consider merging search and trending into one destination.

### 6.7 Correct and expand pack persistence

The Isar row now persists:

- Explicit `createdAtMillis` and monotonic `updatedAtMillis` values.
- Embedded sticker records with stable IDs, file paths, creation times, animation flags, and accessibility text.
- Existing pack identity, name, publisher, and tray bytes.

Pack updates, sticker additions, sticker removals, and validated saves strictly advance the persisted update revision even when multiple operations occur within one millisecond. WhatsApp's `imageDataVersion` is mapped directly from this revision so content and metadata edits invalidate its pack cache.

The startup migration converts legacy path-only rows into embedded records, preserves every file path, infers timestamps from existing files where possible, detects animation once, assigns deterministic IDs, and clears the legacy path list after conversion. Pure migration tests cover legacy conversion, metadata preservation, and idempotence.

Remaining persistence work:

- Retire the legacy `stickerPaths` compatibility field after the migration has shipped broadly.
- Add source/provider attribution and import provenance.
- Add an explicit pack schema version.
- Run production Isar migration tests in CI with the native library available.

Pack readiness also needs file-level validation. `canExportToWhatsApp` currently validates metadata and sticker count, but does not verify that every file exists, decodes as WebP, is 512 by 512, meets its byte limit, or matches the pack's animation type. Discover currently copies downloaded Giphy results directly into packs, making this validation gap especially important.

### 6.8 Improve batch export workflows

Community and comment-sticker exports now share a dedicated
`BatchExportUseCase` that:

- Limits download and conversion concurrency to two items.
- Streams per-item download, conversion, and completion progress to the UI.
- Creates a transient WhatsApp-ready pack without adding it to Isar.
- Waits for the native WhatsApp result before finalizing the local pack.
- Uses the same stable identifier for native staging and local persistence.
- Cleans up Stickr-owned temporary downloads and converted files.

This ordering resolves the previous orphan-pack failure mode: a cancelled,
rejected, or failed WhatsApp launch no longer leaves a new pack in Library.

Remaining improvement:

- Add cancellation and retry controls.
- Preserve successfully downloaded intermediates during recoverable retries.
- Add an export operation ID for diagnostics.
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

Implemented:

- Added a shared `NetworkClient` for Giphy, Apify, and TikWM requests with
  explicit connect, send, and receive timeouts.
- Safe GET requests use bounded retries with exponential jitter and honor
  numeric or HTTP-date `Retry-After` values.
- POST requests, cancelled requests, and non-transient failures are not
  retried.
- Dio failures are normalized into offline, rate-limited, timeout, cancelled,
  unavailable, and general request categories backed by localization keys.
- Discover search, pagination, and downloads cancel when the screen is
  disposed or its tab becomes inactive.
- Apify comment scans cancel when their dialog or shared-link scan page closes.
- Unit and widget tests cover timeout policy, retry limits, `Retry-After`,
  safe-method behavior, normalized errors, and lifecycle cancellation.

Remaining:

- Migrate Imgflip and ScrapeBadger to the shared client.
- Add request IDs, timing metrics, and retry telemetry without logging secrets
  or personal content.
- Third-party response compatibility is protected mainly by unit fixtures, not contract monitoring.
- The selected Apify actor's published schema currently documents a minimum of 100 for `commentsPerUrl`, while the app sends 50. Confirm the live actor accepts 50 or use dataset-output limiting to avoid production request rejection.

### 6.11 Introduce localization

Implemented:

- Added Flutter's localization SDK and configured generated localization output
  through `l10n.yaml`.
- Extracted button labels, errors, onboarding content, progress messages, pack
  validation copy, and accessibility hints into `app_en.arb`.
- Widgets resolve localized resources from `BuildContext`; service-originated
  errors use the active resolved localization with English as the strict
  fallback.
- Added locale fallback and resource-coverage tests.

Remaining:

- Add translated ARB files for selected launch markets.
- Review text expansion and bidirectional layouts before enabling each locale.

### 6.12 Complete the generic video source

Implemented:

- The Create tab opens Android's gallery video picker through `image_picker`.
- Picker output is streamed into a uniquely named app-owned temporary file.
- Copying rejects empty files and enforces a 250 MB limit without loading the
  complete video into memory.
- FFprobe validates duration, video codec, dimensions, and the presence of a
  readable video stream.
- Accepted H.264, HEVC, MPEG, VP8, VP9, AV1, MJPEG, and ProRes sources open the
  same editor and FFmpeg export path as TikTok imports.
- The route deletes its temporary source whenever the editor closes, including
  cancellation and system-back navigation.
- Service and widget tests cover copying, validation, picker cancellation,
  editor handoff, and immediate cleanup.

Remaining work is physical-device coverage for common Android gallery and
document providers.

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

Implemented:

- Rewrote the README around the current Isar pack database and Hive-only
  settings role.
- Documented live Giphy Community and Discover behavior without Tenor or the
  removed offline catalog.
- Documented the synchronous Apify dataset endpoint, TikWM, Imgflip, and the
  shared network client.
- Added the hardened `.stickr` archive layout and validation limits.
- Added exact local run, debug build, signed release AAB, Firebase, Gradle
  wrapper, and Fastlane commands.
- Corrected the repository URL, strict signing behavior, source categories,
  Android scope, and current limitations.

Remaining documents:

- Privacy policy.
- Third-party services and data-flow disclosure.
- API key and incident-response runbook.
- Isar migration policy.
- `.stickr` format specification and versioning policy.

### 6.15 Harden archive import

Implemented:

- Rejects compressed archives above 5 MB before ZIP decoding.
- Preflights the ZIP central directory to reject excessive declared expansion,
  unsupported compression, encrypted entries, unsafe paths, duplicate names,
  symbolic links, and excessive entry counts before payload decompression.
- Uses bounded output streams while reading every accepted entry so forged
  size metadata cannot exceed the 20 MB expanded-data budget.
- Limits individual stickers, manifests, and tray payloads.
- Requires sticker payloads to decode specifically as WebP and to measure
  exactly 512 by 512 before any pack row is created.
- Rolls back the repository row, copied pack files, and staging files if any
  persistence step fails.
- Regression tests cover compressed limits, decompression bombs, wrong formats,
  wrong dimensions, checksum corruption, path traversal, symbolic links, and
  midway failure.

Remaining:

- Validate tray dimensions and format.
- Add an explicit archive format version.
- Add compatibility fixtures for each future archive format version.

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

Implemented:

- Added typed `import_started`, `encode_attempt`, `pack_validation_failed`, and
  `export_whatsapp_result` analytics events.
- Instrumented TikTok, local-gallery, photo-gallery, and camera imports.
- Instrumented static and animated encoding attempts with quality buckets.
- Instrumented categorized pack validation and WhatsApp export outcomes.
- Replaced free-form Crashlytics breadcrumbs and attributes with typed,
  allowlisted categories.
- Removed the full TikTok URL previously sent by `ApifyService`.
- Crash errors retain only exception types and sanitized stack traces; raw
  exception messages are not sent.
- File sizes, quality, sticker counts, and sources use broad buckets or fixed
  categories.
- Console logging now uses professional text prefixes and redacts URL, path,
  and exception-message data.

Remaining:

- Add import completion and categorized failure events.
- Add encode duration and compression fallback count.
- API latency and rate-limit events.
- Cache cleanup results.
- Establish retention, consent, and analytics-disclosure policy before enabling
  production collection.

### 6.18 Fix temporary-file ownership

Implemented:

- `getStickrTemporaryDirectory` is the canonical resolver for the
  `stickr_temp` subdirectory under the platform cache root.
- FFmpeg, overlays, image processing, local-video copies, TikTok imports,
  comment and Apify image downloads, Giphy downloads, meme downloads, batch
  export workspaces, and pack archives use this directory by default.
- Storage measurement and user-triggered cache clearing inspect only this
  owned directory.
- Post-save cleanup canonicalizes candidate paths and rejects anything outside
  `stickr_temp`, including symbolic-link escapes.
- The WorkManager task delegates to the same scoped cleanup implementation.
- Regression tests preserve unrelated MP4 and PNG files in the general
  temporary root and prevent media pipelines from directly resolving it.

Operation-specific subdirectories and process-death expiry policies remain
useful future hardening.
- Add tests proving unrelated files are retained.

### 6.19 Eliminate duplicate and unreachable editor output

Implemented:

- Animated and static editor exports remain in `stickr_temp` while the pack
  chooser is open.
- The editor passes that temporary path directly to the chooser without
  creating an intermediate `documents/stickers` copy.
- `StickerRepository` moves app-owned temporary outputs into the selected
  pack's permanent directory inside the Isar write transaction.
- Cross-filesystem moves fall back to copy-and-delete while preserving the
  same ownership semantics.
- A failed database write restores the temporary source and removes the
  uncommitted destination.
- Dismissing the chooser deletes the generated WebP immediately and leaves the
  editor open for another save attempt.
- File-store, storage-cleanup, repository, and source-contract tests cover
  ownership transfer, rollback, and orphan cleanup.

Remaining:

- Add physical-device coverage for cross-filesystem rename fallback behavior.

### 6.20 Make native staging crash-safe

Implemented:

- Sticker and tray files are copied into a transaction-specific temporary directory.
- Every copied file and the temporary JSON metadata file are flushed and synchronized.
- The previous staged directory is retained as a backup until both atomic renames succeed.
- Commit failures roll the staged directory back to the previous version.
- `StickerContentProvider` repairs interrupted transactions when its process starts.
- Regression tests enforce the temporary-write, synchronization, atomic-rename, and recovery contract.

### 6.21 Resolve interaction and state inconsistencies

Current inconsistencies include:

- Selecting the Create tab immediately opens the TikTok import sheet even though the Create screen offers multiple source choices.
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

Implemented:

- Removed Gradle wrapper exclusions and generated the Gradle 9.3.1 scripts,
  properties, and wrapper JAR for source control.
- Added an exact Fastlane dependency in `android/fastlane/Gemfile` and lock-file
  generation instructions.
- Added strict release define-file handling to the Fastlane beta lane.
- Added an in-app About & licenses screen with an explicit FFmpeg GPL notice,
  application and FFmpeg source links, a written-offer statement, and Flutter's
  third-party `LicensePage`.
- Added `LICENSES/FFMPEG_GPL_NOTICE.md` with upstream source and license links.
- Documented retention of Dart split-debug information and Crashlytics mapping
  configuration.

Remaining:

- Generate and commit `Gemfile.lock` from the approved release Ruby version.
- Obtain legal review of the exact FFmpeg binary and all enabled library terms.
- There is no `integration_test/` suite.
- iOS native tests remain template-level, and no iOS privacy manifest is present.

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

This would avoid teaching users two different collection flows over the same Giphy catalog.

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

### 7.4 Improve local video import resilience

Add physical-device tests for content URIs from Google Photos, Files, and
manufacturer galleries, plus recovery of abandoned temporary copies after
process death.

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

The Android application ID, namespace, native Kotlin packages, ContentProvider authority, App Links declaration, Firebase template, ProGuard rules, and Fastlane package now use `com.stickr.stickr`.

Migration consequence:

- Google Play treats `com.stickr.stickr` as a different application from the former `com.stikk.stikk` ID.
- Builds installed under the former ID cannot receive an in-place upgrade to the new ID.
- Firebase must be configured with a new Android application registration for `com.stickr.stickr`.
- The iOS bundle identifier remains unchanged and should be handled as a separate platform migration decision.

## 8. Recommended delivery roadmap

### Phase 0: Stabilize the current branch

Target: a trustworthy development baseline.

- Keep the corrected share-intent transition test stable.
- Maintain the new zero-issue analyzer baseline.
- Keep README architecture and release instructions synchronized.
- Keep pull-request CI green.
- Extend CI with a debug APK build using the tracked Gradle wrapper.

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

- Share models, image widgets, pagination, errors, downloads, and staging.
- Persist the draft tray.

Exit criteria:

- No user-facing feature requires a provider that cannot issue new credentials.
- Trending and search have consistent behavior.

### Phase 3: Strengthen pack data and export

Target: durable, versioned, diagnosable packs.

- Preserve the explicit Isar metadata and monotonic content revision.
- Add `.stickr` schema versioning and compatibility fixtures.
- Move batch export into a dedicated service with progress and cancellation.
- Add Android device-level WhatsApp validation.

Exit criteria:

- Pack edits invalidate WhatsApp cache correctly.
- Existing user packs migrate without data loss.
- Import and export failures roll back cleanly.

### Phase 4: Complete creation and platform scope

Target: close the largest product gaps.

- Decide and document iOS support.
- Improve mask editing and pack customization.
- Add integration and golden tests.

## 9. Suggested technical backlog

### Highest priority

- Rotate the previously committed Giphy key.
- Preserve the corrected FFmpeg timing, speed, and preview framing contract.
- Generate and commit the Fastlane `Gemfile.lock`.
- Complete legal review for the GPL-enabled FFmpeg release binary.
- Extend CI with an Android debug build.
- Configure Firebase or remove claims that Crashlytics is active.
- Update README.

### High priority

- Migrate remaining external services to the shared network client.
- Validate imported tray image dimensions and format.
- Add device-level Android WhatsApp export tests.
- Resolve FFmpeg license and distribution obligations.
- Add privacy and third-party attribution screens.

### Medium priority

- Persist Community draft trays.
- Add translated ARB files and locale-specific layout tests.
- Add Community search and categories.
- Add cancellation and retry controls to batch export progress.
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
