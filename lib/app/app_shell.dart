import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../ui/components/states/content_state.dart';
import '../ui/adaptive/app_page.dart';
import '../ui/icons/app_icons.dart';

import 'package:openplayx_playback/playback.dart';

import '../core/plugins/source_capability.dart';
import '../data/files/local_media_picker.dart';
import '../data/sources/source_manager.dart';
import '../features/library/library_page.dart';
import '../features/player/player_page.dart';
import '../features/sources/source_defaults_page.dart';
import '../features/sources/source_page.dart';
import '../services/library/library_service.dart';
import '../services/metadata/metadata_runtime.dart';
import '../ui/adaptive/app_navigation.dart';
import '../features/settings/settings_page.dart';
import '../ui/tokens/app_spacing.dart';

import '../core/models/text_model.dart';
import '../plugins/model_langchain/langchain_model.dart';
import '../services/ai_tools/media_tools.dart';
import '../services/ai_tools/tool_registry.dart';
import '../services/conversations/assistant_store.dart';
import '../services/conversations/conversation_coordinator.dart';
import '../features/ai_assistant/assistant_page.dart';
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

class _AppShellState extends State<AppShell> {
  AppLocalizations get l => AppLocalizations.of(context);
  late final _sources = widget.sources ?? SourceManager();
  final _revision = ValueNotifier(0);
  final _player = GlobalKey<PlayerPageState>();
  final _branches = List.generate(4, (_) => GlobalKey<NavigatorState>());
  LibraryService? _library;
  MetadataRuntime? _metadataRuntime;
  AssistantStore? _assistantStore;
  ConversationCoordinator? _assistant;
  PlayerBackend? _backend;
  int _destination = 0;
  bool _showPlayer = false;
  bool _opening = false;
  bool _exitingPlayer = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
    unawaited(_metadataRuntime?.dispose());
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
        : ['home', 'library', 'sources', 'settings'][_destination],
    'playback': _player.currentState?.assistantSnapshot() ?? {'status': 'idle'},
  };

  void _initializeAssistant(LibraryService library) {
    final store = _assistantStore = AssistantStore(library.db);
    final tools = MediaTools(
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
  }

  Future<void> _modelSettings() async {
    if (_assistantStore == null || (_assistant?.busy ?? false)) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AssistantSettingsPage(store: _assistantStore!),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _assistantView() => AssistantView(
    coordinator: _assistant!,
    toolsEnabled: () => _assistantStore!.loadConfig().toolsSupported,
    onSettings: _modelSettings,
  );

  void _openAssistant() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: _assistantView(),
          ),
        ),
      ),
    );
  }

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

  Widget _homeContent() => AppPage(
    body: ListView(
      key: PageStorageKey('home'),
      padding: AppSpacing.page(context),
      children: [
        Text(l.welcome, style: ShadTheme.of(context).textTheme.h3),
        SizedBox(height: 8),
        Text(l.welcomeDescription),
        SizedBox(height: AppSpacing.xl),
        _history(
          l.continueWatching,
          _library!.continueWatching(),
          empty: l.continueEmpty,
        ),
        SizedBox(height: 28),
        _history(
          l.recentlyPlayed,
          _library!.recentlyPlayed(),
          empty: l.recentEmpty,
        ),
        if (_assistant != null) ...[
          const SizedBox(height: 20),
          ShadCard(child: _assistantView()),
        ],
      ],
    ),
    title: Text(l.home),
  );

  Widget _history(String title, List<dynamic> rows, {required String empty}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ShadTheme.of(context).textTheme.h4),
          SizedBox(height: 12),
          if (rows.isEmpty)
            ShadCard(
              padding: EdgeInsets.zero,
              child: Padding(padding: EdgeInsets.all(24), child: Text(empty)),
            )
          else
            SizedBox(
              height: 184 + MediaQuery.textScalerOf(context).scale(14) * 2,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: rows.length,
                separatorBuilder: (_, _) => SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final row = rows[index];
                  final position = row['position'] as int;
                  final duration = row['duration'] as int;
                  return SizedBox(
                    width: 256,
                    child: ShadCard(
                      padding: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _playHistory(row),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(AppIcons.playMedia),
                              SizedBox(height: 8),
                              Text(
                                row['title'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Spacer(),
                              Text(
                                row['completed'] == 1
                                    ? l.rewatch
                                    : l.watchProgress(
                                        position ~/ 60000,
                                        duration ~/ 60000,
                                      ),
                              ),
                              SizedBox(height: 8),
                              ShadProgress(
                                value: duration > 0
                                    ? (position / duration).clamp(0, 1)
                                    : 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );

  Widget _settings() => SettingsPage(
    onModelSettings: _assistantStore == null ? null : _modelSettings,
    onSourceDefaults: () => _branches[3].currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => SourceDefaultsPage(manager: _sources),
      ),
    ),
  );

  Widget _branch(int index) => Navigator(
    key: _branches[index],
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      builder: (_) => switch (index) {
        0 => _home(),
        1 => LibraryPage(sources: _sources, service: _library, onPlay: _play),
        2 => SourcePage(manager: _sources, onPlay: _play),
        _ => _settings(),
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
                                  for (var i = 0; i < 4; i++) _branch(i),
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
              ],
            ),
            floatingActionButton: _assistant == null
                ? null
                : FloatingActionButton.small(
                    tooltip: l.aiAssistant,
                    onPressed: _openAssistant,
                    child: const Icon(LucideIcons.sparkles),
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
