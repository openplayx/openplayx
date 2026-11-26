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
  String get plugins => 'Ask';

  @override
  String get settings => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsMediaLibrary => 'Media library';

  @override
  String get settingsApplication => 'Application';

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
  String get manage => 'Manage';

  @override
  String get about => 'About OpenPlayX';

  @override
  String get aboutDescription => 'Your media. A quieter place to play.';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get aiSettingsSaved => 'Saved.';

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
  String get defaultDescription =>
      'Defaults apply when no source is selected. Existing resources keep their original source and account.';

  @override
  String get defaultBrowse => 'Default browsing source';

  @override
  String get defaultResolve => 'Default resolution source';

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
  String get copyPassword => 'Copy password';

  @override
  String get passwordCopied => 'Password copied';

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
  String get scanExtensions => 'File extensions to scan';

  @override
  String get scanExtensionsHelp =>
      'Only files with a selected extension appear in preview and are added to the library. Hidden files starting with a dot are always skipped.';

  @override
  String get scanExtensionsAllFiles =>
      'Nothing selected: every file will be kept.';

  @override
  String get scanExtensionsVideo => 'Video';

  @override
  String get scanExtensionsAudio => 'Audio';

  @override
  String get scanExtensionsCustom => 'Custom';

  @override
  String scanExtensionsSelected(int count, int total) {
    return '$count of $total selected';
  }

  @override
  String get scanExtensionsSelectAll => 'Select all';

  @override
  String get scanExtensionsSelectNone => 'Clear';

  @override
  String get scanExtensionsAddHint => 'e.g. iso';

  @override
  String get scanExtensionsInvalid =>
      'Use letters and digits only, up to 16 characters each.';

  @override
  String scanExtensionsRemove(String extension) {
    return 'Remove $extension';
  }

  @override
  String get scanExtensionsRestoreDefaults => 'Restore defaults';

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
  String get backToParent => 'Back to parent folder';

  @override
  String get disableSourceConfirm => 'Disable media source?';

  @override
  String get disable => 'Disable';

  @override
  String get toggleSourceFailed => 'Could not change source status. Try again.';

  @override
  String get connectionFailed => 'Connection failed.';

  @override
  String get deleteSourceFailed => 'Could not delete the source. Try again.';

  @override
  String get folderEmpty => 'No browsable media in this folder.';

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
  String get subtitleTrack => 'Subtitles';

  @override
  String get noSubtitleTracks => 'No selectable subtitles';

  @override
  String get subtitleOff => 'Subtitles off';

  @override
  String numberedSubtitleTrack(int id) {
    return 'Subtitle $id';
  }

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
  String get saving => 'Saving…';

  @override
  String get loading => 'Loading…';

  @override
  String watchProgress(int position, int duration) {
    return 'Watched $position / $duration min';
  }

  @override
  String metadataProgressLabel(int done, int total) {
    return 'Scraping $done/$total';
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
    return 'This file source links $count items. Removing it also deletes the file records, playback progress and metadata found only by it; items another file source also found are kept. The original files on your storage are not touched.';
  }

  @override
  String disableSourceDescription(int playing, int running) {
    return '$playing playing, $running requests. New requests will be rejected. Current playback can finish. Configuration and favorites are kept.';
  }

  @override
  String deleteSourceDescription(int fileSources, int playing, int running) {
    return 'Removes this connection\'s configuration and credentials, and its $fileSources file sources with everything they found (file records, playback progress, metadata). The original files on your storage are not touched. $playing playing items and $running requests can finish before connections are released.';
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
    return '$speed MB/s';
  }

  @override
  String get plRemoteBadge => 'Remote';

  @override
  String get plRemoteBadgeTip =>
      'Streaming through remote access. Uses server traffic.';

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
  String scanFoundMedia(int n) {
    return '$n media files found';
  }

  @override
  String get detailOverview => 'Overview';

  @override
  String get detailCast => 'Cast';

  @override
  String get detailDirectors => 'Director';

  @override
  String seasonLabel(int n) {
    return 'Season $n';
  }

  @override
  String episodeLabel(int n) {
    return 'Episode $n';
  }

  @override
  String get detailNoEpisodes => 'No episodes yet.';

  @override
  String get detailExtras => 'Extras';

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
      'Movies and shows added to your library are identified automatically in the background. Only titles, years, IDs and language are sent to TMDB; videos and private paths stay on this device.';

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
  String get metadataForgetToken => 'Remove TMDB credential';

  @override
  String get metadataTokenSaved => 'TMDB token saved on this device.';

  @override
  String get metadataTokenMissing => 'No TMDB token configured.';

  @override
  String get metadataTokenStatusSaved => 'Saved';

  @override
  String get metadataTokenStatusMissing => 'Not set';

  @override
  String get metadataSearch => 'Search TMDB';

  @override
  String get aiAssistant => 'Ask';

  @override
  String get aiPrivacyNotice =>
      'Messages, selected context and tool results are sent to your configured model provider.';

  @override
  String get aiWelcome =>
      'Ask me to find media, continue watching, or control playback. Configure a model to begin.';

  @override
  String get aiYou => 'You';

  @override
  String get aiToolResult => 'Tool result';

  @override
  String get aiConfirmAction => 'Confirm this change';

  @override
  String get aiApprove => 'Approve';

  @override
  String get aiInputHint => 'What would you like to watch?';

  @override
  String get aiStop => 'Stop generating';

  @override
  String get aiSend => 'Send';

  @override
  String get aiToolFailed => 'Tool did not complete';

  @override
  String get aiConfigureFirst =>
      'Set the API domain, model name and key in model settings first.';

  @override
  String get aiSendFailed =>
      'Unable to send. Check the input length and try again.';

  @override
  String get aiCancelled =>
      'Generation stopped. Completed actions are retained.';

  @override
  String get aiTimeout =>
      'The request timed out. Completed actions are retained.';

  @override
  String get aiBudgetReached =>
      'Turn limit reached. Completed results are retained.';

  @override
  String get aiProviderFailed =>
      'Model request failed. Check credentials, endpoint and model support.';

  @override
  String get aiInterrupted =>
      'Interrupted on shutdown; actions will not be replayed.';

  @override
  String aiTokenUsage(int count) {
    return 'Reported tokens: $count';
  }

  @override
  String get aiModelSettings => 'Model settings';

  @override
  String get aiProviderDescription =>
      'Supports OpenAI-compatible APIs. Your API key is saved locally.';

  @override
  String get aiEndpoint => 'API domain';

  @override
  String get aiModel => 'Model name';

  @override
  String get aiApiKey => 'API key';

  @override
  String get aiKeyRequired => 'Enter an API key';

  @override
  String get aiKeySaved => 'Key saved; leave blank to keep it';

  @override
  String get aiSaveFailed =>
      'Unable to save. Check the configuration and credential store access.';

  @override
  String aiExecuting(String name) {
    return 'Running $name…';
  }

  @override
  String get aiAuthenticationFailed =>
      'Authentication failed. Check that the API key and API base URL belong to the same provider.';

  @override
  String get aiRateLimited => 'Provider rate limit reached. Try again later.';

  @override
  String get aiProtocolMismatch =>
      'The endpoint or model does not support this request. Check connection tests.';

  @override
  String get aiTextToolCall =>
      'The model returned tool calls as text instead of executing them, even after retrying. Check that the model and endpoint support tool calling.';

  @override
  String get metadataAutomaticQueued => 'Queued for identification';

  @override
  String get metadataAutomaticWaitingConfig =>
      'Configure a valid TMDB read token for background identification. Local NFO import and playback remain available.';

  @override
  String get metadataAutomaticRetry => 'Retry unfinished identification';

  @override
  String metadataAutomaticStatus(
    int queued,
    int running,
    int waiting,
    int failed,
  ) {
    return 'Background metadata: $queued queued · $running running · $waiting awaiting selection · $failed failed';
  }

  @override
  String get fileSources => 'File sources';

  @override
  String get nameFileSource => 'Name this file source';

  @override
  String get fileSourceEnable => 'Enable';

  @override
  String get fileSourceDisable => 'Disable';

  @override
  String get fileSourceDisabled => 'Disabled';

  @override
  String get noFileSources =>
      'No file sources yet. Add a folder to build your library.';

  @override
  String get removeFileSourceConfirm => 'Delete this file source?';

  @override
  String get libraryEmptyNoMedia =>
      'No media found in your file sources. Rescan or check the folder naming.';

  @override
  String get chooseFolderDescription =>
      'Open a folder and confirm it as a file source. Media inside is indexed, never downloaded.';

  @override
  String get confirmFolder => 'Use this folder';

  @override
  String get libraryNoFileSources =>
      'No file sources yet. Add a folder to a connection under Sources.';

  @override
  String get sourceTabConnections => 'Connections';

  @override
  String get sourceTabFileSources => 'File sources';

  @override
  String get aiNewChat => 'New conversation';

  @override
  String get aiChatHistory => 'Conversations';

  @override
  String get aiShowMedia => 'Show home content';

  @override
  String get aiExpandChat => 'Expand on Home';

  @override
  String get aiLatest => 'Back to latest';

  @override
  String get aiDraftNext => 'Replying. You can draft your next message.';

  @override
  String get aiSuggestMedia => 'Help me find a movie';

  @override
  String get aiSuggestResume => 'Where did I leave off?';

  @override
  String get aiToolPreparing => 'Preparing';

  @override
  String get aiToolRunning => 'Running';

  @override
  String get aiToolWaiting => 'Awaiting confirmation';

  @override
  String get aiToolSucceeded => 'Completed';

  @override
  String get aiToolCancelled => 'Not executed or cancelled';

  @override
  String get aiActionExpired =>
      'This action is no longer available. Select again.';

  @override
  String get aiRemoteImageBlocked => 'Remote image not loaded';

  @override
  String get aiOpenLink => 'Open external link?';

  @override
  String get aiLinkBlocked => 'This link cannot be opened';

  @override
  String get aiTaskSubmitted => 'Task submitted';

  @override
  String get aiPartialFailure => 'Some sources are unavailable';

  @override
  String get aiMoreResults =>
      'More results are available. Ask to see another page.';

  @override
  String get aiNoResults => 'No matching results';

  @override
  String get aiUntitledChat => 'New conversation';

  @override
  String get aiHistoryEmpty => 'No conversations yet';

  @override
  String get aiReplying => 'Replying…';

  @override
  String get aiToolSummary => 'Actions and results come from local services';

  @override
  String get aiEarlier => 'Load earlier messages';

  @override
  String get anonymousHelp =>
      'Leave username and password blank for anonymous access.';

  @override
  String get s3AccessKey => 'Access Key ID';

  @override
  String get s3SecretKey => 'Secret Access Key';

  @override
  String get s3AnonymousHelp => 'Public buckets need no keys.';

  @override
  String get s3Region => 'Region (optional, default us-east-1)';

  @override
  String get s3PathHint => 'bucket/optional-prefix, e.g. media/movies';

  @override
  String get remotePathHint => 'e.g. media/movies; leave blank for the root';

  @override
  String get dlnaSearch => 'Search local network';

  @override
  String get dlnaSearching => 'Searching…';

  @override
  String get dlnaNoDevices =>
      'No media servers found. You can enter the device description URL manually.';

  @override
  String get dlnaDevice => 'Device';

  @override
  String get dlnaAddress => 'Device description URL';

  @override
  String get dlnaAddressHelp =>
      'Filled in when you pick a discovered device; you can also enter it manually.';

  @override
  String get aiOpenExternal => 'Open link';

  @override
  String get serverBrowseAll => 'All';

  @override
  String get serverUnavailable => 'Can\'t reach this server';

  @override
  String get serverEmpty => 'Nothing here yet';

  @override
  String get serverLoadMore => 'Load more';

  @override
  String get localLibrary => 'Local library';

  @override
  String get remoteHomeAccess => 'Home remote access';

  @override
  String get remoteProxy => 'Service (frpc proxy)';

  @override
  String get remoteNoProxies =>
      'No proxies available yet: import the App configuration from your Relay in Settings → Remote access first.';

  @override
  String remoteProxyMissing(String name) {
    return '$name (not in the current App configuration)';
  }

  @override
  String get remoteLanAddress => 'Paired LAN HTTPS address';

  @override
  String get remoteLanFingerprint => 'LAN service certificate SHA-256';

  @override
  String get remoteLanIdentityHelp =>
      'Confirm the 64-digit hexadecimal fingerprint through a trusted channel. The certificate must also pass system trust checks.';

  @override
  String get remoteAutomatic => 'Automatic: verified LAN, otherwise remote';

  @override
  String get remoteLocalOnly => 'LAN only';

  @override
  String get remoteRemoteOnly => 'Remote only';

  @override
  String get developerMode => 'Developer mode';

  @override
  String get developerModeDescription =>
      'Shows debugging entry points, such as the metadata button on the media detail page.';

  @override
  String get metadataConfigureInSettings =>
      'Add a read access token in Settings → TMDB to search.';

  @override
  String get scrapeManagement => 'Scraped metadata';

  @override
  String get scrapedCount => 'Scraped items';

  @override
  String scrapedCountValue(int count) {
    return '$count items';
  }

  @override
  String get scrapeStorage => 'Storage used';

  @override
  String scrapeStorageDetail(String database, String artwork) {
    return 'Database $database · Image cache $artwork';
  }

  @override
  String get scrapeLoading => 'Calculating…';

  @override
  String get scrapeClear => 'Clear all scraped metadata';

  @override
  String get scrapeClearHint =>
      'Deletes metadata fetched from TMDB and NFO files, and cached posters.';

  @override
  String get scrapeClearTitle => 'Clear all scraped metadata?';

  @override
  String get scrapeClearDescription =>
      'Metadata fetched from TMDB and NFO files, matches and downloaded posters will be deleted. This cannot be undone. Video files, playback progress, media server metadata and your manual edits are kept. If TMDB is configured, scraping starts again in the background.';

  @override
  String get scrapeCleared => 'All scraped metadata was cleared.';

  @override
  String get scrapeClearFailed => 'Could not clear. Try again later.';

  @override
  String get artworkCacheLimit => 'Image cache limit';

  @override
  String get artworkCacheLimitDescription =>
      'Posters, backdrops and cast photos. The oldest images are removed when the limit is reached; locked artwork is kept.';

  @override
  String get metadataProgressDone => 'Scraping done';

  @override
  String get edit => 'Edit';

  @override
  String get refresh => 'Refresh';

  @override
  String get addFileSourceShort => 'Add folder';

  @override
  String shelfViewAll(int count) {
    return 'All · $count';
  }

  @override
  String get recentlyAdded => 'Recently added';

  @override
  String get tvShows => 'TV shows';

  @override
  String seasonCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n seasons',
      one: '1 season',
    );
    return '$_temp0';
  }

  @override
  String seasonEpisodeShort(int season, int episode) {
    return 'S$season E$episode';
  }

  @override
  String get detailCastAndCrew => 'Cast & Crew';

  @override
  String get detailGenres => 'Genres';

  @override
  String get detailCollection => 'Collection';

  @override
  String get detailVersions => 'Versions';

  @override
  String get detailViewAll => 'View all';

  @override
  String get detailScrollStart => 'Back to start';

  @override
  String get detailScrollEnd => 'Jump to end';

  @override
  String detailEpisodeCount(int n) {
    return '$n episodes';
  }

  @override
  String detailMovieCount(int n) {
    return '$n movies';
  }

  @override
  String detailRuntime(int n) {
    return '$n min';
  }

  @override
  String get markWatched => 'Mark as watched';

  @override
  String get markUnwatched => 'Mark as unwatched';

  @override
  String get aiMore => 'More';

  @override
  String get aiGreeting => 'What would you like to watch tonight?';

  @override
  String get aiSuggestTonight => 'Recommend a movie for tonight';

  @override
  String get aiSuggestContinue => 'Continue what I was watching';

  @override
  String get aiSuggestSciFi => 'What sci-fi is in my library?';

  @override
  String get aiTestConnection => 'Test connection';

  @override
  String get aiCheckingConnection => 'Testing connection…';

  @override
  String get aiConnectionOk => 'Connected. The model can chat and use tools.';

  @override
  String get aiConnectionOkNoTools =>
      'Connected. The tool-call test did not pass; tasks will still attempt registered tools.';

  @override
  String get aiInvalidSettings =>
      'Enter a valid HTTPS API domain and model name.';

  @override
  String get remoteConnectionMode => 'Connection mode';

  @override
  String get ffmpegSnapshotDebug => 'FFmpeg snapshot debug';

  @override
  String get ffmpegSnapshotAgain => 'Take another';

  @override
  String ffmpegSnapshotAt(String time, String duration) {
    return 'Frame at $time of $duration';
  }

  @override
  String ffmpegSnapshotFailed(String reason) {
    return 'Snapshot failed ($reason).';
  }

  @override
  String get ffmpegUnavailable =>
      'FFmpeg processing is not available in this build.';

  @override
  String get asrDebugTitle => 'Audio & subtitle debug';

  @override
  String get asrChooseEpisode => 'Choose an episode';

  @override
  String get asrSectionResource => 'Current resource';

  @override
  String get asrSectionInput => 'Input';

  @override
  String get asrSectionBackend => 'Recognition';

  @override
  String get asrSectionActions => 'Actions';

  @override
  String get asrSectionStatus => 'Status';

  @override
  String get asrSectionAudio => 'Audio result';

  @override
  String get asrSectionSubtitles => 'Subtitles';

  @override
  String get asrSectionDebug => 'Debug info';

  @override
  String get asrTitle => 'Title';

  @override
  String get asrEpisode => 'Episode';

  @override
  String get asrVersion => 'Version';

  @override
  String get asrDuration => 'Duration';

  @override
  String get asrUnknown => 'Unknown';

  @override
  String get asrStart => 'Start (s or mm:ss)';

  @override
  String get asrEnd => 'End (s or mm:ss)';

  @override
  String get asrWhole => 'Whole episode';

  @override
  String get asrRangeHint =>
      'Defaults to the first 60 seconds. Whole episode must be chosen explicitly.';

  @override
  String get asrWholeUnavailable =>
      'Duration unknown: whole-episode processing is not supported.';

  @override
  String get asrRangeInvalid =>
      'Invalid range: the end must be after the start and within the media.';

  @override
  String asrChannels(int n) {
    return '$n ch';
  }

  @override
  String get asrNotDecodable => 'not decodable';

  @override
  String get asrEmbedded => 'On device';

  @override
  String get asrHttp => 'HTTP service';

  @override
  String get asrNoBackends => 'No recognition backend configured.';

  @override
  String get asrChecking => 'Checking…';

  @override
  String asrBackendReady(String engine, String revision) {
    return 'Ready · $engine · model $revision';
  }

  @override
  String asrBackendUnavailable(String reason) {
    return 'Unavailable: $reason';
  }

  @override
  String get asrExtractOnly => 'Extract audio only';

  @override
  String get asrExtractAndTranscribe => 'Extract and recognise subtitles';

  @override
  String get asrStagePreparing => 'Preparing resource';

  @override
  String get asrStageExtracting => 'Extracting audio';

  @override
  String get asrStageUploading => 'Uploading';

  @override
  String get asrStageQueued => 'Queued';

  @override
  String get asrStageTranscribing => 'Recognising';

  @override
  String get asrStageFormatting => 'Building subtitles';

  @override
  String get asrCancelling => 'Cancelling…';

  @override
  String get asrCancelled => 'Cancelled';

  @override
  String get asrSucceeded => 'Finished';

  @override
  String asrFailed(String reason) {
    return 'Failed: $reason';
  }

  @override
  String get asrAudioTrack => 'Track';

  @override
  String get asrAudioFormat => 'Format';

  @override
  String get asrAudioSize => 'Size';

  @override
  String get asrAudioReused => 'Reused an identical earlier extraction';

  @override
  String get asrNoSpeech => 'No speech recognised in this range.';

  @override
  String get asrWholeResult => 'Whole episode';

  @override
  String asrPartialResult(String start, String end) {
    return 'Partial: $start – $end (not the whole episode)';
  }

  @override
  String get asrSave => 'Save subtitle';

  @override
  String get asrExport => 'Export…';

  @override
  String get asrExported => 'Exported.';

  @override
  String get asrSaved =>
      'Saved. Choose it in the player\'s subtitle list (marked “Recognised”).';

  @override
  String get asrSavedPartial =>
      'Saved (partial range). Choose it in the player\'s subtitle list (marked “Recognised”).';

  @override
  String get asrSaveHint =>
      'Unsaved results are discarded when you leave. Saving adds a new subtitle record; it never replaces existing subtitles or changes playback by itself.';

  @override
  String get asrTaskId => 'Task ID';

  @override
  String get asrBackendLabel => 'Backend';

  @override
  String get asrModel => 'Model';

  @override
  String get asrEngine => 'Engine';

  @override
  String get asrLanguage => 'Language (auto / zh / en …)';

  @override
  String get asrRemoteJob => 'Remote job';

  @override
  String get asrError => 'Error';

  @override
  String get asrContinue => 'Continue';

  @override
  String get asrWholeTitle => 'Process the full video?';

  @override
  String asrWholeBody(String duration, String size) {
    return 'Duration $duration, about $size of audio. Recognition can take a long time.';
  }

  @override
  String get asrUploadTitle => 'Upload audio to a recognition service?';

  @override
  String asrUploadBody(String host, String range, String insecure) {
    return 'Audio of $range will be uploaded to $host. $insecure';
  }

  @override
  String get asrUploadInsecure =>
      'This service uses plain HTTP: the audio is not encrypted in transit.';

  @override
  String get asrUploadAllow => 'Allow upload';

  @override
  String get asrUploadAuthorized => 'uploads allowed';

  @override
  String get asrErrorNoAudio => 'This resource has no audio track.';

  @override
  String get asrErrorDurationUnknown => 'Duration unknown.';

  @override
  String get asrErrorModelMissing => 'Model not installed.';

  @override
  String get asrErrorEngineUnavailable =>
      'This build has no on-device recognizer.';

  @override
  String get asrErrorUnreachable => 'Service unreachable.';

  @override
  String get asrErrorUnauthorized => 'Service rejected the credentials.';

  @override
  String get asrErrorUploadConsent =>
      'Upload to this service has not been authorised.';

  @override
  String get asrErrorTls => 'The service certificate could not be verified.';

  @override
  String get asrErrorRemoteStream => 'This source cannot be read locally yet.';

  @override
  String get asrErrorTrackChanged =>
      'The file changed; choose the audio track again.';

  @override
  String get asrSettingsTitle => 'Speech recognition';

  @override
  String get asrModelFooter =>
      'On-device Whisper models (multilingual). Files are verified by size and SHA-256 before use; nothing is downloaded automatically.';

  @override
  String get asrModelDownload => 'Download';

  @override
  String asrModelDownloading(String done, String total) {
    return 'Downloading $done / $total';
  }

  @override
  String get asrModelDownloadFailed =>
      'Download failed or the file did not verify.';

  @override
  String get asrModelImport => 'Import model file…';

  @override
  String get asrModelImportRejected =>
      'Not a known model file (size/checksum mismatch).';

  @override
  String get asrModelInstalled => 'Installed';

  @override
  String get asrModelInUse => 'Installed · in use';

  @override
  String get asrModelNotInstalled => 'Not installed';

  @override
  String get asrModelUse => 'Use';

  @override
  String get asrModelRemove => 'Remove';

  @override
  String get asrServicesTitle => 'Recognition services';

  @override
  String get asrAddService => 'Add HTTP service';

  @override
  String get asrEditService => 'Edit service';

  @override
  String get asrRemoveService => 'Remove';

  @override
  String get asrServicePrivacy =>
      'Only extracted audio is uploaded, after you allow it. Video links and NAS credentials are never sent.';

  @override
  String get asrServiceName => 'Name';

  @override
  String get asrServiceUrl => 'Service URL';

  @override
  String get asrServiceToken => 'Access token';

  @override
  String get asrServiceUrlInvalid =>
      'Enter an https:// URL without credentials (http:// only when allowed below).';

  @override
  String get asrServiceInvalid => 'Check the model and language.';

  @override
  String get asrAllowHttp => 'Allow plain HTTP (LAN only)';

  @override
  String get asrAllowHttpHint =>
      'Audio would travel unencrypted. HTTPS certificate checks are never disabled.';

  @override
  String get asrInstallModel => 'Install or choose a model';

  @override
  String get asrRecheck => 'Check again';

  @override
  String asrTranscribeBlocked(String reason) {
    return 'Recognition unavailable: $reason';
  }

  @override
  String get embeddedSubtitles => 'Embedded subtitles';

  @override
  String get externalSubtitles => 'External subtitles';

  @override
  String get recognizedSubtitles => 'Recognised subtitles';

  @override
  String get recognizedSubtitleBadge => 'Recognised';

  @override
  String recognizedSubtitleTitle(String time) {
    return 'Saved $time';
  }

  @override
  String recognizedSubtitlePartial(String start, String end) {
    return 'Partial $start–$end';
  }

  @override
  String get recognizedSubtitleFull => 'Whole episode';

  @override
  String get addSourceConnection => 'Add connection';

  @override
  String get sourcesDescription => 'Connect your storage. Organize your media.';

  @override
  String sourceActions(String name) {
    return 'Actions for $name';
  }

  @override
  String get browseSourceFiles => 'Browse files';

  @override
  String get sourceAwaitingVerification => 'Awaiting verification';

  @override
  String sourceFileCount(int count) {
    return '$count file sources';
  }

  @override
  String get sourceRootFolder => 'Root folder';

  @override
  String get rescanFileSource => 'Rescan';

  @override
  String plAbASet(String time) {
    return 'A set at $time';
  }

  @override
  String get plAbClear => 'Clear A-B loop';

  @override
  String get plAbCleared => 'A-B loop cleared';

  @override
  String get plAbLoop => 'A-B loop';

  @override
  String plAbLooping(String a, String b) {
    return 'Looping $a – $b';
  }

  @override
  String get plAbSetA => 'Set point A';

  @override
  String get plAbSetB => 'Set point B';

  @override
  String get plAdvancedTools => 'Advanced tools row';

  @override
  String get plAspectDefault => 'Default';

  @override
  String get plAspectRatio => 'Aspect ratio';

  @override
  String get plAudioDelay => 'Audio delay';

  @override
  String plBoosting(String speed) {
    return '$speed fast forward · release to restore';
  }

  @override
  String get plDelayHint =>
      'Positive values play audio or show subtitles later.';

  @override
  String get plExitFullscreen => 'Exit full screen';

  @override
  String get plFaster => 'Faster';

  @override
  String get plFitBest => 'Best fit';

  @override
  String get plFitFill => 'Fill';

  @override
  String get plFitMode => 'Picture size';

  @override
  String get plFitOriginal => 'Original size';

  @override
  String get plFullscreen => 'Full screen';

  @override
  String get plGo => 'Go';

  @override
  String get plInfo => 'Info';

  @override
  String get plInfoDuration => 'Duration';

  @override
  String get plInfoResolution => 'Resolution';

  @override
  String get plInfoTitle => 'Title';

  @override
  String get plJumpBackMedium => 'Back 1 minute';

  @override
  String get plJumpExtraShort => 'Jump 3 seconds';

  @override
  String get plJumpForwardMedium => 'Forward 1 minute';

  @override
  String get plJumpLong => 'Jump 5 minutes';

  @override
  String plJumpSeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String get plJumpToTime => 'Jump to time';

  @override
  String get plJumpToTimeInvalid => 'Enter a time such as 1:23:45 or 12:30.';

  @override
  String get plLoadSubtitle => 'Load subtitle file…';

  @override
  String get plLockShort => 'Lock';

  @override
  String get plMediaInfo => 'Media info';

  @override
  String get plMenuAudio => 'Audio';

  @override
  String get plMenuPlayback => 'Playback';

  @override
  String get plMenuSubtitle => 'Subtitles';

  @override
  String get plMenuVideo => 'Video';

  @override
  String get plMenuView => 'View';

  @override
  String get plMute => 'Mute';

  @override
  String get plMuted => 'Muted';

  @override
  String get plNextAudioTrack => 'Next audio track';

  @override
  String get plNextSubtitle => 'Next subtitle';

  @override
  String get plNormalSpeed => 'Normal speed';

  @override
  String get plOrientationShort => 'Rotate';

  @override
  String get plPicture => 'Picture';

  @override
  String get plPictureAndSound => 'Picture & sound';

  @override
  String get plRepeatMode => 'Repeat';

  @override
  String get plRepeatOff => 'No repeat';

  @override
  String get plRepeatOne => 'Repeat this item';

  @override
  String get plReset => 'Reset';

  @override
  String get plSettingsAndEffects => 'Settings & effects';

  @override
  String get plShortcuts => 'Keyboard shortcuts';

  @override
  String get plShowPosition => 'Show position';

  @override
  String get plSleepEndOfItem => 'End of item';

  @override
  String get plSleepFinished => 'Sleep timer paused playback';

  @override
  String plSleepMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get plSleepOff => 'Off';

  @override
  String get plSleepShort => 'Sleep';

  @override
  String get plSleepTimer => 'Sleep timer';

  @override
  String get plSlideToUnlock => 'Slide right to unlock';

  @override
  String get plSlower => 'Slower';

  @override
  String get plSnapshot => 'Snapshot';

  @override
  String get plSnapshotFailed => 'Could not save the snapshot';

  @override
  String plSnapshotSaved(String path) {
    return 'Snapshot saved: $path';
  }

  @override
  String get plSpeedShort => 'Speed';

  @override
  String get plStatistics => 'Statistics';

  @override
  String get plStatsAudio => 'Audio played / lost';

  @override
  String get plStatsDemux => 'Demux bitrate';

  @override
  String get plStatsFrames => 'Frames shown / lost';

  @override
  String get plStatsInput => 'Input bitrate';

  @override
  String get plStatsOverlay => 'Statistics overlay';

  @override
  String get plStatsRead => 'Read speed';

  @override
  String get plStop => 'Stop';

  @override
  String get plSubtitleDelay => 'Subtitle delay';

  @override
  String get plSync => 'Sync';

  @override
  String get plTimeTooltip =>
      'Click: total/remaining · Double-click: jump to time';

  @override
  String get plToggleControls => 'Show/hide controls';

  @override
  String get plToggleSubtitles => 'Subtitles on/off';

  @override
  String get plTrackAudio => 'Audio';

  @override
  String get plTracks => 'Audio & subtitles';

  @override
  String get plTracksShort => 'Tracks';

  @override
  String get plTrackSubtitle => 'Subtitle';

  @override
  String get plTrackVideo => 'Video';

  @override
  String get plUnsupported => 'Not available for this player';

  @override
  String get plZoom => 'Zoom';

  @override
  String get plZoomOriginal => 'Original';

  @override
  String get plMenuPlaybackControl => 'Playback controls';

  @override
  String plBoostingShort(String speed) {
    return '$speed fast forward';
  }

  @override
  String get plSwipeUpToLock => 'Swipe up to lock';

  @override
  String plSpeedLocked(String speed) {
    return 'Speed locked at $speed';
  }

  @override
  String get plExternalSubtitleShort => '+ External';

  @override
  String get listSeparator => ', ';

  @override
  String get remoteAccess => 'Remote access';

  @override
  String get remoteHomeAndRoutes => 'Home and connection routes';

  @override
  String get remoteImportTitle => 'Import remote configuration';

  @override
  String get remoteImportFooter =>
      'Paste the App configuration exported by Relay. It takes effect right after import.';

  @override
  String get remoteImportPlaceholder => 'App configuration JSON';

  @override
  String get remoteImport => 'Import';

  @override
  String get remoteImporting => 'Importing…';

  @override
  String get remoteImported => 'Imported and applied.';

  @override
  String get remoteClearConfirmTitle => 'Clear remote configuration?';

  @override
  String get remoteClearConfirmMessage =>
      'Removes the remote configuration and credentials from this device. Import again to restore remote access.';

  @override
  String get remoteClear => 'Clear';

  @override
  String get remoteClearing => 'Clearing…';

  @override
  String get remoteCleared => 'Remote configuration cleared.';

  @override
  String get remoteNotImported => 'Not imported yet';

  @override
  String get remoteNotImportedHint =>
      'Tap “Import” to add a remote configuration.';

  @override
  String get remoteServerName => 'Server name';

  @override
  String get remoteCredentials => 'Credentials';

  @override
  String get remoteCredentialsSecure => 'Saved in system secure storage';

  @override
  String get remoteProxyUnused => 'Not used by any source';

  @override
  String remoteProxyUsedBy(String sources) {
    return 'Sources: $sources';
  }

  @override
  String remoteProxyPort(int port) {
    return 'Port $port';
  }

  @override
  String get remoteConnectionDetails => 'Connection details';

  @override
  String get remoteRelayServer => 'Relay server';

  @override
  String get remoteRelayFooter =>
      'The whole App shares this connection. Credentials are kept in system secure storage.';

  @override
  String get remoteAvailableServices => 'Available services';

  @override
  String get remoteAvailableServicesFooter =>
      'Registered on Relay by Home. Pick one for a source under “Edit source → Home remote access”.';

  @override
  String get remoteNeedsAttention => 'Needs attention';

  @override
  String get remoteSourceProxyMissing =>
      'Its remote access service is not in the current configuration, so remote connection is unavailable.';

  @override
  String get statusConfigured => 'Configured';

  @override
  String get statusNotConfigured => 'Not configured';

  @override
  String get statusAvailable => 'Available';

  @override
  String get statusUnavailable => 'Unavailable';

  @override
  String get plgGroupModel => 'Models';

  @override
  String get plgGroupExternal => 'External capabilities';

  @override
  String get plgGroupBuiltIn => 'Built-in capabilities';

  @override
  String get plgGroupModelDescription => 'Configure the model the agent uses';

  @override
  String get plgGroupExternalDescription =>
      'Self-hosted or cloud services you add';

  @override
  String get plgGroupBuiltInDescription =>
      'Ships with the App, all open by default';

  @override
  String plgCount(int count) {
    return '$count';
  }

  @override
  String extToolCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tools',
      one: '1 tool',
    );
    return '$_temp0';
  }

  @override
  String plgInstanceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instances',
      one: '1 instance',
    );
    return '$_temp0';
  }

  @override
  String get plgExternalHint =>
      'Enter an address and token to detect and set up a service automatically';

  @override
  String get plgExternalEmpty => 'No external services yet';

  @override
  String get extConfigureTitle => 'Set up external capability';

  @override
  String plgBuiltInHint(int count) {
    return '$count capabilities ship with the App, all open by default — nothing to enable one by one';
  }

  @override
  String plgGroupEmpty(String group) {
    return 'No $group yet';
  }

  @override
  String get plgNoAssistant => 'This build does not include the AI assistant';

  @override
  String get plgSelectForDetail => 'Select an item to see details';

  @override
  String get plgDeviceUnsupported => 'Not supported on this device';

  @override
  String get plgTemporarilyUnavailable => 'Temporarily unavailable';

  @override
  String get plgDisabled => 'Plugin disabled';

  @override
  String plgDisableConfirmTitle(String name) {
    return 'Disable “$name”?';
  }

  @override
  String get plgImpactIntro =>
      'New calls are blocked right away. Instance settings, generated subtitles and history are kept.';

  @override
  String plgImpactPlaying(int count) {
    return '$count playing sessions continue until playback ends, then release their connections.';
  }

  @override
  String plgImpactRunning(int count) {
    return '$count running requests are released when they finish.';
  }

  @override
  String plgImpactInstances(String instances) {
    return 'Affected instances: $instances.';
  }

  @override
  String get actionFailedRetry => 'Something went wrong. Please try again.';

  @override
  String get plgUnavailableReason => 'Why it\'s unavailable';

  @override
  String get plgSwitch => 'Plugin switch';

  @override
  String get plgSwitchOn => 'Accepting new calls';

  @override
  String get plgSwitchOff =>
      'New calls are blocked; instance settings are kept';

  @override
  String get plgLocation => 'Runs where';

  @override
  String get plgLocationDevice => 'Runs on this device';

  @override
  String get plgLocationNetwork =>
      'The App connects from this device to the storage you configured';

  @override
  String get plgLocationSelfHosted =>
      'The App runs the adapter on this device; the work happens on the server you configured';

  @override
  String get plgLocationCloudApi =>
      'The App calls a cloud API from this device';

  @override
  String get plgDependencies => 'Dependencies';

  @override
  String plgDependency(String name, String status) {
    return '$name ($status)';
  }

  @override
  String get plgCapabilities => 'Capabilities';

  @override
  String get plgCapabilitiesFooter =>
      'Only methods this plugin actually implements are listed.';

  @override
  String plgInstancesTitle(int count) {
    return 'Instances ($count)';
  }

  @override
  String plgInstanceBusy(int playing, int running) {
    return 'In use: $playing playing · $running requests';
  }

  @override
  String get plgNoInstances => 'No instances';

  @override
  String get plgOpenSettings => 'Open settings';

  @override
  String get plgRuntime => 'Status and diagnostics';

  @override
  String plgRevisions(String saved, String applied) {
    return 'Saved revision $saved · In effect $applied';
  }

  @override
  String get plgNotApplied => 'not yet';

  @override
  String get plgPendingApply =>
      'New settings pending; the old revision still serves calls in progress';

  @override
  String plgActivity(int playing, int running) {
    return 'Active playback $playing · Running requests $running';
  }

  @override
  String plgLastError(String code) {
    return 'Last error: $code';
  }

  @override
  String get plgRefreshStatus => 'Refresh status';

  @override
  String get plgCopyDiagnostics => 'Copy redacted diagnostics';

  @override
  String get plgCopyDiagnosticsHint => 'No addresses, accounts, paths or keys';

  @override
  String get plgDiagnosticsCopied => 'Diagnostics copied';

  @override
  String get extConnectionOk => 'Connection OK';

  @override
  String extRemoveConfirmTitle(String name) {
    return 'Remove “$name”?';
  }

  @override
  String get extRemoveConfirmMessage =>
      'Only the address and token are removed from the App. Data on the server is not affected.';

  @override
  String get extNeedsRecheck => 'Needs re-detection';

  @override
  String extToolAiUnavailable(String problem) {
    return 'Not available to AI: $problem';
  }

  @override
  String get extToolNeedsConfirm => 'Asks for your confirmation first';

  @override
  String get extAiServiceUnavailable =>
      'The service is unavailable, so AI can\'t call it right now';

  @override
  String get extAiNeedsRecheck =>
      'Tap “Re-detect” to fetch the tool definitions';

  @override
  String extAiSummary(int usable, int total) {
    return 'AI can call $usable of $total tools directly; actions that change state ask for your confirmation first';
  }

  @override
  String get extRemoved => 'This external capability was removed';

  @override
  String extVersion(String version) {
    return 'Version $version';
  }

  @override
  String get extAiCalls => 'AI calls';

  @override
  String extToolsTitle(int count) {
    return 'Tools ($count)';
  }

  @override
  String get extNoTools => 'No tools';

  @override
  String get extRecheck => 'Re-detect';

  @override
  String get extConnecting => 'Connecting and detecting…';

  @override
  String extAdded(String name) {
    return 'Added “$name”';
  }

  @override
  String get extConfigureFooter =>
      'Enter the service address and access token. The App connects over MCP to find out what the service is and which tools it offers.';

  @override
  String get extServiceAddress => 'Service address';

  @override
  String get extAccessToken => 'Access token';

  @override
  String get extNameOptional => 'Name (optional)';

  @override
  String get extDetected => 'Detected';

  @override
  String get extTools => 'Tools';

  @override
  String get extConnect => 'Connect and detect';

  @override
  String get scanStatusPending => 'Not scanned';

  @override
  String get scanStatusScanning => 'Scanning';

  @override
  String get scanStatusDone => 'Scan complete';

  @override
  String get scanStatusFailed => 'Scan failed';

  @override
  String get scanStatusInterrupted => 'Scan interrupted';

  @override
  String get scanRescanHint => 'Please scan again';

  @override
  String get libraryDbTooNew =>
      'The library was created by a newer version. Please update the App.';

  @override
  String get errConfigUnknownFields =>
      'The configuration contains unknown fields; the original must be kept.';

  @override
  String get errRemoteKinds =>
      'Remote access currently supports Jellyfin, Emby, Plex and SMB.';

  @override
  String get errRemoteProtocolMismatch =>
      'The remote service protocol does not match; SMB currently supports remote-only mode.';

  @override
  String get errConfigVersionNoOverwrite =>
      'Incompatible configuration version; it cannot be overwritten.';

  @override
  String get errAddressRequired => 'Please enter an address.';

  @override
  String get errTimeoutConcurrency =>
      'Request timeout must be 1–120 seconds and concurrency 1–8.';

  @override
  String get errScopeCount =>
      'Set at least one access scope; at most 100 scopes and 100 exclusions.';

  @override
  String get errScopeRelative =>
      'Scopes and exclusions must be relative paths inside the root; .. and absolute paths are not allowed.';

  @override
  String get errBrowseModeUnsupported =>
      'This plugin does not support that browsing mode.';

  @override
  String get errNoSearchIndex =>
      'This plugin does not provide search or background indexing yet.';

  @override
  String get errLibraryNoDirPolicy =>
      'Library sources do not support folder policies yet.';

  @override
  String get errChooseLocalFolder => 'Please choose a local folder.';

  @override
  String get errAddressRelativeSegments =>
      'The address cannot contain relative path segments.';

  @override
  String get errInvalidServerAddress =>
      'Enter a valid server address; put credentials in their own fields.';

  @override
  String get errSmbAddressFormat =>
      'SMB uses the standard port 445: smb://host/share/optional-folder.';

  @override
  String errUserIdRequired(String kind) {
    return 'Please enter the $kind user ID.';
  }

  @override
  String get errSftpUsernameRequired => 'Please enter the SFTP username.';

  @override
  String get errServerAddressRequired => 'Please enter the server address.';

  @override
  String get errInvalidHost => 'Enter a valid IP, host name or server address.';

  @override
  String get errPortRange => 'Port must be 1–65535.';

  @override
  String get errSmbPort => 'SMB connections use port 445.';

  @override
  String get errPathDots => 'The path cannot contain “.” or “..”.';

  @override
  String get errSignInFailed =>
      'Sign-in failed. Check the account and password, or authorize again.';

  @override
  String get errAddressRedirected =>
      'The address redirects. Enter the server\'s actual entry point.';

  @override
  String get errCannotConnectService =>
      'Cannot connect to the service. Check the address and network.';

  @override
  String get errConnectTimeout => 'Connection timed out. Please try again.';

  @override
  String errKindUsernameRequired(String kind) {
    return 'Please enter the $kind username.';
  }

  @override
  String get errNoValidSignIn =>
      'The server did not return a valid sign-in result.';

  @override
  String get errPlexSessionExpired =>
      'Your sign-in expired. Please sign in to Plex again.';

  @override
  String get errPlexServerUnreachable =>
      'Cannot connect to this Plex server. Make sure it is online.';

  @override
  String errDlnaHttp(int status) {
    return 'DLNA device request failed (HTTP $status).';
  }

  @override
  String get errDlnaForeignHost =>
      'The DLNA device returned an address on another host.';

  @override
  String get errDlnaNotMediaServer =>
      'This device is not a media server (no content directory service).';

  @override
  String get errChooseFolder => 'Please choose a folder.';

  @override
  String get untitled => 'Untitled';

  @override
  String get errChooseVideoOrAudio => 'Please choose a video or audio item.';

  @override
  String get errNoPlayableAddress => 'This item has no playable address.';

  @override
  String get plexPartMedia => 'Media';

  @override
  String get errPathOutsideRoot => 'The path is outside the configured root.';

  @override
  String get errOutsideScope =>
      'This folder is outside the access scope configured for this instance.';

  @override
  String get errAttachmentTooLarge => 'Attachment too large';

  @override
  String errServiceAccessDenied(String service, int status) {
    return '$service denied access (HTTP $status). Check the username and password.';
  }

  @override
  String get errFileNotFound => 'The file or folder does not exist.';

  @override
  String errServiceRequestFailed(String service, int status) {
    return '$service request failed (HTTP $status).';
  }

  @override
  String get errFtpRefused => 'The FTP server refused the connection.';

  @override
  String get errFtpLogin =>
      'FTP sign-in failed. Check the username and password.';

  @override
  String get errFtpNoBinary =>
      'The FTP server does not support binary transfers.';

  @override
  String get errPathChars => 'The path contains unsupported characters.';

  @override
  String get errFtpNoPassive => 'The FTP server does not support passive mode.';

  @override
  String get errFolderNotFoundOrDenied =>
      'The folder does not exist or you lack access.';

  @override
  String get errFtpList => 'FTP could not list the folder.';

  @override
  String get errFtpNoResume =>
      'The FTP server does not support resuming, so seeking is unavailable.';

  @override
  String get errFtpRead => 'Cannot read this FTP file.';

  @override
  String get errFtpNoSize =>
      'The FTP server did not report the file size, so it cannot play.';

  @override
  String get errSftpLogin =>
      'SFTP sign-in failed. Check the username and password.';

  @override
  String get errSftpDisabled => 'SFTP is not enabled on the server.';

  @override
  String get errPathDenied => 'No permission to access this path.';

  @override
  String get errSftpRequest => 'SFTP request failed.';

  @override
  String get errSftpConnect => 'SFTP connection failed.';

  @override
  String get errSftpPlay => 'Cannot play this SFTP file.';

  @override
  String get errChooseFile => 'Please choose a file.';

  @override
  String get errConnectionClosed => 'The connection is closed.';

  @override
  String get errUnsafeResourceUrl =>
      'The media service returned an unsafe resource address.';

  @override
  String errMediaServerHttp(int status) {
    return 'Media service request failed (HTTP $status). Check the address and credentials.';
  }

  @override
  String get errServerArtworkUnavailable => 'Server artwork is unavailable';

  @override
  String get errImageTooLarge => 'Image too large';

  @override
  String get errNoPlayableVersion => 'This media has no playable version.';

  @override
  String get errReselectVersion =>
      'Go back to the library and choose a version again.';

  @override
  String get errServerIdentityMismatch => 'Server item identity does not match';

  @override
  String plexPartLabel(int index, String container) {
    return 'File $index · $container';
  }

  @override
  String get errNoPlayableFile => 'This media has no playable file.';

  @override
  String get errMultiPartUnsupported =>
      'This media has multiple versions or parts, which cannot be played directly yet.';

  @override
  String get errMetadataNotThisServer =>
      'The metadata query does not belong to this server instance';

  @override
  String get errArtworkNotThisServer =>
      'The artwork does not belong to this server instance';

  @override
  String get srcFieldFolder => 'Folder';

  @override
  String get srcFieldWorkgroup => 'Workgroup (optional)';

  @override
  String get srcFieldRegion => 'Region (optional)';

  @override
  String srcFieldRequired(String field) {
    return 'Please enter $field.';
  }

  @override
  String get errResourceNotThisSource =>
      'The resource does not belong to this media source.';

  @override
  String get errOutsideAuthorizedFolder =>
      'The file is outside the authorized folder.';

  @override
  String get errOutsideSmbShare =>
      'The path is outside the configured SMB share.';

  @override
  String get errSmbListShares =>
      'Cannot read the share list. Enter the shared folder path under “Advanced” and try again.';

  @override
  String get errSmbPlay => 'Cannot play this SMB file.';

  @override
  String get errAttachmentNotFound => 'Attachment not found';

  @override
  String get errInvalidFileName => 'Invalid file name.';

  @override
  String get errUnknownWriteShare =>
      'Cannot determine which share to write to.';

  @override
  String get errOpenPlayXFolderBlocked =>
      'A file with the same name exists in the share, so the OpenPlayX folder cannot be created.';

  @override
  String get errTooManySameName =>
      'Too many files with the same name. Tidy up the OpenPlayX folder first.';

  @override
  String get errTempNameConflict =>
      'Temporary file name conflict. Please try again.';

  @override
  String get errUploadIncomplete =>
      'The upload was incomplete; the temporary file was discarded.';

  @override
  String get errSmbWrite =>
      'Writing to SMB failed. Make sure the account can write to this share.';

  @override
  String get errAttachmentTypeOrLimit =>
      'Unsupported attachment type or read limit';

  @override
  String get errSourceMissing =>
      'The media source does not exist or its configuration is incompatible.';

  @override
  String get errSourceKindChange =>
      'The source type cannot be changed while editing.';

  @override
  String get errTokenRequired => 'Please enter the access token.';

  @override
  String get srcStatusDisabled => 'Disabled';

  @override
  String get srcStatusReady => 'Ready';

  @override
  String get srcStatusFailed => 'Connection failed';

  @override
  String get srcStatusInitialized => 'Initialized · Awaiting connection check';

  @override
  String get srcStatusSaved => 'Saved · Applies on next access';

  @override
  String get errArtworkCacheLimit => 'Unsupported image cache limit.';

  @override
  String get errExtensions =>
      'File extensions may contain only letters and digits, up to 100.';

  @override
  String get errSourceDisabled =>
      'The media source is disabled; its configuration is kept.';

  @override
  String get errPluginDisabled =>
      'This plugin is disabled; instance settings are kept.';

  @override
  String get errTokenExpired =>
      'The token has expired. Please update the credentials.';

  @override
  String get errReselectLocalFolder =>
      'Choose the local folder again to restore access.';

  @override
  String get errCredentialsUnavailable =>
      'Credentials are unavailable. Sign in again or update them.';

  @override
  String get errInstanceChanged =>
      'The instance settings changed. Please try again.';

  @override
  String get errRequestTimedOut => 'The request timed out.';

  @override
  String get errSourceUnreachable =>
      'Cannot reach the media source. Check the address, permissions and credentials.';

  @override
  String get errInvalidPaging => 'Invalid paging parameters.';

  @override
  String get errInvalidSearchPaging => 'Invalid search or paging';

  @override
  String get errSearchUnsupported => 'This source does not support search';

  @override
  String get errMetadataUnsupported =>
      'This source does not support metadata lookup';

  @override
  String get errAttachmentsUnsupported =>
      'This source does not support reading attachments';

  @override
  String get errWriteUnsupported => 'This source does not support writing.';

  @override
  String get errWriteTimeout =>
      'Writing timed out. Temporary files starting with .openplayx- may remain on the server.';

  @override
  String get errSourceProxyMissing =>
      'The remote access service this source uses is no longer in the App configuration. Import the App configuration from Relay in Settings → Remote access.';

  @override
  String get errReloadBeforeTest => 'Reload the configuration before testing.';

  @override
  String get errTestTimeout => 'Connection test timed out.';

  @override
  String get errTestFailed =>
      'Connection test failed. Check the address, permissions and credentials.';

  @override
  String get errManualScanDisabled =>
      'Manual file scanning is not enabled for this instance.';

  @override
  String get errScanLimit => 'The scan limit must be 1–5000.';

  @override
  String get errScanPageLimit =>
      'The scan reached the limit of 1000 folder pages. Narrow the access scope.';

  @override
  String get errScanConfigChanged =>
      'The instance settings changed during the scan. Please scan again.';

  @override
  String get errTooManyQueued =>
      'Too many queued requests for this instance. Try again later.';

  @override
  String get credNotRequired => 'No account credentials needed';

  @override
  String get credMissing => 'Credentials missing';

  @override
  String get credConfigured => 'Credentials saved · Not yet verified';

  @override
  String get credExpiring => 'Token expires within 7 days';

  @override
  String get credExpired => 'Token expired';

  @override
  String get credRejected => 'Authentication failed · Update credentials';

  @override
  String get credVerified => 'Connection verified';

  @override
  String get errConfigDbTooNew =>
      'The local configuration database is from a newer version. Please update the App.';

  @override
  String get errConfigVersionKept =>
      'Incompatible configuration version; the original data is kept.';

  @override
  String get errInstanceMetaMismatch =>
      'The instance configuration does not match its metadata.';

  @override
  String get errInstanceQuarantined =>
      'The instance configuration is incompatible or damaged; it was isolated and the original data kept.';

  @override
  String get errInstanceNoOverwrite =>
      'An instance configuration with an incompatible version cannot be overwritten.';

  @override
  String get errConfigChangedElsewhereEdit =>
      'The configuration was changed in another window. Reload before editing.';

  @override
  String get errConfigChangedDelete =>
      'The configuration was updated. Reload before deleting.';

  @override
  String get errDefaultInstanceChanged =>
      'The default instance setting was updated. Please reload.';

  @override
  String get errSettingsChangedElsewhere =>
      'Settings were changed in another window. Please reload.';

  @override
  String get pickerVideoAudio => 'Video and audio';

  @override
  String get pickerAllFiles => 'All files';

  @override
  String get errSeriesIdentityConflict =>
      'The series or season identity conflicts';

  @override
  String get errInfoChangedReload =>
      'The information changed. Reload and try again';

  @override
  String get errWorkIdConflict =>
      'Work ID conflict; manual confirmation needed';

  @override
  String get errInvalidFieldValue => 'Invalid field value';

  @override
  String get errPosterNotThisWork => 'The poster does not belong to this work';

  @override
  String get errRemoteConfigVersion =>
      'The remote access configuration has an incompatible version or unknown fields.';

  @override
  String get errRemoteOutboundCredential =>
      'The outbound and its credential must both be present.';

  @override
  String get errRemoteUuidPlacement =>
      'The UUID may only be stored in the credential.';

  @override
  String get errRemoteCredentialInvalid => 'Invalid remote credential.';

  @override
  String get errRemoteProxiesInvalid =>
      'Proxy names must be non-empty and unique, and remotePort must be a valid port.';

  @override
  String get errRemotePolicyUnsupported =>
      'The remote connection policy is not supported.';

  @override
  String get errRemoteLanNeedsHttps =>
      'Automatic LAN access needs an HTTPS endpoint and a paired certificate SHA-256.';

  @override
  String get errRemoteUnknownField => 'Unknown remote access field.';

  @override
  String get errRemoteChooseProxy =>
      'Choose the proxy to use for remote access.';

  @override
  String get errRemoteEndpoint =>
      'Remote access needs a valid HTTP(S) or SMB service endpoint.';

  @override
  String get errRemoteProxyRef =>
      'Invalid proxy name, remotePort or credential reference.';

  @override
  String get errRemoteProxyHost =>
      'Invalid proxy host or configuration length.';

  @override
  String get errRemoteTlsName => 'Invalid proxy TLS server name.';

  @override
  String get errRemoteNeedsVless =>
      'Pairing needs a VLESS TLS/REALITY outbound with certificate verification on.';

  @override
  String get errRemoteCaPrivateKey =>
      'The CA configuration cannot contain a private key.';

  @override
  String get errRemoteRealityPublic =>
      'The REALITY client stores only public parameters.';

  @override
  String get errRemoteAuthHeader =>
      'Transport auth headers cannot be written into the public route configuration.';

  @override
  String get errRemoteTlsField => 'Unsupported TLS configuration field.';

  @override
  String get errRemoteConfigTooLarge => 'The configuration is too large.';

  @override
  String get errRemoteInvalidJson =>
      'Not valid JSON. Paste the complete App configuration exported by Relay.';

  @override
  String get errRemoteAppConfigShape =>
      'The App configuration must be a JSON object with only “outbound” (object) and “proxies” (array).';

  @override
  String get errRemoteProxyShape =>
      'Each proxy must have only “name” (string) and “remotePort” (port).';

  @override
  String get errRemoteProxiesEmpty =>
      'Proxies cannot be empty and names must be unique.';

  @override
  String get errRemoteOutsideEndpoint =>
      'The request is outside the authorized service endpoint.';

  @override
  String get errRemoteCertMismatch =>
      'The service certificate does not match the paired identity.';

  @override
  String get errRemoteOutsidePaired =>
      'The connection is outside the paired service.';

  @override
  String get errRemoteLanUnreachable =>
      'The LAN service is unreachable or failed identity verification.';

  @override
  String get errRemoteCellularBlocked =>
      'Remote access over cellular is disabled, or the current network cannot be determined.';

  @override
  String get errRemoteCellularUnknown =>
      'Cannot determine the cellular state, so the remote connection was blocked.';

  @override
  String get errRemoteNoCore =>
      'This build lacks the remote connection core. Install a build that includes sing-box.';

  @override
  String get errRemoteNativeConfigTooLarge =>
      'The remote connection configuration is too large.';

  @override
  String get errRemoteCoreStart =>
      'The remote core failed to start. Check the route configuration.';

  @override
  String get rtDisabled => 'Disabled';

  @override
  String get rtUnchecked => 'Not checked';

  @override
  String get rtStarting => 'Starting';

  @override
  String get rtBlocked => 'Needs attention';

  @override
  String get rtError => 'Error';

  @override
  String get rtDraining => 'Finishing up';

  @override
  String get healthLastOk => 'Last connection succeeded';

  @override
  String get healthLocal => 'This device';

  @override
  String get plgDraining =>
      'New calls blocked; waiting for playback or tasks to finish';

  @override
  String plgDependencyBlocked(String name) {
    return 'The dependency “$name” is disabled or unavailable';
  }

  @override
  String get plgNoInstanceAdded => 'No instance added yet';

  @override
  String get plgAllInstancesDisabled => 'All instances are disabled';

  @override
  String get plgInstanceFailing => 'An instance failed to connect';

  @override
  String get plgSomeInstancesBlocked => 'Some instances need attention';

  @override
  String get plgNfoInstance => 'Adjacent file rules';

  @override
  String get plgNoTmdb => 'This build does not include TMDB settings';

  @override
  String get plgTmdbInstance => 'TMDB settings';

  @override
  String get plgTmdbNoToken => 'No access token configured';

  @override
  String get plgNoFfmpeg =>
      'This platform or build does not include FFmpeg media processing';

  @override
  String get plgFfmpegInstance => 'On-device processing';

  @override
  String get plgModelNotConfigured => 'No model or key configured';

  @override
  String get plgNoSources => 'This build does not include media sources';

  @override
  String get plgNoAsr => 'This build does not include speech recognition';

  @override
  String plgModelDetail(String model) {
    return 'Model $model';
  }

  @override
  String get plgLocalAsrUnavailable =>
      'The local recognition engine is unavailable';

  @override
  String get errTmdbTokenRequired => 'Configure a TMDB read access token';

  @override
  String get errQueryCancelled => 'The query was cancelled';

  @override
  String get errTmdbResponseTooLarge => 'The TMDB response is too large';

  @override
  String get errTmdbAuth => 'TMDB authentication failed. Update the token';

  @override
  String get errTmdbNotFound => 'The TMDB item does not exist';

  @override
  String get errTmdbRateLimited =>
      'TMDB is rate limiting requests. Try again later';

  @override
  String get errTmdbUnavailable => 'TMDB is temporarily unavailable';

  @override
  String get errTmdbRequestFailed => 'The TMDB request failed';

  @override
  String get errTmdbInvalidResponse => 'Invalid TMDB response format';

  @override
  String get errTmdbUnreachable => 'Cannot connect to TMDB. Check the network';

  @override
  String get errTmdbNoAttachments => 'TMDB does not read source attachments';

  @override
  String get errTmdbInvalidIds => 'Invalid TMDB ID or season/episode number';

  @override
  String get errIdentifySeriesFirst =>
      'Identify the series first, then choose the season and episode';

  @override
  String get errTmdbRefRequired => 'Details need a TMDB reference';

  @override
  String get errTmdbInvalidIdentity => 'Invalid TMDB item identity or title';

  @override
  String get errNfoRefRequired => 'NFO details need an attachment reference';

  @override
  String get errNfoParse => 'Could not parse the NFO';

  @override
  String get errNfoTooLarge => 'The NFO is larger than 1 MiB';

  @override
  String get errNfoDtd => 'DTD and entity declarations are not allowed in NFO';

  @override
  String get errNfoTooManyNodes => 'The NFO has too many nodes';

  @override
  String get errNfoTooDeep => 'The NFO is nested too deeply';

  @override
  String get errNfoType => 'Unsupported NFO item type';

  @override
  String get errNfoFieldTooLong => 'An NFO field is too long';

  @override
  String get errInvalidMetadataQuery => 'Invalid metadata query parameters';

  @override
  String get errMetadataQueryUnsupported =>
      'This metadata instance does not support that query';

  @override
  String get errMediaKindUnsupported =>
      'Metadata for this media type is not supported';

  @override
  String get errBackgroundIdentify => 'Background identification failed';

  @override
  String get errQueryStale => 'The query expired or was cancelled';

  @override
  String get errTmdbConfigChanged => 'The TMDB settings changed';

  @override
  String get errRequeryCandidates => 'Search for candidates again';

  @override
  String get errChooseEpisodeFirst =>
      'Choose a specific season and episode first';

  @override
  String get errCandidateNotThisQuery =>
      'The candidate does not belong to this query';

  @override
  String get errDetailIdentityMismatch => 'Detail identity does not match';

  @override
  String get errReloadCandidates => 'Reload the candidates';

  @override
  String get errInvalidLocalCandidate => 'Invalid local candidate';

  @override
  String get errChooseSeriesFirst => 'Choose a series first';

  @override
  String get errConfirmMatchFirst => 'Confirm the match first';

  @override
  String get errCatalogTooLarge =>
      'The catalog is too large. Narrow the metadata scope';

  @override
  String get errCursorStuck => 'The paging cursor did not advance';

  @override
  String get errEpisodeSeasonMissing => 'The episode\'s season does not exist';

  @override
  String get errSourceConfigChanged => 'The source configuration changed';

  @override
  String get errInvalidYear => 'Invalid year';

  @override
  String get catSourceBrowse => 'Browse folders';

  @override
  String get catSourceBrowseDesc => 'List this source\'s folders and files';

  @override
  String get catSourceResolve => 'Play';

  @override
  String get catSourceResolveDesc =>
      'Hand the selected item to the player, strictly bound to its instance';

  @override
  String get catSourceAttachments => 'Read attachments';

  @override
  String get catSourceAttachmentsDesc =>
      'Read small files such as NFO and external subtitles (size-limited)';

  @override
  String get catSearchMedia => 'Search media';

  @override
  String get catSearchMediaDesc => 'Search movies and shows on the server';

  @override
  String get catMetadataLookup => 'Metadata';

  @override
  String get catMetadataLookupDesc =>
      'Read metadata organized by the media server';

  @override
  String get catSourceWrite => 'Write new files';

  @override
  String get catSourceWriteDesc =>
      'Save App clips and external downloads as new files in a source folder; never overwrites existing files and requires confirmation';

  @override
  String get catSummaryLocal => 'Folders on this device or mounted';

  @override
  String get catSummarySmb => 'Windows shares and NAS SMB shares';

  @override
  String get catSummaryWebdav => 'WebDAV cloud drives or NAS folders';

  @override
  String get catSummaryFtp => 'FTP server folders';

  @override
  String get catSummarySftp => 'Server folders over SSH';

  @override
  String get catSummaryS3 => 'S3-compatible object storage buckets';

  @override
  String get catSummaryPlex => 'Plex media server';

  @override
  String get catSummaryJellyfin => 'Jellyfin media server';

  @override
  String get catSummaryEmby => 'Emby media server';

  @override
  String get catSummaryDlna => 'DLNA media servers on the local network';

  @override
  String get catDataLocal => 'Reads only the folders you authorize.';

  @override
  String get catDataRemote =>
      'The App connects from this device to the server you configured; file and folder names appear in AI chats (only when AI use is allowed).';

  @override
  String get catNfoName => 'NFO metadata';

  @override
  String get catNfoSummary => 'Reads .nfo files next to your media';

  @override
  String get catNfoToggle =>
      'Controlled by “Scraped metadata”; background scraping runs on its own and cannot be disabled separately yet.';

  @override
  String get catNfoCap => 'Local metadata';

  @override
  String get catNfoCapDesc => 'Match movie info by adjacent-file rules';

  @override
  String get catTmdbSummary =>
      'Look up movies and shows from The Movie Database';

  @override
  String get catTmdbToggle =>
      'Clear the access token to stop using it; background scraping runs on its own and cannot be disabled separately yet.';

  @override
  String get catTmdbData =>
      'Lookups send the parsed title and year to TMDB, never file contents.';

  @override
  String get catTmdbCap => 'Look up metadata';

  @override
  String get catTmdbCapDesc =>
      'Search and match movies and shows; the host does the writing';

  @override
  String get catFfmpegName => 'FFmpeg media processing';

  @override
  String get catFfmpegSummary =>
      'Snapshots, probing, transcoding and audio extraction';

  @override
  String get catFfmpegData =>
      'Processes media on this device; output is kept in the app folder.';

  @override
  String get catProbe => 'Probe';

  @override
  String get catProbeDesc => 'Read duration, codecs and tracks';

  @override
  String get catTranscode => 'Transcode';

  @override
  String get catTranscodeDesc => 'Transcode to a new file with a preset';

  @override
  String get catExtractAudio => 'Extract audio';

  @override
  String get catExtractAudioDesc =>
      'Export an audio track for recognition or saving';

  @override
  String get catSnapshot => 'Snapshot';

  @override
  String get catSnapshotDesc => 'Capture the frame at a given time';

  @override
  String get catAsrName => 'Speech recognition';

  @override
  String get catAsrSummary =>
      'Generate original-language subtitles and transcripts for videos';

  @override
  String get catAsrCapDesc =>
      'Generate original-language subtitles/transcripts; no translation';

  @override
  String get catLlmName => 'Chat model';

  @override
  String get catLlmSummary =>
      'Provides the large language model for the AI assistant';

  @override
  String get catLlmToggle =>
      'Configure or clear the model under “AI and models”; it never creates reasoning tools that call itself.';

  @override
  String get catLlmData =>
      'Chat content, page summaries and tool results are sent to the configured model service, which may cost money.';

  @override
  String get catLlmCap => 'Chat reasoning';

  @override
  String get catLlmCapDesc =>
      'Generate replies and tool calls for the AI assistant';

  @override
  String get catCategorySource => 'Media sources';

  @override
  String get catCategoryMetadata => 'Metadata';

  @override
  String get catCategoryMediaProcessing => 'Media processing';

  @override
  String get catCategorySpeech => 'Subtitle recognition';

  @override
  String get catLocationNetwork => 'Network storage';

  @override
  String get catLocationSelfHosted => 'Self-hosted service';

  @override
  String get catLocationCloudApi => 'Cloud API';

  @override
  String get webSearchPresetName => 'Web search';

  @override
  String get errAssistantConfig =>
      'Enter a valid HTTPS API base URL (http only for a server on this device, such as http://localhost:11434/v1), model and output limit (128–16384)';

  @override
  String get errExtRootAddress =>
      'Enter the service root address, e.g. https://bt.example.com';

  @override
  String get errExtHttpsRequired =>
      'Public addresses must use HTTPS; HTTP is only allowed for LAN or local addresses';

  @override
  String get errExtTokenRequired => 'Please enter the access token';

  @override
  String get errExtTimeout => 'Connection timed out';

  @override
  String get errExtUnreachable => 'Cannot connect to this address';

  @override
  String get errExtTls => 'TLS certificate verification failed';

  @override
  String get errExtTooLarge => 'The service returned too much data';

  @override
  String errExtRejected(String reason) {
    return 'The service rejected the request: $reason';
  }

  @override
  String errExtError(String code) {
    return 'The service returned an error ($code)';
  }

  @override
  String get errExtTokenInvalid => 'Invalid access token';

  @override
  String get errExtNoMcp => 'This address does not offer an MCP endpoint';

  @override
  String get errArtworkCancelled => 'Image loading was cancelled';

  @override
  String get errArtworkQuota => 'Not enough image cache space';

  @override
  String get errArtworkUnauthorized => 'The image address is not authorized';

  @override
  String get errArtworkTypeSize => 'Invalid image type or size';

  @override
  String get errArtworkEmptyOrLarge => 'The image is empty or too large';

  @override
  String get errArtworkContentType => 'Unsupported image content type';

  @override
  String get errArtworkDecodeSize => 'The decoded image is too large';

  @override
  String get errArtworkWait => 'Wait for the image to finish loading';

  @override
  String get errLibraryClosing => 'The library is closing';

  @override
  String get errNameRequired => 'Please enter a name';

  @override
  String get errSeasonCycle =>
      'The source returned a circular season/episode relation';

  @override
  String get errInvalidPagingShort => 'Invalid paging';

  @override
  String get errTitleRequired => 'Please enter a title';

  @override
  String get errScanRunning => 'A scan is already running';

  @override
  String get errFileSourceMissing => 'The file source does not exist';

  @override
  String get errFileSourceDisabled => 'The file source is disabled';

  @override
  String get errSourceScanDisabled => 'Scanning is not enabled for this source';

  @override
  String get errScanTooLarge => 'The scan scope is too large. Narrow it down';

  @override
  String get errScanBindingChanged =>
      'The source or binding changed. Please scan again';

  @override
  String get errSourceIdentityMismatch => 'Source identity does not match';

  @override
  String get errSourceCursorStuck => 'The source paging cursor did not advance';

  @override
  String get errScanIncomplete =>
      'The scan did not finish. Check the source and try again';

  @override
  String get aiToolContextGet => 'Read current page';

  @override
  String get aiToolSourceList => 'List media sources';

  @override
  String get aiToolSourceBrowse => 'Browse folder';

  @override
  String get aiToolLibraryQuery => 'Query library';

  @override
  String get aiToolMediaGet => 'View media details';

  @override
  String get aiToolSearchMedia => 'Search media';

  @override
  String get aiToolProgressQuery => 'View watch progress';

  @override
  String get aiToolPlaybackGet => 'Read playback state';

  @override
  String get aiToolPlaybackOpen => 'Open playback';

  @override
  String get aiToolPlaybackPause => 'Pause';

  @override
  String get aiToolPlaybackResume => 'Resume playback';

  @override
  String get aiToolPlaybackStop => 'Stop playback';

  @override
  String get aiToolPlaybackSeek => 'Seek';

  @override
  String get aiToolPlaybackSetSpeed => 'Set speed';

  @override
  String get aiToolPlaybackSetVolume => 'Set volume';

  @override
  String get aiToolPlaybackSetSubtitle => 'Set subtitles';

  @override
  String get aiToolMediaProcessingCapabilities =>
      'Query media processing capabilities';

  @override
  String get aiToolMediaProbe => 'Analyze media';

  @override
  String get aiToolMediaTranscode => 'Transcode / clip';

  @override
  String get aiToolMediaExtractAudio => 'Extract audio';

  @override
  String get aiToolMediaSnapshot => 'Snapshot';

  @override
  String get aiToolMediaSaveToSource => 'Save back to source';

  @override
  String get aiToolTaskGet => 'Query processing task';

  @override
  String get aiToolTaskList => 'List processing tasks';

  @override
  String get aiToolTaskCancel => 'Cancel processing task';

  @override
  String get aiToolTaskRetry => 'Retry processing task';

  @override
  String get aiToolSpeechRecognitionStatus => 'Query speech recognition status';

  @override
  String get aiToolSubtitleGenerate => 'Recognize subtitles';

  @override
  String get aiToolTranscriptGenerate => 'Generate transcript';

  @override
  String get aiToolSubtitleTaskGet => 'Query subtitle task';

  @override
  String get aiToolSubtitleTaskCancel => 'Cancel subtitle task';

  @override
  String get aiToolSubtitleSave => 'Save subtitles';

  @override
  String get aiToolPluginStatus => 'View plugin status';

  @override
  String get aiToolMcpTavilyWebSearch => 'Web search';

  @override
  String get aiToolWebFetch => 'Read web page';

  @override
  String get aiArgQuery => 'Query';

  @override
  String get aiArgUrl => 'URL';

  @override
  String get aiArgRange => 'Range';

  @override
  String get aiArgEnd => 'end';

  @override
  String get aiArgWholeMedia => 'whole media';

  @override
  String get aiArgTime => 'Time';

  @override
  String get aiArgPosition => 'Position';

  @override
  String get aiArgPreset => 'Preset';

  @override
  String get aiArgLanguage => 'Language';

  @override
  String get aiArgFormat => 'Format';

  @override
  String get aiArgSpeed => 'Speed';

  @override
  String get aiArgVolume => 'Volume';

  @override
  String get aiArgSwitch => 'Switch';

  @override
  String get aiArgOff => 'off';

  @override
  String get aiArgWait => 'Wait';

  @override
  String get aiToolInput => 'INPUT';

  @override
  String get aiToolOutput => 'OUTPUT';

  @override
  String get aiActivityThinking => 'Thinking';

  @override
  String get aiActivityAnswering => 'Replying';

  @override
  String get aiActivityRunningDefault => 'Running';

  @override
  String get aiReasoningStreaming => 'Thinking...';

  @override
  String get aiReasoningDone => 'Thought';

  @override
  String get aiReasoningUnderSecond => 'Thought for less than a second';

  @override
  String get aiStillRunning =>
      'Wait timed out; the task is still running in the background';

  @override
  String get aiStatusQueued => 'queued';

  @override
  String get aiStatusPreparing => 'preparing';

  @override
  String get aiStatusRunning => 'running';

  @override
  String get aiStatusCancelling => 'cancelling';

  @override
  String get aiStatusSucceeded => 'succeeded';

  @override
  String get aiStatusFailed => 'failed';

  @override
  String get aiStatusCancelled => 'cancelled';

  @override
  String get aiStatusInterrupted => 'interrupted';

  @override
  String get aiStageExtracting => 'extracting';

  @override
  String get aiStageUploading => 'uploading';

  @override
  String get aiStageQueued => 'queued';

  @override
  String get aiStageTranscribing => 'transcribing';

  @override
  String get aiStageFormatting => 'formatting';

  @override
  String aiArgWaitValue(String seconds) {
    return 'wait ≤${seconds}s';
  }

  @override
  String aiStepPreparing(String name) {
    return 'Preparing $name...';
  }

  @override
  String aiStepRunning(String name) {
    return 'Executing $name...';
  }

  @override
  String aiStepWaiting(String name) {
    return 'Allow $name?';
  }

  @override
  String aiStepFailed(String name) {
    return '$name failed';
  }

  @override
  String aiStepCancelled(String name) {
    return 'Cancelled $name';
  }

  @override
  String aiShowAll(int count) {
    return 'Show all ($count characters)';
  }

  @override
  String aiActivityPreparingTool(String name) {
    return 'Preparing: $name';
  }

  @override
  String aiActivityTool(String name) {
    return 'Running: $name';
  }

  @override
  String aiActivityConfirm(String name) {
    return 'Waiting for you: $name';
  }

  @override
  String aiStepNumber(int step) {
    return 'step $step';
  }

  @override
  String aiReasoningSeconds(int seconds) {
    return 'Thought for $seconds seconds';
  }

  @override
  String aiReasoningMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: 'a minute',
    );
    return 'Thought for $_temp0';
  }

  @override
  String get cloudJianguoyun => 'Jianguoyun';

  @override
  String get cloud123 => '123 Cloud Drive';

  @override
  String get cloudJianguoyunHelp =>
      'Use your account and a third-party app password. The default WebDAV folder can be changed.';

  @override
  String get cloud123Help =>
      'Enable WebDAV in your 123 account first. Enter the exact URL and credentials supplied by the official console; availability depends on your plan.';

  @override
  String get cloudPreset => 'WebDAV preset';

  @override
  String get cloudCustom => 'Custom WebDAV';

  @override
  String get catSummaryCloudDrive =>
      'Browse and play files in your cloud drive.';

  @override
  String get cloudSignIn => 'Sign in with browser';

  @override
  String get cloudSignInHelp =>
      'Read-only access. Choose the root folder below. To fully disconnect OneDrive, also remove this app in your Microsoft account permissions.';

  @override
  String get cloudNotConfigured =>
      'Cloud sign-in is unavailable in this build. The publisher must configure an OAuth application.';

  @override
  String get cloudSignInFailed => 'Cloud sign-in failed. Please try again.';

  @override
  String get cloudCallbackInvalid =>
      'The authorization callback could not be verified.';

  @override
  String get cloudRoot => 'Selected root folder';

  @override
  String get cloudRootHelp =>
      'Open a folder to select it as the root. Only files below this folder will be browsed and scanned.';

  @override
  String get cloudReauthorize =>
      'Authorization expired or was revoked. Please sign in again.';

  @override
  String get cloudPersonalOnly =>
      'Only personal OneDrive accounts are supported.';

  @override
  String get cloudDisconnect => 'Disconnect account';

  @override
  String get cloudDisconnectHelp =>
      'Clears local credentials and stops cloud requests. Also remove this app in your Microsoft or Dropbox account permissions to revoke the platform grant.';

  @override
  String get plSwitchToLandscape => 'Switch to landscape';

  @override
  String get plSwitchToPortrait => 'Switch to portrait';

  @override
  String get followSystemOrientation => 'Follow system orientation';

  @override
  String get aiUsePlatform => 'Use platform default service';

  @override
  String get aiUsePlatformHint =>
      'Ready to use. No API address, model, or key needed.';

  @override
  String get aiPlatformService => 'Platform service';

  @override
  String get aiPlatformPrivacy =>
      'Your messages are sent to the platform AI service. Daily usage limits apply.';

  @override
  String get aiCustomService => 'Bring your own service';

  @override
  String get aiCustomServiceHint =>
      'Turn off the default service to use your own API. Your settings are kept when switching.';

  @override
  String get detailVideoFile => 'Video file';

  @override
  String get detailNoCatalogInfo =>
      'No movie or TV details yet. This video can be played directly.';

  @override
  String get detailPlaybackProgress => 'Playback progress';

  @override
  String get detailFiles => 'Video files';

  @override
  String get baiduPermissionDenied =>
      'Baidu Netdisk denied playback or file access. Check this account’s permissions, download entitlement and the app’s approved access.';

  @override
  String get baiduAllFiles => 'Select all files';

  @override
  String get voiceSettings => 'Voice transcription';

  @override
  String get voiceSettingsHint =>
      'Independent OpenAI transcription endpoint, model and API key. Audio is sent to this service only after you stop recording. Stop to insert the text for review, or use send to transcribe and send it right away. Android, iOS, macOS and Windows support recording; other platforms are currently unsupported.';

  @override
  String get voiceSettingsError =>
      'Check the transcription address, model and API key in settings. The key must be saved in secure local storage.';

  @override
  String get voiceStart => 'Start voice input';

  @override
  String get voiceStop => 'Stop and transcribe';

  @override
  String get voiceSend => 'Transcribe and send';

  @override
  String get voiceRecording =>
      'Recording… Click stop to transcribe, or cancel to discard.';

  @override
  String get voiceTranscribing => 'Transcribing…';

  @override
  String get voicePreparing => 'Preparing microphone…';

  @override
  String get voiceUnsupported =>
      'Voice recording is not supported on this platform or device.';

  @override
  String get voicePermission =>
      'Microphone permission denied. Allow microphone access in system settings and try again.';

  @override
  String get voiceEmpty => 'No speech was recognized. Please try again.';

  @override
  String get voiceTooLarge =>
      'The recording is too large. Please record a shorter message.';

  @override
  String get voiceRecordingError =>
      'Could not record audio. Check your microphone and try again.';

  @override
  String get voiceTranscriptionError =>
      'Transcription failed. Check your network and transcription settings, then try again.';

  @override
  String get addVideo => 'Add videos';

  @override
  String get addAndShowHome => 'Add and show on Home';

  @override
  String get homeScanScope => 'Video folder or library';

  @override
  String get homeScanScopeHelp =>
      'Videos in this scope and its subfolders will appear on Home. Choose a share, bucket or library next if needed.';

  @override
  String get homeSavedConnections => 'Saved connections';

  @override
  String get homeBindingFailed =>
      'Connection saved, but videos have not been added to Home. Retry here or choose the saved connection from Add videos.';

  @override
  String homeFindingVideos(int count) {
    return 'Finding videos · $count found';
  }

  @override
  String get homeScanInterrupted =>
      'Scan interrupted. Videos already found are available.';

  @override
  String get homeNoVideos => 'No videos found in this scope.';

  @override
  String get homeAdjustScope => 'Choose another folder';

  @override
  String get remotePlatformTitle => 'Platform default';

  @override
  String get remotePlatformHint =>
      'Sign in to load platform Relay nodes and services granted to this device.';

  @override
  String get remotePlatformLogin => 'Sign in';

  @override
  String get remotePlatformLogout => 'Sign out';

  @override
  String get remotePlatformRestore => 'Use platform default';

  @override
  String get remotePlatformActive => 'Using platform configuration';

  @override
  String get remoteCustomActive => 'Using custom configuration';

  @override
  String get remotePlatformEmail => 'Account email';

  @override
  String get remotePlatformAutomatic =>
      'Chosen automatically by your Connector';

  @override
  String get remotePlatformNode => 'Relay node';

  @override
  String get remotePlatformEmpty =>
      'No ready platform nodes. Refresh after an administrator enables a node.';

  @override
  String get remotePlatformNoServices =>
      'No services are granted to this device yet.';

  @override
  String get remotePlatformExpired =>
      'Platform configuration needs refreshing. The last configuration remains in use.';

  @override
  String remotePlatformRequestFailed(String code) {
    return 'Platform request failed: $code';
  }

  @override
  String get remotePlatformNodeUnavailable =>
      'Waiting for your Connector to report its node';

  @override
  String get remoteNodeTest => 'Test nodes';

  @override
  String get remoteNodeTestHint =>
      'Tests TCP/TLS reachability from this device only, not Home service availability. The node is chosen by your Connector and followed automatically.';

  @override
  String get remoteNodeUnreachable => 'Unreachable';

  @override
  String remoteNodeLatency(int ms) {
    return '$ms ms';
  }

  @override
  String get remotePlatformNotLoaded =>
      'Platform configuration has not loaded. Refresh to try again.';

  @override
  String get remotePlatformRegister => 'Register platform account';

  @override
  String get remotePlatformRegisterHint =>
      'Enter your email. We\'ll send a 6-digit verification code to finish registering here.';

  @override
  String get remotePlatformSendRegistration => 'Send verification code';

  @override
  String get remotePlatformRegistrationSent =>
      'If this email can be registered, a verification code has been sent. Check your inbox and spam folder.';

  @override
  String remotePlatformCodeSentTo(String email) {
    return 'Enter the 6-digit code sent to $email and set a password. The code expires in 30 minutes.';
  }

  @override
  String get remotePlatformCode => 'Verification code';

  @override
  String get remotePlatformNewPassword => 'Password (at least 12 characters)';

  @override
  String get remotePlatformConfirmPassword => 'Confirm password';

  @override
  String get remotePlatformCompleteRegistration => 'Create account';

  @override
  String get remotePlatformResendCode => 'Resend code';

  @override
  String remotePlatformResendCodeIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get remotePlatformChangeEmail => 'Change email';

  @override
  String get remotePlatformInvalidCode => 'The verification code is incorrect.';

  @override
  String get remotePlatformCodeExpired =>
      'This code has expired or had too many wrong attempts. Send a new code.';

  @override
  String get remotePlatformPasswordTooShort =>
      'Password must be at least 12 characters.';

  @override
  String get remotePlatformPasswordMismatch => 'Passwords do not match.';

  @override
  String get remotePlatformRegistered =>
      'Account created. Sign in with your new password.';

  @override
  String get remotePlatformInvalidEmail => 'Enter a valid email address.';

  @override
  String get remoteTabCloud => 'Cloud';

  @override
  String get remoteTabLocal => 'Local import';

  @override
  String get remoteModeActive => 'In use';

  @override
  String get remoteModeInactive => 'Not in use';

  @override
  String get remoteCloudInactiveHint =>
      'The local import is in use. Enable the cloud configuration to switch; the local import then stops working.';

  @override
  String get remoteLocalInactiveHint =>
      'The cloud configuration is in use. Enable the local import to switch; the cloud configuration then stops working.';

  @override
  String get remoteLocalEmptyHint =>
      'Import a configuration exported by Relay. Importing switches to it right away and the cloud configuration stops working.';

  @override
  String get remoteEnableCloud => 'Enable cloud configuration';

  @override
  String get remoteEnableLocal => 'Enable local import';

  @override
  String get remoteEnableCloudConfirmTitle =>
      'Switch to the cloud configuration?';

  @override
  String get remoteEnableCloudConfirmMessage =>
      'The local import will stop working. It stays saved on this device, so you can switch back at any time.';

  @override
  String get remoteEnableLocalConfirmTitle => 'Switch to the local import?';

  @override
  String get remoteEnableLocalConfirmMessage =>
      'The cloud configuration will stop working. Your account stays signed in, so you can switch back at any time.';

  @override
  String get remoteImportReplaceCloudTitle => 'Import and switch to it?';

  @override
  String get remoteImportReplaceCloudMessage =>
      'The imported configuration takes effect right away and the cloud configuration stops working. You can switch back on the Cloud tab.';

  @override
  String get remoteClearActiveMessage =>
      'Removes the local import and its credentials from this device. Remote access switches to the cloud configuration.';

  @override
  String get remoteSwitched => 'Switched.';

  @override
  String get remoteSwitch => 'Switch';

  @override
  String get tmdbCloudHint =>
      'Use OpenPlayX cloud to look up movies and shows without a TMDB token. Titles, years, IDs and language are sent through OpenPlayX to TMDB; videos and private paths stay on this device.';

  @override
  String get tmdbLocalHint =>
      'Connect directly to TMDB using your own read access token. The token is saved on this device.';

  @override
  String get voiceCloudHint =>
      'Use OpenPlayX cloud transcription without an API key. Recorded audio is sent through OpenPlayX to OpenAI to turn it into text.';

  @override
  String get voiceConnectionOk =>
      'Connected. The transcription service accepted the test audio.';

  @override
  String get voiceConnectionTimeout =>
      'The connection test timed out. Check the endpoint and network, then try again.';

  @override
  String get voiceConnectionTestHint =>
      'Test connection sends one second of generated silence to this service using the current configuration. It does not use the microphone or save changes.';

  @override
  String get llmModelSettings => 'LLM Model';

  @override
  String get whisperModelSettings => 'Whisper Model';

  @override
  String get settingsPlayer => 'Player';

  @override
  String get settingsSubtitles => 'Subtitles';

  @override
  String get connectorSources => 'From Connector';

  @override
  String get connectorSourceDiscovered =>
      'Discovered automatically. Sign in to choose a folder.';

  @override
  String get connectorSourceLogin => 'Sign in and connect';

  @override
  String get connectorSourceSetup => 'Connect service';

  @override
  String get connectorSourceManaged =>
      'Service settings are managed by Connector. Login and folders stay on this device.';

  @override
  String get connectorSourceHide => 'Hide on this device';

  @override
  String get connectorSourceHideHelp =>
      'This hides the source from this list. Login and folders are kept, and existing home content remains available. Disable the connection to stop using it.';

  @override
  String get connectorSourcesHidden => 'Hidden sources';

  @override
  String get connectorSourceRestore => 'Restore';

  @override
  String get connectorSourceNoneHidden => 'No hidden sources';

  @override
  String get connectorSourceDisabled => 'Service disabled';

  @override
  String get connectorSourceRemoved => 'Service removed';

  @override
  String get connectorSourceSync => 'Sync sources';

  @override
  String get connectorSourceSyncFailed =>
      'Could not sync. Your last successful source list is retained.';

  @override
  String get connectorSourceConnectionSettings => 'Connection settings';

  @override
  String get connectorSourceLoginHelp =>
      'Use the media server account. Leave both fields empty for guest access when supported.';

  @override
  String get connectorSourceRemoteOnlyHelp =>
      'This service currently uses remote access. SMB LAN switching requires a supported secure local transport.';

  @override
  String get connectorSourcePending => 'Not connected yet';

  @override
  String get connectorSourceLan => 'LAN connection';

  @override
  String get connectorSourceRemote => 'Remote connection';

  @override
  String get connectorSourceLoginDiscover => 'Sign in to discover sources';

  @override
  String get connectorSourceDetails => 'Service details';

  @override
  String get connectorSourceAccount => 'Account verification required';

  @override
  String get connectorSourceProtocolChanged =>
      'Service type changed. Set up the connection again.';

  @override
  String get connectorSourceNotReady =>
      'Connector has not reported an available route yet.';

  @override
  String get connectorSourceClearLocal => 'Clear device configuration';

  @override
  String get connectorSourceClearLocalHelp =>
      'Only this device’s login and folder configuration is cleared. The Connector service remains published. This source will be hidden; restore it to set it up again.';

  @override
  String get asrPlatform => 'Groq (free, default)';

  @override
  String get asrPlatformHint =>
      'No setup or sign-in. Selected audio is uploaded through OpenPlayX to Groq V3. Availability is subject to service limits.';

  @override
  String get asrLocal => 'Local model download';

  @override
  String get asrCustom => 'Custom API';

  @override
  String get asrCustomHint =>
      'Use your own OpenAI-compatible API or OpenPlayX ASR service.';

  @override
  String get asrProtocol => 'API protocol';

  @override
  String get asrGenerateWhole => 'Generate full subtitles';

  @override
  String asrChunkProgress(String done, String total) {
    return 'Completed $done of $total; completed chunks are reused on retry.';
  }

  @override
  String get asrBusyRetry =>
      'Service is busy. Retry to continue from completed chunks.';

  @override
  String get asrPlatformUnavailable =>
      'Platform allowance reached. Retry later or choose another service.';

  @override
  String get plPictureInPicture => 'Picture in picture';

  @override
  String get plExitPictureInPicture => 'Exit picture in picture';

  @override
  String get plPictureInPictureFailed =>
      'Unable to enter picture in picture. Please try again.';
}
