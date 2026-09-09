import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Stickr'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @currentTab.
  ///
  /// In en, this message translates to:
  /// **'Current tab'**
  String get currentTab;

  /// No description provided for @switchesToTab.
  ///
  /// In en, this message translates to:
  /// **'Switches to the {label} tab'**
  String switchesToTab(String label);

  /// No description provided for @onboardingTikTokTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste TikTok links'**
  String get onboardingTikTokTitle;

  /// No description provided for @onboardingTikTokBody.
  ///
  /// In en, this message translates to:
  /// **'Drop in any video URL. We fetch a clean clip so you can turn a moment into a sticker.'**
  String get onboardingTikTokBody;

  /// No description provided for @onboardingEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit & remove backgrounds'**
  String get onboardingEditTitle;

  /// No description provided for @onboardingEditBody.
  ///
  /// In en, this message translates to:
  /// **'Trim, add text, and cut out the subject on this device. No account. No uploads.'**
  String get onboardingEditBody;

  /// No description provided for @onboardingWhatsAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Export to WhatsApp'**
  String get onboardingWhatsAppTitle;

  /// No description provided for @onboardingWhatsAppBody.
  ///
  /// In en, this message translates to:
  /// **'Pack your stickers and add them to WhatsApp in a tap. Always free, forever.'**
  String get onboardingWhatsAppBody;

  /// No description provided for @createSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn any moment into a WhatsApp sticker.'**
  String get createSubtitle;

  /// No description provided for @fromPhoto.
  ///
  /// In en, this message translates to:
  /// **'From a photo'**
  String get fromPhoto;

  /// No description provided for @fromPhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto crop, remove the background, add text.'**
  String get fromPhotoSubtitle;

  /// No description provided for @startFromMeme.
  ///
  /// In en, this message translates to:
  /// **'Start from Meme'**
  String get startFromMeme;

  /// No description provided for @startFromMemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a popular template and add your own text.'**
  String get startFromMemeSubtitle;

  /// No description provided for @fromTikTok.
  ///
  /// In en, this message translates to:
  /// **'From TikTok'**
  String get fromTikTok;

  /// No description provided for @fromTikTokSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste a link and pick the perfect clip.'**
  String get fromTikTokSubtitle;

  /// No description provided for @fromVideo.
  ///
  /// In en, this message translates to:
  /// **'From a video'**
  String get fromVideo;

  /// No description provided for @fromVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Make an animated sticker in seconds.'**
  String get fromVideoSubtitle;

  /// No description provided for @freeForeverNote.
  ///
  /// In en, this message translates to:
  /// **'Stickr is 100% free. No accounts, no paywalls.'**
  String get freeForeverNote;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @storageDescription.
  ///
  /// In en, this message translates to:
  /// **'See what Stickr uses on this device and remove disposable working files.'**
  String get storageDescription;

  /// No description provided for @appDocuments.
  ///
  /// In en, this message translates to:
  /// **'App documents'**
  String get appDocuments;

  /// No description provided for @savedPacksAndStickers.
  ///
  /// In en, this message translates to:
  /// **'Saved packs and stickers'**
  String get savedPacksAndStickers;

  /// No description provided for @temporaryCache.
  ///
  /// In en, this message translates to:
  /// **'Temporary cache'**
  String get temporaryCache;

  /// No description provided for @rawVideosAndWorkingFiles.
  ///
  /// In en, this message translates to:
  /// **'Raw videos and working files'**
  String get rawVideosAndWorkingFiles;

  /// No description provided for @totalAppStorage.
  ///
  /// In en, this message translates to:
  /// **'Total app storage'**
  String get totalAppStorage;

  /// No description provided for @clearing.
  ///
  /// In en, this message translates to:
  /// **'Clearing…'**
  String get clearing;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @savedPacksNotDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your saved sticker packs will not be deleted.'**
  String get savedPacksNotDeleted;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @cacheAlreadyClear.
  ///
  /// In en, this message translates to:
  /// **'Cache is already clear.'**
  String get cacheAlreadyClear;

  /// No description provided for @freedStorage.
  ///
  /// In en, this message translates to:
  /// **'Freed {size}.'**
  String freedStorage(String size);

  /// No description provided for @couldNotClearCache.
  ///
  /// In en, this message translates to:
  /// **'Could not clear the cache. Try again.'**
  String get couldNotClearCache;

  /// No description provided for @couldNotReadStorage.
  ///
  /// In en, this message translates to:
  /// **'Could not read storage. Try again'**
  String get couldNotReadStorage;

  /// No description provided for @librarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your packs. Always free, forever.'**
  String get librarySubtitle;

  /// No description provided for @newPack.
  ///
  /// In en, this message translates to:
  /// **'New pack'**
  String get newPack;

  /// No description provided for @noPacksYet.
  ///
  /// In en, this message translates to:
  /// **'No packs yet'**
  String get noPacksYet;

  /// No description provided for @noPacksMessage.
  ///
  /// In en, this message translates to:
  /// **'Create stickers from photos, videos, or TikToks and group them into packs for WhatsApp.'**
  String get noPacksMessage;

  /// No description provided for @createSticker.
  ///
  /// In en, this message translates to:
  /// **'Create a sticker'**
  String get createSticker;

  /// No description provided for @opensReadyPack.
  ///
  /// In en, this message translates to:
  /// **'Opens this pack. Ready for WhatsApp, {countLabel}.'**
  String opensReadyPack(String countLabel);

  /// No description provided for @opensBlockedPack.
  ///
  /// In en, this message translates to:
  /// **'Opens this pack. {reason}'**
  String opensBlockedPack(String reason);

  /// No description provided for @readyCount.
  ///
  /// In en, this message translates to:
  /// **'Ready · {countLabel}'**
  String readyCount(String countLabel);

  /// No description provided for @unexpectedErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get unexpectedErrorTitle;

  /// No description provided for @unexpectedErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Stickr hit an unexpected problem. You can keep using the rest of the app.'**
  String get unexpectedErrorMessage;

  /// No description provided for @allowPhotosVideos.
  ///
  /// In en, this message translates to:
  /// **'Allow access to photos & videos'**
  String get allowPhotosVideos;

  /// No description provided for @mediaPermissionDescription.
  ///
  /// In en, this message translates to:
  /// **'Stickr only reads files you pick so you can cut out stickers and export them to WhatsApp. Nothing is uploaded.'**
  String get mediaPermissionDescription;

  /// No description provided for @allowAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get allowAccess;

  /// No description provided for @permissionTurnedOff.
  ///
  /// In en, this message translates to:
  /// **'Permission turned off'**
  String get permissionTurnedOff;

  /// No description provided for @permissionSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'To pick photos and videos, allow access in system settings.'**
  String get permissionSettingsDescription;

  /// No description provided for @useCamera.
  ///
  /// In en, this message translates to:
  /// **'Use your camera'**
  String get useCamera;

  /// No description provided for @cameraPermissionDescription.
  ///
  /// In en, this message translates to:
  /// **'Stickr uses the camera so you can snap a photo and turn it into a sticker.'**
  String get cameraPermissionDescription;

  /// No description provided for @noStickersFound.
  ///
  /// In en, this message translates to:
  /// **'No stickers found. Try another search.'**
  String get noStickersFound;

  /// No description provided for @couldNotSearchStickers.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t search for stickers. Please try again.'**
  String get couldNotSearchStickers;

  /// No description provided for @couldNotLoadMoreStickers.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load more stickers. Please try again.'**
  String get couldNotLoadMoreStickers;

  /// No description provided for @couldNotSaveSticker.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save that sticker. Please try again.'**
  String get couldNotSaveSticker;

  /// No description provided for @addedToPack.
  ///
  /// In en, this message translates to:
  /// **'Added to {packName} ({countLabel}).'**
  String addedToPack(String packName, String countLabel);

  /// No description provided for @discoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find stickers powered by Giphy.'**
  String get discoverSubtitle;

  /// No description provided for @discoverSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search reactions, cats, anime…'**
  String get discoverSearchHint;

  /// No description provided for @missingGiphyApiKey.
  ///
  /// In en, this message translates to:
  /// **'Add a Giphy API key at build time to enable Discover.'**
  String get missingGiphyApiKey;

  /// No description provided for @discoverEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Search for a mood, reaction, or character.'**
  String get discoverEmptyMessage;

  /// No description provided for @readyToDiscover.
  ///
  /// In en, this message translates to:
  /// **'Ready to discover'**
  String get readyToDiscover;

  /// No description provided for @noStickersYet.
  ///
  /// In en, this message translates to:
  /// **'No stickers yet'**
  String get noStickersYet;

  /// No description provided for @importedPack.
  ///
  /// In en, this message translates to:
  /// **'Imported {packName}.'**
  String importedPack(String packName);

  /// No description provided for @couldNotImportPack.
  ///
  /// In en, this message translates to:
  /// **'Could not import this pack.'**
  String get couldNotImportPack;

  /// No description provided for @photoImportDescription.
  ///
  /// In en, this message translates to:
  /// **'Pick a picture. We’ll cut out the subject on this device, then you can add text and emojis.'**
  String get photoImportDescription;

  /// No description provided for @removeBackground.
  ///
  /// In en, this message translates to:
  /// **'Remove Background'**
  String get removeBackground;

  /// No description provided for @onDeviceMlDescription.
  ///
  /// In en, this message translates to:
  /// **'Private, on-device processing with no API limits.'**
  String get onDeviceMlDescription;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// No description provided for @openingPhotos.
  ///
  /// In en, this message translates to:
  /// **'Opening photos...'**
  String get openingPhotos;

  /// No description provided for @cuttingOutSubject.
  ///
  /// In en, this message translates to:
  /// **'Cutting out the subject...'**
  String get cuttingOutSubject;

  /// No description provided for @preparingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Preparing your photo...'**
  String get preparingPhoto;

  /// No description provided for @scanningLocally.
  ///
  /// In en, this message translates to:
  /// **'Scanning locally'**
  String get scanningLocally;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your clipboard is empty.'**
  String get clipboardEmpty;

  /// No description provided for @tiktokImportDescription.
  ///
  /// In en, this message translates to:
  /// **'Paste a video link and we will fetch a clean MP4 for your animated sticker.'**
  String get tiktokImportDescription;

  /// No description provided for @tiktokUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://www.tiktok.com/@user/video/...'**
  String get tiktokUrlHint;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @findingVideo.
  ///
  /// In en, this message translates to:
  /// **'Finding video...'**
  String get findingVideo;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloading;

  /// No description provided for @importVideo.
  ///
  /// In en, this message translates to:
  /// **'Import video'**
  String get importVideo;

  /// No description provided for @lookingUpTikTok.
  ///
  /// In en, this message translates to:
  /// **'Looking up that TikTok...'**
  String get lookingUpTikTok;

  /// No description provided for @downloadingVideo.
  ///
  /// In en, this message translates to:
  /// **'Downloading video...'**
  String get downloadingVideo;

  /// No description provided for @me.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get me;

  /// No description provided for @editPack.
  ///
  /// In en, this message translates to:
  /// **'Edit pack'**
  String get editPack;

  /// No description provided for @packFormDescription.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp needs a pack name, an author, and a 96×96 tray icon. We’ll make the tray icon for you.'**
  String get packFormDescription;

  /// No description provided for @packName.
  ///
  /// In en, this message translates to:
  /// **'Pack name'**
  String get packName;

  /// No description provided for @packNameHint.
  ///
  /// In en, this message translates to:
  /// **'Monday moods'**
  String get packNameHint;

  /// No description provided for @author.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get author;

  /// No description provided for @authorHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get authorHint;

  /// No description provided for @createPack.
  ///
  /// In en, this message translates to:
  /// **'Create pack'**
  String get createPack;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveToPack.
  ///
  /// In en, this message translates to:
  /// **'Save to a pack'**
  String get saveToPack;

  /// No description provided for @saveAnimatedStickerDescription.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp packs need 3–30 stickers of the same type. Pick a pack with room, or make a new one.'**
  String get saveAnimatedStickerDescription;

  /// No description provided for @saveStaticStickerDescription.
  ///
  /// In en, this message translates to:
  /// **'Photo stickers are static. WhatsApp packs can’t mix them with animated clips.'**
  String get saveStaticStickerDescription;

  /// No description provided for @noPacksAvailable.
  ///
  /// In en, this message translates to:
  /// **'You don’t have any packs yet.'**
  String get noPacksAvailable;

  /// No description provided for @fullStickerPack.
  ///
  /// In en, this message translates to:
  /// **'Full ({count} stickers)'**
  String fullStickerPack(int count);

  /// No description provided for @packForPhotoStickers.
  ///
  /// In en, this message translates to:
  /// **'This pack is for photo stickers'**
  String get packForPhotoStickers;

  /// No description provided for @packForAnimatedStickers.
  ///
  /// In en, this message translates to:
  /// **'This pack is for animated stickers'**
  String get packForAnimatedStickers;

  /// No description provided for @packAuthorCount.
  ///
  /// In en, this message translates to:
  /// **'{author} · {countLabel}'**
  String packAuthorCount(String author, String countLabel);

  /// No description provided for @textTool.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textTool;

  /// No description provided for @emojiTool.
  ///
  /// In en, this message translates to:
  /// **'Emojis'**
  String get emojiTool;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @addTextHint.
  ///
  /// In en, this message translates to:
  /// **'Adds a text sticker to the canvas'**
  String get addTextHint;

  /// No description provided for @addEmojiHint.
  ///
  /// In en, this message translates to:
  /// **'Adds an emoji sticker to the canvas'**
  String get addEmojiHint;

  /// No description provided for @speedOptionsHint.
  ///
  /// In en, this message translates to:
  /// **'Opens playback speed options'**
  String get speedOptionsHint;

  /// No description provided for @couldNotPrepareMeme.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare that meme. Try another template.'**
  String get couldNotPrepareMeme;

  /// No description provided for @startFromMemeSheet.
  ///
  /// In en, this message translates to:
  /// **'Start from a meme'**
  String get startFromMemeSheet;

  /// No description provided for @memeSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a template, then add your own text.'**
  String get memeSheetSubtitle;

  /// No description provided for @memeCropDescription.
  ///
  /// In en, this message translates to:
  /// **'Templates are center-cropped to 1:1 and prepared at 512×512.'**
  String get memeCropDescription;

  /// No description provided for @couldNotLoadTrending.
  ///
  /// In en, this message translates to:
  /// **'Could not load trending stickers. Please retry.'**
  String get couldNotLoadTrending;

  /// No description provided for @myPackCapacity.
  ///
  /// In en, this message translates to:
  /// **'My Pack can hold up to 30 stickers.'**
  String get myPackCapacity;

  /// No description provided for @myPack.
  ///
  /// In en, this message translates to:
  /// **'My Pack'**
  String get myPack;

  /// No description provided for @batchExportIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The batch export did not complete.'**
  String get batchExportIncomplete;

  /// No description provided for @couldNotExportMyPack.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t export My Pack. Please try again.'**
  String get couldNotExportMyPack;

  /// No description provided for @communitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Collect trending stickers and build your next pack.'**
  String get communitySubtitle;

  /// No description provided for @addedToMyPack.
  ///
  /// In en, this message translates to:
  /// **'Added to My Pack'**
  String get addedToMyPack;

  /// No description provided for @addToMyPack.
  ///
  /// In en, this message translates to:
  /// **'Add to My Pack'**
  String get addToMyPack;

  /// No description provided for @animatedBadge.
  ///
  /// In en, this message translates to:
  /// **'GIF'**
  String get animatedBadge;

  /// No description provided for @myPackCount.
  ///
  /// In en, this message translates to:
  /// **'My Pack  {count}/{maximum}'**
  String myPackCount(int count, int maximum);

  /// No description provided for @exportProgress.
  ///
  /// In en, this message translates to:
  /// **'Export {completed}/{total}'**
  String exportProgress(int completed, int total);

  /// No description provided for @exportToWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Export to WhatsApp'**
  String get exportToWhatsApp;

  /// No description provided for @communityTrayHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + on at least 3 stickers to start a pack.'**
  String get communityTrayHint;

  /// No description provided for @scanningComments.
  ///
  /// In en, this message translates to:
  /// **'Scanning comments for stickers...'**
  String get scanningComments;

  /// No description provided for @couldNotScanComments.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t scan those comments. Please try again.'**
  String get couldNotScanComments;

  /// No description provided for @couldNotExportStickers.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t export those stickers. Please try again.'**
  String get couldNotExportStickers;

  /// No description provided for @commentStickers.
  ///
  /// In en, this message translates to:
  /// **'Comment stickers'**
  String get commentStickers;

  /// No description provided for @exportSelection.
  ///
  /// In en, this message translates to:
  /// **'Export ({selected}/{maximum})'**
  String exportSelection(int selected, int maximum);

  /// No description provided for @noCommentStickers.
  ///
  /// In en, this message translates to:
  /// **'No image stickers were found in the scanned comments.'**
  String get noCommentStickers;

  /// No description provided for @pack.
  ///
  /// In en, this message translates to:
  /// **'Pack'**
  String get pack;

  /// No description provided for @packDeleted.
  ///
  /// In en, this message translates to:
  /// **'This pack was deleted.'**
  String get packDeleted;

  /// No description provided for @sharePack.
  ///
  /// In en, this message translates to:
  /// **'Share pack'**
  String get sharePack;

  /// No description provided for @deletePack.
  ///
  /// In en, this message translates to:
  /// **'Delete pack'**
  String get deletePack;

  /// No description provided for @noStickersInPack.
  ///
  /// In en, this message translates to:
  /// **'No stickers in this pack yet.'**
  String get noStickersInPack;

  /// No description provided for @stickerInPack.
  ///
  /// In en, this message translates to:
  /// **'Sticker in {packName}'**
  String stickerInPack(String packName);

  /// No description provided for @removeStickerHint.
  ///
  /// In en, this message translates to:
  /// **'Double tap and hold to remove this sticker'**
  String get removeStickerHint;

  /// No description provided for @addStickers.
  ///
  /// In en, this message translates to:
  /// **'Add stickers'**
  String get addStickers;

  /// No description provided for @adding.
  ///
  /// In en, this message translates to:
  /// **'Adding...'**
  String get adding;

  /// No description provided for @addToWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Add to WhatsApp'**
  String get addToWhatsApp;

  /// No description provided for @whatsAppMinimumStickers.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp requires at least 3 stickers in a pack. Add {remaining} more to continue.'**
  String whatsAppMinimumStickers(int remaining);

  /// No description provided for @couldNotSharePack.
  ///
  /// In en, this message translates to:
  /// **'Could not share this pack.'**
  String get couldNotSharePack;

  /// No description provided for @whatsAppNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp isn’t installed'**
  String get whatsAppNotInstalled;

  /// No description provided for @installWhatsAppDescription.
  ///
  /// In en, this message translates to:
  /// **'Install WhatsApp or WhatsApp Business, then come back to add your sticker pack.'**
  String get installWhatsAppDescription;

  /// No description provided for @installWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Install WhatsApp'**
  String get installWhatsApp;

  /// No description provided for @installWhatsAppBusiness.
  ///
  /// In en, this message translates to:
  /// **'Install WhatsApp Business'**
  String get installWhatsAppBusiness;

  /// No description provided for @couldNotOpenAppStore.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open the app store. Please try again.'**
  String get couldNotOpenAppStore;

  /// No description provided for @deletePackQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete pack?'**
  String get deletePackQuestion;

  /// No description provided for @deletePackDescription.
  ///
  /// In en, this message translates to:
  /// **'“{packName}” and its stickers will be removed from this device.'**
  String deletePackDescription(String packName);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeStickerQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove sticker?'**
  String get removeStickerQuestion;

  /// No description provided for @removeStickerDescription.
  ///
  /// In en, this message translates to:
  /// **'It will be deleted from this pack.'**
  String get removeStickerDescription;

  /// No description provided for @packDetailSummary.
  ///
  /// In en, this message translates to:
  /// **'{countLabel} stickers · 96×96 tray'**
  String packDetailSummary(String countLabel);

  /// No description provided for @stickerSaved.
  ///
  /// In en, this message translates to:
  /// **'Sticker saved ({kilobytes} KB). Add it to a pack from Library.'**
  String stickerSaved(int kilobytes);

  /// No description provided for @addText.
  ///
  /// In en, this message translates to:
  /// **'Add text'**
  String get addText;

  /// No description provided for @textHint.
  ///
  /// In en, this message translates to:
  /// **'Say something'**
  String get textHint;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @makingSticker.
  ///
  /// In en, this message translates to:
  /// **'Making your sticker…'**
  String get makingSticker;

  /// No description provided for @closeEditor.
  ///
  /// In en, this message translates to:
  /// **'Close editor'**
  String get closeEditor;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @trimMaximum.
  ///
  /// In en, this message translates to:
  /// **'{selection} / {maximum} max'**
  String trimMaximum(String selection, String maximum);

  /// No description provided for @clipTrimRange.
  ///
  /// In en, this message translates to:
  /// **'Clip trim range'**
  String get clipTrimRange;

  /// No description provided for @clipTrimHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the handles to set a clip up to {maximum}'**
  String clipTrimHint(String maximum);

  /// No description provided for @trimRangeValue.
  ///
  /// In en, this message translates to:
  /// **'{start} to {end}'**
  String trimRangeValue(String start, String end);

  /// No description provided for @stickerCanvas.
  ///
  /// In en, this message translates to:
  /// **'Sticker canvas'**
  String get stickerCanvas;

  /// No description provided for @stickerCanvasHint.
  ///
  /// In en, this message translates to:
  /// **'Drag a sticker to move it. Pinch to resize. Rotate with two fingers.'**
  String get stickerCanvasHint;

  /// No description provided for @deleteSticker.
  ///
  /// In en, this message translates to:
  /// **'Delete sticker'**
  String get deleteSticker;

  /// No description provided for @deleteStickerHint.
  ///
  /// In en, this message translates to:
  /// **'Removes this sticker from the canvas'**
  String get deleteStickerHint;

  /// No description provided for @packNoLongerExists.
  ///
  /// In en, this message translates to:
  /// **'That pack no longer exists.'**
  String get packNoLongerExists;

  /// No description provided for @packMissingTrayIcon.
  ///
  /// In en, this message translates to:
  /// **'This pack is missing a tray icon.'**
  String get packMissingTrayIcon;

  /// No description provided for @packStickerFileMissing.
  ///
  /// In en, this message translates to:
  /// **'A sticker file is missing from this pack.'**
  String get packStickerFileMissing;

  /// No description provided for @stickrFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'The .stickr file could not be found.'**
  String get stickrFileNotFound;

  /// No description provided for @invalidStickrPack.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid .stickr pack.'**
  String get invalidStickrPack;

  /// No description provided for @packMissingNameOrPublisher.
  ///
  /// In en, this message translates to:
  /// **'This pack is missing a name or publisher.'**
  String get packMissingNameOrPublisher;

  /// No description provided for @packNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Give this pack a name.'**
  String get packNameRequired;

  /// No description provided for @packAuthorRequired.
  ///
  /// In en, this message translates to:
  /// **'Add an author name.'**
  String get packAuthorRequired;

  /// No description provided for @packIdentifierExists.
  ///
  /// In en, this message translates to:
  /// **'A pack with that identifier already exists.'**
  String get packIdentifierExists;

  /// No description provided for @packMaximumStickers.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp packs can hold at most {maximum} stickers.'**
  String packMaximumStickers(int maximum);

  /// No description provided for @packStaticOnly.
  ///
  /// In en, this message translates to:
  /// **'This pack is for static stickers. Create a new pack for animated ones.'**
  String get packStaticOnly;

  /// No description provided for @packAnimatedOnly.
  ///
  /// In en, this message translates to:
  /// **'This pack is for animated stickers. Create a new pack for photo stickers.'**
  String get packAnimatedOnly;

  /// No description provided for @packStickerCountRange.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp packs must contain between {minimum} and {maximum} stickers.'**
  String packStickerCountRange(int minimum, int maximum);

  /// No description provided for @stickerFileMissing.
  ///
  /// In en, this message translates to:
  /// **'The sticker file is missing.'**
  String get stickerFileMissing;

  /// No description provided for @packNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Pack names can be at most {maximum} characters.'**
  String packNameTooLong(int maximum);

  /// No description provided for @packAuthorTooLong.
  ///
  /// In en, this message translates to:
  /// **'Author names can be at most {maximum} characters.'**
  String packAuthorTooLong(int maximum);

  /// No description provided for @trayIconRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a {size}x{size} tray icon.'**
  String trayIconRequired(int size);

  /// No description provided for @addStickersToExport.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 more sticker to export (minimum {minimum}).} other{Add {count} more stickers to export (minimum {minimum}).}}'**
  String addStickersToExport(int count, int minimum);

  /// No description provided for @removeStickersToExport.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Remove 1 sticker to export (maximum {maximum}).} other{Remove {count} stickers to export (maximum {maximum}).}}'**
  String removeStickersToExport(int count, int maximum);

  /// No description provided for @stickerCountOfMaximum.
  ///
  /// In en, this message translates to:
  /// **'{count} / {maximum}'**
  String stickerCountOfMaximum(int count, int maximum);

  /// No description provided for @couldNotCreateTrayIcon.
  ///
  /// In en, this message translates to:
  /// **'Could not create the 96x96 tray icon.'**
  String get couldNotCreateTrayIcon;

  /// No description provided for @whatsAppNotInstalledDevice.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp isn’t installed on this device.'**
  String get whatsAppNotInstalledDevice;

  /// No description provided for @whatsAppReadyDesktop.
  ///
  /// In en, this message translates to:
  /// **'This pack is WhatsApp-ready ({count} stickers, 96×96 tray). Add to WhatsApp from an Android or iOS build.'**
  String whatsAppReadyDesktop(int count);

  /// No description provided for @whatsAppReadyDevice.
  ///
  /// In en, this message translates to:
  /// **'This pack meets WhatsApp’s rules. Connect it from a device build with WhatsApp installed.'**
  String get whatsAppReadyDevice;

  /// No description provided for @whatsAppAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'Add to WhatsApp is available on Android with WhatsApp installed.'**
  String get whatsAppAndroidOnly;

  /// No description provided for @addedToWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Added to WhatsApp.'**
  String get addedToWhatsApp;

  /// No description provided for @couldNotReachWhatsAppExport.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t reach the WhatsApp export on this device.'**
  String get couldNotReachWhatsAppExport;

  /// No description provided for @whatsAppDidNotAddPack.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp didn’t add the pack.'**
  String get whatsAppDidNotAddPack;

  /// No description provided for @whatsAppRejectedPack.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp rejected this pack.'**
  String get whatsAppRejectedPack;

  /// No description provided for @couldNotPrepareWhatsAppFiles.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t prepare sticker files for WhatsApp.'**
  String get couldNotPrepareWhatsAppFiles;

  /// No description provided for @exportAlreadyInProgress.
  ///
  /// In en, this message translates to:
  /// **'An export is already in progress.'**
  String get exportAlreadyInProgress;

  /// No description provided for @packMissingWhatsAppData.
  ///
  /// In en, this message translates to:
  /// **'This pack is missing data WhatsApp needs.'**
  String get packMissingWhatsAppData;

  /// No description provided for @couldNotAddPackToWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t add this pack to WhatsApp.'**
  String get couldNotAddPackToWhatsApp;

  /// No description provided for @invalidTikTokLink.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a TikTok link. Paste a video URL and try again.'**
  String get invalidTikTokLink;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get noInternetConnection;

  /// No description provided for @unreadableTikwmResponse.
  ///
  /// In en, this message translates to:
  /// **'TikWM returned an unreadable response. Please try again.'**
  String get unreadableTikwmResponse;

  /// No description provided for @tikwmVideoNotFound.
  ///
  /// In en, this message translates to:
  /// **'TikWM couldn’t find a video at that link. Check it and try again.'**
  String get tikwmVideoNotFound;

  /// No description provided for @tikwmNoDownload.
  ///
  /// In en, this message translates to:
  /// **'TikWM found that post, but no downloadable video was available.'**
  String get tikwmNoDownload;

  /// No description provided for @emptyVideoDownload.
  ///
  /// In en, this message translates to:
  /// **'The download finished, but the video file was empty.'**
  String get emptyVideoDownload;

  /// No description provided for @tiktokImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while importing that TikTok. Please try again.'**
  String get tiktokImportFailed;

  /// No description provided for @tikwmRateLimited.
  ///
  /// In en, this message translates to:
  /// **'TikWM is receiving too many requests right now. Wait a moment and try again.'**
  String get tikwmRateLimited;

  /// No description provided for @tikwmTikTokNotFound.
  ///
  /// In en, this message translates to:
  /// **'TikWM couldn’t find that TikTok. Check the link or try another public video.'**
  String get tikwmTikTokNotFound;

  /// No description provided for @tikwmProcessFailed.
  ///
  /// In en, this message translates to:
  /// **'TikWM couldn’t process that video right now. Please try again shortly.'**
  String get tikwmProcessFailed;

  /// No description provided for @connectionTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The connection timed out. Try again on a stronger network.'**
  String get connectionTimedOut;

  /// No description provided for @tikwmLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'TikWM couldn’t look up that video right now. Please try again.'**
  String get tikwmLookupFailed;

  /// No description provided for @videoDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t download that video right now. Please try again.'**
  String get videoDownloadFailed;

  /// No description provided for @downloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'The download was cancelled.'**
  String get downloadCancelled;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while downloading. Please try again.'**
  String get downloadFailed;

  /// No description provided for @commentScanNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Comment scanning is not configured. Add SCRAPEBADGER_API_KEY to the app build.'**
  String get commentScanNotConfigured;

  /// No description provided for @commentServiceUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The comment service returned an unreadable response.'**
  String get commentServiceUnreadable;

  /// No description provided for @emptyTikTokStickerImage.
  ///
  /// In en, this message translates to:
  /// **'TikTok returned an empty sticker image.'**
  String get emptyTikTokStickerImage;

  /// No description provided for @commentStickerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'That comment sticker is no longer available.'**
  String get commentStickerUnavailable;

  /// No description provided for @shortTikTokLinkUnresolved.
  ///
  /// In en, this message translates to:
  /// **'The shortened TikTok link could not be resolved.'**
  String get shortTikTokLinkUnresolved;

  /// No description provided for @invalidTikTokVideoId.
  ///
  /// In en, this message translates to:
  /// **'TikTok did not return a valid video ID.'**
  String get invalidTikTokVideoId;

  /// No description provided for @couldNotResolveTikTokLink.
  ///
  /// In en, this message translates to:
  /// **'Could not resolve that TikTok link: {error}'**
  String couldNotResolveTikTokLink(String error);

  /// No description provided for @commentScanUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Comment scanning is not authorized. Check the ScrapeBadger API key.'**
  String get commentScanUnauthorized;

  /// No description provided for @commentScanLimitReached.
  ///
  /// In en, this message translates to:
  /// **'The comment scan limit has been reached. Please try again later.'**
  String get commentScanLimitReached;

  /// No description provided for @tiktokCommentsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'TikTok comments are unavailable right now. Please try again.'**
  String get tiktokCommentsUnavailable;

  /// No description provided for @commentScanTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The comment scan timed out. Please try again.'**
  String get commentScanTimedOut;

  /// No description provided for @commentServiceConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the comment service.'**
  String get commentServiceConnectionFailed;

  /// No description provided for @commentScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not scan TikTok comments. Please try again.'**
  String get commentScanFailed;

  /// No description provided for @apifyNetworkError.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get apifyNetworkError;

  /// No description provided for @apifyLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Apify request limit was reached. Please try again later.'**
  String get apifyLimitReached;

  /// No description provided for @apifyUnreadableResponse.
  ///
  /// In en, this message translates to:
  /// **'Apify returned an unreadable dataset response.'**
  String get apifyUnreadableResponse;

  /// No description provided for @apifyRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not run the synchronous Apify scraper: {error}'**
  String apifyRunFailed(String error);

  /// No description provided for @invalidHttpsTikTokUrl.
  ///
  /// In en, this message translates to:
  /// **'Provide a valid HTTPS TikTok post URL.'**
  String get invalidHttpsTikTokUrl;

  /// No description provided for @apifyNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Apify is not configured. Add APIFY_API_TOKEN to the app build.'**
  String get apifyNotConfigured;

  /// No description provided for @apifyRejectedToken.
  ///
  /// In en, this message translates to:
  /// **'Apify rejected the API token.'**
  String get apifyRejectedToken;

  /// No description provided for @apifyTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The Apify request timed out. Please try again.'**
  String get apifyTimedOut;

  /// No description provided for @apifyConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to Apify.'**
  String get apifyConnectionFailed;

  /// No description provided for @apifyRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Apify could not complete the scraper request.'**
  String get apifyRequestFailed;

  /// No description provided for @commentStickerOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'That comment sticker could not be opened.'**
  String get commentStickerOpenFailed;

  /// No description provided for @stickerCanvasSizeFailed.
  ///
  /// In en, this message translates to:
  /// **'The sticker canvas could not be sized to 512×512.'**
  String get stickerCanvasSizeFailed;

  /// No description provided for @commentStickerTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Could not keep the sticker under 100KB. Try another comment image.'**
  String get commentStickerTooLarge;

  /// No description provided for @savingStickersUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Saving stickers needs the mobile or desktop app.'**
  String get savingStickersUnsupported;

  /// No description provided for @photoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'That photo is no longer available.'**
  String get photoUnavailable;

  /// No description provided for @photoOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'The photo couldn’t be opened.'**
  String get photoOpenFailed;

  /// No description provided for @photoOpenTryAnother.
  ///
  /// In en, this message translates to:
  /// **'That photo couldn’t be opened. Try another one.'**
  String get photoOpenTryAnother;

  /// No description provided for @ffmpegStickerFailed.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg failed while creating the sticker (code {code}).'**
  String ffmpegStickerFailed(int code);

  /// No description provided for @ffmpegNoStickerFile.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg did not write a sticker file.'**
  String get ffmpegNoStickerFile;

  /// No description provided for @stickerEncodeRetry.
  ///
  /// In en, this message translates to:
  /// **'Sticker was {kilobytes}KB. Trying a smaller encode...'**
  String stickerEncodeRetry(int kilobytes);

  /// No description provided for @staticStickerTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Could not keep the sticker under 100KB. Try a simpler photo.'**
  String get staticStickerTooLarge;

  /// No description provided for @animatedStickerTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Could not keep the sticker under 500KB. Try a shorter clip.'**
  String get animatedStickerTooLarge;

  /// No description provided for @exportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled.'**
  String get exportCancelled;

  /// No description provided for @sourceVideoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The source video is no longer available.'**
  String get sourceVideoUnavailable;

  /// No description provided for @videoEmptyOrUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The selected video is empty or unavailable.'**
  String get videoEmptyOrUnavailable;

  /// No description provided for @videoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Choose a video smaller than 250 MB.'**
  String get videoTooLarge;

  /// No description provided for @videoInspectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t inspect that video. Choose a different file.'**
  String get videoInspectionFailed;

  /// No description provided for @videoDurationUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The selected video has no readable duration.'**
  String get videoDurationUnreadable;

  /// No description provided for @videoTooLong.
  ///
  /// In en, this message translates to:
  /// **'Choose a video that is 10 minutes or shorter.'**
  String get videoTooLong;

  /// No description provided for @videoCodecUnsupported.
  ///
  /// In en, this message translates to:
  /// **'The {codec} video codec is not supported.'**
  String videoCodecUnsupported(String codec);

  /// No description provided for @unknownCodec.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get unknownCodec;

  /// No description provided for @videoInvalidDimensions.
  ///
  /// In en, this message translates to:
  /// **'The selected video has invalid dimensions.'**
  String get videoInvalidDimensions;

  /// No description provided for @videoDimensionsTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Choose a video no larger than 4096 by 4096 pixels.'**
  String get videoDimensionsTooLarge;

  /// No description provided for @fileNotReadableVideo.
  ///
  /// In en, this message translates to:
  /// **'The selected file is not a readable video.'**
  String get fileNotReadableVideo;

  /// No description provided for @fileMissingVideoTrack.
  ///
  /// In en, this message translates to:
  /// **'The selected file does not contain a video track.'**
  String get fileMissingVideoTrack;

  /// No description provided for @transparentForegroundRenderFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t render the transparent foreground.'**
  String get transparentForegroundRenderFailed;

  /// No description provided for @textSticker.
  ///
  /// In en, this message translates to:
  /// **'Text sticker'**
  String get textSticker;

  /// No description provided for @textStickerWithText.
  ///
  /// In en, this message translates to:
  /// **'Text sticker, {text}'**
  String textStickerWithText(String text);

  /// No description provided for @emojiSticker.
  ///
  /// In en, this message translates to:
  /// **'Emoji sticker'**
  String get emojiSticker;

  /// No description provided for @imageSticker.
  ///
  /// In en, this message translates to:
  /// **'Image sticker'**
  String get imageSticker;

  /// No description provided for @selectedStickerHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to move, pinch to scale, and rotate with two fingers'**
  String get selectedStickerHint;

  /// No description provided for @unselectedStickerHint.
  ///
  /// In en, this message translates to:
  /// **'Double tap to select this sticker'**
  String get unselectedStickerHint;

  /// No description provided for @giphyRateLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Giphy request limit was reached. Please try again later.'**
  String get giphyRateLimitReached;

  /// No description provided for @giphyTrendingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Trending stickers are unavailable because Giphy is not configured.'**
  String get giphyTrendingUnavailable;

  /// No description provided for @giphySearchRequired.
  ///
  /// In en, this message translates to:
  /// **'Type something to search for stickers.'**
  String get giphySearchRequired;

  /// No description provided for @giphySearchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sticker search is unavailable because Giphy is not configured.'**
  String get giphySearchUnavailable;

  /// No description provided for @couldNotSearchGiphy.
  ///
  /// In en, this message translates to:
  /// **'Could not search Giphy. Please retry.'**
  String get couldNotSearchGiphy;

  /// No description provided for @invalidStickerDownloadUrl.
  ///
  /// In en, this message translates to:
  /// **'That sticker has an invalid download URL.'**
  String get invalidStickerDownloadUrl;

  /// No description provided for @giphyEmptySticker.
  ///
  /// In en, this message translates to:
  /// **'Giphy downloaded an empty sticker.'**
  String get giphyEmptySticker;

  /// No description provided for @stickerDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download that sticker. Please retry.'**
  String get stickerDownloadFailed;

  /// No description provided for @trendingSticker.
  ///
  /// In en, this message translates to:
  /// **'Trending sticker'**
  String get trendingSticker;

  /// No description provided for @giphyUnreadableResponse.
  ///
  /// In en, this message translates to:
  /// **'Giphy returned an unreadable sticker response.'**
  String get giphyUnreadableResponse;

  /// No description provided for @giphyConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to Giphy. Check your connection and retry.'**
  String get giphyConnectionFailed;

  /// No description provided for @giphyRejectedApiKey.
  ///
  /// In en, this message translates to:
  /// **'Giphy rejected the API key. Check GIPHY_API_KEY.'**
  String get giphyRejectedApiKey;

  /// No description provided for @giphyTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The Giphy request timed out. Please retry.'**
  String get giphyTimedOut;

  /// No description provided for @giphyRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Giphy could not complete the request. Please retry.'**
  String get giphyRequestFailed;

  /// No description provided for @imgflipUnreadableResponse.
  ///
  /// In en, this message translates to:
  /// **'Imgflip returned an unreadable response. Please try again.'**
  String get imgflipUnreadableResponse;

  /// No description provided for @imgflipTemplatesFailed.
  ///
  /// In en, this message translates to:
  /// **'Imgflip couldn’t load meme templates right now.'**
  String get imgflipTemplatesFailed;

  /// No description provided for @memeTemplate.
  ///
  /// In en, this message translates to:
  /// **'Meme template'**
  String get memeTemplate;

  /// No description provided for @invalidMemeImageLink.
  ///
  /// In en, this message translates to:
  /// **'That meme template has an invalid image link.'**
  String get invalidMemeImageLink;

  /// No description provided for @memeDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t download that meme template. Please try again.'**
  String get memeDownloadFailed;

  /// No description provided for @imgflipEmptyTemplate.
  ///
  /// In en, this message translates to:
  /// **'Imgflip downloaded an empty meme template.'**
  String get imgflipEmptyTemplate;

  /// No description provided for @imgflipTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Imgflip took too long to respond. Please try again.'**
  String get imgflipTimedOut;

  /// No description provided for @imgflipBusy.
  ///
  /// In en, this message translates to:
  /// **'Imgflip is busy right now. Wait a moment and try again.'**
  String get imgflipBusy;

  /// No description provided for @imgflipTemplateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Imgflip couldn’t download that template.'**
  String get imgflipTemplateDownloadFailed;

  /// No description provided for @imgflipTemplatesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Imgflip templates are unavailable right now.'**
  String get imgflipTemplatesUnavailable;

  /// No description provided for @templateDownloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'The template download was cancelled.'**
  String get templateDownloadCancelled;

  /// No description provided for @templateLoadingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Loading meme templates was cancelled.'**
  String get templateLoadingCancelled;

  /// No description provided for @memeTemplatesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load meme templates. Please try again.'**
  String get memeTemplatesLoadFailed;

  /// No description provided for @photoPrepareFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t prepare that photo. Please try another one.'**
  String get photoPrepareFailed;

  /// No description provided for @noMemeTemplates.
  ///
  /// In en, this message translates to:
  /// **'The meme service did not return any templates.'**
  String get noMemeTemplates;

  /// No description provided for @couldNotLoadPacks.
  ///
  /// In en, this message translates to:
  /// **'Could not load your sticker packs. Please try again.'**
  String get couldNotLoadPacks;

  /// No description provided for @couldNotSavePack.
  ///
  /// In en, this message translates to:
  /// **'Could not save this pack. Please try again.'**
  String get couldNotSavePack;

  /// No description provided for @couldNotAddStickerToPack.
  ///
  /// In en, this message translates to:
  /// **'Could not add this sticker to the pack. Please try again.'**
  String get couldNotAddStickerToPack;

  /// No description provided for @networkOffline.
  ///
  /// In en, this message translates to:
  /// **'Network offline. Check your connection and try again.'**
  String get networkOffline;

  /// No description provided for @serviceRateLimited.
  ///
  /// In en, this message translates to:
  /// **'The service is rate limited. Please try again later.'**
  String get serviceRateLimited;

  /// No description provided for @networkTimeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get networkTimeout;

  /// No description provided for @networkRequestCancelled.
  ///
  /// In en, this message translates to:
  /// **'The request was cancelled.'**
  String get networkRequestCancelled;

  /// No description provided for @networkServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Please try again.'**
  String get networkServiceUnavailable;

  /// No description provided for @networkRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'The network request failed. Please try again.'**
  String get networkRequestFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
