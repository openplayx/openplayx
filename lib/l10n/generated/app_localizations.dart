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

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

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

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// No description provided for @unfavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove favorite'**
  String get unfavorite;

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

  /// No description provided for @recentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get recentlyPlayed;

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
  /// **'Separate with commas. Only matching files appear in preview and are added to the library. Leave blank to keep every file. Hidden files starting with a dot are always skipped.'**
  String get scanExtensionsHelp;

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

  /// No description provided for @sourcesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add a local folder, SMB, Jellyfin or Plex source.'**
  String get sourcesEmpty;

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
  /// **'This binding links {count} items. Remove automatic memberships only when no source evidence remains. Manual memberships, shared media and files are kept.'**
  String removeBindingDescription(int count);

  /// No description provided for @sourceVersion.
  ///
  /// In en, this message translates to:
  /// **'{kind} · Plugin {plugin} · Config v{config} · r{revision}'**
  String sourceVersion(String kind, String plugin, int config, int revision);

  /// No description provided for @disableSourceDescription.
  ///
  /// In en, this message translates to:
  /// **'{playing} playing, {running} requests. New requests will be rejected. Current playback can finish. Configuration and favorites are kept.'**
  String disableSourceDescription(int playing, int running);

  /// No description provided for @deleteSourceDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove this source configuration and credential reference. Files and favorites are kept. {playing} playing items and {running} requests can finish before connections are released.'**
  String deleteSourceDescription(int playing, int running);

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
  /// **'Read {speed} MB/s'**
  String readSpeed(String speed);

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

  /// No description provided for @metadataAttribution.
  ///
  /// In en, this message translates to:
  /// **'This product uses the TMDB API but is not endorsed or certified by TMDB.'**
  String get metadataAttribution;

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
  /// **'AI assistant'**
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
  /// **'Any OpenAI-compatible API, e.g. DeepSeek. The key is stored in the system keychain.'**
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

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Send diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsDescription.
  ///
  /// In en, this message translates to:
  /// **'Optional error reports to the configured Sentry service: app version and sanitized error stacks. No media paths, credentials or chat content. Enabling takes effect after restart; disabling stops new reports in all windows and background tasks. Native crashes are not collected yet.'**
  String get diagnosticsDescription;

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

  /// No description provided for @removeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFavorite;

  /// No description provided for @aiMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get aiMore;

  /// No description provided for @aiGreeting.
  ///
  /// In en, this message translates to:
  /// **'What can I help with?'**
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
  /// **'Process the whole episode?'**
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
  /// **'Service URL (https://…)'**
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
