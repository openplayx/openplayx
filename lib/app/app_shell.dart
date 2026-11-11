import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../ui/components/states/content_state.dart';
import '../ui/adaptive/app_page.dart';

import 'package:openplayx_playback/playback.dart';

import '../core/plugins/source_capability.dart';
import '../data/files/local_media_picker.dart';
import '../data/sources/source_manager.dart';
import '../features/library/home_page.dart';
import 'app_destination.dart';
import '../features/player/player_page.dart';
import '../features/sources/source_page.dart';
import '../services/artwork/artwork_service.dart';
import '../services/library/library_service.dart';
import '../services/metadata/metadata_runtime.dart';
import '../ui/adaptive/app_navigation.dart';
import '../features/settings/settings_page.dart';
import 'player_window.dart';
import '../ui/tokens/app_spacing.dart';
import 'theme/app_theme.dart';

import '../core/models/text_model.dart';
import '../plugins/model_langchain/langchain_model.dart';
import '../services/ai_tools/media_tools.dart';
import '../services/ai_tools/tool_registry.dart';
import '../services/conversations/assistant_store.dart';
import '../services/conversations/conversation_coordinator.dart';
import '../features/ai_assistant/assistant_page.dart';
import '../features/ai_assistant/ai_chat_controller.dart';
import '../features/ai_assistant/ai_chat_panel.dart';
import '../ui/icons/app_icons.dart';
import '../features/ai_assistant/assistant_settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.sources,
    this.library,
    this.backend,
    this.pickMedia = pickLocalMedia,
  });
  final SourceManager? sources;
  final LibraryService? library;
  final PlayerBackend? backend;
  final Future<LocalMedia?> Function() pickMedia;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  AppLocalizations get l => AppLocalizations.of(context);
  late final _sources = widget.sources ?? SourceManager();
  final _revision = ValueNotifier(0);
  final _player = GlobalKey<PlayerPageState>();
  final _branches = List.generate(
    AppDestination.values.length,
    (_) => GlobalKey<NavigatorState>(),
  );
  LibraryService? _library;
  MetadataRuntime? _metadataRuntime;
  ArtworkService? _artwork;
  AssistantStore? _assistantStore;
  ConversationCoordinator? _assistant;
  AiChatController? _chat;
  MediaTools? _mediaTools;
  PlayerBackend? _backend;
  // Desktop playback opens in its own window; tests inject a backend and keep
  // the embedded player.
  late final PlayerWindows? _playerWindows =
      widget.backend == null && supportsPlayerWindow ? PlayerWindows() : null;
  int _destination = 0;
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
      setState(() {
        _library = library;
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
          _assistant = null;
          _assistantStore = null;
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
    _assistant?.dispose();
    _assistantStore?.close();
    _revision.dispose();
    if (widget.library == null) _library?.close();
    if (widget.sources == null) unawaited(_sources.dispose());
    super.dispose();
  }

  Map<String, dynamic> _aiContext() => {
    'page': _showPlayer
        ? 'player'
        : AppDestination.values[_destination].name,
    'playback': _player.currentState?.assistantSnapshot() ?? {'status': 'idle'},
  };

  void _initializeAssistant(LibraryService library) {
    final store = _assistantStore = AssistantStore(library.db);
    final tools = _mediaTools = MediaTools(
      canExecute: () => _assistant?.acceptingActions ?? false,
      library: library,
      sources: _sources,
      context: _aiContext,
      playbackSnapshot: _backend == null
          ? null
          : () =>
                _player.currentState?.assistantSnapshot() ?? {'status': 'idle'},
      playbackControl: _backend == null
          ? null
          : (command, args) async {
              final player = _player.currentState;
              if (player == null ||
                  player.assistantSnapshot()['session_id'] !=
                      args['session_id']) {
                throw const ToolFailure('staleSession');
              }
              try {
                return await player.assistantControl(command, args);
              } catch (_) {
                throw const ToolFailure('playbackRejected');
              }
            },
      openResource: _backend == null
          ? null
          : (entry) async {
              if (!ToolExecution.active || _opening || _exitingPlayer) {
                throw const ToolFailure('playerBusy');
              }
              final ref = entry.ref;
              final PlayableStream stream;
              if (ref.instanceId == '@local') {
                if (!await File(ref.id).exists()) {
                  throw const ToolFailure('notFound');
                }
                stream = PlayableStream(Uri.file(ref.id));
              } else {
                stream = await _sources.resolve(ref);
              }
              // The user may stop generation or open another resource during resolve.
              if (!mounted ||
                  !ToolExecution.active ||
                  !(_assistant?.acceptingActions ?? false) ||
                  _opening ||
                  _exitingPlayer) {
                await stream.release();
                throw const ToolFailure('cancelled');
              }
              await _play(
                SourceSelection(entry.name, stream, ref: ref, entry: entry),
              );
              final result =
                  _player.currentState?.assistantSnapshot() ??
                  {'status': 'idle'};
              if (result['status'] == 'error') {
                throw const ToolFailure('playbackFailed');
              }
              return {'command_status': 'submitted', 'playback': result};
            },
    );
    _assistant = ConversationCoordinator(
      store: store,
      gateway: ToolGateway(tools.registry, journal: store),
      context: _aiContext,
      confirmationTarget: (_, arguments) {
        final id = arguments['media_id'];
        if (id is! String) return null;
        final rows = _library!.db.select('SELECT title FROM media WHERE id=?', [
          id,
        ]);
        return rows.isEmpty
            ? null
            : MediaTools.safeText(rows.first['title'] as String);
      },
      model: () async {
        final config = store.loadConfig();
        config.validate();
        if (!config.cloudAllowed) {
          throw const ModelFailure('configurationRequired');
        }
        final key = await store.key(config);
        if (key.isEmpty) throw const ModelFailure('configurationRequired');
        return LangChainModel(
          apiKey: key,
          endpoint: config.endpoint,
          model: config.model,
          maxTokens: config.maxTokens,
          streaming: config.streamVerified || !config.textVerified,
        );
      },
    );
    _chat = AiChatController(_assistant!);
  }

  Future<void> _modelSettings() async {
    if (_assistantStore == null || (_assistant?.busy ?? false)) return;
    // Open inside the settings tab like other settings sub-pages, so the
    // navigation stays visible. The chat sheet (root route) closes first,
    // otherwise it would sit on top of the page.
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    final settings = AppDestination.settings.index;
    if (_destination != settings) _select(settings);
    await _branches[settings].currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => AssistantSettingsPage(store: _assistantStore!),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _assistantView() => AssistantView(
    coordinator: _assistant!,
    controller: _chat,
    toolsEnabled: () => _assistantStore!.loadConfig().toolsSupported,
    onSettings: _modelSettings,
    onOpenMedia: _openChatMedia,
    onFavorite: (id) async {
      final rows = _library!.db.select(
        'SELECT favorite FROM media WHERE id=?',
        [id],
      );
      if (rows.isEmpty) throw StateError('Media unavailable');
      final favorite = rows.first['favorite'] != 1;
      _library!.favorite(id, favorite);
      _revision.value++;
      return favorite;
    },
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
          : _library!.resources(item['media_id'] as String);
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
    if (entry.ref.instanceId == '@local' &&
        !await File(entry.ref.id).exists()) {
      throw StateError('File unavailable');
    }
    final stream = entry.ref.instanceId == '@local'
        ? PlayableStream(Uri.file(entry.ref.id))
        : await _sources.resolve(entry.ref);
    if (!mounted) {
      await stream.release();
      return;
    }
    await _play(
      SourceSelection(entry.name, stream, ref: entry.ref, entry: entry),
    );
  }

  Future<void> _openAssistant() => showAiChatPanel(
    context,
    playing: _showPlayer,
    builder: (_) => _assistantView(),
  );

  // Pinned to the top-right corner, aligned with the page header row. Page
  // headers and the player top bar keep that corner free for it.
  Widget _assistantButton(BuildContext context) => Positioned(
    top: MediaQuery.paddingOf(context).top + AppSpacing.md,
    right: AppSpacing.page(context).right,
    child: Tooltip(
      message: l.aiAssistant,
      child: Semantics(
        label: l.aiAssistant,
        button: true,
        // Plain icon, no filled background. Over the (black) player it uses
        // the dark theme so the icon stays visible.
        child: _showPlayer
            ? ShadTheme(data: AppTheme.dark, child: _assistantIcon())
            : _assistantIcon(),
      ),
    ),
  );

  Widget _assistantIcon() => ShadIconButton.ghost(
    icon: const Icon(AppIcons.assistant),
    onPressed: _openAssistant,
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
      ShadToaster.of(context).show(ShadToast(description: Text(message)));

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
      PlayableStream stream;
      if (ref.instanceId == '@local') {
        if (!await File(ref.id).exists()) throw StateError(l.fileUnavailable);
        stream = PlayableStream(Uri.file(ref.id));
      } else {
        await _sources.load();
        stream = await _sources.resolve(ref);
      }
      if (!mounted) {
        await stream.release();
        return;
      }
      _opening = false;
      await _play(
        SourceSelection(resource['name'] as String, stream, ref: ref),
      );
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

  Widget _homeContent() => AppPage(title: Text(l.home), body: _homeMedia());

  Widget _homeMedia() => HomePage(
    sources: _sources,
    service: _library!,
    onPlay: _play,
    onResume: _playHistory,
  );

  Widget _settings() => SettingsPage(
    library: _library,
    sources: _sources,
    onModelSettings: _assistantStore == null ? null : _modelSettings,
  );

  Widget _branch(int index) => Navigator(
    key: _branches[index],
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      builder: (_) => switch (AppDestination.values[index]) {
        AppDestination.home => _home(),
        AppDestination.sources => SourcePage(
          manager: _sources,
          library: _library,
          onPlay: _play,
        ),
        AppDestination.settings => _settings(),
      },
    ),
  );

  void _select(int index) {
    setState(() => _destination = index);
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
                              child: IndexedStack(
                                index: _destination,
                                children: [
                                  for (final d in AppDestination.values)
                                    _branch(d.index),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                        onExit: _exitPlayer,
                        pickMedia: widget.pickMedia,
                        onFileSelected: () =>
                            setState(() => _showPlayer = true),
                      ),
                    ),
                  ),
                if (_assistant != null) _assistantButton(context),
              ],
            ),
            bottomNavigationBar: sidebar || _showPlayer
                ? null
                : AppBottomBar(selected: _destination, onSelected: _select),
          );
        },
      ),
    );
  }
}
