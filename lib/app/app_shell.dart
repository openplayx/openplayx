import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../ui/components/states/content_state.dart';
import '../ui/adaptive/app_page.dart';

import 'package:openplayx_playback/playback.dart';

import '../core/capabilities/source_capability.dart';
import '../core/models/text_model.dart';
import '../data/files/local_media_picker.dart';
import '../capabilities/playback/playback_launcher.dart';
import '../capabilities/sources/source_manager.dart';
import '../features/library/view/home_page.dart';
import 'app_destination.dart';
import '../features/player/view/player_page.dart';
import '../features/sources/view/source_page.dart';
import '../capabilities/artwork/artwork_service.dart';
import '../capabilities/library/library_service.dart';
import '../capabilities/metadata/metadata_runtime.dart';
import 'app_navigation.dart';
import '../features/settings/settings_page.dart';
import '../features/assistant/view/plugins/plugin_management_page.dart';
import 'player_window.dart';
import '../ui/tokens/app_motion.dart';
import '../ui/tokens/app_spacing.dart';
import '../ui/theme/app_theme.dart';

import '../assistant/plugins/library/media_tools.dart';
import '../capabilities/speech/asr_backend_config.dart';
import '../capabilities/speech/asr_model_store.dart';
import '../capabilities/speech/subtitle_generation_service.dart';
import '../capabilities/media_processing/media_processing_service.dart';
import '../assistant/plugins/external/external_service_registry.dart';
import '../capabilities/metadata/tmdb_credentials.dart';
import '../assistant/assistant_module.dart';
import '../assistant/playback_port.dart';
import '../assistant/plugins/plugin_manager.dart';
import '../assistant/conversation/assistant_store.dart';
import '../assistant/conversation/conversation_coordinator.dart';
import '../features/assistant/view/assistant_page.dart';
import '../features/assistant/controller/ai_chat_controller.dart';
import '../features/assistant/view/ai_chat_panel.dart';
import '../ui/icons/app_icons.dart';
import '../ui/adaptive/assistant_action.dart';
import '../ui/components/feedback/app_feedback.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.sources,
    this.library,
    this.backend,
    this.assistantModel,
    this.pickMedia = pickLocalMedia,
  });
  final SourceManager? sources;
  final LibraryService? library;
  final PlayerBackend? backend;
  final Future<TextModelCapability> Function()? assistantModel;
  final Future<LocalMedia?> Function() pickMedia;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  AppLocalizations get l => AppLocalizations.of(context);
  late final _sources = widget.sources ?? SourceManager();
  late final _launcher = PlaybackLauncher(_sources);
  final _revision = ValueNotifier(0);
  final _player = GlobalKey<PlayerPageState>();
  final _branches = List.generate(
    AppDestination.values.length,
    (_) => GlobalKey<NavigatorState>(),
  );
  // Page depth per tab; the bottom bar only shows on a tab's root page.
  late final _depths = List.generate(
    AppDestination.values.length,
    (_) => _PageDepthObserver(_depthChanged),
  );
  LibraryService? _library;
  MetadataRuntime? _metadataRuntime;
  ArtworkService? _artwork;
  AssistantModule? _assistantModule;
  AssistantStore? get _assistantStore => _assistantModule?.store;
  ConversationCoordinator? get _assistant => _assistantModule?.coordinator;
  AiChatController? _chat;
  MediaTools? get _mediaTools => _assistantModule?.mediaTools;
  MediaProcessingService? _mediaProcessing;
  SubtitleGenerationService? _subtitles;
  PluginManager? _plugins;
  PlayerBackend? _backend;
  // Desktop playback opens in its own window; tests inject a backend and keep
  // the embedded player.
  late final PlayerWindows? _playerWindows =
      widget.backend == null && supportsPlayerWindow ? PlayerWindows() : null;
  int _destination = 0;
  // The plugin branch is built on first visit, so its status refresh does not
  // run behind the home page at startup.
  bool _pluginsVisited = false;
  final _pluginsKey = GlobalKey<PluginManagementPageState>();
  PluginGroup? _pluginsInitialGroup;
  bool _showPlayer = false;
  bool _opening = false;
  bool _exitingPlayer = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sources.networkChanged();
  }

  Future<void> _load() async {
    try {
      final library = widget.library ?? await LibraryService.open();
      if (!mounted) {
        if (widget.library == null) library.close();
        return;
      }
      // The library drops what a removed connection brought in.
      library.followSources(_sources);
      setState(() {
        _library = library;
        final media = _mediaProcessing = MediaProcessingService(
          db: library.db,
          sources: _sources,
          root: MediaProcessingService.defaultRoot(),
          switches: _sources.switches,
        );
        MediaProcessingService.current = media;
        unawaited(media.recover().catchError((_) {}));
        try {
          final subtitles = _subtitles = SubtitleGenerationService(
            db: library.db,
            media: media,
            backends: AsrBackendRegistry(
              db: library.configuration,
              models: AsrModelStore(asrModelRoot()),
            ),
            root: SubtitleGenerationService.defaultRoot(),
            switches: _sources.switches,
          );
          SubtitleGenerationService.current = subtitles;
          unawaited(subtitles.recover().catchError((_) {}));
        } catch (_) {
          // Optional: subtitle generation must not block playback.
          _subtitles = null;
        }
        // Plugin Manager: the AI's view of the capabilities above, following
        // their App-wide switches.
        final plugins = _plugins = PluginManager(
          sources: _sources,
          asr: () => _subtitles?.backends,
          media: () => _mediaProcessing,
          tmdbConfigured: () async {
            try {
              return library.metadata.setting(tmdbTokenKey).trim().isNotEmpty;
            } catch (_) {
              return false;
            }
          },
          model: () {
            final store = _assistantStore;
            if (store == null) return null;
            final config = store.loadConfig();
            final host = Uri.tryParse(config.endpoint)?.host ?? '';
            return (
              host.isEmpty ? config.model : '${config.model} · $host',
              config.configured,
            );
          },
        );
        unawaited(plugins.refresh().catchError((_) {}));
        _artwork = ArtworkService(
          _sources,
          retainedArtwork: () => library.metadata.retainedArtwork,
        );
        _metadataRuntime = MetadataRuntime(library, _sources);
        unawaited(_metadataRuntime!.start());
        _backend =
            widget.backend ??
            (LibVlcBackend.isSupported ? LibVlcBackend() : null);
        _error = null;
        try {
          _initializeAssistant(library);
        } catch (_) {
          // Optional AI storage must not prevent traditional playback.
          _assistantModule = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = l.libraryOpenFailed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_metadataRuntime?.dispose());
    _artwork?.dispose();
    _chat?.dispose();
    _assistantModule?.dispose();
    _plugins?.dispose();
    if (SubtitleGenerationService.current == _subtitles) {
      SubtitleGenerationService.current = null;
    }
    _subtitles?.dispose();
    if (MediaProcessingService.current == _mediaProcessing) {
      MediaProcessingService.current = null;
    }
    _mediaProcessing?.dispose();
    _revision.dispose();
    if (widget.library == null) _library?.close();
    if (widget.sources == null) unawaited(_sources.dispose());
    super.dispose();
  }

  PageContextSource? _originPage;

  Map<String, dynamic> _aiContext() => {
    'pageContext':
        _originPage?.read() ??
        PageContextData(
          pageType: _showPlayer
              ? 'player'
              : AppDestination.values[_destination].name,
        ).toJson(),
    'page': _showPlayer ? 'player' : AppDestination.values[_destination].name,
    'playback':
        _playerWindows?.lastSnapshot ??
        _player.currentState?.assistantSnapshot() ??
        {'status': 'idle'},
  };

  Future<Map<String, dynamic>> _playbackSnapshot({
    bool waitForSession = false,
  }) async {
    if (_playerWindows?.hasActive ?? false) {
      return _playerWindows!.snapshot(waitForSession: waitForSession);
    }
    return _player.currentState?.assistantSnapshot() ?? {'status': 'idle'};
  }

  void _initializeAssistant(LibraryService library) {
    final module = _assistantModule = AssistantModule(
      library: library,
      sources: _sources,
      context: _aiContext,
      playback: _backend == null ? null : _ShellPlayback(this),
      media: _mediaProcessing,
      subtitles: _subtitles,
      plugins: _plugins,
      model: widget.assistantModel,
    );
    _chat = AiChatController(module.coordinator);
  }

  /// Model settings live on the AI page's 模型 page.
  Future<void> _modelSettings() async {
    if (_assistantStore == null || (_assistant?.busy ?? false)) return;
    // The chat page (root route) closes first, otherwise it would cover the page.
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    final ai = AppDestination.plugins.index;
    _pluginsInitialGroup = PluginGroup.model;
    _branches[ai].currentState?.popUntil((r) => r.isFirst);
    _pluginsKey.currentState?.showGroup(PluginGroup.model);
    if (_destination != ai) _select(ai);
  }

  Widget _assistantView({VoidCallback? onBack}) => AssistantView(
    onBack: onBack,
    coordinator: _assistant!,
    controller: _chat,
    // toolsSupported records a connection probe, not a user permission.
    // A skipped/failed/stale probe must not silently turn actions into chat.
    // The registry and gateway still enforce per-plugin AI permissions.
    toolsEnabled: () => _assistant!.configured,
    onSettings: _modelSettings,
    onOpenMedia: _openChatMedia,
  );

  Future<void> _openChatMedia(Map<String, dynamic> item) async {
    SourceEntry? entry;
    if (item['ref'] is String) {
      entry = _mediaTools!.entryForReference(item['ref'] as String);
    }
    if (item['media_id'] is String || item['resource_id'] is String) {
      final resources = item['resource_id'] is String
          ? _library!.db.select('SELECT * FROM resources WHERE id=?', [
              item['resource_id'],
            ])
          : _library!.versions(item['media_id'] as String);
      if (resources.isEmpty || !mounted) {
        throw StateError('Resource unavailable');
      }
      String? id = resources.length == 1
          ? resources.single['id'] as String
          : null;
      id ??= await showShadDialog<String>(
        context: context,
        builder: (context) => ShadDialog(
          title: Text(l.chooseVersion),
          child: SizedBox(
            width: 480,
            height: 320,
            child: ListView(
              children: [
                for (final resource in resources)
                  ShadButton.ghost(
                    onPressed: () =>
                        Navigator.pop(context, resource['id'] as String),
                    child: Text(
                      MediaTools.safeText(resource['name'] as String),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      if (id == null) return;
      final fresh = _library!.db.select('SELECT * FROM resources WHERE id=?', [
        id,
      ]);
      if (fresh.isEmpty) throw StateError('Resource unavailable');
      final r = fresh.single;
      entry = SourceEntry(
        ResourceRef(r['source'] as String, r['item'] as String),
        r['name'] as String,
        isFolder: false,
      );
    }
    if (entry == null || entry.isFolder || !mounted) {
      throw StateError('Resource unavailable');
    }
    final selection = await _launcher.select(
      entry.ref,
      entry.name,
      entry: entry,
      wanted: () => mounted,
    );
    if (selection == null) return;
    _closeAssistant();
    await _play(selection);
  }

  Future<void> _openAssistant() => showAiChatPage(
    context,
    builder: (_, close) => _assistantView(onBack: close),
  );

  // Media opened from the chat plays in the shell, so leave the chat page.
  void _closeAssistant() => Navigator.of(
    context,
    rootNavigator: true,
  ).popUntil((r) => r.settings.name != aiChatRouteName && r is PageRoute);

  // Pages draw the assistant button in their own header (see AppPage), so it
  // moves with route transitions.
  Widget _withAssistant(Widget child) => _assistant == null
      ? child
      : AssistantAction(
          label: l.aiAssistant,
          onContext: (source) => _originPage = source,
          onPressed: _openAssistant,
          child: child,
        );

  // The player is not a route: there the button is overlaid in the top-right
  // corner, which the player top bar keeps free for it.
  Widget _playerAssistantButton(BuildContext context) => Positioned(
    top: MediaQuery.paddingOf(context).top + AppSpacing.md,
    right: AppSpacing.page(context).right,
    child: Tooltip(
      message: l.aiAssistant,
      child: Semantics(
        label: l.aiAssistant,
        button: true,
        // Dark theme so the icon stays visible over the (black) player.
        child: _withPlayerControls(
          ShadTheme(data: AppTheme.dark, child: _assistantIcon()),
        ),
      ),
    ),
  );

  // Over the player the button shows and hides together with its controls.
  Widget _withPlayerControls(Widget child) {
    final visibility = _player.currentState?.controlsVisibility;
    if (visibility == null) return child;
    return ValueListenableBuilder<bool>(
      valueListenable: visibility,
      builder: (context, visible, child) => IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: AppMotion.duration(context, AppMotion.controls),
            child: child,
          ),
        ),
      ),
      child: child,
    );
  }

  Widget _assistantIcon() => ShadIconButton.ghost(
    width: AppPage.headerHeight,
    height: AppPage.headerHeight,
    icon: const Icon(AppIcons.assistant),
    onPressed: () {
      _originPage = PageContextSource(
        const PageContextData(pageType: 'player'),
      );
      _openAssistant();
    },
  );

  Future<void> _exitPlayer() async {
    if (_exitingPlayer) return;
    _exitingPlayer = true;
    try {
      if (await _player.currentState!.stopPlayback() && mounted) {
        setState(() => _showPlayer = false);
        _revision.value++;
      }
    } finally {
      _exitingPlayer = false;
    }
  }

  Future<void> _play(SourceSelection selection) async {
    if (_playerWindows != null && !_opening && !_exitingPlayer) {
      _opening = true;
      try {
        if (await _playerWindows.open(selection)) return;
      } finally {
        _opening = false;
      }
    }
    if (_opening || _exitingPlayer || _backend == null) {
      await selection.stream.release();
      if (mounted && _backend == null) _message(l.platformUnsupported);
      return;
    }
    _opening = true;
    // On mobile the player lives below the assistant's full-page route.
    // Reveal it for tool opens as well as media-card taps, without stopping
    // the app-owned coordinator that may still need to select subtitles.
    FocusManager.instance.primaryFocus?.unfocus();
    _closeAssistant();
    setState(() {
      _showPlayer = true;
    });
    try {
      await _player.currentState!.playSelection(selection);
    } finally {
      _opening = false;
    }
  }

  void _message(String message) =>
      showAppToast(context, message, kind: FeedbackKind.error);

  Future<void> _playHistory(dynamic media) async {
    if (_opening) return;
    // Continue the exact recorded resource, rather than selecting another version.
    final resources = _library!
        .resources(media['id'] as String)
        .where((r) => r['id'] == media['resource_id']);
    if (resources.isEmpty) {
      _message(l.historyUnavailable);
      return;
    }
    final resource = resources.first;
    final ref = ResourceRef(
      resource['source'] as String,
      resource['item'] as String,
    );
    _opening = true;
    try {
      final selection = await _launcher.select(
        ref,
        resource['name'] as String,
        wanted: () => mounted,
      );
      if (selection == null) return;
      _opening = false;
      await _play(selection);
    } catch (_) {
      if (mounted) _message(l.historyOpenFailed);
    } finally {
      _opening = false;
    }
  }

  Widget _home() => ValueListenableBuilder<int>(
    valueListenable: _revision,
    builder: (_, _, _) => _homeContent(),
  );

  Widget _homeContent() => AppPage(
    pageContext: const PageContextData(pageType: 'home'),
    title: Text(l.home),
    body: _homeMedia(),
  );

  Widget _homeMedia() => HomePage(
    sources: _sources,
    service: _library!,
    onPlay: _play,
    onResume: _playHistory,
  );

  Widget _settings() =>
      SettingsPage(library: _library, sources: _sources, plugins: _plugins);

  Widget _pluginsPage() => _plugins == null
      ? AppPage(
          pageContext: const PageContextData(pageType: 'plugins'),
          title: Text(l.plugins),
          body: ContentState(message: l.loading, loading: true),
        )
      : PluginManagementPage(
          key: _pluginsKey,
          manager: _plugins!,
          sources: _sources,
          assistantStore: _assistantStore,
          initialGroup: _pluginsInitialGroup,
          externalServices: ExternalServiceRegistry.forDb(
            _library!.configuration,
          ),
          openEditor: pluginEditorOpener(
            library: _library,
            sources: _sources,
            onModelSettings: _assistantStore == null ? null : _modelSettings,
          ),
        );

  // Observers fire while the navigator is mid-update, so rebuild after it.
  void _depthChanged() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) setState(() {});
  });

  // Hidden tabs keep their state but stop animating.
  Widget _branch(int index) =>
      TickerMode(enabled: index == _destination, child: _navigator(index));

  Widget _navigator(int index) => Navigator(
    key: _branches[index],
    observers: [_depths[index]],
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      builder: (_) => switch (AppDestination.values[index]) {
        AppDestination.home => _home(),
        AppDestination.sources => SourcePage(
          manager: _sources,
          library: _library,
          onPlay: _play,
        ),
        AppDestination.plugins => _pluginsPage(),
        AppDestination.settings => _settings(),
      },
    ),
  );

  void _select(int index) {
    setState(() {
      _destination = index;
      if (index == AppDestination.plugins.index) _pluginsVisited = true;
    });
    if (index == 0) _revision.value++;
  }

  @override
  Widget build(BuildContext context) {
    if (_library == null) {
      return Scaffold(
        body: Center(
          child: _error == null
              ? ContentState(message: l.loading, loading: true)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    ShadButton.ghost(onPressed: _load, child: Text(l.retry)),
                  ],
                ),
        ),
      );
    }
    return PopScope(
      canPop: !_showPlayer && _destination == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_showPlayer) {
          await _exitPlayer();
        } else if (!await _branches[_destination].currentState!.maybePop()) {
          if (mounted) _select(0);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final effectiveWidth =
              constraints.maxWidth /
              (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1, 2);
          final wide = effectiveWidth >= 840;
          final sidebar = effectiveWidth >= 600;
          return Scaffold(
            body: Stack(
              children: [
                Offstage(
                  offstage: _showPlayer,
                  // Pauses animations and deferred page refreshes under the player.
                  child: TickerMode(
                    enabled: !_showPlayer,
                    child: Row(
                      children: [
                        if (sidebar)
                          AppSidebar(
                            selected: _destination,
                            onSelected: _select,
                            compact: !wide,
                          ),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: _withAssistant(
                                  IndexedStack(
                                    index: _destination,
                                    children: [
                                      for (final d in AppDestination.values)
                                        d == AppDestination.plugins &&
                                                !_pluginsVisited
                                            ? const SizedBox.shrink()
                                            : _branch(d.index),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_backend != null)
                  Offstage(
                    offstage: !_showPlayer,
                    child: ExcludeFocus(
                      excluding: !_showPlayer,
                      child: PlayerPage(
                        key: _player,
                        backend: _backend,
                        sourceManager: _sources,
                        libraryService: _library,
                        active: _showPlayer,
                        onExit: _exitPlayer,
                        pickMedia: widget.pickMedia,
                        onFileSelected: () =>
                            setState(() => _showPlayer = true),
                      ),
                    ),
                  ),
                if (_assistant != null && _showPlayer)
                  _playerAssistantButton(context),
              ],
            ),
            bottomNavigationBar:
                sidebar || _showPlayer || _depths[_destination].depth > 1
                ? null
                : AppBottomBar(selected: _destination, onSelected: _select),
          );
        },
      ),
    );
  }
}

/// Counts the page routes on a tab's navigator (dialogs use the root one).
/// The player as the assistant reaches it: the active player window on
/// desktop, else the embedded player.
class _ShellPlayback implements PlaybackPort {
  _ShellPlayback(this._shell);
  final _AppShellState _shell;

  @override
  FutureOr<Map<String, dynamic>> snapshot({bool waitForSession = false}) =>
      _shell._playbackSnapshot(waitForSession: waitForSession);

  @override
  Future<Map<String, dynamic>> control(
    String command,
    Map<String, dynamic> args,
  ) async {
    final windows = _shell._playerWindows;
    if (windows?.hasActive ?? false) return windows!.control(command, args);
    final player = _shell._player.currentState;
    if (player == null ||
        player.assistantSnapshot()['session_id'] != args['session_id']) {
      throw StateError('staleSession');
    }
    return player.assistantControl(command, args);
  }

  @override
  bool get ready =>
      _shell.mounted && !_shell._opening && !_shell._exitingPlayer;

  @override
  Future<void> play(SourceSelection selection) => _shell._play(selection);
}

class _PageDepthObserver extends NavigatorObserver {
  _PageDepthObserver(this.onChanged);
  final VoidCallback onChanged;
  int depth = 0;

  void _change(Route<dynamic> route, int delta) {
    if (route is! PageRoute) return;
    depth += delta;
    onChanged();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, 1);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, -1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, -1);
}
