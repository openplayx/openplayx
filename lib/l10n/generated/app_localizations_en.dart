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
  String get plugins => 'AI';

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
      'Separate with commas. Only matching files appear in preview and are added to the library. Leave blank to keep every file. Hidden files starting with a dot are always skipped.';

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
    return 'This binding links $count items. Remove automatic memberships only when no source evidence remains. Manual memberships, shared media and files are kept.';
  }

  @override
  String sourceVersion(String kind, String plugin, int config, int revision) {
    return '$kind · Plugin $plugin · Config v$config · r$revision';
  }

  @override
  String disableSourceDescription(int playing, int running) {
    return '$playing playing, $running requests. New requests will be rejected. Current playback can finish. Configuration and favorites are kept.';
  }

  @override
  String deleteSourceDescription(int playing, int running) {
    return 'Remove this source configuration and credential reference. Files and favorites are kept. $playing playing items and $running requests can finish before connections are released.';
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
  String get aiAssistant => 'AI assistant';

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
      'Any OpenAI-compatible API, e.g. DeepSeek. The key is stored in the system keychain.';

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
  String get diagnosticsTitle => 'Send diagnostics';

  @override
  String get diagnosticsDescription =>
      'Optional error reports to the configured Sentry service: app version and sanitized error stacks. No media paths, credentials or chat content. Enabling takes effect after restart; disabling stops new reports in all windows and background tasks. Native crashes are not collected yet.';

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
  String get removeFavorite => 'Remove from favorites';

  @override
  String get aiMore => 'More';

  @override
  String get aiGreeting => 'What can I help with?';

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
  String get asrWholeTitle => 'Process the whole episode?';

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
  String get sourceConnectionDetails => 'Connection details';

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
}
