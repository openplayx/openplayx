import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sources;

  /// No description provided for @plugins.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get plugins;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsMediaLibrary.
  ///
  /// In en, this message translates to:
  /// **'Media library'**
  String get settingsMediaLibrary;

  /// No description provided for @settingsApplication.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get settingsApplication;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeMode;

  /// No description provided for @themeDescription.
  ///
  /// In en, this message translates to:
  /// **'Apply now and restore on launch'**
  String get themeDescription;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @preferenceSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save preferences'**
  String get preferenceSaveFailed;

  /// No description provided for @preferenceSaveRetry.
  ///
  /// In en, this message translates to:
  /// **'Your choice is active. Select it again to retry saving.'**
  String get preferenceSaveRetry;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About OpenPlayX'**
  String get about;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Your media. A quieter place to play.'**
  String get aboutDescription;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @aiSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get aiSettingsSaved;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

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

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get openFile;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to OpenPlayX'**
  String get welcome;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off, or explore your library.'**
  String get welcomeDescription;

  /// No description provided for @continueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue watching'**
  String get continueWatching;

  /// No description provided for @continueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Unfinished videos will appear here after you start watching.'**
  String get continueEmpty;

  /// No description provided for @recentEmpty.
  ///
  /// In en, this message translates to:
  /// **'No playback history yet. Choose a video from your library or sources.'**
  String get recentEmpty;

  /// No description provided for @rewatch.
  ///
  /// In en, this message translates to:
  /// **'Finished · Play again'**
  String get rewatch;

  /// No description provided for @libraryOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the library. Try again.'**
  String get libraryOpenFailed;

  /// No description provided for @platformUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Playback is unavailable on this platform.'**
  String get platformUnsupported;

  /// No description provided for @historyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This history item\'s resource is unavailable.'**
  String get historyUnavailable;

  /// No description provided for @fileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'File unavailable'**
  String get fileUnavailable;

  /// No description provided for @historyOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this item. Check the file or source connection.'**
  String get historyOpenFailed;

  /// No description provided for @libraryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the library. Go back and try again.'**
  String get libraryLoadFailed;

  /// No description provided for @createLibrary.
  ///
  /// In en, this message translates to:
  /// **'Create library'**
  String get createLibrary;

  /// No description provided for @contentType.
  ///
  /// In en, this message translates to:
  /// **'Content type'**
  String get contentType;

  /// No description provided for @mixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get mixed;

  /// No description provided for @movie.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get movie;

  /// No description provided for @series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get series;

  /// No description provided for @homeVideos.
  ///
  /// In en, this message translates to:
  /// **'Home videos'**
  String get homeVideos;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @chooseScopeSource.
  ///
  /// In en, this message translates to:
  /// **'Choose a source to scan'**
  String get chooseScopeSource;

  /// No description provided for @addEnabledSource.
  ///
  /// In en, this message translates to:
  /// **'Add and enable a source first.'**
  String get addEnabledSource;

  /// No description provided for @bindFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add the source. Check the connection and retry.'**
  String get bindFailed;

  /// No description provided for @scanFailedRetained.
  ///
  /// In en, this message translates to:
  /// **'Scan failed. Indexed media is retained; you can retry.'**
  String get scanFailedRetained;

  /// No description provided for @localUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Local file unavailable'**
  String get localUnavailable;

  /// No description provided for @watchedSuffix.
  ///
  /// In en, this message translates to:
  /// **' · Finished'**
  String get watchedSuffix;

  /// No description provided for @missingOnScan.
  ///
  /// In en, this message translates to:
  /// **'Not found in scan; may be unavailable'**
  String get missingOnScan;

  /// No description provided for @verifyOnPlay.
  ///
  /// In en, this message translates to:
  /// **'Availability checked on playback'**
  String get verifyOnPlay;

  /// No description provided for @chooseVersion.
  ///
  /// In en, this message translates to:
  /// **'Choose a version. Each version keeps its own playback timeline.'**
  String get chooseVersion;

  /// No description provided for @season.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get season;

  /// No description provided for @episode.
  ///
  /// In en, this message translates to:
  /// **'Episode'**
  String get episode;

  /// No description provided for @media.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get media;

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextPage;

  /// No description provided for @versionOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this version. Check its source or choose another.'**
  String get versionOpenFailed;

  /// No description provided for @addToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Add to another library'**
  String get addToLibrary;

  /// No description provided for @chooseLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose library'**
  String get chooseLibrary;

  /// No description provided for @correctTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit title'**
  String get correctTitle;

  /// No description provided for @continueIncludingHistory.
  ///
  /// In en, this message translates to:
  /// **'Continue watching (including items outside your library)'**
  String get continueIncludingHistory;

  /// No description provided for @allLibraries.
  ///
  /// In en, this message translates to:
  /// **'All libraries'**
  String get allLibraries;

  /// No description provided for @renameLibrary.
  ///
  /// In en, this message translates to:
  /// **'Rename library'**
  String get renameLibrary;

  /// No description provided for @addSourceScope.
  ///
  /// In en, this message translates to:
  /// **'Add source scope'**
  String get addSourceScope;

  /// No description provided for @deleteLibrary.
  ///
  /// In en, this message translates to:
  /// **'Delete library'**
  String get deleteLibrary;

  /// No description provided for @deleteLibraryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this library?'**
  String get deleteLibraryConfirm;

  /// No description provided for @deleteLibraryDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove the library and its memberships. Files, media and favorites are kept.'**
  String get deleteLibraryDescription;

  /// No description provided for @searchLibrary.
  ///
  /// In en, this message translates to:
  /// **'Search library'**
  String get searchLibrary;

  /// No description provided for @allSources.
  ///
  /// In en, this message translates to:
  /// **'All sources'**
  String get allSources;

  /// No description provided for @allTypes.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get allTypes;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @allWatchStates.
  ///
  /// In en, this message translates to:
  /// **'All watch states'**
  String get allWatchStates;

  /// No description provided for @watched.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get watched;

  /// No description provided for @unwatched.
  ///
  /// In en, this message translates to:
  /// **'Unfinished'**
  String get unwatched;

  /// No description provided for @restoreIgnored.
  ///
  /// In en, this message translates to:
  /// **'Restore ignored items on next scan'**
  String get restoreIgnored;

  /// No description provided for @sourceNeedsSetup.
  ///
  /// In en, this message translates to:
  /// **'Source setup required'**
  String get sourceNeedsSetup;

  /// No description provided for @rescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get rescan;

  /// No description provided for @removeBinding.
  ///
  /// In en, this message translates to:
  /// **'Remove binding'**
  String get removeBinding;

  /// No description provided for @removeBindingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove scan binding?'**
  String get removeBindingConfirm;

  /// No description provided for @createFirstLibrary.
  ///
  /// In en, this message translates to:
  /// **'Create your first library'**
  String get createFirstLibrary;

  /// No description provided for @noMatchingMedia.
  ///
  /// In en, this message translates to:
  /// **'No matching media'**
  String get noMatchingMedia;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No media yet. Add a source scope or rescan.'**
  String get libraryEmpty;

  /// No description provided for @browseFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not browse. Check the source and retry.'**
  String get browseFailed;

  /// No description provided for @scopeDescription.
  ///
  /// In en, this message translates to:
  /// **'Scanning indexes media without downloading it. Choose an authorized folder or server library.'**
  String get scopeDescription;

  /// No description provided for @parent.
  ///
  /// In en, this message translates to:
  /// **'Parent folder'**
  String get parent;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @rootFolder.
  ///
  /// In en, this message translates to:
  /// **'Root folder'**
  String get rootFolder;

  /// No description provided for @confirmScanScope.
  ///
  /// In en, this message translates to:
  /// **'Scan this scope'**
  String get confirmScanScope;

  /// No description provided for @chooseScanScope.
  ///
  /// In en, this message translates to:
  /// **'Choose scan scope'**
  String get chooseScanScope;

  /// No description provided for @defaultDescription.
  ///
  /// In en, this message translates to:
  /// **'Defaults apply when no source is selected. Existing resources keep their original source and account.'**
  String get defaultDescription;

  /// No description provided for @defaultBrowse.
  ///
  /// In en, this message translates to:
  /// **'Default browsing source'**
  String get defaultBrowse;

  /// No description provided for @defaultResolve.
  ///
  /// In en, this message translates to:
  /// **'Default resolution source'**
  String get defaultResolve;

  /// No description provided for @localFolder.
  ///
  /// In en, this message translates to:
  /// **'Local folder'**
  String get localFolder;

  /// No description provided for @pickFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not choose a folder. Try again.'**
  String get pickFolderFailed;

  /// No description provided for @openBrowserFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser. Use the sign-in link to retry.'**
  String get openBrowserFailed;

  /// No description provided for @noPlexServers.
  ///
  /// In en, this message translates to:
  /// **'No accessible servers in this Plex account.'**
  String get noPlexServers;

  /// No description provided for @plexSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Plex sign-in failed. Try again.'**
  String get plexSignInFailed;

  /// No description provided for @enterToken.
  ///
  /// In en, this message translates to:
  /// **'Enter an access token to connect.'**
  String get enterToken;

  /// No description provided for @signInPlexFirst.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Plex and choose a server first.'**
  String get signInPlexFirst;

  /// No description provided for @connectionFormFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Check the address and credentials.'**
  String get connectionFormFailed;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @copyPassword.
  ///
  /// In en, this message translates to:
  /// **'Copy password'**
  String get copyPassword;

  /// No description provided for @passwordCopied.
  ///
  /// In en, this message translates to:
  /// **'Password copied'**
  String get passwordCopied;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @addressHint.
  ///
  /// In en, this message translates to:
  /// **'192.168.1.10 or https://media.example.com'**
  String get addressHint;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @guestHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave username and password blank for guest access.'**
  String get guestHelp;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @keepCredentials.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep the current sign-in.'**
  String get keepCredentials;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @optionalPath.
  ///
  /// In en, this message translates to:
  /// **'Path (optional)'**
  String get optionalPath;

  /// No description provided for @smbPathHint.
  ///
  /// In en, this message translates to:
  /// **'Share/video-folder'**
  String get smbPathHint;

  /// No description provided for @serverPathHint.
  ///
  /// In en, this message translates to:
  /// **'For example jellyfin; otherwise leave blank.'**
  String get serverPathHint;

  /// No description provided for @scanExtensions.
  ///
  /// In en, this message translates to:
  /// **'File extensions to scan'**
  String get scanExtensions;

  /// No description provided for @scanExtensionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Only files with a selected extension appear in preview and are added to the library. Hidden files starting with a dot are always skipped.'**
  String get scanExtensionsHelp;

  /// No description provided for @scanExtensionsAllFiles.
  ///
  /// In en, this message translates to:
  /// **'Nothing selected: every file will be kept.'**
  String get scanExtensionsAllFiles;

  /// No description provided for @scanExtensionsVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get scanExtensionsVideo;

  /// No description provided for @scanExtensionsAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get scanExtensionsAudio;

  /// No description provided for @scanExtensionsCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get scanExtensionsCustom;

  /// No description provided for @scanExtensionsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} selected'**
  String scanExtensionsSelected(int count, int total);

  /// No description provided for @scanExtensionsSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get scanExtensionsSelectAll;

  /// No description provided for @scanExtensionsSelectNone.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get scanExtensionsSelectNone;

  /// No description provided for @scanExtensionsAddHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. iso'**
  String get scanExtensionsAddHint;

  /// No description provided for @scanExtensionsInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use letters and digits only, up to 16 characters each.'**
  String get scanExtensionsInvalid;

  /// No description provided for @scanExtensionsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove {extension}'**
  String scanExtensionsRemove(String extension);

  /// No description provided for @scanExtensionsRestoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get scanExtensionsRestoreDefaults;

  /// No description provided for @optionalDomain.
  ///
  /// In en, this message translates to:
  /// **'Workgroup (optional)'**
  String get optionalDomain;

  /// No description provided for @waitingPlex.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Plex authorization…'**
  String get waitingPlex;

  /// No description provided for @signInPlex.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Plex'**
  String get signInPlex;

  /// No description provided for @signInPlexAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Plex again'**
  String get signInPlexAgain;

  /// No description provided for @plexBrowserHelp.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Plex in your browser, then choose a server.'**
  String get plexBrowserHelp;

  /// No description provided for @reopenSignIn.
  ///
  /// In en, this message translates to:
  /// **'Reopen sign-in page'**
  String get reopenSignIn;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @manualServer.
  ///
  /// In en, this message translates to:
  /// **'Connect manually'**
  String get manualServer;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddress;

  /// No description provided for @portInAddress.
  ///
  /// In en, this message translates to:
  /// **'Include a custom port in the address.'**
  String get portInAddress;

  /// No description provided for @accessToken.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get accessToken;

  /// No description provided for @addSource.
  ///
  /// In en, this message translates to:
  /// **'Add media source'**
  String get addSource;

  /// No description provided for @editSource.
  ///
  /// In en, this message translates to:
  /// **'Edit media source'**
  String get editSource;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @optionalName.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get optionalName;

  /// No description provided for @chooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get chooseFolder;

  /// No description provided for @folderAccessHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder this app is allowed to access.'**
  String get folderAccessHelp;

  /// No description provided for @loadSourcesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load sources. Try again.'**
  String get loadSourcesFailed;

  /// No description provided for @filePlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play this file.'**
  String get filePlayFailed;

  /// No description provided for @backToParent.
  ///
  /// In en, this message translates to:
  /// **'Back to parent folder'**
  String get backToParent;

  /// No description provided for @disableSourceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Disable media source?'**
  String get disableSourceConfirm;

  /// No description provided for @disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// No description provided for @toggleSourceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change source status. Try again.'**
  String get toggleSourceFailed;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed.'**
  String get connectionFailed;

  /// No description provided for @deleteSourceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the source. Try again.'**
  String get deleteSourceFailed;

  /// No description provided for @folderEmpty.
  ///
  /// In en, this message translates to:
  /// **'No browsable media in this folder.'**
  String get folderEmpty;

  /// No description provided for @addSourceShort.
  ///
  /// In en, this message translates to:
  /// **'Add source'**
  String get addSourceShort;

  /// No description provided for @playerClosed.
  ///
  /// In en, this message translates to:
  /// **'Player is closed'**
  String get playerClosed;

  /// No description provided for @historySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save history. Playback can continue.'**
  String get historySaveFailed;

  /// No description provided for @adjustFailed.
  ///
  /// In en, this message translates to:
  /// **'Adjustment failed. Try again.'**
  String get adjustFailed;

  /// No description provided for @audioTrack.
  ///
  /// In en, this message translates to:
  /// **'Audio track'**
  String get audioTrack;

  /// No description provided for @noAudioTracks.
  ///
  /// In en, this message translates to:
  /// **'No selectable audio tracks'**
  String get noAudioTracks;

  /// No description provided for @subtitleTrack.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get subtitleTrack;

  /// No description provided for @noSubtitleTracks.
  ///
  /// In en, this message translates to:
  /// **'No selectable subtitles'**
  String get noSubtitleTracks;

  /// No description provided for @subtitleOff.
  ///
  /// In en, this message translates to:
  /// **'Subtitles off'**
  String get subtitleOff;

  /// No description provided for @numberedSubtitleTrack.
  ///
  /// In en, this message translates to:
  /// **'Subtitle {id}'**
  String numberedSubtitleTrack(int id);

  /// No description provided for @playbackCommandFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed. Reopen the media file.'**
  String get playbackCommandFailed;

  /// No description provided for @openFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the file. Choose again.'**
  String get openFileFailed;

  /// No description provided for @stopPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not stop playback. Try going back again.'**
  String get stopPlaybackFailed;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @rewind.
  ///
  /// In en, this message translates to:
  /// **'Back 10 seconds'**
  String get rewind;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward 10 seconds'**
  String get forward;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// No description provided for @morePlaybackSettings.
  ///
  /// In en, this message translates to:
  /// **'More playback settings'**
  String get morePlaybackSettings;

  /// No description provided for @lockControls.
  ///
  /// In en, this message translates to:
  /// **'Lock controls'**
  String get lockControls;

  /// No description provided for @playerVolume.
  ///
  /// In en, this message translates to:
  /// **'Player volume'**
  String get playerVolume;

  /// No description provided for @playerEmpty.
  ///
  /// In en, this message translates to:
  /// **'Open a video to start watching'**
  String get playerEmpty;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @playbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed. Check the file or choose another.'**
  String get playbackFailed;

  /// No description provided for @boost.
  ///
  /// In en, this message translates to:
  /// **'Temporary 2× · Release to restore'**
  String get boost;

  /// No description provided for @unlockControls.
  ///
  /// In en, this message translates to:
  /// **'Unlock controls'**
  String get unlockControls;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @watchProgress.
  ///
  /// In en, this message translates to:
  /// **'Watched {position} / {duration} min'**
  String watchProgress(int position, int duration);

  /// No description provided for @metadataProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Scraping {done}/{total}'**
  String metadataProgressLabel(int done, int total);

  /// No description provided for @watchedMinutes.
  ///
  /// In en, this message translates to:
  /// **' · Watched {minutes} min'**
  String watchedMinutes(int minutes);

  /// No description provided for @localResource.
  ///
  /// In en, this message translates to:
  /// **'Local file (access checked on playback){progress}'**
  String localResource(String progress);

  /// No description provided for @setupResource.
  ///
  /// In en, this message translates to:
  /// **'Configure or enable the source{progress}'**
  String setupResource(String progress);

  /// No description provided for @removeBindingDescription.
  ///
  /// In en, this message translates to:
  /// **'This file source links {count} items. Removing it also deletes the file records, playback progress and metadata found only by it; items another file source also found are kept. The original files on your storage are not touched.'**
  String removeBindingDescription(int count);

  /// No description provided for @disableSourceDescription.
  ///
  /// In en, this message translates to:
  /// **'{playing} playing, {running} requests. New requests will be rejected. Current playback can finish. Configuration and favorites are kept.'**
  String disableSourceDescription(int playing, int running);

  /// No description provided for @deleteSourceDescription.
  ///
  /// In en, this message translates to:
  /// **'Removes this connection\'s configuration and credentials, and its {fileSources} file sources with everything they found (file records, playback progress, metadata). The original files on your storage are not touched. {playing} playing items and {running} requests can finish before connections are released.'**
  String deleteSourceDescription(int fileSources, int playing, int running);

  /// No description provided for @deleteNamedSource.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteNamedSource(String name);

  /// No description provided for @numberedAudioTrack.
  ///
  /// In en, this message translates to:
  /// **'Audio track {id}'**
  String numberedAudioTrack(int id);

  /// No description provided for @remainingTime.
  ///
  /// In en, this message translates to:
  /// **'{time} remaining'**
  String remainingTime(String time);

  /// No description provided for @readSpeed.
  ///
  /// In en, this message translates to:
  /// **'{speed} MB/s'**
  String readSpeed(String speed);

  /// No description provided for @plRemoteBadge.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get plRemoteBadge;

  /// No description provided for @plRemoteBadgeTip.
  ///
  /// In en, this message translates to:
  /// **'Streaming through remote access. Uses server traffic.'**
  String get plRemoteBadgeTip;

  /// No description provided for @notVerified.
  ///
  /// In en, this message translates to:
  /// **'Not verified yet'**
  String get notVerified;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @pendingApply.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingApply;

  /// No description provided for @applied.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get applied;

  /// No description provided for @applyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not apply'**
  String get applyFailed;

  /// No description provided for @credentialsMissing.
  ///
  /// In en, this message translates to:
  /// **'Sign-in required'**
  String get credentialsMissing;

  /// No description provided for @credentialsReady.
  ///
  /// In en, this message translates to:
  /// **'Credentials saved'**
  String get credentialsReady;

  /// No description provided for @localSource.
  ///
  /// In en, this message translates to:
  /// **'Local folder'**
  String get localSource;

  /// No description provided for @credentialsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Credential status unknown'**
  String get credentialsUnknown;

  /// No description provided for @screenOrientation.
  ///
  /// In en, this message translates to:
  /// **'Screen orientation'**
  String get screenOrientation;

  /// No description provided for @orientationSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get orientationSystem;

  /// No description provided for @orientationPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get orientationPortrait;

  /// No description provided for @orientationLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get orientationLandscape;

  /// No description provided for @videoRotation.
  ///
  /// In en, this message translates to:
  /// **'Video rotation'**
  String get videoRotation;

  /// No description provided for @rotationOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original (0°)'**
  String get rotationOriginal;

  /// No description provided for @sourceReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get sourceReady;

  /// No description provided for @sourceConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get sourceConnectionFailed;

  /// No description provided for @sourceInitialized.
  ///
  /// In en, this message translates to:
  /// **'Initialized · Awaiting connection test'**
  String get sourceInitialized;

  /// No description provided for @sourceSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved · Applies on next access'**
  String get sourceSaved;

  /// No description provided for @credentialsNotRequired.
  ///
  /// In en, this message translates to:
  /// **'No credentials required'**
  String get credentialsNotRequired;

  /// No description provided for @credentialsUnverified.
  ///
  /// In en, this message translates to:
  /// **'Credentials saved · Not verified'**
  String get credentialsUnverified;

  /// No description provided for @credentialsExpiring.
  ///
  /// In en, this message translates to:
  /// **'Token expires within 7 days'**
  String get credentialsExpiring;

  /// No description provided for @credentialsExpired.
  ///
  /// In en, this message translates to:
  /// **'Token expired'**
  String get credentialsExpired;

  /// No description provided for @credentialsRejected.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed · Update credentials'**
  String get credentialsRejected;

  /// No description provided for @credentialsVerified.
  ///
  /// In en, this message translates to:
  /// **'Connection verified'**
  String get credentialsVerified;

  /// No description provided for @playbackPosition.
  ///
  /// In en, this message translates to:
  /// **'Playback position'**
  String get playbackPosition;

  /// No description provided for @shadHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get shadHours;

  /// No description provided for @shadMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get shadMinutes;

  /// No description provided for @shadSeconds.
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get shadSeconds;

  /// No description provided for @shadPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get shadPeriod;

  /// No description provided for @shadMorning.
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get shadMorning;

  /// No description provided for @shadSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get shadSelectDate;

  /// No description provided for @shadCut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get shadCut;

  /// No description provided for @shadCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get shadCopy;

  /// No description provided for @shadPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get shadPaste;

  /// No description provided for @shadSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get shadSelectAll;

  /// No description provided for @shadDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get shadDone;

  /// No description provided for @scanFoundMedia.
  ///
  /// In en, this message translates to:
  /// **'{n} media files found'**
  String scanFoundMedia(int n);

  /// No description provided for @detailOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get detailOverview;

  /// No description provided for @detailCast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get detailCast;

  /// No description provided for @detailDirectors.
  ///
  /// In en, this message translates to:
  /// **'Director'**
  String get detailDirectors;

  /// No description provided for @seasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Season {n}'**
  String seasonLabel(int n);

  /// No description provided for @episodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Episode {n}'**
  String episodeLabel(int n);

  /// No description provided for @detailNoEpisodes.
  ///
  /// In en, this message translates to:
  /// **'No episodes yet.'**
  String get detailNoEpisodes;

  /// No description provided for @detailExtras.
  ///
  /// In en, this message translates to:
  /// **'Extras'**
  String get detailExtras;

  /// No description provided for @metadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get metadata;

  /// No description provided for @metadataIdentify.
  ///
  /// In en, this message translates to:
  /// **'Identify / rematch'**
  String get metadataIdentify;

  /// No description provided for @metadataImport.
  ///
  /// In en, this message translates to:
  /// **'Import nearby NFO and artwork'**
  String get metadataImport;

  /// No description provided for @metadataRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh linked work'**
  String get metadataRefresh;

  /// No description provided for @metadataSource.
  ///
  /// In en, this message translates to:
  /// **'Field sources'**
  String get metadataSource;

  /// No description provided for @metadataQuery.
  ///
  /// In en, this message translates to:
  /// **'Title or name'**
  String get metadataQuery;

  /// No description provided for @metadataYear.
  ///
  /// In en, this message translates to:
  /// **'Year (optional)'**
  String get metadataYear;

  /// No description provided for @metadataProviderId.
  ///
  /// In en, this message translates to:
  /// **'TMDB ID (optional)'**
  String get metadataProviderId;

  /// No description provided for @metadataLanguage.
  ///
  /// In en, this message translates to:
  /// **'Metadata language'**
  String get metadataLanguage;

  /// No description provided for @metadataToken.
  ///
  /// In en, this message translates to:
  /// **'TMDB read access token'**
  String get metadataToken;

  /// No description provided for @metadataConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure TMDB'**
  String get metadataConfigure;

  /// No description provided for @metadataPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Movies and shows added to your library are identified automatically in the background. Only titles, years, IDs and language are sent to TMDB; videos and private paths stay on this device.'**
  String get metadataPrivacy;

  /// No description provided for @metadataSaved.
  ///
  /// In en, this message translates to:
  /// **'TMDB configuration saved'**
  String get metadataSaved;

  /// No description provided for @metadataCandidates.
  ///
  /// In en, this message translates to:
  /// **'Choose a work'**
  String get metadataCandidates;

  /// No description provided for @metadataChooseChildren.
  ///
  /// In en, this message translates to:
  /// **'Choose season / episode'**
  String get metadataChooseChildren;

  /// No description provided for @metadataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm this match'**
  String get metadataConfirm;

  /// No description provided for @metadataKeepLocks.
  ///
  /// In en, this message translates to:
  /// **'Locked fields and artwork will be retained. Playback progress and resource versions stay intact.'**
  String get metadataKeepLocks;

  /// No description provided for @metadataOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get metadataOverview;

  /// No description provided for @metadataOriginalTitle.
  ///
  /// In en, this message translates to:
  /// **'Original title'**
  String get metadataOriginalTitle;

  /// No description provided for @metadataGenres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get metadataGenres;

  /// No description provided for @metadataEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit and lock fields'**
  String get metadataEdit;

  /// No description provided for @metadataRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore automatic value'**
  String get metadataRestore;

  /// No description provided for @metadataArtwork.
  ///
  /// In en, this message translates to:
  /// **'Choose artwork'**
  String get metadataArtwork;

  /// No description provided for @metadataArtworkLocked.
  ///
  /// In en, this message translates to:
  /// **'Artwork locked'**
  String get metadataArtworkLocked;

  /// No description provided for @metadataReset.
  ///
  /// In en, this message translates to:
  /// **'Reset match'**
  String get metadataReset;

  /// No description provided for @metadataResetDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove imported fields and the work association. User overrides, locked artwork and playback data are retained.'**
  String get metadataResetDescription;

  /// No description provided for @metadataClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear artwork cache'**
  String get metadataClearCache;

  /// No description provided for @metadataBatch.
  ///
  /// In en, this message translates to:
  /// **'Import library metadata'**
  String get metadataBatch;

  /// No description provided for @metadataBatchDone.
  ///
  /// In en, this message translates to:
  /// **'Library metadata import finished. See each item for status.'**
  String get metadataBatchDone;

  /// No description provided for @metadataUnmatched.
  ///
  /// In en, this message translates to:
  /// **'No matching metadata found'**
  String get metadataUnmatched;

  /// No description provided for @metadataAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your selection'**
  String get metadataAwaiting;

  /// No description provided for @metadataCompleted.
  ///
  /// In en, this message translates to:
  /// **'Metadata saved'**
  String get metadataCompleted;

  /// No description provided for @metadataCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled or interrupted; saved information is retained'**
  String get metadataCancelled;

  /// No description provided for @metadataBusy.
  ///
  /// In en, this message translates to:
  /// **'Looking up metadata…'**
  String get metadataBusy;

  /// No description provided for @metadataNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not identified'**
  String get metadataNotStarted;

  /// No description provided for @metadataFailed.
  ///
  /// In en, this message translates to:
  /// **'Metadata could not be read. Existing media remains available.'**
  String get metadataFailed;

  /// No description provided for @metadataConflict.
  ///
  /// In en, this message translates to:
  /// **'Work identity conflicts. Choose the correct candidate.'**
  String get metadataConflict;

  /// No description provided for @metadataStale.
  ///
  /// In en, this message translates to:
  /// **'Information changed during lookup. Search again.'**
  String get metadataStale;

  /// No description provided for @metadataAuth.
  ///
  /// In en, this message translates to:
  /// **'Configure a valid TMDB read access token.'**
  String get metadataAuth;

  /// No description provided for @metadataOffline.
  ///
  /// In en, this message translates to:
  /// **'Network request failed. Please retry when connected.'**
  String get metadataOffline;

  /// No description provided for @metadataPermission.
  ///
  /// In en, this message translates to:
  /// **'The source does not allow reading this attachment.'**
  String get metadataPermission;

  /// No description provided for @metadataRateLimited.
  ///
  /// In en, this message translates to:
  /// **'TMDB is rate limiting requests. Retry later.'**
  String get metadataRateLimited;

  /// No description provided for @metadataMissingSource.
  ///
  /// In en, this message translates to:
  /// **'Source file missing'**
  String get metadataMissingSource;

  /// No description provided for @metadataForgetToken.
  ///
  /// In en, this message translates to:
  /// **'Remove TMDB credential'**
  String get metadataForgetToken;

  /// No description provided for @metadataTokenSaved.
  ///
  /// In en, this message translates to:
  /// **'TMDB token saved on this device.'**
  String get metadataTokenSaved;

  /// No description provided for @metadataTokenMissing.
  ///
  /// In en, this message translates to:
  /// **'No TMDB token configured.'**
  String get metadataTokenMissing;

  /// No description provided for @metadataTokenStatusSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get metadataTokenStatusSaved;

  /// No description provided for @metadataTokenStatusMissing.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get metadataTokenStatusMissing;

  /// No description provided for @metadataSearch.
  ///
  /// In en, this message translates to:
  /// **'Search TMDB'**
  String get metadataSearch;

  /// No description provided for @aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get aiAssistant;

  /// No description provided for @aiPrivacyNotice.
  ///
  /// In en, this message translates to:
  /// **'Messages, selected context and tool results are sent to your configured model provider.'**
  String get aiPrivacyNotice;

  /// No description provided for @aiWelcome.
  ///
  /// In en, this message translates to:
  /// **'Ask me to find media, continue watching, or control playback. Configure a model to begin.'**
  String get aiWelcome;

  /// No description provided for @aiYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get aiYou;

  /// No description provided for @aiToolResult.
  ///
  /// In en, this message translates to:
  /// **'Tool result'**
  String get aiToolResult;

  /// No description provided for @aiConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm this change'**
  String get aiConfirmAction;

  /// No description provided for @aiApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get aiApprove;

  /// No description provided for @aiInputHint.
  ///
  /// In en, this message translates to:
  /// **'What would you like to watch?'**
  String get aiInputHint;

  /// No description provided for @aiStop.
  ///
  /// In en, this message translates to:
  /// **'Stop generating'**
  String get aiStop;

  /// No description provided for @aiSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get aiSend;

  /// No description provided for @aiToolFailed.
  ///
  /// In en, this message translates to:
  /// **'Tool did not complete'**
  String get aiToolFailed;

  /// No description provided for @aiConfigureFirst.
  ///
  /// In en, this message translates to:
  /// **'Set the API domain, model name and key in model settings first.'**
  String get aiConfigureFirst;

  /// No description provided for @aiSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to send. Check the input length and try again.'**
  String get aiSendFailed;

  /// No description provided for @aiCancelled.
  ///
  /// In en, this message translates to:
  /// **'Generation stopped. Completed actions are retained.'**
  String get aiCancelled;

  /// No description provided for @aiTimeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Completed actions are retained.'**
  String get aiTimeout;

  /// No description provided for @aiBudgetReached.
  ///
  /// In en, this message translates to:
  /// **'Turn limit reached. Completed results are retained.'**
  String get aiBudgetReached;

  /// No description provided for @aiProviderFailed.
  ///
  /// In en, this message translates to:
  /// **'Model request failed. Check credentials, endpoint and model support.'**
  String get aiProviderFailed;

  /// No description provided for @aiInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted on shutdown; actions will not be replayed.'**
  String get aiInterrupted;

  /// No description provided for @aiTokenUsage.
  ///
  /// In en, this message translates to:
  /// **'Reported tokens: {count}'**
  String aiTokenUsage(int count);

  /// No description provided for @aiModelSettings.
  ///
  /// In en, this message translates to:
  /// **'Model settings'**
  String get aiModelSettings;

  /// No description provided for @aiProviderDescription.
  ///
  /// In en, this message translates to:
  /// **'Supports OpenAI-compatible APIs. Your API key is saved locally.'**
  String get aiProviderDescription;

  /// No description provided for @aiEndpoint.
  ///
  /// In en, this message translates to:
  /// **'API domain'**
  String get aiEndpoint;

  /// No description provided for @aiModel.
  ///
  /// In en, this message translates to:
  /// **'Model name'**
  String get aiModel;

  /// No description provided for @aiApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get aiApiKey;

  /// No description provided for @aiKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an API key'**
  String get aiKeyRequired;

  /// No description provided for @aiKeySaved.
  ///
  /// In en, this message translates to:
  /// **'Key saved; leave blank to keep it'**
  String get aiKeySaved;

  /// No description provided for @aiSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to save. Check the configuration and credential store access.'**
  String get aiSaveFailed;

  /// No description provided for @aiExecuting.
  ///
  /// In en, this message translates to:
  /// **'Running {name}…'**
  String aiExecuting(String name);

  /// No description provided for @aiAuthenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Check that the API key and API base URL belong to the same provider.'**
  String get aiAuthenticationFailed;

  /// No description provided for @aiRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Provider rate limit reached. Try again later.'**
  String get aiRateLimited;

  /// No description provided for @aiProtocolMismatch.
  ///
  /// In en, this message translates to:
  /// **'The endpoint or model does not support this request. Check connection tests.'**
  String get aiProtocolMismatch;

  /// No description provided for @aiTextToolCall.
  ///
  /// In en, this message translates to:
  /// **'The model returned tool calls as text instead of executing them, even after retrying. Check that the model and endpoint support tool calling.'**
  String get aiTextToolCall;

  /// No description provided for @metadataAutomaticQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued for identification'**
  String get metadataAutomaticQueued;

  /// No description provided for @metadataAutomaticWaitingConfig.
  ///
  /// In en, this message translates to:
  /// **'Configure a valid TMDB read token for background identification. Local NFO import and playback remain available.'**
  String get metadataAutomaticWaitingConfig;

  /// No description provided for @metadataAutomaticRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry unfinished identification'**
  String get metadataAutomaticRetry;

  /// No description provided for @metadataAutomaticStatus.
  ///
  /// In en, this message translates to:
  /// **'Background metadata: {queued} queued · {running} running · {waiting} awaiting selection · {failed} failed'**
  String metadataAutomaticStatus(
    int queued,
    int running,
    int waiting,
    int failed,
  );

  /// No description provided for @fileSources.
  ///
  /// In en, this message translates to:
  /// **'File sources'**
  String get fileSources;

  /// No description provided for @nameFileSource.
  ///
  /// In en, this message translates to:
  /// **'Name this file source'**
  String get nameFileSource;

  /// No description provided for @fileSourceEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get fileSourceEnable;

  /// No description provided for @fileSourceDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get fileSourceDisable;

  /// No description provided for @fileSourceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get fileSourceDisabled;

  /// No description provided for @noFileSources.
  ///
  /// In en, this message translates to:
  /// **'No file sources yet. Add a folder to build your library.'**
  String get noFileSources;

  /// No description provided for @removeFileSourceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this file source?'**
  String get removeFileSourceConfirm;

  /// No description provided for @libraryEmptyNoMedia.
  ///
  /// In en, this message translates to:
  /// **'No media found in your file sources. Rescan or check the folder naming.'**
  String get libraryEmptyNoMedia;

  /// No description provided for @chooseFolderDescription.
  ///
  /// In en, this message translates to:
  /// **'Open a folder and confirm it as a file source. Media inside is indexed, never downloaded.'**
  String get chooseFolderDescription;

  /// No description provided for @confirmFolder.
  ///
  /// In en, this message translates to:
  /// **'Use this folder'**
  String get confirmFolder;

  /// No description provided for @libraryNoFileSources.
  ///
  /// In en, this message translates to:
  /// **'No file sources yet. Add a folder to a connection under Sources.'**
  String get libraryNoFileSources;

  /// No description provided for @sourceTabConnections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get sourceTabConnections;

  /// No description provided for @sourceTabFileSources.
  ///
  /// In en, this message translates to:
  /// **'File sources'**
  String get sourceTabFileSources;

  /// No description provided for @aiNewChat.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get aiNewChat;

  /// No description provided for @aiChatHistory.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get aiChatHistory;

  /// No description provided for @aiShowMedia.
  ///
  /// In en, this message translates to:
  /// **'Show home content'**
  String get aiShowMedia;

  /// No description provided for @aiExpandChat.
  ///
  /// In en, this message translates to:
  /// **'Expand on Home'**
  String get aiExpandChat;

  /// No description provided for @aiLatest.
  ///
  /// In en, this message translates to:
  /// **'Back to latest'**
  String get aiLatest;

  /// No description provided for @aiDraftNext.
  ///
  /// In en, this message translates to:
  /// **'Replying. You can draft your next message.'**
  String get aiDraftNext;

  /// No description provided for @aiSuggestMedia.
  ///
  /// In en, this message translates to:
  /// **'Help me find a movie'**
  String get aiSuggestMedia;

  /// No description provided for @aiSuggestResume.
  ///
  /// In en, this message translates to:
  /// **'Where did I leave off?'**
  String get aiSuggestResume;

  /// No description provided for @aiToolPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get aiToolPreparing;

  /// No description provided for @aiToolRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get aiToolRunning;

  /// No description provided for @aiToolWaiting.
  ///
  /// In en, this message translates to:
  /// **'Awaiting confirmation'**
  String get aiToolWaiting;

  /// No description provided for @aiToolSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get aiToolSucceeded;

  /// No description provided for @aiToolCancelled.
  ///
  /// In en, this message translates to:
  /// **'Not executed or cancelled'**
  String get aiToolCancelled;

  /// No description provided for @aiActionExpired.
  ///
  /// In en, this message translates to:
  /// **'This action is no longer available. Select again.'**
  String get aiActionExpired;

  /// No description provided for @aiRemoteImageBlocked.
  ///
  /// In en, this message translates to:
  /// **'Remote image not loaded'**
  String get aiRemoteImageBlocked;

  /// No description provided for @aiOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open external link?'**
  String get aiOpenLink;

  /// No description provided for @aiLinkBlocked.
  ///
  /// In en, this message translates to:
  /// **'This link cannot be opened'**
  String get aiLinkBlocked;

  /// No description provided for @aiTaskSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Task submitted'**
  String get aiTaskSubmitted;

  /// No description provided for @aiPartialFailure.
  ///
  /// In en, this message translates to:
  /// **'Some sources are unavailable'**
  String get aiPartialFailure;

  /// No description provided for @aiMoreResults.
  ///
  /// In en, this message translates to:
  /// **'More results are available. Ask to see another page.'**
  String get aiMoreResults;

  /// No description provided for @aiNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get aiNoResults;

  /// No description provided for @aiUntitledChat.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get aiUntitledChat;

  /// No description provided for @aiHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get aiHistoryEmpty;

  /// No description provided for @aiReplying.
  ///
  /// In en, this message translates to:
  /// **'Replying…'**
  String get aiReplying;

  /// No description provided for @aiToolSummary.
  ///
  /// In en, this message translates to:
  /// **'Actions and results come from local services'**
  String get aiToolSummary;

  /// No description provided for @aiEarlier.
  ///
  /// In en, this message translates to:
  /// **'Load earlier messages'**
  String get aiEarlier;

  /// No description provided for @anonymousHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave username and password blank for anonymous access.'**
  String get anonymousHelp;

  /// No description provided for @s3AccessKey.
  ///
  /// In en, this message translates to:
  /// **'Access Key ID'**
  String get s3AccessKey;

  /// No description provided for @s3SecretKey.
  ///
  /// In en, this message translates to:
  /// **'Secret Access Key'**
  String get s3SecretKey;

  /// No description provided for @s3AnonymousHelp.
  ///
  /// In en, this message translates to:
  /// **'Public buckets need no keys.'**
  String get s3AnonymousHelp;

  /// No description provided for @s3Region.
  ///
  /// In en, this message translates to:
  /// **'Region (optional, default us-east-1)'**
  String get s3Region;

  /// No description provided for @s3PathHint.
  ///
  /// In en, this message translates to:
  /// **'bucket/optional-prefix, e.g. media/movies'**
  String get s3PathHint;

  /// No description provided for @remotePathHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. media/movies; leave blank for the root'**
  String get remotePathHint;

  /// No description provided for @dlnaSearch.
  ///
  /// In en, this message translates to:
  /// **'Search local network'**
  String get dlnaSearch;

  /// No description provided for @dlnaSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get dlnaSearching;

  /// No description provided for @dlnaNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No media servers found. You can enter the device description URL manually.'**
  String get dlnaNoDevices;

  /// No description provided for @dlnaDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get dlnaDevice;

  /// No description provided for @dlnaAddress.
  ///
  /// In en, this message translates to:
  /// **'Device description URL'**
  String get dlnaAddress;

  /// No description provided for @dlnaAddressHelp.
  ///
  /// In en, this message translates to:
  /// **'Filled in when you pick a discovered device; you can also enter it manually.'**
  String get dlnaAddressHelp;

  /// No description provided for @aiOpenExternal.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get aiOpenExternal;

  /// No description provided for @serverBrowseAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get serverBrowseAll;

  /// No description provided for @serverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach this server'**
  String get serverUnavailable;

  /// No description provided for @serverEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get serverEmpty;

  /// No description provided for @serverLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get serverLoadMore;

  /// No description provided for @localLibrary.
  ///
  /// In en, this message translates to:
  /// **'Local library'**
  String get localLibrary;

  /// No description provided for @remoteHomeAccess.
  ///
  /// In en, this message translates to:
  /// **'Home remote access'**
  String get remoteHomeAccess;

  /// No description provided for @remoteProxy.
  ///
  /// In en, this message translates to:
  /// **'Service (frpc proxy)'**
  String get remoteProxy;

  /// No description provided for @remoteNoProxies.
  ///
  /// In en, this message translates to:
  /// **'No proxies available yet: import the App configuration from your Relay in Settings → Remote access first.'**
  String get remoteNoProxies;

  /// No description provided for @remoteProxyMissing.
  ///
  /// In en, this message translates to:
  /// **'{name} (not in the current App configuration)'**
  String remoteProxyMissing(String name);

  /// No description provided for @remoteLanAddress.
  ///
  /// In en, this message translates to:
  /// **'Paired LAN HTTPS address'**
  String get remoteLanAddress;

  /// No description provided for @remoteLanFingerprint.
  ///
  /// In en, this message translates to:
  /// **'LAN service certificate SHA-256'**
  String get remoteLanFingerprint;

  /// No description provided for @remoteLanIdentityHelp.
  ///
  /// In en, this message translates to:
  /// **'Confirm the 64-digit hexadecimal fingerprint through a trusted channel. The certificate must also pass system trust checks.'**
  String get remoteLanIdentityHelp;

  /// No description provided for @remoteAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic: verified LAN, otherwise remote'**
  String get remoteAutomatic;

  /// No description provided for @remoteLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'LAN only'**
  String get remoteLocalOnly;

  /// No description provided for @remoteRemoteOnly.
  ///
  /// In en, this message translates to:
  /// **'Remote only'**
  String get remoteRemoteOnly;

  /// No description provided for @developerMode.
  ///
  /// In en, this message translates to:
  /// **'Developer mode'**
  String get developerMode;

  /// No description provided for @developerModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Shows debugging entry points, such as the metadata button on the media detail page.'**
  String get developerModeDescription;

  /// No description provided for @metadataConfigureInSettings.
  ///
  /// In en, this message translates to:
  /// **'Add a read access token in Settings → TMDB to search.'**
  String get metadataConfigureInSettings;

  /// No description provided for @scrapeManagement.
  ///
  /// In en, this message translates to:
  /// **'Scraped metadata'**
  String get scrapeManagement;

  /// No description provided for @scrapedCount.
  ///
  /// In en, this message translates to:
  /// **'Scraped items'**
  String get scrapedCount;

  /// No description provided for @scrapedCountValue.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String scrapedCountValue(int count);

  /// No description provided for @scrapeStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage used'**
  String get scrapeStorage;

  /// No description provided for @scrapeStorageDetail.
  ///
  /// In en, this message translates to:
  /// **'Database {database} · Image cache {artwork}'**
  String scrapeStorageDetail(String database, String artwork);

  /// No description provided for @scrapeLoading.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get scrapeLoading;

  /// No description provided for @scrapeClear.
  ///
  /// In en, this message translates to:
  /// **'Clear all scraped metadata'**
  String get scrapeClear;

  /// No description provided for @scrapeClearHint.
  ///
  /// In en, this message translates to:
  /// **'Deletes metadata fetched from TMDB and NFO files, and cached posters.'**
  String get scrapeClearHint;

  /// No description provided for @scrapeClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all scraped metadata?'**
  String get scrapeClearTitle;

  /// No description provided for @scrapeClearDescription.
  ///
  /// In en, this message translates to:
  /// **'Metadata fetched from TMDB and NFO files, matches and downloaded posters will be deleted. This cannot be undone. Video files, playback progress, media server metadata and your manual edits are kept. If TMDB is configured, scraping starts again in the background.'**
  String get scrapeClearDescription;

  /// No description provided for @scrapeCleared.
  ///
  /// In en, this message translates to:
  /// **'All scraped metadata was cleared.'**
  String get scrapeCleared;

  /// No description provided for @scrapeClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clear. Try again later.'**
  String get scrapeClearFailed;

  /// No description provided for @artworkCacheLimit.
  ///
  /// In en, this message translates to:
  /// **'Image cache limit'**
  String get artworkCacheLimit;

  /// No description provided for @artworkCacheLimitDescription.
  ///
  /// In en, this message translates to:
  /// **'Posters, backdrops and cast photos. The oldest images are removed when the limit is reached; locked artwork is kept.'**
  String get artworkCacheLimitDescription;

  /// No description provided for @metadataProgressDone.
  ///
  /// In en, this message translates to:
  /// **'Scraping done'**
  String get metadataProgressDone;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @addFileSourceShort.
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get addFileSourceShort;

  /// No description provided for @shelfViewAll.
  ///
  /// In en, this message translates to:
  /// **'All · {count}'**
  String shelfViewAll(int count);

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get recentlyAdded;

  /// No description provided for @tvShows.
  ///
  /// In en, this message translates to:
  /// **'TV shows'**
  String get tvShows;

  /// No description provided for @seasonCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 season} other{{n} seasons}}'**
  String seasonCount(int n);

  /// No description provided for @seasonEpisodeShort.
  ///
  /// In en, this message translates to:
  /// **'S{season} E{episode}'**
  String seasonEpisodeShort(int season, int episode);

  /// No description provided for @detailCastAndCrew.
  ///
  /// In en, this message translates to:
  /// **'Cast & Crew'**
  String get detailCastAndCrew;

  /// No description provided for @detailGenres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get detailGenres;

  /// No description provided for @detailCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get detailCollection;

  /// No description provided for @detailVersions.
  ///
  /// In en, this message translates to:
  /// **'Versions'**
  String get detailVersions;

  /// No description provided for @detailViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get detailViewAll;

  /// No description provided for @detailScrollStart.
  ///
  /// In en, this message translates to:
  /// **'Back to start'**
  String get detailScrollStart;

  /// No description provided for @detailScrollEnd.
  ///
  /// In en, this message translates to:
  /// **'Jump to end'**
  String get detailScrollEnd;

  /// No description provided for @detailEpisodeCount.
  ///
  /// In en, this message translates to:
  /// **'{n} episodes'**
  String detailEpisodeCount(int n);

  /// No description provided for @detailMovieCount.
  ///
  /// In en, this message translates to:
  /// **'{n} movies'**
  String detailMovieCount(int n);

  /// No description provided for @detailRuntime.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String detailRuntime(int n);

  /// No description provided for @markWatched.
  ///
  /// In en, this message translates to:
  /// **'Mark as watched'**
  String get markWatched;

  /// No description provided for @markUnwatched.
  ///
  /// In en, this message translates to:
  /// **'Mark as unwatched'**
  String get markUnwatched;

  /// No description provided for @aiMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get aiMore;

  /// No description provided for @aiGreeting.
  ///
  /// In en, this message translates to:
  /// **'What would you like to watch tonight?'**
  String get aiGreeting;

  /// No description provided for @aiSuggestTonight.
  ///
  /// In en, this message translates to:
  /// **'Recommend a movie for tonight'**
  String get aiSuggestTonight;

  /// No description provided for @aiSuggestContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue what I was watching'**
  String get aiSuggestContinue;

  /// No description provided for @aiSuggestSciFi.
  ///
  /// In en, this message translates to:
  /// **'What sci-fi is in my library?'**
  String get aiSuggestSciFi;

  /// No description provided for @aiTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get aiTestConnection;

  /// No description provided for @aiCheckingConnection.
  ///
  /// In en, this message translates to:
  /// **'Testing connection…'**
  String get aiCheckingConnection;

  /// No description provided for @aiConnectionOk.
  ///
  /// In en, this message translates to:
  /// **'Connected. The model can chat and use tools.'**
  String get aiConnectionOk;

  /// No description provided for @aiConnectionOkNoTools.
  ///
  /// In en, this message translates to:
  /// **'Connected. The tool-call test did not pass; tasks will still attempt registered tools.'**
  String get aiConnectionOkNoTools;

  /// No description provided for @aiInvalidSettings.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTPS API domain and model name.'**
  String get aiInvalidSettings;

  /// No description provided for @remoteConnectionMode.
  ///
  /// In en, this message translates to:
  /// **'Connection mode'**
  String get remoteConnectionMode;

  /// No description provided for @ffmpegSnapshotDebug.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg snapshot debug'**
  String get ffmpegSnapshotDebug;

  /// No description provided for @ffmpegSnapshotAgain.
  ///
  /// In en, this message translates to:
  /// **'Take another'**
  String get ffmpegSnapshotAgain;

  /// No description provided for @ffmpegSnapshotAt.
  ///
  /// In en, this message translates to:
  /// **'Frame at {time} of {duration}'**
  String ffmpegSnapshotAt(String time, String duration);

  /// No description provided for @ffmpegSnapshotFailed.
  ///
  /// In en, this message translates to:
  /// **'Snapshot failed ({reason}).'**
  String ffmpegSnapshotFailed(String reason);

  /// No description provided for @ffmpegUnavailable.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg processing is not available in this build.'**
  String get ffmpegUnavailable;

  /// No description provided for @asrDebugTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio & subtitle debug'**
  String get asrDebugTitle;

  /// No description provided for @asrChooseEpisode.
  ///
  /// In en, this message translates to:
  /// **'Choose an episode'**
  String get asrChooseEpisode;

  /// No description provided for @asrSectionResource.
  ///
  /// In en, this message translates to:
  /// **'Current resource'**
  String get asrSectionResource;

  /// No description provided for @asrSectionInput.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get asrSectionInput;

  /// No description provided for @asrSectionBackend.
  ///
  /// In en, this message translates to:
  /// **'Recognition'**
  String get asrSectionBackend;

  /// No description provided for @asrSectionActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get asrSectionActions;

  /// No description provided for @asrSectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get asrSectionStatus;

  /// No description provided for @asrSectionAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio result'**
  String get asrSectionAudio;

  /// No description provided for @asrSectionSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get asrSectionSubtitles;

  /// No description provided for @asrSectionDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug info'**
  String get asrSectionDebug;

  /// No description provided for @asrTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get asrTitle;

  /// No description provided for @asrEpisode.
  ///
  /// In en, this message translates to:
  /// **'Episode'**
  String get asrEpisode;

  /// No description provided for @asrVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get asrVersion;

  /// No description provided for @asrDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get asrDuration;

  /// No description provided for @asrUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get asrUnknown;

  /// No description provided for @asrStart.
  ///
  /// In en, this message translates to:
  /// **'Start (s or mm:ss)'**
  String get asrStart;

  /// No description provided for @asrEnd.
  ///
  /// In en, this message translates to:
  /// **'End (s or mm:ss)'**
  String get asrEnd;

  /// No description provided for @asrWhole.
  ///
  /// In en, this message translates to:
  /// **'Whole episode'**
  String get asrWhole;

  /// No description provided for @asrRangeHint.
  ///
  /// In en, this message translates to:
  /// **'Defaults to the first 60 seconds. Whole episode must be chosen explicitly.'**
  String get asrRangeHint;

  /// No description provided for @asrWholeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Duration unknown: whole-episode processing is not supported.'**
  String get asrWholeUnavailable;

  /// No description provided for @asrRangeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid range: the end must be after the start and within the media.'**
  String get asrRangeInvalid;

  /// No description provided for @asrChannels.
  ///
  /// In en, this message translates to:
  /// **'{n} ch'**
  String asrChannels(int n);

  /// No description provided for @asrNotDecodable.
  ///
  /// In en, this message translates to:
  /// **'not decodable'**
  String get asrNotDecodable;

  /// No description provided for @asrEmbedded.
  ///
  /// In en, this message translates to:
  /// **'On device'**
  String get asrEmbedded;

  /// No description provided for @asrHttp.
  ///
  /// In en, this message translates to:
  /// **'HTTP service'**
  String get asrHttp;

  /// No description provided for @asrNoBackends.
  ///
  /// In en, this message translates to:
  /// **'No recognition backend configured.'**
  String get asrNoBackends;

  /// No description provided for @asrChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get asrChecking;

  /// No description provided for @asrBackendReady.
  ///
  /// In en, this message translates to:
  /// **'Ready · {engine} · model {revision}'**
  String asrBackendReady(String engine, String revision);

  /// No description provided for @asrBackendUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable: {reason}'**
  String asrBackendUnavailable(String reason);

  /// No description provided for @asrExtractOnly.
  ///
  /// In en, this message translates to:
  /// **'Extract audio only'**
  String get asrExtractOnly;

  /// No description provided for @asrExtractAndTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Extract and recognise subtitles'**
  String get asrExtractAndTranscribe;

  /// No description provided for @asrStagePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing resource'**
  String get asrStagePreparing;

  /// No description provided for @asrStageExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting audio'**
  String get asrStageExtracting;

  /// No description provided for @asrStageUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get asrStageUploading;

  /// No description provided for @asrStageQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get asrStageQueued;

  /// No description provided for @asrStageTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Recognising'**
  String get asrStageTranscribing;

  /// No description provided for @asrStageFormatting.
  ///
  /// In en, this message translates to:
  /// **'Building subtitles'**
  String get asrStageFormatting;

  /// No description provided for @asrCancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling…'**
  String get asrCancelling;

  /// No description provided for @asrCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get asrCancelled;

  /// No description provided for @asrSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get asrSucceeded;

  /// No description provided for @asrFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {reason}'**
  String asrFailed(String reason);

  /// No description provided for @asrAudioTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get asrAudioTrack;

  /// No description provided for @asrAudioFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get asrAudioFormat;

  /// No description provided for @asrAudioSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get asrAudioSize;

  /// No description provided for @asrAudioReused.
  ///
  /// In en, this message translates to:
  /// **'Reused an identical earlier extraction'**
  String get asrAudioReused;

  /// No description provided for @asrNoSpeech.
  ///
  /// In en, this message translates to:
  /// **'No speech recognised in this range.'**
  String get asrNoSpeech;

  /// No description provided for @asrWholeResult.
  ///
  /// In en, this message translates to:
  /// **'Whole episode'**
  String get asrWholeResult;

  /// No description provided for @asrPartialResult.
  ///
  /// In en, this message translates to:
  /// **'Partial: {start} – {end} (not the whole episode)'**
  String asrPartialResult(String start, String end);

  /// No description provided for @asrSave.
  ///
  /// In en, this message translates to:
  /// **'Save subtitle'**
  String get asrSave;

  /// No description provided for @asrExport.
  ///
  /// In en, this message translates to:
  /// **'Export…'**
  String get asrExport;

  /// No description provided for @asrExported.
  ///
  /// In en, this message translates to:
  /// **'Exported.'**
  String get asrExported;

  /// No description provided for @asrSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved. Choose it in the player\'s subtitle list (marked “Recognised”).'**
  String get asrSaved;

  /// No description provided for @asrSavedPartial.
  ///
  /// In en, this message translates to:
  /// **'Saved (partial range). Choose it in the player\'s subtitle list (marked “Recognised”).'**
  String get asrSavedPartial;

  /// No description provided for @asrSaveHint.
  ///
  /// In en, this message translates to:
  /// **'Unsaved results are discarded when you leave. Saving adds a new subtitle record; it never replaces existing subtitles or changes playback by itself.'**
  String get asrSaveHint;

  /// No description provided for @asrTaskId.
  ///
  /// In en, this message translates to:
  /// **'Task ID'**
  String get asrTaskId;

  /// No description provided for @asrBackendLabel.
  ///
  /// In en, this message translates to:
  /// **'Backend'**
  String get asrBackendLabel;

  /// No description provided for @asrModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get asrModel;

  /// No description provided for @asrEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get asrEngine;

  /// No description provided for @asrLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language (auto / zh / en …)'**
  String get asrLanguage;

  /// No description provided for @asrRemoteJob.
  ///
  /// In en, this message translates to:
  /// **'Remote job'**
  String get asrRemoteJob;

  /// No description provided for @asrError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get asrError;

  /// No description provided for @asrContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get asrContinue;

  /// No description provided for @asrWholeTitle.
  ///
  /// In en, this message translates to:
  /// **'Process the full video?'**
  String get asrWholeTitle;

  /// No description provided for @asrWholeBody.
  ///
  /// In en, this message translates to:
  /// **'Duration {duration}, about {size} of audio. Recognition can take a long time.'**
  String asrWholeBody(String duration, String size);

  /// No description provided for @asrUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload audio to a recognition service?'**
  String get asrUploadTitle;

  /// No description provided for @asrUploadBody.
  ///
  /// In en, this message translates to:
  /// **'Audio of {range} will be uploaded to {host}. {insecure}'**
  String asrUploadBody(String host, String range, String insecure);

  /// No description provided for @asrUploadInsecure.
  ///
  /// In en, this message translates to:
  /// **'This service uses plain HTTP: the audio is not encrypted in transit.'**
  String get asrUploadInsecure;

  /// No description provided for @asrUploadAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow upload'**
  String get asrUploadAllow;

  /// No description provided for @asrUploadAuthorized.
  ///
  /// In en, this message translates to:
  /// **'uploads allowed'**
  String get asrUploadAuthorized;

  /// No description provided for @asrErrorNoAudio.
  ///
  /// In en, this message translates to:
  /// **'This resource has no audio track.'**
  String get asrErrorNoAudio;

  /// No description provided for @asrErrorDurationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Duration unknown.'**
  String get asrErrorDurationUnknown;

  /// No description provided for @asrErrorModelMissing.
  ///
  /// In en, this message translates to:
  /// **'Model not installed.'**
  String get asrErrorModelMissing;

  /// No description provided for @asrErrorEngineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This build has no on-device recognizer.'**
  String get asrErrorEngineUnavailable;

  /// No description provided for @asrErrorUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Service unreachable.'**
  String get asrErrorUnreachable;

  /// No description provided for @asrErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Service rejected the credentials.'**
  String get asrErrorUnauthorized;

  /// No description provided for @asrErrorUploadConsent.
  ///
  /// In en, this message translates to:
  /// **'Upload to this service has not been authorised.'**
  String get asrErrorUploadConsent;

  /// No description provided for @asrErrorTls.
  ///
  /// In en, this message translates to:
  /// **'The service certificate could not be verified.'**
  String get asrErrorTls;

  /// No description provided for @asrErrorRemoteStream.
  ///
  /// In en, this message translates to:
  /// **'This source cannot be read locally yet.'**
  String get asrErrorRemoteStream;

  /// No description provided for @asrErrorTrackChanged.
  ///
  /// In en, this message translates to:
  /// **'The file changed; choose the audio track again.'**
  String get asrErrorTrackChanged;

  /// No description provided for @asrSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition'**
  String get asrSettingsTitle;

  /// No description provided for @asrModelFooter.
  ///
  /// In en, this message translates to:
  /// **'On-device Whisper models (multilingual). Files are verified by size and SHA-256 before use; nothing is downloaded automatically.'**
  String get asrModelFooter;

  /// No description provided for @asrModelDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get asrModelDownload;

  /// No description provided for @asrModelDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading {done} / {total}'**
  String asrModelDownloading(String done, String total);

  /// No description provided for @asrModelDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed or the file did not verify.'**
  String get asrModelDownloadFailed;

  /// No description provided for @asrModelImport.
  ///
  /// In en, this message translates to:
  /// **'Import model file…'**
  String get asrModelImport;

  /// No description provided for @asrModelImportRejected.
  ///
  /// In en, this message translates to:
  /// **'Not a known model file (size/checksum mismatch).'**
  String get asrModelImportRejected;

  /// No description provided for @asrModelInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get asrModelInstalled;

  /// No description provided for @asrModelInUse.
  ///
  /// In en, this message translates to:
  /// **'Installed · in use'**
  String get asrModelInUse;

  /// No description provided for @asrModelNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get asrModelNotInstalled;

  /// No description provided for @asrModelUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get asrModelUse;

  /// No description provided for @asrModelRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get asrModelRemove;

  /// No description provided for @asrServicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recognition services'**
  String get asrServicesTitle;

  /// No description provided for @asrAddService.
  ///
  /// In en, this message translates to:
  /// **'Add HTTP service'**
  String get asrAddService;

  /// No description provided for @asrEditService.
  ///
  /// In en, this message translates to:
  /// **'Edit service'**
  String get asrEditService;

  /// No description provided for @asrRemoveService.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get asrRemoveService;

  /// No description provided for @asrServicePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Only extracted audio is uploaded, after you allow it. Video links and NAS credentials are never sent.'**
  String get asrServicePrivacy;

  /// No description provided for @asrServiceName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get asrServiceName;

  /// No description provided for @asrServiceUrl.
  ///
  /// In en, this message translates to:
  /// **'Service URL'**
  String get asrServiceUrl;

  /// No description provided for @asrServiceToken.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get asrServiceToken;

  /// No description provided for @asrServiceUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an https:// URL without credentials (http:// only when allowed below).'**
  String get asrServiceUrlInvalid;

  /// No description provided for @asrServiceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the model and language.'**
  String get asrServiceInvalid;

  /// No description provided for @asrAllowHttp.
  ///
  /// In en, this message translates to:
  /// **'Allow plain HTTP (LAN only)'**
  String get asrAllowHttp;

  /// No description provided for @asrAllowHttpHint.
  ///
  /// In en, this message translates to:
  /// **'Audio would travel unencrypted. HTTPS certificate checks are never disabled.'**
  String get asrAllowHttpHint;

  /// No description provided for @asrInstallModel.
  ///
  /// In en, this message translates to:
  /// **'Install or choose a model'**
  String get asrInstallModel;

  /// No description provided for @asrRecheck.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get asrRecheck;

  /// No description provided for @asrTranscribeBlocked.
  ///
  /// In en, this message translates to:
  /// **'Recognition unavailable: {reason}'**
  String asrTranscribeBlocked(String reason);

  /// No description provided for @embeddedSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Embedded subtitles'**
  String get embeddedSubtitles;

  /// No description provided for @externalSubtitles.
  ///
  /// In en, this message translates to:
  /// **'External subtitles'**
  String get externalSubtitles;

  /// No description provided for @recognizedSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Recognised subtitles'**
  String get recognizedSubtitles;

  /// No description provided for @recognizedSubtitleBadge.
  ///
  /// In en, this message translates to:
  /// **'Recognised'**
  String get recognizedSubtitleBadge;

  /// No description provided for @recognizedSubtitleTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved {time}'**
  String recognizedSubtitleTitle(String time);

  /// No description provided for @recognizedSubtitlePartial.
  ///
  /// In en, this message translates to:
  /// **'Partial {start}–{end}'**
  String recognizedSubtitlePartial(String start, String end);

  /// No description provided for @recognizedSubtitleFull.
  ///
  /// In en, this message translates to:
  /// **'Whole episode'**
  String get recognizedSubtitleFull;

  /// No description provided for @addSourceConnection.
  ///
  /// In en, this message translates to:
  /// **'Add connection'**
  String get addSourceConnection;

  /// No description provided for @sourcesDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect your storage. Organize your media.'**
  String get sourcesDescription;

  /// No description provided for @sourceActions.
  ///
  /// In en, this message translates to:
  /// **'Actions for {name}'**
  String sourceActions(String name);

  /// No description provided for @browseSourceFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse files'**
  String get browseSourceFiles;

  /// No description provided for @sourceAwaitingVerification.
  ///
  /// In en, this message translates to:
  /// **'Awaiting verification'**
  String get sourceAwaitingVerification;

  /// No description provided for @sourceFileCount.
  ///
  /// In en, this message translates to:
  /// **'{count} file sources'**
  String sourceFileCount(int count);

  /// No description provided for @sourceRootFolder.
  ///
  /// In en, this message translates to:
  /// **'Root folder'**
  String get sourceRootFolder;

  /// No description provided for @rescanFileSource.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get rescanFileSource;

  /// No description provided for @plAbASet.
  ///
  /// In en, this message translates to:
  /// **'A set at {time}'**
  String plAbASet(String time);

  /// No description provided for @plAbClear.
  ///
  /// In en, this message translates to:
  /// **'Clear A-B loop'**
  String get plAbClear;

  /// No description provided for @plAbCleared.
  ///
  /// In en, this message translates to:
  /// **'A-B loop cleared'**
  String get plAbCleared;

  /// No description provided for @plAbLoop.
  ///
  /// In en, this message translates to:
  /// **'A-B loop'**
  String get plAbLoop;

  /// No description provided for @plAbLooping.
  ///
  /// In en, this message translates to:
  /// **'Looping {a} – {b}'**
  String plAbLooping(String a, String b);

  /// No description provided for @plAbSetA.
  ///
  /// In en, this message translates to:
  /// **'Set point A'**
  String get plAbSetA;

  /// No description provided for @plAbSetB.
  ///
  /// In en, this message translates to:
  /// **'Set point B'**
  String get plAbSetB;

  /// No description provided for @plAdvancedTools.
  ///
  /// In en, this message translates to:
  /// **'Advanced tools row'**
  String get plAdvancedTools;

  /// No description provided for @plAspectDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get plAspectDefault;

  /// No description provided for @plAspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio'**
  String get plAspectRatio;

  /// No description provided for @plAudioDelay.
  ///
  /// In en, this message translates to:
  /// **'Audio delay'**
  String get plAudioDelay;

  /// No description provided for @plBoosting.
  ///
  /// In en, this message translates to:
  /// **'{speed} fast forward · release to restore'**
  String plBoosting(String speed);

  /// No description provided for @plDelayHint.
  ///
  /// In en, this message translates to:
  /// **'Positive values play audio or show subtitles later.'**
  String get plDelayHint;

  /// No description provided for @plExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get plExitFullscreen;

  /// No description provided for @plFaster.
  ///
  /// In en, this message translates to:
  /// **'Faster'**
  String get plFaster;

  /// No description provided for @plFitBest.
  ///
  /// In en, this message translates to:
  /// **'Best fit'**
  String get plFitBest;

  /// No description provided for @plFitFill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get plFitFill;

  /// No description provided for @plFitMode.
  ///
  /// In en, this message translates to:
  /// **'Picture size'**
  String get plFitMode;

  /// No description provided for @plFitOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original size'**
  String get plFitOriginal;

  /// No description provided for @plFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get plFullscreen;

  /// No description provided for @plGo.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get plGo;

  /// No description provided for @plInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get plInfo;

  /// No description provided for @plInfoDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get plInfoDuration;

  /// No description provided for @plInfoResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get plInfoResolution;

  /// No description provided for @plInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get plInfoTitle;

  /// No description provided for @plJumpBackMedium.
  ///
  /// In en, this message translates to:
  /// **'Back 1 minute'**
  String get plJumpBackMedium;

  /// No description provided for @plJumpExtraShort.
  ///
  /// In en, this message translates to:
  /// **'Jump 3 seconds'**
  String get plJumpExtraShort;

  /// No description provided for @plJumpForwardMedium.
  ///
  /// In en, this message translates to:
  /// **'Forward 1 minute'**
  String get plJumpForwardMedium;

  /// No description provided for @plJumpLong.
  ///
  /// In en, this message translates to:
  /// **'Jump 5 minutes'**
  String get plJumpLong;

  /// No description provided for @plJumpSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String plJumpSeconds(String seconds);

  /// No description provided for @plJumpToTime.
  ///
  /// In en, this message translates to:
  /// **'Jump to time'**
  String get plJumpToTime;

  /// No description provided for @plJumpToTimeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a time such as 1:23:45 or 12:30.'**
  String get plJumpToTimeInvalid;

  /// No description provided for @plLoadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Load subtitle file…'**
  String get plLoadSubtitle;

  /// No description provided for @plLockShort.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get plLockShort;

  /// No description provided for @plMediaInfo.
  ///
  /// In en, this message translates to:
  /// **'Media info'**
  String get plMediaInfo;

  /// No description provided for @plMenuAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get plMenuAudio;

  /// No description provided for @plMenuPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get plMenuPlayback;

  /// No description provided for @plMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get plMenuSubtitle;

  /// No description provided for @plMenuVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get plMenuVideo;

  /// No description provided for @plMenuView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get plMenuView;

  /// No description provided for @plMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get plMute;

  /// No description provided for @plMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get plMuted;

  /// No description provided for @plNextAudioTrack.
  ///
  /// In en, this message translates to:
  /// **'Next audio track'**
  String get plNextAudioTrack;

  /// No description provided for @plNextSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Next subtitle'**
  String get plNextSubtitle;

  /// No description provided for @plNormalSpeed.
  ///
  /// In en, this message translates to:
  /// **'Normal speed'**
  String get plNormalSpeed;

  /// No description provided for @plOrientationShort.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get plOrientationShort;

  /// No description provided for @plPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get plPicture;

  /// No description provided for @plPictureAndSound.
  ///
  /// In en, this message translates to:
  /// **'Picture & sound'**
  String get plPictureAndSound;

  /// No description provided for @plRepeatMode.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get plRepeatMode;

  /// No description provided for @plRepeatOff.
  ///
  /// In en, this message translates to:
  /// **'No repeat'**
  String get plRepeatOff;

  /// No description provided for @plRepeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat this item'**
  String get plRepeatOne;

  /// No description provided for @plReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get plReset;

  /// No description provided for @plSettingsAndEffects.
  ///
  /// In en, this message translates to:
  /// **'Settings & effects'**
  String get plSettingsAndEffects;

  /// No description provided for @plShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get plShortcuts;

  /// No description provided for @plShowPosition.
  ///
  /// In en, this message translates to:
  /// **'Show position'**
  String get plShowPosition;

  /// No description provided for @plSleepEndOfItem.
  ///
  /// In en, this message translates to:
  /// **'End of item'**
  String get plSleepEndOfItem;

  /// No description provided for @plSleepFinished.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer paused playback'**
  String get plSleepFinished;

  /// No description provided for @plSleepMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String plSleepMinutes(int minutes);

  /// No description provided for @plSleepOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get plSleepOff;

  /// No description provided for @plSleepShort.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get plSleepShort;

  /// No description provided for @plSleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get plSleepTimer;

  /// No description provided for @plSlideToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Slide right to unlock'**
  String get plSlideToUnlock;

  /// No description provided for @plSlower.
  ///
  /// In en, this message translates to:
  /// **'Slower'**
  String get plSlower;

  /// No description provided for @plSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Snapshot'**
  String get plSnapshot;

  /// No description provided for @plSnapshotFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the snapshot'**
  String get plSnapshotFailed;

  /// No description provided for @plSnapshotSaved.
  ///
  /// In en, this message translates to:
  /// **'Snapshot saved: {path}'**
  String plSnapshotSaved(String path);

  /// No description provided for @plSpeedShort.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get plSpeedShort;

  /// No description provided for @plStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get plStatistics;

  /// No description provided for @plStatsAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio played / lost'**
  String get plStatsAudio;

  /// No description provided for @plStatsDemux.
  ///
  /// In en, this message translates to:
  /// **'Demux bitrate'**
  String get plStatsDemux;

  /// No description provided for @plStatsFrames.
  ///
  /// In en, this message translates to:
  /// **'Frames shown / lost'**
  String get plStatsFrames;

  /// No description provided for @plStatsInput.
  ///
  /// In en, this message translates to:
  /// **'Input bitrate'**
  String get plStatsInput;

  /// No description provided for @plStatsOverlay.
  ///
  /// In en, this message translates to:
  /// **'Statistics overlay'**
  String get plStatsOverlay;

  /// No description provided for @plStatsRead.
  ///
  /// In en, this message translates to:
  /// **'Read speed'**
  String get plStatsRead;

  /// No description provided for @plStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get plStop;

  /// No description provided for @plSubtitleDelay.
  ///
  /// In en, this message translates to:
  /// **'Subtitle delay'**
  String get plSubtitleDelay;

  /// No description provided for @plSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get plSync;

  /// No description provided for @plTimeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Click: total/remaining · Double-click: jump to time'**
  String get plTimeTooltip;

  /// No description provided for @plToggleControls.
  ///
  /// In en, this message translates to:
  /// **'Show/hide controls'**
  String get plToggleControls;

  /// No description provided for @plToggleSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles on/off'**
  String get plToggleSubtitles;

  /// No description provided for @plTrackAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get plTrackAudio;

  /// No description provided for @plTracks.
  ///
  /// In en, this message translates to:
  /// **'Audio & subtitles'**
  String get plTracks;

  /// No description provided for @plTracksShort.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get plTracksShort;

  /// No description provided for @plTrackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get plTrackSubtitle;

  /// No description provided for @plTrackVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get plTrackVideo;

  /// No description provided for @plUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not available for this player'**
  String get plUnsupported;

  /// No description provided for @plZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get plZoom;

  /// No description provided for @plZoomOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get plZoomOriginal;

  /// No description provided for @plMenuPlaybackControl.
  ///
  /// In en, this message translates to:
  /// **'Playback controls'**
  String get plMenuPlaybackControl;

  /// No description provided for @plBoostingShort.
  ///
  /// In en, this message translates to:
  /// **'{speed} fast forward'**
  String plBoostingShort(String speed);

  /// No description provided for @plSwipeUpToLock.
  ///
  /// In en, this message translates to:
  /// **'Swipe up to lock'**
  String get plSwipeUpToLock;

  /// No description provided for @plSpeedLocked.
  ///
  /// In en, this message translates to:
  /// **'Speed locked at {speed}'**
  String plSpeedLocked(String speed);

  /// No description provided for @plExternalSubtitleShort.
  ///
  /// In en, this message translates to:
  /// **'+ External'**
  String get plExternalSubtitleShort;

  /// No description provided for @listSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get listSeparator;

  /// No description provided for @remoteAccess.
  ///
  /// In en, this message translates to:
  /// **'Remote access'**
  String get remoteAccess;

  /// No description provided for @remoteHomeAndRoutes.
  ///
  /// In en, this message translates to:
  /// **'Home and connection routes'**
  String get remoteHomeAndRoutes;

  /// No description provided for @remoteImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import remote configuration'**
  String get remoteImportTitle;

  /// No description provided for @remoteImportFooter.
  ///
  /// In en, this message translates to:
  /// **'Paste the App configuration exported by Relay. It takes effect right after import.'**
  String get remoteImportFooter;

  /// No description provided for @remoteImportPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'App configuration JSON'**
  String get remoteImportPlaceholder;

  /// No description provided for @remoteImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get remoteImport;

  /// No description provided for @remoteImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get remoteImporting;

  /// No description provided for @remoteImported.
  ///
  /// In en, this message translates to:
  /// **'Imported and applied.'**
  String get remoteImported;

  /// No description provided for @remoteClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear remote configuration?'**
  String get remoteClearConfirmTitle;

  /// No description provided for @remoteClearConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Removes the remote configuration and credentials from this device. Import again to restore remote access.'**
  String get remoteClearConfirmMessage;

  /// No description provided for @remoteClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get remoteClear;

  /// No description provided for @remoteClearing.
  ///
  /// In en, this message translates to:
  /// **'Clearing…'**
  String get remoteClearing;

  /// No description provided for @remoteCleared.
  ///
  /// In en, this message translates to:
  /// **'Remote configuration cleared.'**
  String get remoteCleared;

  /// No description provided for @remoteNotImported.
  ///
  /// In en, this message translates to:
  /// **'Not imported yet'**
  String get remoteNotImported;

  /// No description provided for @remoteNotImportedHint.
  ///
  /// In en, this message translates to:
  /// **'Tap “Import” to add a remote configuration.'**
  String get remoteNotImportedHint;

  /// No description provided for @remoteServerName.
  ///
  /// In en, this message translates to:
  /// **'Server name'**
  String get remoteServerName;

  /// No description provided for @remoteCredentials.
  ///
  /// In en, this message translates to:
  /// **'Credentials'**
  String get remoteCredentials;

  /// No description provided for @remoteCredentialsSecure.
  ///
  /// In en, this message translates to:
  /// **'Saved in system secure storage'**
  String get remoteCredentialsSecure;

  /// No description provided for @remoteProxyUnused.
  ///
  /// In en, this message translates to:
  /// **'Not used by any source'**
  String get remoteProxyUnused;

  /// No description provided for @remoteProxyUsedBy.
  ///
  /// In en, this message translates to:
  /// **'Sources: {sources}'**
  String remoteProxyUsedBy(String sources);

  /// No description provided for @remoteProxyPort.
  ///
  /// In en, this message translates to:
  /// **'Port {port}'**
  String remoteProxyPort(int port);

  /// No description provided for @remoteConnectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Connection details'**
  String get remoteConnectionDetails;

  /// No description provided for @remoteRelayServer.
  ///
  /// In en, this message translates to:
  /// **'Relay server'**
  String get remoteRelayServer;

  /// No description provided for @remoteRelayFooter.
  ///
  /// In en, this message translates to:
  /// **'The whole App shares this connection. Credentials are kept in system secure storage.'**
  String get remoteRelayFooter;

  /// No description provided for @remoteAvailableServices.
  ///
  /// In en, this message translates to:
  /// **'Available services'**
  String get remoteAvailableServices;

  /// No description provided for @remoteAvailableServicesFooter.
  ///
  /// In en, this message translates to:
  /// **'Registered on Relay by Home. Pick one for a source under “Edit source → Home remote access”.'**
  String get remoteAvailableServicesFooter;

  /// No description provided for @remoteNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get remoteNeedsAttention;

  /// No description provided for @remoteSourceProxyMissing.
  ///
  /// In en, this message translates to:
  /// **'Its remote access service is not in the current configuration, so remote connection is unavailable.'**
  String get remoteSourceProxyMissing;

  /// No description provided for @statusConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get statusConfigured;

  /// No description provided for @statusNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get statusNotConfigured;

  /// No description provided for @statusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get statusAvailable;

  /// No description provided for @statusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get statusUnavailable;

  /// No description provided for @plgGroupModel.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get plgGroupModel;

  /// No description provided for @plgGroupExternal.
  ///
  /// In en, this message translates to:
  /// **'External capabilities'**
  String get plgGroupExternal;

  /// No description provided for @plgGroupBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in capabilities'**
  String get plgGroupBuiltIn;

  /// No description provided for @plgGroupModelDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure the model the agent uses'**
  String get plgGroupModelDescription;

  /// No description provided for @plgGroupExternalDescription.
  ///
  /// In en, this message translates to:
  /// **'Self-hosted or cloud services you add'**
  String get plgGroupExternalDescription;

  /// No description provided for @plgGroupBuiltInDescription.
  ///
  /// In en, this message translates to:
  /// **'Ships with the App, all open by default'**
  String get plgGroupBuiltInDescription;

  /// No description provided for @plgCount.
  ///
  /// In en, this message translates to:
  /// **'{count}'**
  String plgCount(int count);

  /// No description provided for @extToolCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tool} other{{count} tools}}'**
  String extToolCount(int count);

  /// No description provided for @plgInstanceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 instance} other{{count} instances}}'**
  String plgInstanceCount(int count);

  /// No description provided for @plgExternalHint.
  ///
  /// In en, this message translates to:
  /// **'Enter an address and token to detect and set up a service automatically'**
  String get plgExternalHint;

  /// No description provided for @plgExternalEmpty.
  ///
  /// In en, this message translates to:
  /// **'No external services yet'**
  String get plgExternalEmpty;

  /// No description provided for @extConfigureTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up external capability'**
  String get extConfigureTitle;

  /// No description provided for @plgBuiltInHint.
  ///
  /// In en, this message translates to:
  /// **'{count} capabilities ship with the App, all open by default — nothing to enable one by one'**
  String plgBuiltInHint(int count);

  /// No description provided for @plgGroupEmpty.
  ///
  /// In en, this message translates to:
  /// **'No {group} yet'**
  String plgGroupEmpty(String group);

  /// No description provided for @plgNoAssistant.
  ///
  /// In en, this message translates to:
  /// **'This build does not include the AI assistant'**
  String get plgNoAssistant;

  /// No description provided for @plgSelectForDetail.
  ///
  /// In en, this message translates to:
  /// **'Select an item to see details'**
  String get plgSelectForDetail;

  /// No description provided for @plgDeviceUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not supported on this device'**
  String get plgDeviceUnsupported;

  /// No description provided for @plgTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Temporarily unavailable'**
  String get plgTemporarilyUnavailable;

  /// No description provided for @plgDisabled.
  ///
  /// In en, this message translates to:
  /// **'Plugin disabled'**
  String get plgDisabled;

  /// No description provided for @plgDisableConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable “{name}”?'**
  String plgDisableConfirmTitle(String name);

  /// No description provided for @plgImpactIntro.
  ///
  /// In en, this message translates to:
  /// **'New calls are blocked right away. Instance settings, generated subtitles and history are kept.'**
  String get plgImpactIntro;

  /// No description provided for @plgImpactPlaying.
  ///
  /// In en, this message translates to:
  /// **'{count} playing sessions continue until playback ends, then release their connections.'**
  String plgImpactPlaying(int count);

  /// No description provided for @plgImpactRunning.
  ///
  /// In en, this message translates to:
  /// **'{count} running requests are released when they finish.'**
  String plgImpactRunning(int count);

  /// No description provided for @plgImpactInstances.
  ///
  /// In en, this message translates to:
  /// **'Affected instances: {instances}.'**
  String plgImpactInstances(String instances);

  /// No description provided for @actionFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get actionFailedRetry;

  /// No description provided for @plgUnavailableReason.
  ///
  /// In en, this message translates to:
  /// **'Why it\'s unavailable'**
  String get plgUnavailableReason;

  /// No description provided for @plgSwitch.
  ///
  /// In en, this message translates to:
  /// **'Plugin switch'**
  String get plgSwitch;

  /// No description provided for @plgSwitchOn.
  ///
  /// In en, this message translates to:
  /// **'Accepting new calls'**
  String get plgSwitchOn;

  /// No description provided for @plgSwitchOff.
  ///
  /// In en, this message translates to:
  /// **'New calls are blocked; instance settings are kept'**
  String get plgSwitchOff;

  /// No description provided for @plgLocation.
  ///
  /// In en, this message translates to:
  /// **'Runs where'**
  String get plgLocation;

  /// No description provided for @plgLocationDevice.
  ///
  /// In en, this message translates to:
  /// **'Runs on this device'**
  String get plgLocationDevice;

  /// No description provided for @plgLocationNetwork.
  ///
  /// In en, this message translates to:
  /// **'The App connects from this device to the storage you configured'**
  String get plgLocationNetwork;

  /// No description provided for @plgLocationSelfHosted.
  ///
  /// In en, this message translates to:
  /// **'The App runs the adapter on this device; the work happens on the server you configured'**
  String get plgLocationSelfHosted;

  /// No description provided for @plgLocationCloudApi.
  ///
  /// In en, this message translates to:
  /// **'The App calls a cloud API from this device'**
  String get plgLocationCloudApi;

  /// No description provided for @plgDependencies.
  ///
  /// In en, this message translates to:
  /// **'Dependencies'**
  String get plgDependencies;

  /// No description provided for @plgDependency.
  ///
  /// In en, this message translates to:
  /// **'{name} ({status})'**
  String plgDependency(String name, String status);

  /// No description provided for @plgCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get plgCapabilities;

  /// No description provided for @plgCapabilitiesFooter.
  ///
  /// In en, this message translates to:
  /// **'Only methods this plugin actually implements are listed.'**
  String get plgCapabilitiesFooter;

  /// No description provided for @plgInstancesTitle.
  ///
  /// In en, this message translates to:
  /// **'Instances ({count})'**
  String plgInstancesTitle(int count);

  /// No description provided for @plgInstanceBusy.
  ///
  /// In en, this message translates to:
  /// **'In use: {playing} playing · {running} requests'**
  String plgInstanceBusy(int playing, int running);

  /// No description provided for @plgNoInstances.
  ///
  /// In en, this message translates to:
  /// **'No instances'**
  String get plgNoInstances;

  /// No description provided for @plgOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get plgOpenSettings;

  /// No description provided for @plgRuntime.
  ///
  /// In en, this message translates to:
  /// **'Status and diagnostics'**
  String get plgRuntime;

  /// No description provided for @plgRevisions.
  ///
  /// In en, this message translates to:
  /// **'Saved revision {saved} · In effect {applied}'**
  String plgRevisions(String saved, String applied);

  /// No description provided for @plgNotApplied.
  ///
  /// In en, this message translates to:
  /// **'not yet'**
  String get plgNotApplied;

  /// No description provided for @plgPendingApply.
  ///
  /// In en, this message translates to:
  /// **'New settings pending; the old revision still serves calls in progress'**
  String get plgPendingApply;

  /// No description provided for @plgActivity.
  ///
  /// In en, this message translates to:
  /// **'Active playback {playing} · Running requests {running}'**
  String plgActivity(int playing, int running);

  /// No description provided for @plgLastError.
  ///
  /// In en, this message translates to:
  /// **'Last error: {code}'**
  String plgLastError(String code);

  /// No description provided for @plgRefreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get plgRefreshStatus;

  /// No description provided for @plgCopyDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Copy redacted diagnostics'**
  String get plgCopyDiagnostics;

  /// No description provided for @plgCopyDiagnosticsHint.
  ///
  /// In en, this message translates to:
  /// **'No addresses, accounts, paths or keys'**
  String get plgCopyDiagnosticsHint;

  /// No description provided for @plgDiagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics copied'**
  String get plgDiagnosticsCopied;

  /// No description provided for @extConnectionOk.
  ///
  /// In en, this message translates to:
  /// **'Connection OK'**
  String get extConnectionOk;

  /// No description provided for @extRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove “{name}”?'**
  String extRemoveConfirmTitle(String name);

  /// No description provided for @extRemoveConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Only the address and token are removed from the App. Data on the server is not affected.'**
  String get extRemoveConfirmMessage;

  /// No description provided for @extNeedsRecheck.
  ///
  /// In en, this message translates to:
  /// **'Needs re-detection'**
  String get extNeedsRecheck;

  /// No description provided for @extToolAiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available to AI: {problem}'**
  String extToolAiUnavailable(String problem);

  /// No description provided for @extToolNeedsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Asks for your confirmation first'**
  String get extToolNeedsConfirm;

  /// No description provided for @extAiServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The service is unavailable, so AI can\'t call it right now'**
  String get extAiServiceUnavailable;

  /// No description provided for @extAiNeedsRecheck.
  ///
  /// In en, this message translates to:
  /// **'Tap “Re-detect” to fetch the tool definitions'**
  String get extAiNeedsRecheck;

  /// No description provided for @extAiSummary.
  ///
  /// In en, this message translates to:
  /// **'AI can call {usable} of {total} tools directly; actions that change state ask for your confirmation first'**
  String extAiSummary(int usable, int total);

  /// No description provided for @extRemoved.
  ///
  /// In en, this message translates to:
  /// **'This external capability was removed'**
  String get extRemoved;

  /// No description provided for @extVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String extVersion(String version);

  /// No description provided for @extAiCalls.
  ///
  /// In en, this message translates to:
  /// **'AI calls'**
  String get extAiCalls;

  /// No description provided for @extToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tools ({count})'**
  String extToolsTitle(int count);

  /// No description provided for @extNoTools.
  ///
  /// In en, this message translates to:
  /// **'No tools'**
  String get extNoTools;

  /// No description provided for @extRecheck.
  ///
  /// In en, this message translates to:
  /// **'Re-detect'**
  String get extRecheck;

  /// No description provided for @extConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting and detecting…'**
  String get extConnecting;

  /// No description provided for @extAdded.
  ///
  /// In en, this message translates to:
  /// **'Added “{name}”'**
  String extAdded(String name);

  /// No description provided for @extConfigureFooter.
  ///
  /// In en, this message translates to:
  /// **'Enter the service address and access token. The App connects over MCP to find out what the service is and which tools it offers.'**
  String get extConfigureFooter;

  /// No description provided for @extServiceAddress.
  ///
  /// In en, this message translates to:
  /// **'Service address'**
  String get extServiceAddress;

  /// No description provided for @extAccessToken.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get extAccessToken;

  /// No description provided for @extNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get extNameOptional;

  /// No description provided for @extDetected.
  ///
  /// In en, this message translates to:
  /// **'Detected'**
  String get extDetected;

  /// No description provided for @extTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get extTools;

  /// No description provided for @extConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect and detect'**
  String get extConnect;

  /// No description provided for @scanStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Not scanned'**
  String get scanStatusPending;

  /// No description provided for @scanStatusScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get scanStatusScanning;

  /// No description provided for @scanStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Scan complete'**
  String get scanStatusDone;

  /// No description provided for @scanStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed'**
  String get scanStatusFailed;

  /// No description provided for @scanStatusInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Scan interrupted'**
  String get scanStatusInterrupted;

  /// No description provided for @scanRescanHint.
  ///
  /// In en, this message translates to:
  /// **'Please scan again'**
  String get scanRescanHint;

  /// No description provided for @libraryDbTooNew.
  ///
  /// In en, this message translates to:
  /// **'The library was created by a newer version. Please update the App.'**
  String get libraryDbTooNew;

  /// No description provided for @errConfigUnknownFields.
  ///
  /// In en, this message translates to:
  /// **'The configuration contains unknown fields; the original must be kept.'**
  String get errConfigUnknownFields;

  /// No description provided for @errRemoteKinds.
  ///
  /// In en, this message translates to:
  /// **'Remote access currently supports Jellyfin, Emby, Plex and SMB.'**
  String get errRemoteKinds;

  /// No description provided for @errRemoteProtocolMismatch.
  ///
  /// In en, this message translates to:
  /// **'The remote service protocol does not match; SMB currently supports remote-only mode.'**
  String get errRemoteProtocolMismatch;

  /// No description provided for @errConfigVersionNoOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Incompatible configuration version; it cannot be overwritten.'**
  String get errConfigVersionNoOverwrite;

  /// No description provided for @errAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter an address.'**
  String get errAddressRequired;

  /// No description provided for @errTimeoutConcurrency.
  ///
  /// In en, this message translates to:
  /// **'Request timeout must be 1–120 seconds and concurrency 1–8.'**
  String get errTimeoutConcurrency;

  /// No description provided for @errScopeCount.
  ///
  /// In en, this message translates to:
  /// **'Set at least one access scope; at most 100 scopes and 100 exclusions.'**
  String get errScopeCount;

  /// No description provided for @errScopeRelative.
  ///
  /// In en, this message translates to:
  /// **'Scopes and exclusions must be relative paths inside the root; .. and absolute paths are not allowed.'**
  String get errScopeRelative;

  /// No description provided for @errBrowseModeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This plugin does not support that browsing mode.'**
  String get errBrowseModeUnsupported;

  /// No description provided for @errNoSearchIndex.
  ///
  /// In en, this message translates to:
  /// **'This plugin does not provide search or background indexing yet.'**
  String get errNoSearchIndex;

  /// No description provided for @errLibraryNoDirPolicy.
  ///
  /// In en, this message translates to:
  /// **'Library sources do not support folder policies yet.'**
  String get errLibraryNoDirPolicy;

  /// No description provided for @errChooseLocalFolder.
  ///
  /// In en, this message translates to:
  /// **'Please choose a local folder.'**
  String get errChooseLocalFolder;

  /// No description provided for @errAddressRelativeSegments.
  ///
  /// In en, this message translates to:
  /// **'The address cannot contain relative path segments.'**
  String get errAddressRelativeSegments;

  /// No description provided for @errInvalidServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid server address; put credentials in their own fields.'**
  String get errInvalidServerAddress;

  /// No description provided for @errSmbAddressFormat.
  ///
  /// In en, this message translates to:
  /// **'SMB uses the standard port 445: smb://host/share/optional-folder.'**
  String get errSmbAddressFormat;

  /// No description provided for @errUserIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the {kind} user ID.'**
  String errUserIdRequired(String kind);

  /// No description provided for @errSftpUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the SFTP username.'**
  String get errSftpUsernameRequired;

  /// No description provided for @errServerAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the server address.'**
  String get errServerAddressRequired;

  /// No description provided for @errInvalidHost.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid IP, host name or server address.'**
  String get errInvalidHost;

  /// No description provided for @errPortRange.
  ///
  /// In en, this message translates to:
  /// **'Port must be 1–65535.'**
  String get errPortRange;

  /// No description provided for @errSmbPort.
  ///
  /// In en, this message translates to:
  /// **'SMB connections use port 445.'**
  String get errSmbPort;

  /// No description provided for @errPathDots.
  ///
  /// In en, this message translates to:
  /// **'The path cannot contain “.” or “..”.'**
  String get errPathDots;

  /// No description provided for @errSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Check the account and password, or authorize again.'**
  String get errSignInFailed;

  /// No description provided for @errAddressRedirected.
  ///
  /// In en, this message translates to:
  /// **'The address redirects. Enter the server\'s actual entry point.'**
  String get errAddressRedirected;

  /// No description provided for @errCannotConnectService.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to the service. Check the address and network.'**
  String get errCannotConnectService;

  /// No description provided for @errConnectTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Please try again.'**
  String get errConnectTimeout;

  /// No description provided for @errKindUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the {kind} username.'**
  String errKindUsernameRequired(String kind);

  /// No description provided for @errNoValidSignIn.
  ///
  /// In en, this message translates to:
  /// **'The server did not return a valid sign-in result.'**
  String get errNoValidSignIn;

  /// No description provided for @errPlexSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in expired. Please sign in to Plex again.'**
  String get errPlexSessionExpired;

  /// No description provided for @errPlexServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to this Plex server. Make sure it is online.'**
  String get errPlexServerUnreachable;

  /// No description provided for @errDlnaHttp.
  ///
  /// In en, this message translates to:
  /// **'DLNA device request failed (HTTP {status}).'**
  String errDlnaHttp(int status);

  /// No description provided for @errDlnaForeignHost.
  ///
  /// In en, this message translates to:
  /// **'The DLNA device returned an address on another host.'**
  String get errDlnaForeignHost;

  /// No description provided for @errDlnaNotMediaServer.
  ///
  /// In en, this message translates to:
  /// **'This device is not a media server (no content directory service).'**
  String get errDlnaNotMediaServer;

  /// No description provided for @errChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Please choose a folder.'**
  String get errChooseFolder;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @errChooseVideoOrAudio.
  ///
  /// In en, this message translates to:
  /// **'Please choose a video or audio item.'**
  String get errChooseVideoOrAudio;

  /// No description provided for @errNoPlayableAddress.
  ///
  /// In en, this message translates to:
  /// **'This item has no playable address.'**
  String get errNoPlayableAddress;

  /// No description provided for @plexPartMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get plexPartMedia;

  /// No description provided for @errPathOutsideRoot.
  ///
  /// In en, this message translates to:
  /// **'The path is outside the configured root.'**
  String get errPathOutsideRoot;

  /// No description provided for @errOutsideScope.
  ///
  /// In en, this message translates to:
  /// **'This folder is outside the access scope configured for this instance.'**
  String get errOutsideScope;

  /// No description provided for @errAttachmentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Attachment too large'**
  String get errAttachmentTooLarge;

  /// No description provided for @errServiceAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'{service} denied access (HTTP {status}). Check the username and password.'**
  String errServiceAccessDenied(String service, int status);

  /// No description provided for @errFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'The file or folder does not exist.'**
  String get errFileNotFound;

  /// No description provided for @errServiceRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'{service} request failed (HTTP {status}).'**
  String errServiceRequestFailed(String service, int status);

  /// No description provided for @errFtpRefused.
  ///
  /// In en, this message translates to:
  /// **'The FTP server refused the connection.'**
  String get errFtpRefused;

  /// No description provided for @errFtpLogin.
  ///
  /// In en, this message translates to:
  /// **'FTP sign-in failed. Check the username and password.'**
  String get errFtpLogin;

  /// No description provided for @errFtpNoBinary.
  ///
  /// In en, this message translates to:
  /// **'The FTP server does not support binary transfers.'**
  String get errFtpNoBinary;

  /// No description provided for @errPathChars.
  ///
  /// In en, this message translates to:
  /// **'The path contains unsupported characters.'**
  String get errPathChars;

  /// No description provided for @errFtpNoPassive.
  ///
  /// In en, this message translates to:
  /// **'The FTP server does not support passive mode.'**
  String get errFtpNoPassive;

  /// No description provided for @errFolderNotFoundOrDenied.
  ///
  /// In en, this message translates to:
  /// **'The folder does not exist or you lack access.'**
  String get errFolderNotFoundOrDenied;

  /// No description provided for @errFtpList.
  ///
  /// In en, this message translates to:
  /// **'FTP could not list the folder.'**
  String get errFtpList;

  /// No description provided for @errFtpNoResume.
  ///
  /// In en, this message translates to:
  /// **'The FTP server does not support resuming, so seeking is unavailable.'**
  String get errFtpNoResume;

  /// No description provided for @errFtpRead.
  ///
  /// In en, this message translates to:
  /// **'Cannot read this FTP file.'**
  String get errFtpRead;

  /// No description provided for @errFtpNoSize.
  ///
  /// In en, this message translates to:
  /// **'The FTP server did not report the file size, so it cannot play.'**
  String get errFtpNoSize;

  /// No description provided for @errSftpLogin.
  ///
  /// In en, this message translates to:
  /// **'SFTP sign-in failed. Check the username and password.'**
  String get errSftpLogin;

  /// No description provided for @errSftpDisabled.
  ///
  /// In en, this message translates to:
  /// **'SFTP is not enabled on the server.'**
  String get errSftpDisabled;

  /// No description provided for @errPathDenied.
  ///
  /// In en, this message translates to:
  /// **'No permission to access this path.'**
  String get errPathDenied;

  /// No description provided for @errSftpRequest.
  ///
  /// In en, this message translates to:
  /// **'SFTP request failed.'**
  String get errSftpRequest;

  /// No description provided for @errSftpConnect.
  ///
  /// In en, this message translates to:
  /// **'SFTP connection failed.'**
  String get errSftpConnect;

  /// No description provided for @errSftpPlay.
  ///
  /// In en, this message translates to:
  /// **'Cannot play this SFTP file.'**
  String get errSftpPlay;

  /// No description provided for @errChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Please choose a file.'**
  String get errChooseFile;

  /// No description provided for @errConnectionClosed.
  ///
  /// In en, this message translates to:
  /// **'The connection is closed.'**
  String get errConnectionClosed;

  /// No description provided for @errUnsafeResourceUrl.
  ///
  /// In en, this message translates to:
  /// **'The media service returned an unsafe resource address.'**
  String get errUnsafeResourceUrl;

  /// No description provided for @errMediaServerHttp.
  ///
  /// In en, this message translates to:
  /// **'Media service request failed (HTTP {status}). Check the address and credentials.'**
  String errMediaServerHttp(int status);

  /// No description provided for @errServerArtworkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Server artwork is unavailable'**
  String get errServerArtworkUnavailable;

  /// No description provided for @errImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image too large'**
  String get errImageTooLarge;

  /// No description provided for @errNoPlayableVersion.
  ///
  /// In en, this message translates to:
  /// **'This media has no playable version.'**
  String get errNoPlayableVersion;

  /// No description provided for @errReselectVersion.
  ///
  /// In en, this message translates to:
  /// **'Go back to the library and choose a version again.'**
  String get errReselectVersion;

  /// No description provided for @errServerIdentityMismatch.
  ///
  /// In en, this message translates to:
  /// **'Server item identity does not match'**
  String get errServerIdentityMismatch;

  /// No description provided for @plexPartLabel.
  ///
  /// In en, this message translates to:
  /// **'File {index} · {container}'**
  String plexPartLabel(int index, String container);

  /// No description provided for @errNoPlayableFile.
  ///
  /// In en, this message translates to:
  /// **'This media has no playable file.'**
  String get errNoPlayableFile;

  /// No description provided for @errMultiPartUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This media has multiple versions or parts, which cannot be played directly yet.'**
  String get errMultiPartUnsupported;

  /// No description provided for @errMetadataNotThisServer.
  ///
  /// In en, this message translates to:
  /// **'The metadata query does not belong to this server instance'**
  String get errMetadataNotThisServer;

  /// No description provided for @errArtworkNotThisServer.
  ///
  /// In en, this message translates to:
  /// **'The artwork does not belong to this server instance'**
  String get errArtworkNotThisServer;

  /// No description provided for @srcFieldFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get srcFieldFolder;

  /// No description provided for @srcFieldWorkgroup.
  ///
  /// In en, this message translates to:
  /// **'Workgroup (optional)'**
  String get srcFieldWorkgroup;

  /// No description provided for @srcFieldRegion.
  ///
  /// In en, this message translates to:
  /// **'Region (optional)'**
  String get srcFieldRegion;

  /// No description provided for @srcFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter {field}.'**
  String srcFieldRequired(String field);

  /// No description provided for @errResourceNotThisSource.
  ///
  /// In en, this message translates to:
  /// **'The resource does not belong to this media source.'**
  String get errResourceNotThisSource;

  /// No description provided for @errOutsideAuthorizedFolder.
  ///
  /// In en, this message translates to:
  /// **'The file is outside the authorized folder.'**
  String get errOutsideAuthorizedFolder;

  /// No description provided for @errOutsideSmbShare.
  ///
  /// In en, this message translates to:
  /// **'The path is outside the configured SMB share.'**
  String get errOutsideSmbShare;

  /// No description provided for @errSmbListShares.
  ///
  /// In en, this message translates to:
  /// **'Cannot read the share list. Enter the shared folder path under “Advanced” and try again.'**
  String get errSmbListShares;

  /// No description provided for @errSmbPlay.
  ///
  /// In en, this message translates to:
  /// **'Cannot play this SMB file.'**
  String get errSmbPlay;

  /// No description provided for @errAttachmentNotFound.
  ///
  /// In en, this message translates to:
  /// **'Attachment not found'**
  String get errAttachmentNotFound;

  /// No description provided for @errInvalidFileName.
  ///
  /// In en, this message translates to:
  /// **'Invalid file name.'**
  String get errInvalidFileName;

  /// No description provided for @errUnknownWriteShare.
  ///
  /// In en, this message translates to:
  /// **'Cannot determine which share to write to.'**
  String get errUnknownWriteShare;

  /// No description provided for @errOpenPlayXFolderBlocked.
  ///
  /// In en, this message translates to:
  /// **'A file with the same name exists in the share, so the OpenPlayX folder cannot be created.'**
  String get errOpenPlayXFolderBlocked;

  /// No description provided for @errTooManySameName.
  ///
  /// In en, this message translates to:
  /// **'Too many files with the same name. Tidy up the OpenPlayX folder first.'**
  String get errTooManySameName;

  /// No description provided for @errTempNameConflict.
  ///
  /// In en, this message translates to:
  /// **'Temporary file name conflict. Please try again.'**
  String get errTempNameConflict;

  /// No description provided for @errUploadIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The upload was incomplete; the temporary file was discarded.'**
  String get errUploadIncomplete;

  /// No description provided for @errSmbWrite.
  ///
  /// In en, this message translates to:
  /// **'Writing to SMB failed. Make sure the account can write to this share.'**
  String get errSmbWrite;

  /// No description provided for @errAttachmentTypeOrLimit.
  ///
  /// In en, this message translates to:
  /// **'Unsupported attachment type or read limit'**
  String get errAttachmentTypeOrLimit;

  /// No description provided for @errSourceMissing.
  ///
  /// In en, this message translates to:
  /// **'The media source does not exist or its configuration is incompatible.'**
  String get errSourceMissing;

  /// No description provided for @errSourceKindChange.
  ///
  /// In en, this message translates to:
  /// **'The source type cannot be changed while editing.'**
  String get errSourceKindChange;

  /// No description provided for @errTokenRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the access token.'**
  String get errTokenRequired;

  /// No description provided for @srcStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get srcStatusDisabled;

  /// No description provided for @srcStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get srcStatusReady;

  /// No description provided for @srcStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get srcStatusFailed;

  /// No description provided for @srcStatusInitialized.
  ///
  /// In en, this message translates to:
  /// **'Initialized · Awaiting connection check'**
  String get srcStatusInitialized;

  /// No description provided for @srcStatusSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved · Applies on next access'**
  String get srcStatusSaved;

  /// No description provided for @errArtworkCacheLimit.
  ///
  /// In en, this message translates to:
  /// **'Unsupported image cache limit.'**
  String get errArtworkCacheLimit;

  /// No description provided for @errExtensions.
  ///
  /// In en, this message translates to:
  /// **'File extensions may contain only letters and digits, up to 100.'**
  String get errExtensions;

  /// No description provided for @errSourceDisabled.
  ///
  /// In en, this message translates to:
  /// **'The media source is disabled; its configuration is kept.'**
  String get errSourceDisabled;

  /// No description provided for @errPluginDisabled.
  ///
  /// In en, this message translates to:
  /// **'This plugin is disabled; instance settings are kept.'**
  String get errPluginDisabled;

  /// No description provided for @errTokenExpired.
  ///
  /// In en, this message translates to:
  /// **'The token has expired. Please update the credentials.'**
  String get errTokenExpired;

  /// No description provided for @errReselectLocalFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose the local folder again to restore access.'**
  String get errReselectLocalFolder;

  /// No description provided for @errCredentialsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Credentials are unavailable. Sign in again or update them.'**
  String get errCredentialsUnavailable;

  /// No description provided for @errInstanceChanged.
  ///
  /// In en, this message translates to:
  /// **'The instance settings changed. Please try again.'**
  String get errInstanceChanged;

  /// No description provided for @errRequestTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The request timed out.'**
  String get errRequestTimedOut;

  /// No description provided for @errSourceUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the media source. Check the address, permissions and credentials.'**
  String get errSourceUnreachable;

  /// No description provided for @errInvalidPaging.
  ///
  /// In en, this message translates to:
  /// **'Invalid paging parameters.'**
  String get errInvalidPaging;

  /// No description provided for @errInvalidSearchPaging.
  ///
  /// In en, this message translates to:
  /// **'Invalid search or paging'**
  String get errInvalidSearchPaging;

  /// No description provided for @errSearchUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This source does not support search'**
  String get errSearchUnsupported;

  /// No description provided for @errMetadataUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This source does not support metadata lookup'**
  String get errMetadataUnsupported;

  /// No description provided for @errAttachmentsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This source does not support reading attachments'**
  String get errAttachmentsUnsupported;

  /// No description provided for @errWriteUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This source does not support writing.'**
  String get errWriteUnsupported;

  /// No description provided for @errWriteTimeout.
  ///
  /// In en, this message translates to:
  /// **'Writing timed out. Temporary files starting with .openplayx- may remain on the server.'**
  String get errWriteTimeout;

  /// No description provided for @errSourceProxyMissing.
  ///
  /// In en, this message translates to:
  /// **'The remote access service this source uses is no longer in the App configuration. Import the App configuration from Relay in Settings → Remote access.'**
  String get errSourceProxyMissing;

  /// No description provided for @errReloadBeforeTest.
  ///
  /// In en, this message translates to:
  /// **'Reload the configuration before testing.'**
  String get errReloadBeforeTest;

  /// No description provided for @errTestTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection test timed out.'**
  String get errTestTimeout;

  /// No description provided for @errTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection test failed. Check the address, permissions and credentials.'**
  String get errTestFailed;

  /// No description provided for @errManualScanDisabled.
  ///
  /// In en, this message translates to:
  /// **'Manual file scanning is not enabled for this instance.'**
  String get errManualScanDisabled;

  /// No description provided for @errScanLimit.
  ///
  /// In en, this message translates to:
  /// **'The scan limit must be 1–5000.'**
  String get errScanLimit;

  /// No description provided for @errScanPageLimit.
  ///
  /// In en, this message translates to:
  /// **'The scan reached the limit of 1000 folder pages. Narrow the access scope.'**
  String get errScanPageLimit;

  /// No description provided for @errScanConfigChanged.
  ///
  /// In en, this message translates to:
  /// **'The instance settings changed during the scan. Please scan again.'**
  String get errScanConfigChanged;

  /// No description provided for @errTooManyQueued.
  ///
  /// In en, this message translates to:
  /// **'Too many queued requests for this instance. Try again later.'**
  String get errTooManyQueued;

  /// No description provided for @credNotRequired.
  ///
  /// In en, this message translates to:
  /// **'No account credentials needed'**
  String get credNotRequired;

  /// No description provided for @credMissing.
  ///
  /// In en, this message translates to:
  /// **'Credentials missing'**
  String get credMissing;

  /// No description provided for @credConfigured.
  ///
  /// In en, this message translates to:
  /// **'Credentials saved · Not yet verified'**
  String get credConfigured;

  /// No description provided for @credExpiring.
  ///
  /// In en, this message translates to:
  /// **'Token expires within 7 days'**
  String get credExpiring;

  /// No description provided for @credExpired.
  ///
  /// In en, this message translates to:
  /// **'Token expired'**
  String get credExpired;

  /// No description provided for @credRejected.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed · Update credentials'**
  String get credRejected;

  /// No description provided for @credVerified.
  ///
  /// In en, this message translates to:
  /// **'Connection verified'**
  String get credVerified;

  /// No description provided for @errConfigDbTooNew.
  ///
  /// In en, this message translates to:
  /// **'The local configuration database is from a newer version. Please update the App.'**
  String get errConfigDbTooNew;

  /// No description provided for @errConfigVersionKept.
  ///
  /// In en, this message translates to:
  /// **'Incompatible configuration version; the original data is kept.'**
  String get errConfigVersionKept;

  /// No description provided for @errInstanceMetaMismatch.
  ///
  /// In en, this message translates to:
  /// **'The instance configuration does not match its metadata.'**
  String get errInstanceMetaMismatch;

  /// No description provided for @errInstanceQuarantined.
  ///
  /// In en, this message translates to:
  /// **'The instance configuration is incompatible or damaged; it was isolated and the original data kept.'**
  String get errInstanceQuarantined;

  /// No description provided for @errInstanceNoOverwrite.
  ///
  /// In en, this message translates to:
  /// **'An instance configuration with an incompatible version cannot be overwritten.'**
  String get errInstanceNoOverwrite;

  /// No description provided for @errConfigChangedElsewhereEdit.
  ///
  /// In en, this message translates to:
  /// **'The configuration was changed in another window. Reload before editing.'**
  String get errConfigChangedElsewhereEdit;

  /// No description provided for @errConfigChangedDelete.
  ///
  /// In en, this message translates to:
  /// **'The configuration was updated. Reload before deleting.'**
  String get errConfigChangedDelete;

  /// No description provided for @errDefaultInstanceChanged.
  ///
  /// In en, this message translates to:
  /// **'The default instance setting was updated. Please reload.'**
  String get errDefaultInstanceChanged;

  /// No description provided for @errSettingsChangedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Settings were changed in another window. Please reload.'**
  String get errSettingsChangedElsewhere;

  /// No description provided for @pickerVideoAudio.
  ///
  /// In en, this message translates to:
  /// **'Video and audio'**
  String get pickerVideoAudio;

  /// No description provided for @pickerAllFiles.
  ///
  /// In en, this message translates to:
  /// **'All files'**
  String get pickerAllFiles;

  /// No description provided for @errSeriesIdentityConflict.
  ///
  /// In en, this message translates to:
  /// **'The series or season identity conflicts'**
  String get errSeriesIdentityConflict;

  /// No description provided for @errInfoChangedReload.
  ///
  /// In en, this message translates to:
  /// **'The information changed. Reload and try again'**
  String get errInfoChangedReload;

  /// No description provided for @errWorkIdConflict.
  ///
  /// In en, this message translates to:
  /// **'Work ID conflict; manual confirmation needed'**
  String get errWorkIdConflict;

  /// No description provided for @errInvalidFieldValue.
  ///
  /// In en, this message translates to:
  /// **'Invalid field value'**
  String get errInvalidFieldValue;

  /// No description provided for @errPosterNotThisWork.
  ///
  /// In en, this message translates to:
  /// **'The poster does not belong to this work'**
  String get errPosterNotThisWork;

  /// No description provided for @errRemoteConfigVersion.
  ///
  /// In en, this message translates to:
  /// **'The remote access configuration has an incompatible version or unknown fields.'**
  String get errRemoteConfigVersion;

  /// No description provided for @errRemoteOutboundCredential.
  ///
  /// In en, this message translates to:
  /// **'The outbound and its credential must both be present.'**
  String get errRemoteOutboundCredential;

  /// No description provided for @errRemoteUuidPlacement.
  ///
  /// In en, this message translates to:
  /// **'The UUID may only be stored in the credential.'**
  String get errRemoteUuidPlacement;

  /// No description provided for @errRemoteCredentialInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid remote credential.'**
  String get errRemoteCredentialInvalid;

  /// No description provided for @errRemoteProxiesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Proxy names must be non-empty and unique, and remotePort must be a valid port.'**
  String get errRemoteProxiesInvalid;

  /// No description provided for @errRemotePolicyUnsupported.
  ///
  /// In en, this message translates to:
  /// **'The remote connection policy is not supported.'**
  String get errRemotePolicyUnsupported;

  /// No description provided for @errRemoteLanNeedsHttps.
  ///
  /// In en, this message translates to:
  /// **'Automatic LAN access needs an HTTPS endpoint and a paired certificate SHA-256.'**
  String get errRemoteLanNeedsHttps;

  /// No description provided for @errRemoteUnknownField.
  ///
  /// In en, this message translates to:
  /// **'Unknown remote access field.'**
  String get errRemoteUnknownField;

  /// No description provided for @errRemoteChooseProxy.
  ///
  /// In en, this message translates to:
  /// **'Choose the proxy to use for remote access.'**
  String get errRemoteChooseProxy;

  /// No description provided for @errRemoteEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Remote access needs a valid HTTP(S) or SMB service endpoint.'**
  String get errRemoteEndpoint;

  /// No description provided for @errRemoteProxyRef.
  ///
  /// In en, this message translates to:
  /// **'Invalid proxy name, remotePort or credential reference.'**
  String get errRemoteProxyRef;

  /// No description provided for @errRemoteProxyHost.
  ///
  /// In en, this message translates to:
  /// **'Invalid proxy host or configuration length.'**
  String get errRemoteProxyHost;

  /// No description provided for @errRemoteTlsName.
  ///
  /// In en, this message translates to:
  /// **'Invalid proxy TLS server name.'**
  String get errRemoteTlsName;

  /// No description provided for @errRemoteNeedsVless.
  ///
  /// In en, this message translates to:
  /// **'Pairing needs a VLESS TLS/REALITY outbound with certificate verification on.'**
  String get errRemoteNeedsVless;

  /// No description provided for @errRemoteCaPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'The CA configuration cannot contain a private key.'**
  String get errRemoteCaPrivateKey;

  /// No description provided for @errRemoteRealityPublic.
  ///
  /// In en, this message translates to:
  /// **'The REALITY client stores only public parameters.'**
  String get errRemoteRealityPublic;

  /// No description provided for @errRemoteAuthHeader.
  ///
  /// In en, this message translates to:
  /// **'Transport auth headers cannot be written into the public route configuration.'**
  String get errRemoteAuthHeader;

  /// No description provided for @errRemoteTlsField.
  ///
  /// In en, this message translates to:
  /// **'Unsupported TLS configuration field.'**
  String get errRemoteTlsField;

  /// No description provided for @errRemoteConfigTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The configuration is too large.'**
  String get errRemoteConfigTooLarge;

  /// No description provided for @errRemoteInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'Not valid JSON. Paste the complete App configuration exported by Relay.'**
  String get errRemoteInvalidJson;

  /// No description provided for @errRemoteAppConfigShape.
  ///
  /// In en, this message translates to:
  /// **'The App configuration must be a JSON object with only “outbound” (object) and “proxies” (array).'**
  String get errRemoteAppConfigShape;

  /// No description provided for @errRemoteProxyShape.
  ///
  /// In en, this message translates to:
  /// **'Each proxy must have only “name” (string) and “remotePort” (port).'**
  String get errRemoteProxyShape;

  /// No description provided for @errRemoteProxiesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Proxies cannot be empty and names must be unique.'**
  String get errRemoteProxiesEmpty;

  /// No description provided for @errRemoteOutsideEndpoint.
  ///
  /// In en, this message translates to:
  /// **'The request is outside the authorized service endpoint.'**
  String get errRemoteOutsideEndpoint;

  /// No description provided for @errRemoteCertMismatch.
  ///
  /// In en, this message translates to:
  /// **'The service certificate does not match the paired identity.'**
  String get errRemoteCertMismatch;

  /// No description provided for @errRemoteOutsidePaired.
  ///
  /// In en, this message translates to:
  /// **'The connection is outside the paired service.'**
  String get errRemoteOutsidePaired;

  /// No description provided for @errRemoteLanUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The LAN service is unreachable or failed identity verification.'**
  String get errRemoteLanUnreachable;

  /// No description provided for @errRemoteCellularBlocked.
  ///
  /// In en, this message translates to:
  /// **'Remote access over cellular is disabled, or the current network cannot be determined.'**
  String get errRemoteCellularBlocked;

  /// No description provided for @errRemoteCellularUnknown.
  ///
  /// In en, this message translates to:
  /// **'Cannot determine the cellular state, so the remote connection was blocked.'**
  String get errRemoteCellularUnknown;

  /// No description provided for @errRemoteNoCore.
  ///
  /// In en, this message translates to:
  /// **'This build lacks the remote connection core. Install a build that includes sing-box.'**
  String get errRemoteNoCore;

  /// No description provided for @errRemoteNativeConfigTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The remote connection configuration is too large.'**
  String get errRemoteNativeConfigTooLarge;

  /// No description provided for @errRemoteCoreStart.
  ///
  /// In en, this message translates to:
  /// **'The remote core failed to start. Check the route configuration.'**
  String get errRemoteCoreStart;

  /// No description provided for @rtDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get rtDisabled;

  /// No description provided for @rtUnchecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked'**
  String get rtUnchecked;

  /// No description provided for @rtStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get rtStarting;

  /// No description provided for @rtBlocked.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get rtBlocked;

  /// No description provided for @rtError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get rtError;

  /// No description provided for @rtDraining.
  ///
  /// In en, this message translates to:
  /// **'Finishing up'**
  String get rtDraining;

  /// No description provided for @healthLastOk.
  ///
  /// In en, this message translates to:
  /// **'Last connection succeeded'**
  String get healthLastOk;

  /// No description provided for @healthLocal.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get healthLocal;

  /// No description provided for @plgDraining.
  ///
  /// In en, this message translates to:
  /// **'New calls blocked; waiting for playback or tasks to finish'**
  String get plgDraining;

  /// No description provided for @plgDependencyBlocked.
  ///
  /// In en, this message translates to:
  /// **'The dependency “{name}” is disabled or unavailable'**
  String plgDependencyBlocked(String name);

  /// No description provided for @plgNoInstanceAdded.
  ///
  /// In en, this message translates to:
  /// **'No instance added yet'**
  String get plgNoInstanceAdded;

  /// No description provided for @plgAllInstancesDisabled.
  ///
  /// In en, this message translates to:
  /// **'All instances are disabled'**
  String get plgAllInstancesDisabled;

  /// No description provided for @plgInstanceFailing.
  ///
  /// In en, this message translates to:
  /// **'An instance failed to connect'**
  String get plgInstanceFailing;

  /// No description provided for @plgSomeInstancesBlocked.
  ///
  /// In en, this message translates to:
  /// **'Some instances need attention'**
  String get plgSomeInstancesBlocked;

  /// No description provided for @plgNfoInstance.
  ///
  /// In en, this message translates to:
  /// **'Adjacent file rules'**
  String get plgNfoInstance;

  /// No description provided for @plgNoTmdb.
  ///
  /// In en, this message translates to:
  /// **'This build does not include TMDB settings'**
  String get plgNoTmdb;

  /// No description provided for @plgTmdbInstance.
  ///
  /// In en, this message translates to:
  /// **'TMDB settings'**
  String get plgTmdbInstance;

  /// No description provided for @plgTmdbNoToken.
  ///
  /// In en, this message translates to:
  /// **'No access token configured'**
  String get plgTmdbNoToken;

  /// No description provided for @plgNoFfmpeg.
  ///
  /// In en, this message translates to:
  /// **'This platform or build does not include FFmpeg media processing'**
  String get plgNoFfmpeg;

  /// No description provided for @plgFfmpegInstance.
  ///
  /// In en, this message translates to:
  /// **'On-device processing'**
  String get plgFfmpegInstance;

  /// No description provided for @plgModelNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No model or key configured'**
  String get plgModelNotConfigured;

  /// No description provided for @plgNoSources.
  ///
  /// In en, this message translates to:
  /// **'This build does not include media sources'**
  String get plgNoSources;

  /// No description provided for @plgNoAsr.
  ///
  /// In en, this message translates to:
  /// **'This build does not include speech recognition'**
  String get plgNoAsr;

  /// No description provided for @plgModelDetail.
  ///
  /// In en, this message translates to:
  /// **'Model {model}'**
  String plgModelDetail(String model);

  /// No description provided for @plgLocalAsrUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The local recognition engine is unavailable'**
  String get plgLocalAsrUnavailable;

  /// No description provided for @errTmdbTokenRequired.
  ///
  /// In en, this message translates to:
  /// **'Configure a TMDB read access token'**
  String get errTmdbTokenRequired;

  /// No description provided for @errQueryCancelled.
  ///
  /// In en, this message translates to:
  /// **'The query was cancelled'**
  String get errQueryCancelled;

  /// No description provided for @errTmdbResponseTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The TMDB response is too large'**
  String get errTmdbResponseTooLarge;

  /// No description provided for @errTmdbAuth.
  ///
  /// In en, this message translates to:
  /// **'TMDB authentication failed. Update the token'**
  String get errTmdbAuth;

  /// No description provided for @errTmdbNotFound.
  ///
  /// In en, this message translates to:
  /// **'The TMDB item does not exist'**
  String get errTmdbNotFound;

  /// No description provided for @errTmdbRateLimited.
  ///
  /// In en, this message translates to:
  /// **'TMDB is rate limiting requests. Try again later'**
  String get errTmdbRateLimited;

  /// No description provided for @errTmdbUnavailable.
  ///
  /// In en, this message translates to:
  /// **'TMDB is temporarily unavailable'**
  String get errTmdbUnavailable;

  /// No description provided for @errTmdbRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'The TMDB request failed'**
  String get errTmdbRequestFailed;

  /// No description provided for @errTmdbInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'Invalid TMDB response format'**
  String get errTmdbInvalidResponse;

  /// No description provided for @errTmdbUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to TMDB. Check the network'**
  String get errTmdbUnreachable;

  /// No description provided for @errTmdbNoAttachments.
  ///
  /// In en, this message translates to:
  /// **'TMDB does not read source attachments'**
  String get errTmdbNoAttachments;

  /// No description provided for @errTmdbInvalidIds.
  ///
  /// In en, this message translates to:
  /// **'Invalid TMDB ID or season/episode number'**
  String get errTmdbInvalidIds;

  /// No description provided for @errIdentifySeriesFirst.
  ///
  /// In en, this message translates to:
  /// **'Identify the series first, then choose the season and episode'**
  String get errIdentifySeriesFirst;

  /// No description provided for @errTmdbRefRequired.
  ///
  /// In en, this message translates to:
  /// **'Details need a TMDB reference'**
  String get errTmdbRefRequired;

  /// No description provided for @errTmdbInvalidIdentity.
  ///
  /// In en, this message translates to:
  /// **'Invalid TMDB item identity or title'**
  String get errTmdbInvalidIdentity;

  /// No description provided for @errNfoRefRequired.
  ///
  /// In en, this message translates to:
  /// **'NFO details need an attachment reference'**
  String get errNfoRefRequired;

  /// No description provided for @errNfoParse.
  ///
  /// In en, this message translates to:
  /// **'Could not parse the NFO'**
  String get errNfoParse;

  /// No description provided for @errNfoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The NFO is larger than 1 MiB'**
  String get errNfoTooLarge;

  /// No description provided for @errNfoDtd.
  ///
  /// In en, this message translates to:
  /// **'DTD and entity declarations are not allowed in NFO'**
  String get errNfoDtd;

  /// No description provided for @errNfoTooManyNodes.
  ///
  /// In en, this message translates to:
  /// **'The NFO has too many nodes'**
  String get errNfoTooManyNodes;

  /// No description provided for @errNfoTooDeep.
  ///
  /// In en, this message translates to:
  /// **'The NFO is nested too deeply'**
  String get errNfoTooDeep;

  /// No description provided for @errNfoType.
  ///
  /// In en, this message translates to:
  /// **'Unsupported NFO item type'**
  String get errNfoType;

  /// No description provided for @errNfoFieldTooLong.
  ///
  /// In en, this message translates to:
  /// **'An NFO field is too long'**
  String get errNfoFieldTooLong;

  /// No description provided for @errInvalidMetadataQuery.
  ///
  /// In en, this message translates to:
  /// **'Invalid metadata query parameters'**
  String get errInvalidMetadataQuery;

  /// No description provided for @errMetadataQueryUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This metadata instance does not support that query'**
  String get errMetadataQueryUnsupported;

  /// No description provided for @errMediaKindUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Metadata for this media type is not supported'**
  String get errMediaKindUnsupported;

  /// No description provided for @errBackgroundIdentify.
  ///
  /// In en, this message translates to:
  /// **'Background identification failed'**
  String get errBackgroundIdentify;

  /// No description provided for @errQueryStale.
  ///
  /// In en, this message translates to:
  /// **'The query expired or was cancelled'**
  String get errQueryStale;

  /// No description provided for @errTmdbConfigChanged.
  ///
  /// In en, this message translates to:
  /// **'The TMDB settings changed'**
  String get errTmdbConfigChanged;

  /// No description provided for @errRequeryCandidates.
  ///
  /// In en, this message translates to:
  /// **'Search for candidates again'**
  String get errRequeryCandidates;

  /// No description provided for @errChooseEpisodeFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a specific season and episode first'**
  String get errChooseEpisodeFirst;

  /// No description provided for @errCandidateNotThisQuery.
  ///
  /// In en, this message translates to:
  /// **'The candidate does not belong to this query'**
  String get errCandidateNotThisQuery;

  /// No description provided for @errDetailIdentityMismatch.
  ///
  /// In en, this message translates to:
  /// **'Detail identity does not match'**
  String get errDetailIdentityMismatch;

  /// No description provided for @errReloadCandidates.
  ///
  /// In en, this message translates to:
  /// **'Reload the candidates'**
  String get errReloadCandidates;

  /// No description provided for @errInvalidLocalCandidate.
  ///
  /// In en, this message translates to:
  /// **'Invalid local candidate'**
  String get errInvalidLocalCandidate;

  /// No description provided for @errChooseSeriesFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a series first'**
  String get errChooseSeriesFirst;

  /// No description provided for @errConfirmMatchFirst.
  ///
  /// In en, this message translates to:
  /// **'Confirm the match first'**
  String get errConfirmMatchFirst;

  /// No description provided for @errCatalogTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The catalog is too large. Narrow the metadata scope'**
  String get errCatalogTooLarge;

  /// No description provided for @errCursorStuck.
  ///
  /// In en, this message translates to:
  /// **'The paging cursor did not advance'**
  String get errCursorStuck;

  /// No description provided for @errEpisodeSeasonMissing.
  ///
  /// In en, this message translates to:
  /// **'The episode\'s season does not exist'**
  String get errEpisodeSeasonMissing;

  /// No description provided for @errSourceConfigChanged.
  ///
  /// In en, this message translates to:
  /// **'The source configuration changed'**
  String get errSourceConfigChanged;

  /// No description provided for @errInvalidYear.
  ///
  /// In en, this message translates to:
  /// **'Invalid year'**
  String get errInvalidYear;

  /// No description provided for @catSourceBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse folders'**
  String get catSourceBrowse;

  /// No description provided for @catSourceBrowseDesc.
  ///
  /// In en, this message translates to:
  /// **'List this source\'s folders and files'**
  String get catSourceBrowseDesc;

  /// No description provided for @catSourceResolve.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get catSourceResolve;

  /// No description provided for @catSourceResolveDesc.
  ///
  /// In en, this message translates to:
  /// **'Hand the selected item to the player, strictly bound to its instance'**
  String get catSourceResolveDesc;

  /// No description provided for @catSourceAttachments.
  ///
  /// In en, this message translates to:
  /// **'Read attachments'**
  String get catSourceAttachments;

  /// No description provided for @catSourceAttachmentsDesc.
  ///
  /// In en, this message translates to:
  /// **'Read small files such as NFO and external subtitles (size-limited)'**
  String get catSourceAttachmentsDesc;

  /// No description provided for @catSearchMedia.
  ///
  /// In en, this message translates to:
  /// **'Search media'**
  String get catSearchMedia;

  /// No description provided for @catSearchMediaDesc.
  ///
  /// In en, this message translates to:
  /// **'Search movies and shows on the server'**
  String get catSearchMediaDesc;

  /// No description provided for @catMetadataLookup.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get catMetadataLookup;

  /// No description provided for @catMetadataLookupDesc.
  ///
  /// In en, this message translates to:
  /// **'Read metadata organized by the media server'**
  String get catMetadataLookupDesc;

  /// No description provided for @catSourceWrite.
  ///
  /// In en, this message translates to:
  /// **'Write new files'**
  String get catSourceWrite;

  /// No description provided for @catSourceWriteDesc.
  ///
  /// In en, this message translates to:
  /// **'Save App clips and external downloads as new files in a source folder; never overwrites existing files and requires confirmation'**
  String get catSourceWriteDesc;

  /// No description provided for @catSummaryLocal.
  ///
  /// In en, this message translates to:
  /// **'Folders on this device or mounted'**
  String get catSummaryLocal;

  /// No description provided for @catSummarySmb.
  ///
  /// In en, this message translates to:
  /// **'Windows shares and NAS SMB shares'**
  String get catSummarySmb;

  /// No description provided for @catSummaryWebdav.
  ///
  /// In en, this message translates to:
  /// **'WebDAV cloud drives or NAS folders'**
  String get catSummaryWebdav;

  /// No description provided for @catSummaryFtp.
  ///
  /// In en, this message translates to:
  /// **'FTP server folders'**
  String get catSummaryFtp;

  /// No description provided for @catSummarySftp.
  ///
  /// In en, this message translates to:
  /// **'Server folders over SSH'**
  String get catSummarySftp;

  /// No description provided for @catSummaryS3.
  ///
  /// In en, this message translates to:
  /// **'S3-compatible object storage buckets'**
  String get catSummaryS3;

  /// No description provided for @catSummaryPlex.
  ///
  /// In en, this message translates to:
  /// **'Plex media server'**
  String get catSummaryPlex;

  /// No description provided for @catSummaryJellyfin.
  ///
  /// In en, this message translates to:
  /// **'Jellyfin media server'**
  String get catSummaryJellyfin;

  /// No description provided for @catSummaryEmby.
  ///
  /// In en, this message translates to:
  /// **'Emby media server'**
  String get catSummaryEmby;

  /// No description provided for @catSummaryDlna.
  ///
  /// In en, this message translates to:
  /// **'DLNA media servers on the local network'**
  String get catSummaryDlna;

  /// No description provided for @catDataLocal.
  ///
  /// In en, this message translates to:
  /// **'Reads only the folders you authorize.'**
  String get catDataLocal;

  /// No description provided for @catDataRemote.
  ///
  /// In en, this message translates to:
  /// **'The App connects from this device to the server you configured; file and folder names appear in AI chats (only when AI use is allowed).'**
  String get catDataRemote;

  /// No description provided for @catNfoName.
  ///
  /// In en, this message translates to:
  /// **'NFO metadata'**
  String get catNfoName;

  /// No description provided for @catNfoSummary.
  ///
  /// In en, this message translates to:
  /// **'Reads .nfo files next to your media'**
  String get catNfoSummary;

  /// No description provided for @catNfoToggle.
  ///
  /// In en, this message translates to:
  /// **'Controlled by “Scraped metadata”; background scraping runs on its own and cannot be disabled separately yet.'**
  String get catNfoToggle;

  /// No description provided for @catNfoCap.
  ///
  /// In en, this message translates to:
  /// **'Local metadata'**
  String get catNfoCap;

  /// No description provided for @catNfoCapDesc.
  ///
  /// In en, this message translates to:
  /// **'Match movie info by adjacent-file rules'**
  String get catNfoCapDesc;

  /// No description provided for @catTmdbSummary.
  ///
  /// In en, this message translates to:
  /// **'Look up movies and shows from The Movie Database'**
  String get catTmdbSummary;

  /// No description provided for @catTmdbToggle.
  ///
  /// In en, this message translates to:
  /// **'Clear the access token to stop using it; background scraping runs on its own and cannot be disabled separately yet.'**
  String get catTmdbToggle;

  /// No description provided for @catTmdbData.
  ///
  /// In en, this message translates to:
  /// **'Lookups send the parsed title and year to TMDB, never file contents.'**
  String get catTmdbData;

  /// No description provided for @catTmdbCap.
  ///
  /// In en, this message translates to:
  /// **'Look up metadata'**
  String get catTmdbCap;

  /// No description provided for @catTmdbCapDesc.
  ///
  /// In en, this message translates to:
  /// **'Search and match movies and shows; the host does the writing'**
  String get catTmdbCapDesc;

  /// No description provided for @catFfmpegName.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg media processing'**
  String get catFfmpegName;

  /// No description provided for @catFfmpegSummary.
  ///
  /// In en, this message translates to:
  /// **'Snapshots, probing, transcoding and audio extraction'**
  String get catFfmpegSummary;

  /// No description provided for @catFfmpegData.
  ///
  /// In en, this message translates to:
  /// **'Processes media on this device; output is kept in the app folder.'**
  String get catFfmpegData;

  /// No description provided for @catProbe.
  ///
  /// In en, this message translates to:
  /// **'Probe'**
  String get catProbe;

  /// No description provided for @catProbeDesc.
  ///
  /// In en, this message translates to:
  /// **'Read duration, codecs and tracks'**
  String get catProbeDesc;

  /// No description provided for @catTranscode.
  ///
  /// In en, this message translates to:
  /// **'Transcode'**
  String get catTranscode;

  /// No description provided for @catTranscodeDesc.
  ///
  /// In en, this message translates to:
  /// **'Transcode to a new file with a preset'**
  String get catTranscodeDesc;

  /// No description provided for @catExtractAudio.
  ///
  /// In en, this message translates to:
  /// **'Extract audio'**
  String get catExtractAudio;

  /// No description provided for @catExtractAudioDesc.
  ///
  /// In en, this message translates to:
  /// **'Export an audio track for recognition or saving'**
  String get catExtractAudioDesc;

  /// No description provided for @catSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Snapshot'**
  String get catSnapshot;

  /// No description provided for @catSnapshotDesc.
  ///
  /// In en, this message translates to:
  /// **'Capture the frame at a given time'**
  String get catSnapshotDesc;

  /// No description provided for @catAsrName.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition'**
  String get catAsrName;

  /// No description provided for @catAsrSummary.
  ///
  /// In en, this message translates to:
  /// **'Generate original-language subtitles and transcripts for videos'**
  String get catAsrSummary;

  /// No description provided for @catAsrCapDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate original-language subtitles/transcripts; no translation'**
  String get catAsrCapDesc;

  /// No description provided for @catLlmName.
  ///
  /// In en, this message translates to:
  /// **'Chat model'**
  String get catLlmName;

  /// No description provided for @catLlmSummary.
  ///
  /// In en, this message translates to:
  /// **'Provides the large language model for the AI assistant'**
  String get catLlmSummary;

  /// No description provided for @catLlmToggle.
  ///
  /// In en, this message translates to:
  /// **'Configure or clear the model under “AI and models”; it never creates reasoning tools that call itself.'**
  String get catLlmToggle;

  /// No description provided for @catLlmData.
  ///
  /// In en, this message translates to:
  /// **'Chat content, page summaries and tool results are sent to the configured model service, which may cost money.'**
  String get catLlmData;

  /// No description provided for @catLlmCap.
  ///
  /// In en, this message translates to:
  /// **'Chat reasoning'**
  String get catLlmCap;

  /// No description provided for @catLlmCapDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate replies and tool calls for the AI assistant'**
  String get catLlmCapDesc;

  /// No description provided for @catCategorySource.
  ///
  /// In en, this message translates to:
  /// **'Media sources'**
  String get catCategorySource;

  /// No description provided for @catCategoryMetadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get catCategoryMetadata;

  /// No description provided for @catCategoryMediaProcessing.
  ///
  /// In en, this message translates to:
  /// **'Media processing'**
  String get catCategoryMediaProcessing;

  /// No description provided for @catCategorySpeech.
  ///
  /// In en, this message translates to:
  /// **'Subtitle recognition'**
  String get catCategorySpeech;

  /// No description provided for @catLocationNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network storage'**
  String get catLocationNetwork;

  /// No description provided for @catLocationSelfHosted.
  ///
  /// In en, this message translates to:
  /// **'Self-hosted service'**
  String get catLocationSelfHosted;

  /// No description provided for @catLocationCloudApi.
  ///
  /// In en, this message translates to:
  /// **'Cloud API'**
  String get catLocationCloudApi;

  /// No description provided for @webSearchPresetName.
  ///
  /// In en, this message translates to:
  /// **'Web search'**
  String get webSearchPresetName;

  /// No description provided for @errAssistantConfig.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTPS API base URL (http only for a server on this device, such as http://localhost:11434/v1), model and output limit (128–16384)'**
  String get errAssistantConfig;

  /// No description provided for @errExtRootAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter the service root address, e.g. https://bt.example.com'**
  String get errExtRootAddress;

  /// No description provided for @errExtHttpsRequired.
  ///
  /// In en, this message translates to:
  /// **'Public addresses must use HTTPS; HTTP is only allowed for LAN or local addresses'**
  String get errExtHttpsRequired;

  /// No description provided for @errExtTokenRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the access token'**
  String get errExtTokenRequired;

  /// No description provided for @errExtTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out'**
  String get errExtTimeout;

  /// No description provided for @errExtUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to this address'**
  String get errExtUnreachable;

  /// No description provided for @errExtTls.
  ///
  /// In en, this message translates to:
  /// **'TLS certificate verification failed'**
  String get errExtTls;

  /// No description provided for @errExtTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The service returned too much data'**
  String get errExtTooLarge;

  /// No description provided for @errExtRejected.
  ///
  /// In en, this message translates to:
  /// **'The service rejected the request: {reason}'**
  String errExtRejected(String reason);

  /// No description provided for @errExtError.
  ///
  /// In en, this message translates to:
  /// **'The service returned an error ({code})'**
  String errExtError(String code);

  /// No description provided for @errExtTokenInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid access token'**
  String get errExtTokenInvalid;

  /// No description provided for @errExtNoMcp.
  ///
  /// In en, this message translates to:
  /// **'This address does not offer an MCP endpoint'**
  String get errExtNoMcp;

  /// No description provided for @errArtworkCancelled.
  ///
  /// In en, this message translates to:
  /// **'Image loading was cancelled'**
  String get errArtworkCancelled;

  /// No description provided for @errArtworkQuota.
  ///
  /// In en, this message translates to:
  /// **'Not enough image cache space'**
  String get errArtworkQuota;

  /// No description provided for @errArtworkUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'The image address is not authorized'**
  String get errArtworkUnauthorized;

  /// No description provided for @errArtworkTypeSize.
  ///
  /// In en, this message translates to:
  /// **'Invalid image type or size'**
  String get errArtworkTypeSize;

  /// No description provided for @errArtworkEmptyOrLarge.
  ///
  /// In en, this message translates to:
  /// **'The image is empty or too large'**
  String get errArtworkEmptyOrLarge;

  /// No description provided for @errArtworkContentType.
  ///
  /// In en, this message translates to:
  /// **'Unsupported image content type'**
  String get errArtworkContentType;

  /// No description provided for @errArtworkDecodeSize.
  ///
  /// In en, this message translates to:
  /// **'The decoded image is too large'**
  String get errArtworkDecodeSize;

  /// No description provided for @errArtworkWait.
  ///
  /// In en, this message translates to:
  /// **'Wait for the image to finish loading'**
  String get errArtworkWait;

  /// No description provided for @errLibraryClosing.
  ///
  /// In en, this message translates to:
  /// **'The library is closing'**
  String get errLibraryClosing;

  /// No description provided for @errNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get errNameRequired;

  /// No description provided for @errSeasonCycle.
  ///
  /// In en, this message translates to:
  /// **'The source returned a circular season/episode relation'**
  String get errSeasonCycle;

  /// No description provided for @errInvalidPagingShort.
  ///
  /// In en, this message translates to:
  /// **'Invalid paging'**
  String get errInvalidPagingShort;

  /// No description provided for @errTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get errTitleRequired;

  /// No description provided for @errScanRunning.
  ///
  /// In en, this message translates to:
  /// **'A scan is already running'**
  String get errScanRunning;

  /// No description provided for @errFileSourceMissing.
  ///
  /// In en, this message translates to:
  /// **'The file source does not exist'**
  String get errFileSourceMissing;

  /// No description provided for @errFileSourceDisabled.
  ///
  /// In en, this message translates to:
  /// **'The file source is disabled'**
  String get errFileSourceDisabled;

  /// No description provided for @errSourceScanDisabled.
  ///
  /// In en, this message translates to:
  /// **'Scanning is not enabled for this source'**
  String get errSourceScanDisabled;

  /// No description provided for @errScanTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The scan scope is too large. Narrow it down'**
  String get errScanTooLarge;

  /// No description provided for @errScanBindingChanged.
  ///
  /// In en, this message translates to:
  /// **'The source or binding changed. Please scan again'**
  String get errScanBindingChanged;

  /// No description provided for @errSourceIdentityMismatch.
  ///
  /// In en, this message translates to:
  /// **'Source identity does not match'**
  String get errSourceIdentityMismatch;

  /// No description provided for @errSourceCursorStuck.
  ///
  /// In en, this message translates to:
  /// **'The source paging cursor did not advance'**
  String get errSourceCursorStuck;

  /// No description provided for @errScanIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The scan did not finish. Check the source and try again'**
  String get errScanIncomplete;

  /// No description provided for @aiToolContextGet.
  ///
  /// In en, this message translates to:
  /// **'Read current page'**
  String get aiToolContextGet;

  /// No description provided for @aiToolSourceList.
  ///
  /// In en, this message translates to:
  /// **'List media sources'**
  String get aiToolSourceList;

  /// No description provided for @aiToolSourceBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse folder'**
  String get aiToolSourceBrowse;

  /// No description provided for @aiToolLibraryQuery.
  ///
  /// In en, this message translates to:
  /// **'Query library'**
  String get aiToolLibraryQuery;

  /// No description provided for @aiToolMediaGet.
  ///
  /// In en, this message translates to:
  /// **'View media details'**
  String get aiToolMediaGet;

  /// No description provided for @aiToolSearchMedia.
  ///
  /// In en, this message translates to:
  /// **'Search media'**
  String get aiToolSearchMedia;

  /// No description provided for @aiToolProgressQuery.
  ///
  /// In en, this message translates to:
  /// **'View watch progress'**
  String get aiToolProgressQuery;

  /// No description provided for @aiToolPlaybackGet.
  ///
  /// In en, this message translates to:
  /// **'Read playback state'**
  String get aiToolPlaybackGet;

  /// No description provided for @aiToolPlaybackOpen.
  ///
  /// In en, this message translates to:
  /// **'Open playback'**
  String get aiToolPlaybackOpen;

  /// No description provided for @aiToolPlaybackPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get aiToolPlaybackPause;

  /// No description provided for @aiToolPlaybackResume.
  ///
  /// In en, this message translates to:
  /// **'Resume playback'**
  String get aiToolPlaybackResume;

  /// No description provided for @aiToolPlaybackStop.
  ///
  /// In en, this message translates to:
  /// **'Stop playback'**
  String get aiToolPlaybackStop;

  /// No description provided for @aiToolPlaybackSeek.
  ///
  /// In en, this message translates to:
  /// **'Seek'**
  String get aiToolPlaybackSeek;

  /// No description provided for @aiToolPlaybackSetSpeed.
  ///
  /// In en, this message translates to:
  /// **'Set speed'**
  String get aiToolPlaybackSetSpeed;

  /// No description provided for @aiToolPlaybackSetVolume.
  ///
  /// In en, this message translates to:
  /// **'Set volume'**
  String get aiToolPlaybackSetVolume;

  /// No description provided for @aiToolPlaybackSetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set subtitles'**
  String get aiToolPlaybackSetSubtitle;

  /// No description provided for @aiToolMediaProcessingCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Query media processing capabilities'**
  String get aiToolMediaProcessingCapabilities;

  /// No description provided for @aiToolMediaProbe.
  ///
  /// In en, this message translates to:
  /// **'Analyze media'**
  String get aiToolMediaProbe;

  /// No description provided for @aiToolMediaTranscode.
  ///
  /// In en, this message translates to:
  /// **'Transcode / clip'**
  String get aiToolMediaTranscode;

  /// No description provided for @aiToolMediaExtractAudio.
  ///
  /// In en, this message translates to:
  /// **'Extract audio'**
  String get aiToolMediaExtractAudio;

  /// No description provided for @aiToolMediaSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Snapshot'**
  String get aiToolMediaSnapshot;

  /// No description provided for @aiToolMediaSaveToSource.
  ///
  /// In en, this message translates to:
  /// **'Save back to source'**
  String get aiToolMediaSaveToSource;

  /// No description provided for @aiToolTaskGet.
  ///
  /// In en, this message translates to:
  /// **'Query processing task'**
  String get aiToolTaskGet;

  /// No description provided for @aiToolTaskList.
  ///
  /// In en, this message translates to:
  /// **'List processing tasks'**
  String get aiToolTaskList;

  /// No description provided for @aiToolTaskCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel processing task'**
  String get aiToolTaskCancel;

  /// No description provided for @aiToolTaskRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry processing task'**
  String get aiToolTaskRetry;

  /// No description provided for @aiToolSpeechRecognitionStatus.
  ///
  /// In en, this message translates to:
  /// **'Query speech recognition status'**
  String get aiToolSpeechRecognitionStatus;

  /// No description provided for @aiToolSubtitleGenerate.
  ///
  /// In en, this message translates to:
  /// **'Recognize subtitles'**
  String get aiToolSubtitleGenerate;

  /// No description provided for @aiToolTranscriptGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate transcript'**
  String get aiToolTranscriptGenerate;

  /// No description provided for @aiToolSubtitleTaskGet.
  ///
  /// In en, this message translates to:
  /// **'Query subtitle task'**
  String get aiToolSubtitleTaskGet;

  /// No description provided for @aiToolSubtitleTaskCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel subtitle task'**
  String get aiToolSubtitleTaskCancel;

  /// No description provided for @aiToolSubtitleSave.
  ///
  /// In en, this message translates to:
  /// **'Save subtitles'**
  String get aiToolSubtitleSave;

  /// No description provided for @aiToolPluginStatus.
  ///
  /// In en, this message translates to:
  /// **'View plugin status'**
  String get aiToolPluginStatus;

  /// No description provided for @aiToolMcpTavilyWebSearch.
  ///
  /// In en, this message translates to:
  /// **'Web search'**
  String get aiToolMcpTavilyWebSearch;

  /// No description provided for @aiToolWebFetch.
  ///
  /// In en, this message translates to:
  /// **'Read web page'**
  String get aiToolWebFetch;

  /// No description provided for @aiArgQuery.
  ///
  /// In en, this message translates to:
  /// **'Query'**
  String get aiArgQuery;

  /// No description provided for @aiArgUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get aiArgUrl;

  /// No description provided for @aiArgRange.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get aiArgRange;

  /// No description provided for @aiArgEnd.
  ///
  /// In en, this message translates to:
  /// **'end'**
  String get aiArgEnd;

  /// No description provided for @aiArgWholeMedia.
  ///
  /// In en, this message translates to:
  /// **'whole media'**
  String get aiArgWholeMedia;

  /// No description provided for @aiArgTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get aiArgTime;

  /// No description provided for @aiArgPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get aiArgPosition;

  /// No description provided for @aiArgPreset.
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get aiArgPreset;

  /// No description provided for @aiArgLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get aiArgLanguage;

  /// No description provided for @aiArgFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get aiArgFormat;

  /// No description provided for @aiArgSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get aiArgSpeed;

  /// No description provided for @aiArgVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get aiArgVolume;

  /// No description provided for @aiArgSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get aiArgSwitch;

  /// No description provided for @aiArgOff.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get aiArgOff;

  /// No description provided for @aiArgWait.
  ///
  /// In en, this message translates to:
  /// **'Wait'**
  String get aiArgWait;

  /// No description provided for @aiToolInput.
  ///
  /// In en, this message translates to:
  /// **'INPUT'**
  String get aiToolInput;

  /// No description provided for @aiToolOutput.
  ///
  /// In en, this message translates to:
  /// **'OUTPUT'**
  String get aiToolOutput;

  /// No description provided for @aiActivityThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get aiActivityThinking;

  /// No description provided for @aiActivityAnswering.
  ///
  /// In en, this message translates to:
  /// **'Replying'**
  String get aiActivityAnswering;

  /// No description provided for @aiActivityRunningDefault.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get aiActivityRunningDefault;

  /// No description provided for @aiReasoningStreaming.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get aiReasoningStreaming;

  /// No description provided for @aiReasoningDone.
  ///
  /// In en, this message translates to:
  /// **'Thought'**
  String get aiReasoningDone;

  /// No description provided for @aiReasoningUnderSecond.
  ///
  /// In en, this message translates to:
  /// **'Thought for less than a second'**
  String get aiReasoningUnderSecond;

  /// No description provided for @aiStillRunning.
  ///
  /// In en, this message translates to:
  /// **'Wait timed out; the task is still running in the background'**
  String get aiStillRunning;

  /// No description provided for @aiStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'queued'**
  String get aiStatusQueued;

  /// No description provided for @aiStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'preparing'**
  String get aiStatusPreparing;

  /// No description provided for @aiStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'running'**
  String get aiStatusRunning;

  /// No description provided for @aiStatusCancelling.
  ///
  /// In en, this message translates to:
  /// **'cancelling'**
  String get aiStatusCancelling;

  /// No description provided for @aiStatusSucceeded.
  ///
  /// In en, this message translates to:
  /// **'succeeded'**
  String get aiStatusSucceeded;

  /// No description provided for @aiStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get aiStatusFailed;

  /// No description provided for @aiStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'cancelled'**
  String get aiStatusCancelled;

  /// No description provided for @aiStatusInterrupted.
  ///
  /// In en, this message translates to:
  /// **'interrupted'**
  String get aiStatusInterrupted;

  /// No description provided for @aiStageExtracting.
  ///
  /// In en, this message translates to:
  /// **'extracting'**
  String get aiStageExtracting;

  /// No description provided for @aiStageUploading.
  ///
  /// In en, this message translates to:
  /// **'uploading'**
  String get aiStageUploading;

  /// No description provided for @aiStageQueued.
  ///
  /// In en, this message translates to:
  /// **'queued'**
  String get aiStageQueued;

  /// No description provided for @aiStageTranscribing.
  ///
  /// In en, this message translates to:
  /// **'transcribing'**
  String get aiStageTranscribing;

  /// No description provided for @aiStageFormatting.
  ///
  /// In en, this message translates to:
  /// **'formatting'**
  String get aiStageFormatting;

  /// No description provided for @aiArgWaitValue.
  ///
  /// In en, this message translates to:
  /// **'wait ≤{seconds}s'**
  String aiArgWaitValue(String seconds);

  /// No description provided for @aiStepPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing {name}...'**
  String aiStepPreparing(String name);

  /// No description provided for @aiStepRunning.
  ///
  /// In en, this message translates to:
  /// **'Executing {name}...'**
  String aiStepRunning(String name);

  /// No description provided for @aiStepWaiting.
  ///
  /// In en, this message translates to:
  /// **'Allow {name}?'**
  String aiStepWaiting(String name);

  /// No description provided for @aiStepFailed.
  ///
  /// In en, this message translates to:
  /// **'{name} failed'**
  String aiStepFailed(String name);

  /// No description provided for @aiStepCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled {name}'**
  String aiStepCancelled(String name);

  /// No description provided for @aiShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all ({count} characters)'**
  String aiShowAll(int count);

  /// No description provided for @aiActivityPreparingTool.
  ///
  /// In en, this message translates to:
  /// **'Preparing: {name}'**
  String aiActivityPreparingTool(String name);

  /// No description provided for @aiActivityTool.
  ///
  /// In en, this message translates to:
  /// **'Running: {name}'**
  String aiActivityTool(String name);

  /// No description provided for @aiActivityConfirm.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you: {name}'**
  String aiActivityConfirm(String name);

  /// No description provided for @aiStepNumber.
  ///
  /// In en, this message translates to:
  /// **'step {step}'**
  String aiStepNumber(int step);

  /// No description provided for @aiReasoningSeconds.
  ///
  /// In en, this message translates to:
  /// **'Thought for {seconds} seconds'**
  String aiReasoningSeconds(int seconds);

  /// No description provided for @aiReasoningMinutes.
  ///
  /// In en, this message translates to:
  /// **'Thought for {minutes, plural, =1{a minute} other{{minutes} minutes}}'**
  String aiReasoningMinutes(int minutes);

  /// No description provided for @cloudJianguoyun.
  ///
  /// In en, this message translates to:
  /// **'Jianguoyun'**
  String get cloudJianguoyun;

  /// No description provided for @cloud123.
  ///
  /// In en, this message translates to:
  /// **'123 Cloud Drive'**
  String get cloud123;

  /// No description provided for @cloudJianguoyunHelp.
  ///
  /// In en, this message translates to:
  /// **'Use your account and a third-party app password. The default WebDAV folder can be changed.'**
  String get cloudJianguoyunHelp;

  /// No description provided for @cloud123Help.
  ///
  /// In en, this message translates to:
  /// **'Enable WebDAV in your 123 account first. Enter the exact URL and credentials supplied by the official console; availability depends on your plan.'**
  String get cloud123Help;

  /// No description provided for @cloudPreset.
  ///
  /// In en, this message translates to:
  /// **'WebDAV preset'**
  String get cloudPreset;

  /// No description provided for @cloudCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom WebDAV'**
  String get cloudCustom;

  /// No description provided for @catSummaryCloudDrive.
  ///
  /// In en, this message translates to:
  /// **'Browse and play files in your cloud drive.'**
  String get catSummaryCloudDrive;

  /// No description provided for @cloudSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with browser'**
  String get cloudSignIn;

  /// No description provided for @cloudSignInHelp.
  ///
  /// In en, this message translates to:
  /// **'Read-only access. Choose the root folder below. To fully disconnect OneDrive, also remove this app in your Microsoft account permissions.'**
  String get cloudSignInHelp;

  /// No description provided for @cloudNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Cloud sign-in is unavailable in this build. The publisher must configure an OAuth application.'**
  String get cloudNotConfigured;

  /// No description provided for @cloudSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Cloud sign-in failed. Please try again.'**
  String get cloudSignInFailed;

  /// No description provided for @cloudCallbackInvalid.
  ///
  /// In en, this message translates to:
  /// **'The authorization callback could not be verified.'**
  String get cloudCallbackInvalid;

  /// No description provided for @cloudRoot.
  ///
  /// In en, this message translates to:
  /// **'Selected root folder'**
  String get cloudRoot;

  /// No description provided for @cloudRootHelp.
  ///
  /// In en, this message translates to:
  /// **'Open a folder to select it as the root. Only files below this folder will be browsed and scanned.'**
  String get cloudRootHelp;

  /// No description provided for @cloudReauthorize.
  ///
  /// In en, this message translates to:
  /// **'Authorization expired or was revoked. Please sign in again.'**
  String get cloudReauthorize;

  /// No description provided for @cloudPersonalOnly.
  ///
  /// In en, this message translates to:
  /// **'Only personal OneDrive accounts are supported.'**
  String get cloudPersonalOnly;

  /// No description provided for @cloudDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect account'**
  String get cloudDisconnect;

  /// No description provided for @cloudDisconnectHelp.
  ///
  /// In en, this message translates to:
  /// **'Clears local credentials and stops cloud requests. Also remove this app in your Microsoft or Dropbox account permissions to revoke the platform grant.'**
  String get cloudDisconnectHelp;

  /// No description provided for @plSwitchToLandscape.
  ///
  /// In en, this message translates to:
  /// **'Switch to landscape'**
  String get plSwitchToLandscape;

  /// No description provided for @plSwitchToPortrait.
  ///
  /// In en, this message translates to:
  /// **'Switch to portrait'**
  String get plSwitchToPortrait;

  /// No description provided for @followSystemOrientation.
  ///
  /// In en, this message translates to:
  /// **'Follow system orientation'**
  String get followSystemOrientation;

  /// No description provided for @aiUsePlatform.
  ///
  /// In en, this message translates to:
  /// **'Use platform default service'**
  String get aiUsePlatform;

  /// No description provided for @aiUsePlatformHint.
  ///
  /// In en, this message translates to:
  /// **'Ready to use. No API address, model, or key needed.'**
  String get aiUsePlatformHint;

  /// No description provided for @aiPlatformService.
  ///
  /// In en, this message translates to:
  /// **'Platform service'**
  String get aiPlatformService;

  /// No description provided for @aiPlatformPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your messages are sent to the platform AI service. Daily usage limits apply.'**
  String get aiPlatformPrivacy;

  /// No description provided for @aiCustomService.
  ///
  /// In en, this message translates to:
  /// **'Bring your own service'**
  String get aiCustomService;

  /// No description provided for @aiCustomServiceHint.
  ///
  /// In en, this message translates to:
  /// **'Turn off the default service to use your own API. Your settings are kept when switching.'**
  String get aiCustomServiceHint;

  /// No description provided for @detailVideoFile.
  ///
  /// In en, this message translates to:
  /// **'Video file'**
  String get detailVideoFile;

  /// No description provided for @detailNoCatalogInfo.
  ///
  /// In en, this message translates to:
  /// **'No movie or TV details yet. This video can be played directly.'**
  String get detailNoCatalogInfo;

  /// No description provided for @detailPlaybackProgress.
  ///
  /// In en, this message translates to:
  /// **'Playback progress'**
  String get detailPlaybackProgress;

  /// No description provided for @detailFiles.
  ///
  /// In en, this message translates to:
  /// **'Video files'**
  String get detailFiles;

  /// No description provided for @baiduPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Baidu Netdisk denied playback or file access. Check this account’s permissions, download entitlement and the app’s approved access.'**
  String get baiduPermissionDenied;

  /// No description provided for @baiduAllFiles.
  ///
  /// In en, this message translates to:
  /// **'Select all files'**
  String get baiduAllFiles;

  /// No description provided for @voiceSettings.
  ///
  /// In en, this message translates to:
  /// **'Voice transcription'**
  String get voiceSettings;

  /// No description provided for @voiceSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Independent OpenAI transcription endpoint, model and API key. Audio is sent to this service only after you stop recording. Stop to insert the text for review, or use send to transcribe and send it right away. Android, iOS, macOS and Windows support recording; other platforms are currently unsupported.'**
  String get voiceSettingsHint;

  /// No description provided for @voiceSettingsError.
  ///
  /// In en, this message translates to:
  /// **'Check the transcription address, model and API key in settings. The key must be saved in secure local storage.'**
  String get voiceSettingsError;

  /// No description provided for @voiceStart.
  ///
  /// In en, this message translates to:
  /// **'Start voice input'**
  String get voiceStart;

  /// No description provided for @voiceStop.
  ///
  /// In en, this message translates to:
  /// **'Stop and transcribe'**
  String get voiceStop;

  /// No description provided for @voiceSend.
  ///
  /// In en, this message translates to:
  /// **'Transcribe and send'**
  String get voiceSend;

  /// No description provided for @voiceRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording… Click stop to transcribe, or cancel to discard.'**
  String get voiceRecording;

  /// No description provided for @voiceTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing…'**
  String get voiceTranscribing;

  /// No description provided for @voicePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing microphone…'**
  String get voicePreparing;

  /// No description provided for @voiceUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Voice recording is not supported on this platform or device.'**
  String get voiceUnsupported;

  /// No description provided for @voicePermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied. Allow microphone access in system settings and try again.'**
  String get voicePermission;

  /// No description provided for @voiceEmpty.
  ///
  /// In en, this message translates to:
  /// **'No speech was recognized. Please try again.'**
  String get voiceEmpty;

  /// No description provided for @voiceTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The recording is too large. Please record a shorter message.'**
  String get voiceTooLarge;

  /// No description provided for @voiceRecordingError.
  ///
  /// In en, this message translates to:
  /// **'Could not record audio. Check your microphone and try again.'**
  String get voiceRecordingError;

  /// No description provided for @voiceTranscriptionError.
  ///
  /// In en, this message translates to:
  /// **'Transcription failed. Check your network and transcription settings, then try again.'**
  String get voiceTranscriptionError;

  /// No description provided for @addVideo.
  ///
  /// In en, this message translates to:
  /// **'Add videos'**
  String get addVideo;

  /// No description provided for @addAndShowHome.
  ///
  /// In en, this message translates to:
  /// **'Add and show on Home'**
  String get addAndShowHome;

  /// No description provided for @homeScanScope.
  ///
  /// In en, this message translates to:
  /// **'Video folder or library'**
  String get homeScanScope;

  /// No description provided for @homeScanScopeHelp.
  ///
  /// In en, this message translates to:
  /// **'Videos in this scope and its subfolders will appear on Home. Choose a share, bucket or library next if needed.'**
  String get homeScanScopeHelp;

  /// No description provided for @homeSavedConnections.
  ///
  /// In en, this message translates to:
  /// **'Saved connections'**
  String get homeSavedConnections;

  /// No description provided for @homeBindingFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection saved, but videos have not been added to Home. Retry here or choose the saved connection from Add videos.'**
  String get homeBindingFailed;

  /// No description provided for @homeFindingVideos.
  ///
  /// In en, this message translates to:
  /// **'Finding videos · {count} found'**
  String homeFindingVideos(int count);

  /// No description provided for @homeScanInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Scan interrupted. Videos already found are available.'**
  String get homeScanInterrupted;

  /// No description provided for @homeNoVideos.
  ///
  /// In en, this message translates to:
  /// **'No videos found in this scope.'**
  String get homeNoVideos;

  /// No description provided for @homeAdjustScope.
  ///
  /// In en, this message translates to:
  /// **'Choose another folder'**
  String get homeAdjustScope;

  /// No description provided for @remotePlatformTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform default'**
  String get remotePlatformTitle;

  /// No description provided for @remotePlatformHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in to load platform Relay nodes and services granted to this device.'**
  String get remotePlatformHint;

  /// No description provided for @remotePlatformLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get remotePlatformLogin;

  /// No description provided for @remotePlatformLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get remotePlatformLogout;

  /// No description provided for @remotePlatformRestore.
  ///
  /// In en, this message translates to:
  /// **'Use platform default'**
  String get remotePlatformRestore;

  /// No description provided for @remotePlatformActive.
  ///
  /// In en, this message translates to:
  /// **'Using platform configuration'**
  String get remotePlatformActive;

  /// No description provided for @remoteCustomActive.
  ///
  /// In en, this message translates to:
  /// **'Using custom configuration'**
  String get remoteCustomActive;

  /// No description provided for @remotePlatformEmail.
  ///
  /// In en, this message translates to:
  /// **'Account email'**
  String get remotePlatformEmail;

  /// No description provided for @remotePlatformAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Chosen automatically by your Connector'**
  String get remotePlatformAutomatic;

  /// No description provided for @remotePlatformNode.
  ///
  /// In en, this message translates to:
  /// **'Relay node'**
  String get remotePlatformNode;

  /// No description provided for @remotePlatformEmpty.
  ///
  /// In en, this message translates to:
  /// **'No ready platform nodes. Refresh after an administrator enables a node.'**
  String get remotePlatformEmpty;

  /// No description provided for @remotePlatformNoServices.
  ///
  /// In en, this message translates to:
  /// **'No services are granted to this device yet.'**
  String get remotePlatformNoServices;

  /// No description provided for @remotePlatformExpired.
  ///
  /// In en, this message translates to:
  /// **'Platform configuration needs refreshing. The last configuration remains in use.'**
  String get remotePlatformExpired;

  /// No description provided for @remotePlatformRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Platform request failed: {code}'**
  String remotePlatformRequestFailed(String code);

  /// No description provided for @remotePlatformNodeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your Connector to report its node'**
  String get remotePlatformNodeUnavailable;

  /// No description provided for @remoteNodeTest.
  ///
  /// In en, this message translates to:
  /// **'Test nodes'**
  String get remoteNodeTest;

  /// No description provided for @remoteNodeTestHint.
  ///
  /// In en, this message translates to:
  /// **'Tests TCP/TLS reachability from this device only, not Home service availability. The node is chosen by your Connector and followed automatically.'**
  String get remoteNodeTestHint;

  /// No description provided for @remoteNodeUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get remoteNodeUnreachable;

  /// No description provided for @remoteNodeLatency.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String remoteNodeLatency(int ms);

  /// No description provided for @remotePlatformNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Platform configuration has not loaded. Refresh to try again.'**
  String get remotePlatformNotLoaded;

  /// No description provided for @remotePlatformRegister.
  ///
  /// In en, this message translates to:
  /// **'Register platform account'**
  String get remotePlatformRegister;

  /// No description provided for @remotePlatformRegisterHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email. We\'ll send a 6-digit verification code to finish registering here.'**
  String get remotePlatformRegisterHint;

  /// No description provided for @remotePlatformSendRegistration.
  ///
  /// In en, this message translates to:
  /// **'Send verification code'**
  String get remotePlatformSendRegistration;

  /// No description provided for @remotePlatformRegistrationSent.
  ///
  /// In en, this message translates to:
  /// **'If this email can be registered, a verification code has been sent. Check your inbox and spam folder.'**
  String get remotePlatformRegistrationSent;

  /// No description provided for @remotePlatformCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {email} and set a password. The code expires in 30 minutes.'**
  String remotePlatformCodeSentTo(String email);

  /// No description provided for @remotePlatformCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get remotePlatformCode;

  /// No description provided for @remotePlatformNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Password (at least 12 characters)'**
  String get remotePlatformNewPassword;

  /// No description provided for @remotePlatformConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get remotePlatformConfirmPassword;

  /// No description provided for @remotePlatformCompleteRegistration.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get remotePlatformCompleteRegistration;

  /// No description provided for @remotePlatformResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get remotePlatformResendCode;

  /// No description provided for @remotePlatformResendCodeIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String remotePlatformResendCodeIn(int seconds);

  /// No description provided for @remotePlatformChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get remotePlatformChangeEmail;

  /// No description provided for @remotePlatformInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'The verification code is incorrect.'**
  String get remotePlatformInvalidCode;

  /// No description provided for @remotePlatformCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired or had too many wrong attempts. Send a new code.'**
  String get remotePlatformCodeExpired;

  /// No description provided for @remotePlatformPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 12 characters.'**
  String get remotePlatformPasswordTooShort;

  /// No description provided for @remotePlatformPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get remotePlatformPasswordMismatch;

  /// No description provided for @remotePlatformRegistered.
  ///
  /// In en, this message translates to:
  /// **'Account created. Sign in with your new password.'**
  String get remotePlatformRegistered;

  /// No description provided for @remotePlatformInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get remotePlatformInvalidEmail;

  /// No description provided for @remoteTabCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get remoteTabCloud;

  /// No description provided for @remoteTabLocal.
  ///
  /// In en, this message translates to:
  /// **'Local import'**
  String get remoteTabLocal;

  /// No description provided for @remoteModeActive.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get remoteModeActive;

  /// No description provided for @remoteModeInactive.
  ///
  /// In en, this message translates to:
  /// **'Not in use'**
  String get remoteModeInactive;

  /// No description provided for @remoteCloudInactiveHint.
  ///
  /// In en, this message translates to:
  /// **'The local import is in use. Enable the cloud configuration to switch; the local import then stops working.'**
  String get remoteCloudInactiveHint;

  /// No description provided for @remoteLocalInactiveHint.
  ///
  /// In en, this message translates to:
  /// **'The cloud configuration is in use. Enable the local import to switch; the cloud configuration then stops working.'**
  String get remoteLocalInactiveHint;

  /// No description provided for @remoteLocalEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Import a configuration exported by Relay. Importing switches to it right away and the cloud configuration stops working.'**
  String get remoteLocalEmptyHint;

  /// No description provided for @remoteEnableCloud.
  ///
  /// In en, this message translates to:
  /// **'Enable cloud configuration'**
  String get remoteEnableCloud;

  /// No description provided for @remoteEnableLocal.
  ///
  /// In en, this message translates to:
  /// **'Enable local import'**
  String get remoteEnableLocal;

  /// No description provided for @remoteEnableCloudConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to the cloud configuration?'**
  String get remoteEnableCloudConfirmTitle;

  /// No description provided for @remoteEnableCloudConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'The local import will stop working. It stays saved on this device, so you can switch back at any time.'**
  String get remoteEnableCloudConfirmMessage;

  /// No description provided for @remoteEnableLocalConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to the local import?'**
  String get remoteEnableLocalConfirmTitle;

  /// No description provided for @remoteEnableLocalConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'The cloud configuration will stop working. Your account stays signed in, so you can switch back at any time.'**
  String get remoteEnableLocalConfirmMessage;

  /// No description provided for @remoteImportReplaceCloudTitle.
  ///
  /// In en, this message translates to:
  /// **'Import and switch to it?'**
  String get remoteImportReplaceCloudTitle;

  /// No description provided for @remoteImportReplaceCloudMessage.
  ///
  /// In en, this message translates to:
  /// **'The imported configuration takes effect right away and the cloud configuration stops working. You can switch back on the Cloud tab.'**
  String get remoteImportReplaceCloudMessage;

  /// No description provided for @remoteClearActiveMessage.
  ///
  /// In en, this message translates to:
  /// **'Removes the local import and its credentials from this device. Remote access switches to the cloud configuration.'**
  String get remoteClearActiveMessage;

  /// No description provided for @remoteSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched.'**
  String get remoteSwitched;

  /// No description provided for @remoteSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get remoteSwitch;

  /// No description provided for @tmdbCloudHint.
  ///
  /// In en, this message translates to:
  /// **'Use OpenPlayX cloud to look up movies and shows without a TMDB token. Titles, years, IDs and language are sent through OpenPlayX to TMDB; videos and private paths stay on this device.'**
  String get tmdbCloudHint;

  /// No description provided for @tmdbLocalHint.
  ///
  /// In en, this message translates to:
  /// **'Connect directly to TMDB using your own read access token. The token is saved on this device.'**
  String get tmdbLocalHint;

  /// No description provided for @voiceCloudHint.
  ///
  /// In en, this message translates to:
  /// **'Use OpenPlayX cloud transcription without an API key. Recorded audio is sent through OpenPlayX to OpenAI to turn it into text.'**
  String get voiceCloudHint;

  /// No description provided for @voiceConnectionOk.
  ///
  /// In en, this message translates to:
  /// **'Connected. The transcription service accepted the test audio.'**
  String get voiceConnectionOk;

  /// No description provided for @voiceConnectionTimeout.
  ///
  /// In en, this message translates to:
  /// **'The connection test timed out. Check the endpoint and network, then try again.'**
  String get voiceConnectionTimeout;

  /// No description provided for @voiceConnectionTestHint.
  ///
  /// In en, this message translates to:
  /// **'Test connection sends one second of generated silence to this service using the current configuration. It does not use the microphone or save changes.'**
  String get voiceConnectionTestHint;

  /// No description provided for @llmModelSettings.
  ///
  /// In en, this message translates to:
  /// **'LLM Model'**
  String get llmModelSettings;

  /// No description provided for @whisperModelSettings.
  ///
  /// In en, this message translates to:
  /// **'Whisper Model'**
  String get whisperModelSettings;

  /// No description provided for @settingsPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get settingsPlayer;

  /// No description provided for @settingsSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get settingsSubtitles;

  /// No description provided for @connectorSources.
  ///
  /// In en, this message translates to:
  /// **'From Connector'**
  String get connectorSources;

  /// No description provided for @connectorSourceDiscovered.
  ///
  /// In en, this message translates to:
  /// **'Discovered automatically. Sign in to choose a folder.'**
  String get connectorSourceDiscovered;

  /// No description provided for @connectorSourceLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in and connect'**
  String get connectorSourceLogin;

  /// No description provided for @connectorSourceSetup.
  ///
  /// In en, this message translates to:
  /// **'Connect service'**
  String get connectorSourceSetup;

  /// No description provided for @connectorSourceManaged.
  ///
  /// In en, this message translates to:
  /// **'Service settings are managed by Connector. Login and folders stay on this device.'**
  String get connectorSourceManaged;

  /// No description provided for @connectorSourceHide.
  ///
  /// In en, this message translates to:
  /// **'Hide on this device'**
  String get connectorSourceHide;

  /// No description provided for @connectorSourceHideHelp.
  ///
  /// In en, this message translates to:
  /// **'This hides the source from this list. Login and folders are kept, and existing home content remains available. Disable the connection to stop using it.'**
  String get connectorSourceHideHelp;

  /// No description provided for @connectorSourcesHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden sources'**
  String get connectorSourcesHidden;

  /// No description provided for @connectorSourceRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get connectorSourceRestore;

  /// No description provided for @connectorSourceNoneHidden.
  ///
  /// In en, this message translates to:
  /// **'No hidden sources'**
  String get connectorSourceNoneHidden;

  /// No description provided for @connectorSourceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Service disabled'**
  String get connectorSourceDisabled;

  /// No description provided for @connectorSourceRemoved.
  ///
  /// In en, this message translates to:
  /// **'Service removed'**
  String get connectorSourceRemoved;

  /// No description provided for @connectorSourceSync.
  ///
  /// In en, this message translates to:
  /// **'Sync sources'**
  String get connectorSourceSync;

  /// No description provided for @connectorSourceSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sync. Your last successful source list is retained.'**
  String get connectorSourceSyncFailed;

  /// No description provided for @connectorSourceConnectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Connection settings'**
  String get connectorSourceConnectionSettings;

  /// No description provided for @connectorSourceLoginHelp.
  ///
  /// In en, this message translates to:
  /// **'Use the media server account. Leave both fields empty for guest access when supported.'**
  String get connectorSourceLoginHelp;

  /// No description provided for @connectorSourceRemoteOnlyHelp.
  ///
  /// In en, this message translates to:
  /// **'This service currently uses remote access. SMB LAN switching requires a supported secure local transport.'**
  String get connectorSourceRemoteOnlyHelp;

  /// No description provided for @connectorSourcePending.
  ///
  /// In en, this message translates to:
  /// **'Not connected yet'**
  String get connectorSourcePending;

  /// No description provided for @connectorSourceLan.
  ///
  /// In en, this message translates to:
  /// **'LAN connection'**
  String get connectorSourceLan;

  /// No description provided for @connectorSourceRemote.
  ///
  /// In en, this message translates to:
  /// **'Remote connection'**
  String get connectorSourceRemote;

  /// No description provided for @connectorSourceLoginDiscover.
  ///
  /// In en, this message translates to:
  /// **'Sign in to discover sources'**
  String get connectorSourceLoginDiscover;

  /// No description provided for @connectorSourceDetails.
  ///
  /// In en, this message translates to:
  /// **'Service details'**
  String get connectorSourceDetails;

  /// No description provided for @connectorSourceAccount.
  ///
  /// In en, this message translates to:
  /// **'Account verification required'**
  String get connectorSourceAccount;

  /// No description provided for @connectorSourceProtocolChanged.
  ///
  /// In en, this message translates to:
  /// **'Service type changed. Set up the connection again.'**
  String get connectorSourceProtocolChanged;

  /// No description provided for @connectorSourceNotReady.
  ///
  /// In en, this message translates to:
  /// **'Connector has not reported an available route yet.'**
  String get connectorSourceNotReady;

  /// No description provided for @connectorSourceClearLocal.
  ///
  /// In en, this message translates to:
  /// **'Clear device configuration'**
  String get connectorSourceClearLocal;

  /// No description provided for @connectorSourceClearLocalHelp.
  ///
  /// In en, this message translates to:
  /// **'Only this device’s login and folder configuration is cleared. The Connector service remains published. This source will be hidden; restore it to set it up again.'**
  String get connectorSourceClearLocalHelp;

  /// No description provided for @asrPlatform.
  ///
  /// In en, this message translates to:
  /// **'Groq (free, default)'**
  String get asrPlatform;

  /// No description provided for @asrPlatformHint.
  ///
  /// In en, this message translates to:
  /// **'No setup or sign-in. Selected audio is uploaded through OpenPlayX to Groq V3. Availability is subject to service limits.'**
  String get asrPlatformHint;

  /// No description provided for @asrLocal.
  ///
  /// In en, this message translates to:
  /// **'Local model download'**
  String get asrLocal;

  /// No description provided for @asrCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom API'**
  String get asrCustom;

  /// No description provided for @asrCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Use your own OpenAI-compatible API or OpenPlayX ASR service.'**
  String get asrCustomHint;

  /// No description provided for @asrProtocol.
  ///
  /// In en, this message translates to:
  /// **'API protocol'**
  String get asrProtocol;

  /// No description provided for @asrGenerateWhole.
  ///
  /// In en, this message translates to:
  /// **'Generate full subtitles'**
  String get asrGenerateWhole;

  /// No description provided for @asrChunkProgress.
  ///
  /// In en, this message translates to:
  /// **'Completed {done} of {total}; completed chunks are reused on retry.'**
  String asrChunkProgress(String done, String total);

  /// No description provided for @asrBusyRetry.
  ///
  /// In en, this message translates to:
  /// **'Service is busy. Retry to continue from completed chunks.'**
  String get asrBusyRetry;

  /// No description provided for @asrPlatformUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Platform allowance reached. Retry later or choose another service.'**
  String get asrPlatformUnavailable;

  /// No description provided for @plPictureInPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture in picture'**
  String get plPictureInPicture;

  /// No description provided for @plExitPictureInPicture.
  ///
  /// In en, this message translates to:
  /// **'Exit picture in picture'**
  String get plExitPictureInPicture;

  /// No description provided for @plPictureInPictureFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to enter picture in picture. Please try again.'**
  String get plPictureInPictureFailed;

  /// No description provided for @alignTitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle alignment'**
  String get alignTitle;

  /// No description provided for @alignAuto.
  ///
  /// In en, this message translates to:
  /// **'Reference alignment'**
  String get alignAuto;

  /// No description provided for @alignManual.
  ///
  /// In en, this message translates to:
  /// **'Manual offset'**
  String get alignManual;

  /// No description provided for @alignHistory.
  ///
  /// In en, this message translates to:
  /// **'Alignment history'**
  String get alignHistory;

  /// No description provided for @alignIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose an SRT reference already synchronized to this video, in the same dialogue language. Processing stays on this device.'**
  String get alignIntro;

  /// No description provided for @alignSource.
  ///
  /// In en, this message translates to:
  /// **'Current subtitle'**
  String get alignSource;

  /// No description provided for @alignReference.
  ///
  /// In en, this message translates to:
  /// **'Choose reference SRT'**
  String get alignReference;

  /// No description provided for @alignStart.
  ///
  /// In en, this message translates to:
  /// **'Start alignment'**
  String get alignStart;

  /// No description provided for @alignReading.
  ///
  /// In en, this message translates to:
  /// **'Reading subtitle files…'**
  String get alignReading;

  /// No description provided for @alignMatching.
  ///
  /// In en, this message translates to:
  /// **'Matching dialogue and validating timing…'**
  String get alignMatching;

  /// No description provided for @alignResult.
  ///
  /// In en, this message translates to:
  /// **'Alignment ready to preview'**
  String get alignResult;

  /// No description provided for @alignReview.
  ///
  /// In en, this message translates to:
  /// **'More evidence needed'**
  String get alignReview;

  /// No description provided for @alignReviewHelp.
  ///
  /// In en, this message translates to:
  /// **'This result cannot be applied safely. Check the reference version and language, or adjust the delay manually. No subtitle was changed.'**
  String get alignReviewHelp;

  /// No description provided for @alignApply.
  ///
  /// In en, this message translates to:
  /// **'Apply aligned copy'**
  String get alignApply;

  /// No description provided for @alignPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview in player'**
  String get alignPreview;

  /// No description provided for @alignOriginal.
  ///
  /// In en, this message translates to:
  /// **'Return to original'**
  String get alignOriginal;

  /// No description provided for @alignApplied.
  ///
  /// In en, this message translates to:
  /// **'Aligned subtitle applied'**
  String get alignApplied;

  /// No description provided for @alignPreviewing.
  ///
  /// In en, this message translates to:
  /// **'Previewing aligned subtitle'**
  String get alignPreviewing;

  /// No description provided for @alignRetained.
  ///
  /// In en, this message translates to:
  /// **'The original is retained. You can undo this change.'**
  String get alignRetained;

  /// No description provided for @alignCoverage.
  ///
  /// In en, this message translates to:
  /// **'Matched dialogue'**
  String get alignCoverage;

  /// No description provided for @alignError.
  ///
  /// In en, this message translates to:
  /// **'Held-out anchor P95'**
  String get alignError;

  /// No description provided for @alignScale.
  ///
  /// In en, this message translates to:
  /// **'Timeline scale'**
  String get alignScale;

  /// No description provided for @alignOffset.
  ///
  /// In en, this message translates to:
  /// **'Timeline offset'**
  String get alignOffset;

  /// No description provided for @alignInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid mapped cues'**
  String get alignInvalid;

  /// No description provided for @alignEvidence.
  ///
  /// In en, this message translates to:
  /// **'Metrics measure agreement with the reference, not a probability of correctness. Only fixed and linear corrections are supported.'**
  String get alignEvidence;

  /// No description provided for @alignChooseFiles.
  ///
  /// In en, this message translates to:
  /// **'Select a local SRT subtitle and a different reference SRT first.'**
  String get alignChooseFiles;

  /// No description provided for @alignInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Not enough unique matching dialogue. Choose a reference in the same language and version.'**
  String get alignInsufficient;

  /// No description provided for @alignReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read or process these subtitles. Use valid UTF-8 SRT files up to 4 MB and 12,000 cues.'**
  String get alignReadFailed;

  /// No description provided for @alignApplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch subtitles. Check the current track and retry.'**
  String get alignApplyFailed;

  /// No description provided for @alignSourceChanged.
  ///
  /// In en, this message translates to:
  /// **'The selected subtitle changed. Restore it or run alignment again.'**
  String get alignSourceChanged;

  /// No description provided for @alignDelayHelp.
  ///
  /// In en, this message translates to:
  /// **'Positive values delay subtitles; negative values show them earlier. This changes playback only.'**
  String get alignDelayHelp;

  /// No description provided for @alignHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No alignment has been applied in this playback session.'**
  String get alignHistoryEmpty;

  /// No description provided for @alignHistorySession.
  ///
  /// In en, this message translates to:
  /// **'History is for this playback session. Generated copies are retained in application storage.'**
  String get alignHistorySession;

  /// No description provided for @alignCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse and continue watching'**
  String get alignCollapse;

  /// No description provided for @alignPreviewAnchor.
  ///
  /// In en, this message translates to:
  /// **'Preview validation anchor'**
  String get alignPreviewAnchor;

  /// No description provided for @alignReset.
  ///
  /// In en, this message translates to:
  /// **'Reset offset'**
  String get alignReset;

  /// No description provided for @alignReferenceSaved.
  ///
  /// In en, this message translates to:
  /// **'Use saved speech-recognition subtitle'**
  String get alignReferenceSaved;

  /// No description provided for @alignNoSource.
  ///
  /// In en, this message translates to:
  /// **'Choose an external or saved SRT subtitle to align. Embedded and image subtitles are not supported here.'**
  String get alignNoSource;

  /// No description provided for @webPlaybackTitle.
  ///
  /// In en, this message translates to:
  /// **'Web playback'**
  String get webPlaybackTitle;

  /// No description provided for @webPlaybackDescription.
  ///
  /// In en, this message translates to:
  /// **'Watch shared media in a browser on your local network.'**
  String get webPlaybackDescription;

  /// No description provided for @webPlaybackEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable Web playback'**
  String get webPlaybackEnabled;

  /// No description provided for @webPlaybackInterface.
  ///
  /// In en, this message translates to:
  /// **'Network interface'**
  String get webPlaybackInterface;

  /// No description provided for @webPlaybackNoNetwork.
  ///
  /// In en, this message translates to:
  /// **'No private IPv4 interface found. Connect to a local network and retry.'**
  String get webPlaybackNoNetwork;

  /// No description provided for @webPlaybackAddress.
  ///
  /// In en, this message translates to:
  /// **'Browser address'**
  String get webPlaybackAddress;

  /// No description provided for @webPlaybackPreview.
  ///
  /// In en, this message translates to:
  /// **'Open browser'**
  String get webPlaybackPreview;

  /// No description provided for @webPlaybackPairing.
  ///
  /// In en, this message translates to:
  /// **'Connect a device'**
  String get webPlaybackPairing;

  /// No description provided for @webPlaybackCode.
  ///
  /// In en, this message translates to:
  /// **'Pairing code'**
  String get webPlaybackCode;

  /// No description provided for @webPlaybackCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'Open the address on another device and enter this code. Valid for 5 minutes.'**
  String get webPlaybackCodeHelp;

  /// No description provided for @webPlaybackRefreshCode.
  ///
  /// In en, this message translates to:
  /// **'New pairing code'**
  String get webPlaybackRefreshCode;

  /// No description provided for @webPlaybackExpired.
  ///
  /// In en, this message translates to:
  /// **'Code expired. Generate a new code to pair a device.'**
  String get webPlaybackExpired;

  /// No description provided for @webPlaybackShare.
  ///
  /// In en, this message translates to:
  /// **'Shared folders'**
  String get webPlaybackShare;

  /// No description provided for @webPlaybackShareHelp.
  ///
  /// In en, this message translates to:
  /// **'Only selected, enabled library folders are shared. Changing this also ends playback of removed media.'**
  String get webPlaybackShareHelp;

  /// No description provided for @webPlaybackNoScopes.
  ///
  /// In en, this message translates to:
  /// **'Add a folder to your library and scan it before sharing.'**
  String get webPlaybackNoScopes;

  /// No description provided for @webPlaybackSessions.
  ///
  /// In en, this message translates to:
  /// **'Now watching'**
  String get webPlaybackSessions;

  /// No description provided for @webPlaybackNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No devices are currently watching.'**
  String get webPlaybackNoSessions;

  /// No description provided for @webPlaybackEndSession.
  ///
  /// In en, this message translates to:
  /// **'End session'**
  String get webPlaybackEndSession;

  /// No description provided for @webPlaybackDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct Play · Original quality'**
  String get webPlaybackDirect;

  /// No description provided for @webPlaybackKeepOpen.
  ///
  /// In en, this message translates to:
  /// **'Keep OpenPlayX running. This version supports Direct Play only; format compatibility depends on the browser.'**
  String get webPlaybackKeepOpen;

  /// No description provided for @webPlaybackHttpNotice.
  ///
  /// In en, this message translates to:
  /// **'Use on a trusted local network. HTTP traffic is not encrypted. Stopping the service disconnects all devices.'**
  String get webPlaybackHttpNotice;

  /// No description provided for @webPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to update the service. Check the network interface and whether port 8090 is available.'**
  String get webPlaybackFailed;

  /// No description provided for @webPlaybackCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get webPlaybackCopied;

  /// No description provided for @webPlaybackStopped.
  ///
  /// In en, this message translates to:
  /// **'Service is off'**
  String get webPlaybackStopped;

  /// No description provided for @tvViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get tvViewDetails;

  /// No description provided for @tvSeekHint.
  ///
  /// In en, this message translates to:
  /// **'Left / right to preview · Confirm to seek · Back to cancel'**
  String get tvSeekHint;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
