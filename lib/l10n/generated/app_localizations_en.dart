// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get home => 'Home';

  @override
  String get library => 'Library';

  @override
  String get sources => 'Sources';

  @override
  String get settings => 'Settings';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeMode => 'Theme';

  @override
  String get themeDescription => 'Apply now and restore on launch';

  @override
  String get language => 'Language';

  @override
  String get preferenceSaveFailed => 'Could not save preferences';

  @override
  String get preferenceSaveRetry =>
      'Your choice is active. Select it again to retry saving.';

  @override
  String get sourceDefaults => 'Source defaults';

  @override
  String get sourceDefaultsDescription =>
      'Manage default sources for browsing, search and scans';

  @override
  String get manage => 'Manage';

  @override
  String get about => 'About OpenPlayX';

  @override
  String get aboutDescription => 'Your media. A quieter place to play.';

  @override
  String get favorite => 'Favorite';

  @override
  String get unfavorite => 'Remove favorite';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get remove => 'Remove';

  @override
  String get close => 'Close';

  @override
  String get openFile => 'Open file';

  @override
  String get welcome => 'Welcome to OpenPlayX';

  @override
  String get welcomeDescription =>
      'Pick up where you left off, or explore your library.';

  @override
  String get continueWatching => 'Continue watching';

  @override
  String get continueEmpty =>
      'Unfinished videos will appear here after you start watching.';

  @override
  String get recentlyPlayed => 'Recently played';

  @override
  String get recentEmpty =>
      'No playback history yet. Choose a video from your library or sources.';

  @override
  String get rewatch => 'Finished · Play again';

  @override
  String get libraryOpenFailed => 'Could not open the library. Try again.';

  @override
  String get platformUnsupported => 'Playback is unavailable on this platform.';

  @override
  String get historyUnavailable =>
      'This history item\'s resource is unavailable.';

  @override
  String get fileUnavailable => 'File unavailable';

  @override
  String get historyOpenFailed =>
      'Could not open this item. Check the file or source connection.';

  @override
  String get libraryLoadFailed =>
      'Could not open the library. Go back and try again.';

  @override
  String get createLibrary => 'Create library';

  @override
  String get contentType => 'Content type';

  @override
  String get mixed => 'Mixed';

  @override
  String get movie => 'Movies';

  @override
  String get series => 'Series';

  @override
  String get homeVideos => 'Home videos';

  @override
  String get audio => 'Audio';

  @override
  String get chooseScopeSource => 'Choose a source to scan';

  @override
  String get addEnabledSource => 'Add and enable a source first.';

  @override
  String get bindFailed =>
      'Could not add the source. Check the connection and retry.';

  @override
  String get scanFailedRetained =>
      'Scan failed. Indexed media is retained; you can retry.';

  @override
  String get localUnavailable => 'Local file unavailable';

  @override
  String get watchedSuffix => ' · Finished';

  @override
  String get missingOnScan => 'Not found in scan; may be unavailable';

  @override
  String get verifyOnPlay => 'Availability checked on playback';

  @override
  String get chooseVersion =>
      'Choose a version. Each version keeps its own playback timeline.';

  @override
  String get season => 'Season';

  @override
  String get episode => 'Episode';

  @override
  String get media => 'Media';

  @override
  String get previousPage => 'Previous';

  @override
  String get nextPage => 'Next';

  @override
  String get versionOpenFailed =>
      'Could not open this version. Check its source or choose another.';

  @override
  String get addToLibrary => 'Add to another library';

  @override
  String get chooseLibrary => 'Choose library';

  @override
  String get correctTitle => 'Edit title';

  @override
  String get removeFromLibrary =>
      'Remove from this library (keep files and media records)';

  @override
  String get continueIncludingHistory =>
      'Continue watching (including items outside your library)';

  @override
  String get allLibraries => 'All libraries';

  @override
  String get renameLibrary => 'Rename library';

  @override
  String get addSourceScope => 'Add source scope';

  @override
  String get deleteLibrary => 'Delete library';

  @override
  String get deleteLibraryConfirm => 'Delete this library?';

  @override
  String get deleteLibraryDescription =>
      'Remove the library and its memberships. Files, media and favorites are kept.';

  @override
  String get searchLibrary => 'Search library';

  @override
  String get allSources => 'All sources';

  @override
  String get allTypes => 'All types';

  @override
  String get video => 'Video';

  @override
  String get allWatchStates => 'All watch states';

  @override
  String get watched => 'Finished';

  @override
  String get unwatched => 'Unfinished';

  @override
  String get restoreIgnored => 'Restore ignored items on next scan';

  @override
  String get sourceNeedsSetup => 'Source setup required';

  @override
  String get rescan => 'Rescan';

  @override
  String get removeBinding => 'Remove binding';

  @override
  String get removeBindingConfirm => 'Remove scan binding?';

  @override
  String get createFirstLibrary => 'Create your first library';

  @override
  String get noMatchingMedia => 'No matching media';

  @override
  String get libraryEmpty => 'No media yet. Add a source scope or rescan.';

  @override
  String get browseFailed => 'Could not browse. Check the source and retry.';

  @override
  String get scopeDescription =>
      'Scanning indexes media without downloading it. Choose an authorized folder or server library.';

  @override
  String get parent => 'Parent folder';

  @override
  String get loadMore => 'Load more';

  @override
  String get rootFolder => 'Root folder';

  @override
  String get confirmScanScope => 'Scan this scope';

  @override
  String get chooseScanScope => 'Choose scan scope';

  @override
  String get defaultSaveFailed => 'Could not save the default source.';

  @override
  String get defaultDescription =>
      'Defaults apply when no source is selected. Existing resources keep their original source and account.';

  @override
  String get defaultBrowse => 'Default browsing source';

  @override
  String get defaultResolve => 'Default resolution source';

  @override
  String get chooseEachTime => 'Choose each time';

  @override
  String get defaultUnavailable =>
      'A default source is unavailable. Choose again; no other account was substituted.';

  @override
  String get searchScope => 'Multi-source search scope';

  @override
  String get searchScopeDescription =>
      'Search scope can include multiple sources. Current sources support browsing and resolution; search settings will appear when a search capability is available.';

  @override
  String get sourceDefaultsTitle => 'Default sources and search scope';

  @override
  String get localFolder => 'Local folder';

  @override
  String get pickFolderFailed => 'Could not choose a folder. Try again.';

  @override
  String get openBrowserFailed =>
      'Could not open the browser. Use the sign-in link to retry.';

  @override
  String get noPlexServers => 'No accessible servers in this Plex account.';

  @override
  String get plexSignInFailed => 'Plex sign-in failed. Try again.';

  @override
  String get enterToken => 'Enter an access token to connect.';

  @override
  String get signInPlexFirst => 'Sign in to Plex and choose a server first.';

  @override
  String get connectionFormFailed =>
      'Connection failed. Check the address and credentials.';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get showPassword => 'Show password';

  @override
  String get address => 'Address';

  @override
  String get addressHint => '192.168.1.10 or https://media.example.com';

  @override
  String get username => 'Username';

  @override
  String get guestHelp => 'Leave username and password blank for guest access.';

  @override
  String get password => 'Password';

  @override
  String get keepCredentials => 'Leave blank to keep the current sign-in.';

  @override
  String get advanced => 'Advanced';

  @override
  String get port => 'Port';

  @override
  String get optionalPath => 'Path (optional)';

  @override
  String get smbPathHint => 'Share/video-folder';

  @override
  String get serverPathHint => 'For example jellyfin; otherwise leave blank.';

  @override
  String get optionalDomain => 'Workgroup (optional)';

  @override
  String get waitingPlex => 'Waiting for Plex authorization…';

  @override
  String get signInPlex => 'Sign in to Plex';

  @override
  String get signInPlexAgain => 'Sign in to Plex again';

  @override
  String get plexBrowserHelp =>
      'Sign in to Plex in your browser, then choose a server.';

  @override
  String get reopenSignIn => 'Reopen sign-in page';

  @override
  String get server => 'Server';

  @override
  String get manualServer => 'Connect manually';

  @override
  String get serverAddress => 'Server address';

  @override
  String get portInAddress => 'Include a custom port in the address.';

  @override
  String get accessToken => 'Access token';

  @override
  String get addSource => 'Add media source';

  @override
  String get editSource => 'Edit media source';

  @override
  String get type => 'Type';

  @override
  String get optionalName => 'Name (optional)';

  @override
  String get chooseFolder => 'Choose folder';

  @override
  String get folderAccessHelp =>
      'Choose a folder this app is allowed to access.';

  @override
  String get loadSourcesFailed => 'Could not load sources. Try again.';

  @override
  String get filePlayFailed => 'Could not play this file.';

  @override
  String get previewLimit =>
      'Preview limit of 500 files reached; results are incomplete.';

  @override
  String get previewDescription =>
      'Access scopes and scan exclusions apply. This preview does not update the library or create a background index.';

  @override
  String get scanFailed => 'Scan failed.';

  @override
  String get backToParent => 'Back to parent folder';

  @override
  String get sourcesEmpty =>
      'Add a local folder, SMB, Jellyfin or Plex source.';

  @override
  String get disableSourceConfirm => 'Disable media source?';

  @override
  String get disable => 'Disable';

  @override
  String get toggleSourceFailed => 'Could not change source status. Try again.';

  @override
  String get verifyConnection => 'Test connection';

  @override
  String get connectionFailed => 'Connection failed.';

  @override
  String get previewScan => 'Preview scan';

  @override
  String get deleteSource => 'Delete media source';

  @override
  String get deleteSourceFailed => 'Could not delete the source. Try again.';

  @override
  String get folderEmpty => 'No browsable media in this folder.';

  @override
  String get reloadConfiguration => 'Reload configuration';

  @override
  String get defaultBrowseUnavailable =>
      'Default source unavailable. Choose again; no other account was substituted.';

  @override
  String get browseDefault => 'Browse default';

  @override
  String get capabilityDefaults => 'Default sources';

  @override
  String get addSourceShort => 'Add source';

  @override
  String get playerClosed => 'Player is closed';

  @override
  String get historySaveFailed =>
      'Could not save history. Playback can continue.';

  @override
  String get adjustFailed => 'Adjustment failed. Try again.';

  @override
  String get audioTrack => 'Audio track';

  @override
  String get noAudioTracks => 'No selectable audio tracks';

  @override
  String get playbackCommandFailed => 'Playback failed. Reopen the media file.';

  @override
  String get openFileFailed => 'Could not open the file. Choose again.';

  @override
  String get stopPlaybackFailed =>
      'Could not stop playback. Try going back again.';

  @override
  String get volume => 'Volume';

  @override
  String get brightness => 'Brightness';

  @override
  String get rewind => 'Back 10 seconds';

  @override
  String get pause => 'Pause';

  @override
  String get play => 'Play';

  @override
  String get forward => 'Forward 10 seconds';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get morePlaybackSettings => 'More playback settings';

  @override
  String get lockControls => 'Lock controls';

  @override
  String get playerVolume => 'Player volume';

  @override
  String get playerEmpty => 'Open a video to start watching';

  @override
  String get back => 'Back';

  @override
  String get playbackFailed =>
      'Playback failed. Check the file or choose another.';

  @override
  String get boost => 'Temporary 2× · Release to restore';

  @override
  String get unlockControls => 'Unlock controls';

  @override
  String get loading => 'Loading…';

  @override
  String watchProgress(int position, int duration) {
    return 'Watched $position / $duration min';
  }

  @override
  String watchedMinutes(int minutes) {
    return ' · Watched $minutes min';
  }

  @override
  String localResource(String progress) {
    return 'Local file (access checked on playback)$progress';
  }

  @override
  String setupResource(String progress) {
    return 'Configure or enable the source$progress';
  }

  @override
  String removeBindingDescription(int count) {
    return 'This binding links $count items. Remove automatic memberships only when no source evidence remains. Manual memberships, shared media and files are kept.';
  }

  @override
  String sourceVersion(String kind, String plugin, int config, int revision) {
    return '$kind · Plugin $plugin · Config v$config · r$revision';
  }

  @override
  String disableSourceDescription(int playing, int running, int defaults) {
    return '$playing playing, $running requests, $defaults default bindings. New requests will be rejected and defaults cleared. Current playback can finish. Configuration and favorites are kept.';
  }

  @override
  String deleteSourceDescription(int defaults, int playing, int running) {
    return 'Remove this source configuration and credential reference. Files and favorites are kept. $defaults default bindings and search-scope bindings will be cleared. $playing playing items and $running requests can finish before connections are released.';
  }

  @override
  String previewTitle(String name) {
    return 'Scan preview: $name';
  }

  @override
  String filesFound(int count) {
    return '$count files found.';
  }

  @override
  String deleteNamedSource(String name) {
    return 'Delete $name?';
  }

  @override
  String numberedAudioTrack(int id) {
    return 'Audio track $id';
  }

  @override
  String remainingTime(String time) {
    return '$time remaining';
  }

  @override
  String readSpeed(String speed) {
    return 'Read $speed MB/s';
  }

  @override
  String get notVerified => 'Not verified yet';

  @override
  String get disabled => 'Disabled';

  @override
  String get pendingApply => 'Pending';

  @override
  String get applied => 'Applied';

  @override
  String get applyFailed => 'Could not apply';

  @override
  String get credentialsMissing => 'Sign-in required';

  @override
  String get credentialsReady => 'Credentials saved';

  @override
  String get localSource => 'Local folder';

  @override
  String get credentialsUnknown => 'Credential status unknown';

  @override
  String get screenOrientation => 'Screen orientation';

  @override
  String get orientationSystem => 'Follow system';

  @override
  String get orientationPortrait => 'Portrait';

  @override
  String get orientationLandscape => 'Landscape';

  @override
  String get videoRotation => 'Video rotation';

  @override
  String get rotationOriginal => 'Original (0°)';

  @override
  String get sourceReady => 'Ready';

  @override
  String get sourceConnectionFailed => 'Connection failed';

  @override
  String get sourceInitialized => 'Initialized · Awaiting connection test';

  @override
  String get sourceSaved => 'Saved · Applies on next access';

  @override
  String get credentialsNotRequired => 'No credentials required';

  @override
  String get credentialsUnverified => 'Credentials saved · Not verified';

  @override
  String get credentialsExpiring => 'Token expires within 7 days';

  @override
  String get credentialsExpired => 'Token expired';

  @override
  String get credentialsRejected =>
      'Authentication failed · Update credentials';

  @override
  String get credentialsVerified => 'Connection verified';

  @override
  String get playbackPosition => 'Playback position';

  @override
  String get shadHours => 'Hours';

  @override
  String get shadMinutes => 'Minutes';

  @override
  String get shadSeconds => 'Seconds';

  @override
  String get shadPeriod => 'Period';

  @override
  String get shadMorning => 'AM';

  @override
  String get shadSelectDate => 'Select date';

  @override
  String get shadCut => 'Cut';

  @override
  String get shadCopy => 'Copy';

  @override
  String get shadPaste => 'Paste';

  @override
  String get shadSelectAll => 'Select all';

  @override
  String get shadDone => 'Done';

  @override
  String get metadata => 'Metadata';

  @override
  String get metadataIdentify => 'Identify / rematch';

  @override
  String get metadataImport => 'Import nearby NFO and artwork';

  @override
  String get metadataRefresh => 'Refresh linked work';

  @override
  String get metadataSource => 'Field sources';

  @override
  String get metadataQuery => 'Title or name';

  @override
  String get metadataYear => 'Year (optional)';

  @override
  String get metadataProviderId => 'TMDB ID (optional)';

  @override
  String get metadataLanguage => 'Metadata language';

  @override
  String get metadataToken => 'TMDB read access token';

  @override
  String get metadataConfigure => 'Configure TMDB';

  @override
  String get metadataPrivacy =>
      'Online lookup sends only the title, year, ID and language to TMDB. Videos and private paths stay on this device. Online lookup runs only when requested.';

  @override
  String get metadataSaved => 'TMDB configuration saved';

  @override
  String get metadataCandidates => 'Choose a work';

  @override
  String get metadataChooseChildren => 'Choose season / episode';

  @override
  String get metadataConfirm => 'Confirm this match';

  @override
  String get metadataKeepLocks =>
      'Locked fields and artwork will be retained. Playback progress and resource versions stay intact.';

  @override
  String get metadataOverview => 'Overview';

  @override
  String get metadataOriginalTitle => 'Original title';

  @override
  String get metadataGenres => 'Genres';

  @override
  String get metadataEdit => 'Edit and lock fields';

  @override
  String get metadataRestore => 'Restore automatic value';

  @override
  String get metadataArtwork => 'Choose artwork';

  @override
  String get metadataArtworkLocked => 'Artwork locked';

  @override
  String get metadataReset => 'Reset match';

  @override
  String get metadataResetDescription =>
      'Remove imported fields and the work association. User overrides, locked artwork and playback data are retained.';

  @override
  String get metadataClearCache => 'Clear artwork cache';

  @override
  String get metadataBatch => 'Import library metadata';

  @override
  String get metadataBatchDone =>
      'Library metadata import finished. See each item for status.';

  @override
  String get metadataUnmatched => 'No matching metadata found';

  @override
  String get metadataAwaiting => 'Waiting for your selection';

  @override
  String get metadataCompleted => 'Metadata saved';

  @override
  String get metadataCancelled =>
      'Cancelled or interrupted; saved information is retained';

  @override
  String get metadataBusy => 'Looking up metadata…';

  @override
  String get metadataNotStarted => 'Not identified';

  @override
  String get metadataFailed =>
      'Metadata could not be read. Existing media remains available.';

  @override
  String get metadataConflict =>
      'Work identity conflicts. Choose the correct candidate.';

  @override
  String get metadataStale =>
      'Information changed during lookup. Search again.';

  @override
  String get metadataAuth => 'Configure a valid TMDB read access token.';

  @override
  String get metadataOffline =>
      'Network request failed. Please retry when connected.';

  @override
  String get metadataPermission =>
      'The source does not allow reading this attachment.';

  @override
  String get metadataRateLimited =>
      'TMDB is rate limiting requests. Retry later.';

  @override
  String get metadataMissingSource => 'Source file missing';

  @override
  String get metadataAttribution =>
      'This product uses the TMDB API but is not endorsed or certified by TMDB.';

  @override
  String get metadataForgetToken => 'Remove TMDB credential';

  @override
  String get metadataSearch => 'Search TMDB';
}
