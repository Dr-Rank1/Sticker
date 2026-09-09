// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Stickr';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get continueLabel => 'Continue';

  @override
  String get retry => 'Retry';

  @override
  String get tryAgain => 'Try again';

  @override
  String get search => 'Search';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get started';

  @override
  String get notNow => 'Not now';

  @override
  String get openSettings => 'Open settings';

  @override
  String get library => 'Library';

  @override
  String get create => 'Create';

  @override
  String get discover => 'Discover';

  @override
  String get community => 'Community';

  @override
  String get settings => 'Settings';

  @override
  String get currentTab => 'Current tab';

  @override
  String switchesToTab(String label) {
    return 'Switches to the $label tab';
  }

  @override
  String get onboardingTikTokTitle => 'Paste TikTok links';

  @override
  String get onboardingTikTokBody =>
      'Drop in any video URL. We fetch a clean clip so you can turn a moment into a sticker.';

  @override
  String get onboardingEditTitle => 'Edit & remove backgrounds';

  @override
  String get onboardingEditBody =>
      'Trim, add text, and cut out the subject on this device. No account. No uploads.';

  @override
  String get onboardingWhatsAppTitle => 'Export to WhatsApp';

  @override
  String get onboardingWhatsAppBody =>
      'Pack your stickers and add them to WhatsApp in a tap. Always free, forever.';

  @override
  String get createSubtitle => 'Turn any moment into a WhatsApp sticker.';

  @override
  String get fromPhoto => 'From a photo';

  @override
  String get fromPhotoSubtitle => 'Auto crop, remove the background, add text.';

  @override
  String get startFromMeme => 'Start from Meme';

  @override
  String get startFromMemeSubtitle =>
      'Pick a popular template and add your own text.';

  @override
  String get fromTikTok => 'From TikTok';

  @override
  String get fromTikTokSubtitle => 'Paste a link and pick the perfect clip.';

  @override
  String get fromVideo => 'From a video';

  @override
  String get fromVideoSubtitle => 'Make an animated sticker in seconds.';

  @override
  String get freeForeverNote =>
      'Stickr is 100% free. No accounts, no paywalls.';

  @override
  String get storage => 'Storage';

  @override
  String get storageDescription =>
      'See what Stickr uses on this device and remove disposable working files.';

  @override
  String get appDocuments => 'App documents';

  @override
  String get savedPacksAndStickers => 'Saved packs and stickers';

  @override
  String get temporaryCache => 'Temporary cache';

  @override
  String get rawVideosAndWorkingFiles => 'Raw videos and working files';

  @override
  String get totalAppStorage => 'Total app storage';

  @override
  String get clearing => 'Clearing…';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String get savedPacksNotDeleted =>
      'Your saved sticker packs will not be deleted.';

  @override
  String get appearance => 'Appearance';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get cacheAlreadyClear => 'Cache is already clear.';

  @override
  String freedStorage(String size) {
    return 'Freed $size.';
  }

  @override
  String get couldNotClearCache => 'Could not clear the cache. Try again.';

  @override
  String get couldNotReadStorage => 'Could not read storage. Try again';

  @override
  String get librarySubtitle => 'Your packs. Always free, forever.';

  @override
  String get newPack => 'New pack';

  @override
  String get noPacksYet => 'No packs yet';

  @override
  String get noPacksMessage =>
      'Create stickers from photos, videos, or TikToks and group them into packs for WhatsApp.';

  @override
  String get createSticker => 'Create a sticker';

  @override
  String opensReadyPack(String countLabel) {
    return 'Opens this pack. Ready for WhatsApp, $countLabel.';
  }

  @override
  String opensBlockedPack(String reason) {
    return 'Opens this pack. $reason';
  }

  @override
  String readyCount(String countLabel) {
    return 'Ready · $countLabel';
  }

  @override
  String get unexpectedErrorTitle => 'Something went wrong';

  @override
  String get unexpectedErrorMessage =>
      'Stickr hit an unexpected problem. You can keep using the rest of the app.';

  @override
  String get allowPhotosVideos => 'Allow access to photos & videos';

  @override
  String get mediaPermissionDescription =>
      'Stickr only reads files you pick so you can cut out stickers and export them to WhatsApp. Nothing is uploaded.';

  @override
  String get allowAccess => 'Allow access';

  @override
  String get permissionTurnedOff => 'Permission turned off';

  @override
  String get permissionSettingsDescription =>
      'To pick photos and videos, allow access in system settings.';

  @override
  String get useCamera => 'Use your camera';

  @override
  String get cameraPermissionDescription =>
      'Stickr uses the camera so you can snap a photo and turn it into a sticker.';

  @override
  String get noStickersFound => 'No stickers found. Try another search.';

  @override
  String get couldNotSearchStickers =>
      'Couldn’t search for stickers. Please try again.';

  @override
  String get couldNotLoadMoreStickers =>
      'Couldn’t load more stickers. Please try again.';

  @override
  String get couldNotSaveSticker =>
      'Couldn’t save that sticker. Please try again.';

  @override
  String addedToPack(String packName, String countLabel) {
    return 'Added to $packName ($countLabel).';
  }

  @override
  String get discoverSubtitle => 'Find stickers powered by Giphy.';

  @override
  String get discoverSearchHint => 'Search reactions, cats, anime…';

  @override
  String get missingGiphyApiKey =>
      'Add a Giphy API key at build time to enable Discover.';

  @override
  String get discoverEmptyMessage =>
      'Search for a mood, reaction, or character.';

  @override
  String get readyToDiscover => 'Ready to discover';

  @override
  String get noStickersYet => 'No stickers yet';

  @override
  String importedPack(String packName) {
    return 'Imported $packName.';
  }

  @override
  String get couldNotImportPack => 'Could not import this pack.';

  @override
  String get photoImportDescription =>
      'Pick a picture. We’ll cut out the subject on this device, then you can add text and emojis.';

  @override
  String get removeBackground => 'Remove Background';

  @override
  String get onDeviceMlDescription =>
      'Private, on-device processing with no API limits.';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get openingPhotos => 'Opening photos...';

  @override
  String get cuttingOutSubject => 'Cutting out the subject...';

  @override
  String get preparingPhoto => 'Preparing your photo...';

  @override
  String get scanningLocally => 'Scanning locally';

  @override
  String get clipboardEmpty => 'Your clipboard is empty.';

  @override
  String get tiktokImportDescription =>
      'Paste a video link and we will fetch a clean MP4 for your animated sticker.';

  @override
  String get tiktokUrlHint => 'https://www.tiktok.com/@user/video/...';

  @override
  String get paste => 'Paste';

  @override
  String get findingVideo => 'Finding video...';

  @override
  String get downloading => 'Downloading...';

  @override
  String get importVideo => 'Import video';

  @override
  String get lookingUpTikTok => 'Looking up that TikTok...';

  @override
  String get downloadingVideo => 'Downloading video...';

  @override
  String get me => 'Me';

  @override
  String get editPack => 'Edit pack';

  @override
  String get packFormDescription =>
      'WhatsApp needs a pack name, an author, and a 96×96 tray icon. We’ll make the tray icon for you.';

  @override
  String get packName => 'Pack name';

  @override
  String get packNameHint => 'Monday moods';

  @override
  String get author => 'Author';

  @override
  String get authorHint => 'Your name';

  @override
  String get createPack => 'Create pack';

  @override
  String get save => 'Save';

  @override
  String get saveToPack => 'Save to a pack';

  @override
  String get saveAnimatedStickerDescription =>
      'WhatsApp packs need 3–30 stickers of the same type. Pick a pack with room, or make a new one.';

  @override
  String get saveStaticStickerDescription =>
      'Photo stickers are static. WhatsApp packs can’t mix them with animated clips.';

  @override
  String get noPacksAvailable => 'You don’t have any packs yet.';

  @override
  String fullStickerPack(int count) {
    return 'Full ($count stickers)';
  }

  @override
  String get packForPhotoStickers => 'This pack is for photo stickers';

  @override
  String get packForAnimatedStickers => 'This pack is for animated stickers';

  @override
  String packAuthorCount(String author, String countLabel) {
    return '$author · $countLabel';
  }

  @override
  String get textTool => 'Text';

  @override
  String get emojiTool => 'Emojis';

  @override
  String get speed => 'Speed';

  @override
  String get addTextHint => 'Adds a text sticker to the canvas';

  @override
  String get addEmojiHint => 'Adds an emoji sticker to the canvas';

  @override
  String get speedOptionsHint => 'Opens playback speed options';

  @override
  String get couldNotPrepareMeme =>
      'Could not prepare that meme. Try another template.';

  @override
  String get startFromMemeSheet => 'Start from a meme';

  @override
  String get memeSheetSubtitle => 'Pick a template, then add your own text.';

  @override
  String get memeCropDescription =>
      'Templates are center-cropped to 1:1 and prepared at 512×512.';

  @override
  String get couldNotLoadTrending =>
      'Could not load trending stickers. Please retry.';

  @override
  String get myPackCapacity => 'My Pack can hold up to 30 stickers.';

  @override
  String get myPack => 'My Pack';

  @override
  String get batchExportIncomplete => 'The batch export did not complete.';

  @override
  String get couldNotExportMyPack =>
      'Couldn’t export My Pack. Please try again.';

  @override
  String get communitySubtitle =>
      'Collect trending stickers and build your next pack.';

  @override
  String get addedToMyPack => 'Added to My Pack';

  @override
  String get addToMyPack => 'Add to My Pack';

  @override
  String get animatedBadge => 'GIF';

  @override
  String myPackCount(int count, int maximum) {
    return 'My Pack  $count/$maximum';
  }

  @override
  String exportProgress(int completed, int total) {
    return 'Export $completed/$total';
  }

  @override
  String get exportToWhatsApp => 'Export to WhatsApp';

  @override
  String get communityTrayHint =>
      'Tap + on at least 3 stickers to start a pack.';

  @override
  String get scanningComments => 'Scanning comments for stickers...';

  @override
  String get couldNotScanComments =>
      'Couldn’t scan those comments. Please try again.';

  @override
  String get couldNotExportStickers =>
      'Couldn’t export those stickers. Please try again.';

  @override
  String get commentStickers => 'Comment stickers';

  @override
  String exportSelection(int selected, int maximum) {
    return 'Export ($selected/$maximum)';
  }

  @override
  String get noCommentStickers =>
      'No image stickers were found in the scanned comments.';

  @override
  String get pack => 'Pack';

  @override
  String get packDeleted => 'This pack was deleted.';

  @override
  String get sharePack => 'Share pack';

  @override
  String get deletePack => 'Delete pack';

  @override
  String get noStickersInPack => 'No stickers in this pack yet.';

  @override
  String stickerInPack(String packName) {
    return 'Sticker in $packName';
  }

  @override
  String get removeStickerHint => 'Double tap and hold to remove this sticker';

  @override
  String get addStickers => 'Add stickers';

  @override
  String get adding => 'Adding...';

  @override
  String get addToWhatsApp => 'Add to WhatsApp';

  @override
  String whatsAppMinimumStickers(int remaining) {
    return 'WhatsApp requires at least 3 stickers in a pack. Add $remaining more to continue.';
  }

  @override
  String get couldNotSharePack => 'Could not share this pack.';

  @override
  String get whatsAppNotInstalled => 'WhatsApp isn’t installed';

  @override
  String get installWhatsAppDescription =>
      'Install WhatsApp or WhatsApp Business, then come back to add your sticker pack.';

  @override
  String get installWhatsApp => 'Install WhatsApp';

  @override
  String get installWhatsAppBusiness => 'Install WhatsApp Business';

  @override
  String get couldNotOpenAppStore =>
      'Couldn’t open the app store. Please try again.';

  @override
  String get deletePackQuestion => 'Delete pack?';

  @override
  String deletePackDescription(String packName) {
    return '“$packName” and its stickers will be removed from this device.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get remove => 'Remove';

  @override
  String get removeStickerQuestion => 'Remove sticker?';

  @override
  String get removeStickerDescription => 'It will be deleted from this pack.';

  @override
  String packDetailSummary(String countLabel) {
    return '$countLabel stickers · 96×96 tray';
  }

  @override
  String stickerSaved(int kilobytes) {
    return 'Sticker saved ($kilobytes KB). Add it to a pack from Library.';
  }

  @override
  String get addText => 'Add text';

  @override
  String get textHint => 'Say something';

  @override
  String get add => 'Add';

  @override
  String get makingSticker => 'Making your sticker…';

  @override
  String get closeEditor => 'Close editor';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String trimMaximum(String selection, String maximum) {
    return '$selection / $maximum max';
  }

  @override
  String get clipTrimRange => 'Clip trim range';

  @override
  String clipTrimHint(String maximum) {
    return 'Drag the handles to set a clip up to $maximum';
  }

  @override
  String trimRangeValue(String start, String end) {
    return '$start to $end';
  }

  @override
  String get stickerCanvas => 'Sticker canvas';

  @override
  String get stickerCanvasHint =>
      'Drag a sticker to move it. Pinch to resize. Rotate with two fingers.';

  @override
  String get deleteSticker => 'Delete sticker';

  @override
  String get deleteStickerHint => 'Removes this sticker from the canvas';

  @override
  String get packNoLongerExists => 'That pack no longer exists.';

  @override
  String get packMissingTrayIcon => 'This pack is missing a tray icon.';

  @override
  String get packStickerFileMissing =>
      'A sticker file is missing from this pack.';

  @override
  String get stickrFileNotFound => 'The .stickr file could not be found.';

  @override
  String get invalidStickrPack => 'This is not a valid .stickr pack.';

  @override
  String get packMissingNameOrPublisher =>
      'This pack is missing a name or publisher.';

  @override
  String get packNameRequired => 'Give this pack a name.';

  @override
  String get packAuthorRequired => 'Add an author name.';

  @override
  String get packIdentifierExists =>
      'A pack with that identifier already exists.';

  @override
  String packMaximumStickers(int maximum) {
    return 'WhatsApp packs can hold at most $maximum stickers.';
  }

  @override
  String get packStaticOnly =>
      'This pack is for static stickers. Create a new pack for animated ones.';

  @override
  String get packAnimatedOnly =>
      'This pack is for animated stickers. Create a new pack for photo stickers.';

  @override
  String packStickerCountRange(int minimum, int maximum) {
    return 'WhatsApp packs must contain between $minimum and $maximum stickers.';
  }

  @override
  String get stickerFileMissing => 'The sticker file is missing.';

  @override
  String packNameTooLong(int maximum) {
    return 'Pack names can be at most $maximum characters.';
  }

  @override
  String packAuthorTooLong(int maximum) {
    return 'Author names can be at most $maximum characters.';
  }

  @override
  String trayIconRequired(int size) {
    return 'Add a ${size}x$size tray icon.';
  }

  @override
  String addStickersToExport(int count, int minimum) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count more stickers to export (minimum $minimum).',
      one: 'Add 1 more sticker to export (minimum $minimum).',
    );
    return '$_temp0';
  }

  @override
  String removeStickersToExport(int count, int maximum) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove $count stickers to export (maximum $maximum).',
      one: 'Remove 1 sticker to export (maximum $maximum).',
    );
    return '$_temp0';
  }

  @override
  String stickerCountOfMaximum(int count, int maximum) {
    return '$count / $maximum';
  }

  @override
  String get couldNotCreateTrayIcon => 'Could not create the 96x96 tray icon.';

  @override
  String get whatsAppNotInstalledDevice =>
      'WhatsApp isn’t installed on this device.';

  @override
  String whatsAppReadyDesktop(int count) {
    return 'This pack is WhatsApp-ready ($count stickers, 96×96 tray). Add to WhatsApp from an Android or iOS build.';
  }

  @override
  String get whatsAppReadyDevice =>
      'This pack meets WhatsApp’s rules. Connect it from a device build with WhatsApp installed.';

  @override
  String get whatsAppAndroidOnly =>
      'Add to WhatsApp is available on Android with WhatsApp installed.';

  @override
  String get addedToWhatsApp => 'Added to WhatsApp.';

  @override
  String get couldNotReachWhatsAppExport =>
      'Couldn’t reach the WhatsApp export on this device.';

  @override
  String get whatsAppDidNotAddPack => 'WhatsApp didn’t add the pack.';

  @override
  String get whatsAppRejectedPack => 'WhatsApp rejected this pack.';

  @override
  String get couldNotPrepareWhatsAppFiles =>
      'Couldn’t prepare sticker files for WhatsApp.';

  @override
  String get exportAlreadyInProgress => 'An export is already in progress.';

  @override
  String get packMissingWhatsAppData =>
      'This pack is missing data WhatsApp needs.';

  @override
  String get couldNotAddPackToWhatsApp => 'Couldn’t add this pack to WhatsApp.';

  @override
  String get invalidTikTokLink =>
      'That doesn\'t look like a TikTok link. Paste a video URL and try again.';

  @override
  String get noInternetConnection =>
      'No internet connection. Check your network and try again.';

  @override
  String get unreadableTikwmResponse =>
      'TikWM returned an unreadable response. Please try again.';

  @override
  String get tikwmVideoNotFound =>
      'TikWM couldn’t find a video at that link. Check it and try again.';

  @override
  String get tikwmNoDownload =>
      'TikWM found that post, but no downloadable video was available.';

  @override
  String get emptyVideoDownload =>
      'The download finished, but the video file was empty.';

  @override
  String get tiktokImportFailed =>
      'Something went wrong while importing that TikTok. Please try again.';

  @override
  String get tikwmRateLimited =>
      'TikWM is receiving too many requests right now. Wait a moment and try again.';

  @override
  String get tikwmTikTokNotFound =>
      'TikWM couldn’t find that TikTok. Check the link or try another public video.';

  @override
  String get tikwmProcessFailed =>
      'TikWM couldn’t process that video right now. Please try again shortly.';

  @override
  String get connectionTimedOut =>
      'The connection timed out. Try again on a stronger network.';

  @override
  String get tikwmLookupFailed =>
      'TikWM couldn’t look up that video right now. Please try again.';

  @override
  String get videoDownloadFailed =>
      'We couldn’t download that video right now. Please try again.';

  @override
  String get downloadCancelled => 'The download was cancelled.';

  @override
  String get downloadFailed =>
      'Something went wrong while downloading. Please try again.';

  @override
  String get commentScanNotConfigured =>
      'Comment scanning is not configured. Add SCRAPEBADGER_API_KEY to the app build.';

  @override
  String get commentServiceUnreadable =>
      'The comment service returned an unreadable response.';

  @override
  String get emptyTikTokStickerImage =>
      'TikTok returned an empty sticker image.';

  @override
  String get commentStickerUnavailable =>
      'That comment sticker is no longer available.';

  @override
  String get shortTikTokLinkUnresolved =>
      'The shortened TikTok link could not be resolved.';

  @override
  String get invalidTikTokVideoId => 'TikTok did not return a valid video ID.';

  @override
  String couldNotResolveTikTokLink(String error) {
    return 'Could not resolve that TikTok link: $error';
  }

  @override
  String get commentScanUnauthorized =>
      'Comment scanning is not authorized. Check the ScrapeBadger API key.';

  @override
  String get commentScanLimitReached =>
      'The comment scan limit has been reached. Please try again later.';

  @override
  String get tiktokCommentsUnavailable =>
      'TikTok comments are unavailable right now. Please try again.';

  @override
  String get commentScanTimedOut =>
      'The comment scan timed out. Please try again.';

  @override
  String get commentServiceConnectionFailed =>
      'Could not connect to the comment service.';

  @override
  String get commentScanFailed =>
      'Could not scan TikTok comments. Please try again.';

  @override
  String get apifyNetworkError =>
      'No internet connection. Check your network and try again.';

  @override
  String get apifyLimitReached =>
      'Apify request limit was reached. Please try again later.';

  @override
  String get apifyUnreadableResponse =>
      'Apify returned an unreadable dataset response.';

  @override
  String apifyRunFailed(String error) {
    return 'Could not run the synchronous Apify scraper: $error';
  }

  @override
  String get invalidHttpsTikTokUrl => 'Provide a valid HTTPS TikTok post URL.';

  @override
  String get apifyNotConfigured =>
      'Apify is not configured. Add APIFY_API_TOKEN to the app build.';

  @override
  String get apifyRejectedToken => 'Apify rejected the API token.';

  @override
  String get apifyTimedOut => 'The Apify request timed out. Please try again.';

  @override
  String get apifyConnectionFailed => 'Could not connect to Apify.';

  @override
  String get apifyRequestFailed =>
      'Apify could not complete the scraper request.';

  @override
  String get commentStickerOpenFailed =>
      'That comment sticker could not be opened.';

  @override
  String get stickerCanvasSizeFailed =>
      'The sticker canvas could not be sized to 512×512.';

  @override
  String get commentStickerTooLarge =>
      'Could not keep the sticker under 100KB. Try another comment image.';

  @override
  String get savingStickersUnsupported =>
      'Saving stickers needs the mobile or desktop app.';

  @override
  String get photoUnavailable => 'That photo is no longer available.';

  @override
  String get photoOpenFailed => 'The photo couldn’t be opened.';

  @override
  String get photoOpenTryAnother =>
      'That photo couldn’t be opened. Try another one.';

  @override
  String ffmpegStickerFailed(int code) {
    return 'FFmpeg failed while creating the sticker (code $code).';
  }

  @override
  String get ffmpegNoStickerFile => 'FFmpeg did not write a sticker file.';

  @override
  String stickerEncodeRetry(int kilobytes) {
    return 'Sticker was ${kilobytes}KB. Trying a smaller encode...';
  }

  @override
  String get staticStickerTooLarge =>
      'Could not keep the sticker under 100KB. Try a simpler photo.';

  @override
  String get animatedStickerTooLarge =>
      'Could not keep the sticker under 500KB. Try a shorter clip.';

  @override
  String get exportCancelled => 'Export cancelled.';

  @override
  String get sourceVideoUnavailable =>
      'The source video is no longer available.';

  @override
  String get videoEmptyOrUnavailable =>
      'The selected video is empty or unavailable.';

  @override
  String get videoTooLarge => 'Choose a video smaller than 250 MB.';

  @override
  String get videoInspectionFailed =>
      'Couldn’t inspect that video. Choose a different file.';

  @override
  String get videoDurationUnreadable =>
      'The selected video has no readable duration.';

  @override
  String get videoTooLong => 'Choose a video that is 10 minutes or shorter.';

  @override
  String videoCodecUnsupported(String codec) {
    return 'The $codec video codec is not supported.';
  }

  @override
  String get unknownCodec => 'unknown';

  @override
  String get videoInvalidDimensions =>
      'The selected video has invalid dimensions.';

  @override
  String get videoDimensionsTooLarge =>
      'Choose a video no larger than 4096 by 4096 pixels.';

  @override
  String get fileNotReadableVideo =>
      'The selected file is not a readable video.';

  @override
  String get fileMissingVideoTrack =>
      'The selected file does not contain a video track.';

  @override
  String get transparentForegroundRenderFailed =>
      'Couldn’t render the transparent foreground.';

  @override
  String get textSticker => 'Text sticker';

  @override
  String textStickerWithText(String text) {
    return 'Text sticker, $text';
  }

  @override
  String get emojiSticker => 'Emoji sticker';

  @override
  String get imageSticker => 'Image sticker';

  @override
  String get selectedStickerHint =>
      'Drag to move, pinch to scale, and rotate with two fingers';

  @override
  String get unselectedStickerHint => 'Double tap to select this sticker';

  @override
  String get giphyRateLimitReached =>
      'Giphy request limit was reached. Please try again later.';

  @override
  String get giphyTrendingUnavailable =>
      'Trending stickers are unavailable because Giphy is not configured.';

  @override
  String get giphySearchRequired => 'Type something to search for stickers.';

  @override
  String get giphySearchUnavailable =>
      'Sticker search is unavailable because Giphy is not configured.';

  @override
  String get couldNotSearchGiphy => 'Could not search Giphy. Please retry.';

  @override
  String get invalidStickerDownloadUrl =>
      'That sticker has an invalid download URL.';

  @override
  String get giphyEmptySticker => 'Giphy downloaded an empty sticker.';

  @override
  String get stickerDownloadFailed =>
      'Could not download that sticker. Please retry.';

  @override
  String get trendingSticker => 'Trending sticker';

  @override
  String get giphyUnreadableResponse =>
      'Giphy returned an unreadable sticker response.';

  @override
  String get giphyConnectionFailed =>
      'Could not connect to Giphy. Check your connection and retry.';

  @override
  String get giphyRejectedApiKey =>
      'Giphy rejected the API key. Check GIPHY_API_KEY.';

  @override
  String get giphyTimedOut => 'The Giphy request timed out. Please retry.';

  @override
  String get giphyRequestFailed =>
      'Giphy could not complete the request. Please retry.';

  @override
  String get imgflipUnreadableResponse =>
      'Imgflip returned an unreadable response. Please try again.';

  @override
  String get imgflipTemplatesFailed =>
      'Imgflip couldn’t load meme templates right now.';

  @override
  String get memeTemplate => 'Meme template';

  @override
  String get invalidMemeImageLink =>
      'That meme template has an invalid image link.';

  @override
  String get memeDownloadFailed =>
      'Couldn’t download that meme template. Please try again.';

  @override
  String get imgflipEmptyTemplate =>
      'Imgflip downloaded an empty meme template.';

  @override
  String get imgflipTimedOut =>
      'Imgflip took too long to respond. Please try again.';

  @override
  String get imgflipBusy =>
      'Imgflip is busy right now. Wait a moment and try again.';

  @override
  String get imgflipTemplateDownloadFailed =>
      'Imgflip couldn’t download that template.';

  @override
  String get imgflipTemplatesUnavailable =>
      'Imgflip templates are unavailable right now.';

  @override
  String get templateDownloadCancelled =>
      'The template download was cancelled.';

  @override
  String get templateLoadingCancelled =>
      'Loading meme templates was cancelled.';

  @override
  String get memeTemplatesLoadFailed =>
      'Couldn’t load meme templates. Please try again.';

  @override
  String get photoPrepareFailed =>
      'Couldn’t prepare that photo. Please try another one.';

  @override
  String get noMemeTemplates =>
      'The meme service did not return any templates.';

  @override
  String get couldNotLoadPacks =>
      'Could not load your sticker packs. Please try again.';

  @override
  String get couldNotSavePack => 'Could not save this pack. Please try again.';

  @override
  String get couldNotAddStickerToPack =>
      'Could not add this sticker to the pack. Please try again.';
}
