import 'dart:async';

import '../capabilities/library/library_service.dart';
import '../capabilities/media_processing/media_processing_service.dart';
import '../capabilities/playback/playback_launcher.dart';
import '../capabilities/sources/source_manager.dart';
import '../capabilities/speech/subtitle_generation_service.dart';
import '../core/capabilities/source_capability.dart';
import '../core/models/text_model.dart';
import 'conversation/assistant_store.dart';
import 'conversation/conversation_coordinator.dart';
import 'model/langchain_model.dart';
import 'playback_port.dart';
import 'plugins/external/external_presets.dart';
import 'plugins/external/external_service_registry.dart';
import 'plugins/external/external_service_setup.dart';
import 'plugins/plugin_manager.dart';
import 'plugins/external/external_tools.dart';
import 'plugins/media_processing/media_processing_tools.dart';
import 'plugins/library/media_tools.dart';
import 'plugins/tools/plugin_tools.dart';
import 'plugins/speech/subtitle_tools.dart';
import 'plugins/tools/tool_registry.dart';
import 'plugins/web/web_tools.dart';

/// The assembled assistant: its store, the tools of every plugin over the
/// capabilities, the external services and the conversation. The App
/// creates one and hands it the capabilities and a [PlaybackPort].
class AssistantModule {
  AssistantModule({
    required LibraryService library,
    required SourceManager sources,
    required Map<String, dynamic> Function() context,
    PlaybackPort? playback,
    MediaProcessingService? media,
    SubtitleGenerationService? subtitles,
    PluginManager? plugins,
    Future<TextModelCapability> Function()? model,
  }) {
    store = AssistantStore(library.db, configuration: library.configuration);
    bool accepting() => _coordinator?.acceptingActions ?? false;
    final launcher = PlaybackLauncher(sources);
    final tools = mediaTools = MediaTools(
      canExecute: accepting,
      library: library,
      sources: sources,
      context: context,
      access: plugins,
      playbackSnapshot: playback?.snapshot,
      playbackControl: playback == null
          ? null
          : (command, args) => _control(playback, command, args),
      openResource: playback == null
          ? null
          : (entry) => _open(playback, launcher, entry, accepting),
    );
    if (media != null) {
      final mediaProcessing = MediaProcessingTools(
        registry: tools.registry,
        service: media,
        library: library,
        sources: sources,
        entryForReference: tools.entryForReference,
        issueReference: tools.issueReference,
        canExecute: accepting,
        access: plugins,
      );
      if (subtitles != null) {
        SubtitleTools(
          registry: tools.registry,
          service: subtitles,
          media: mediaProcessing,
          canExecute: accepting,
          access: plugins,
        );
      }
    }
    // Built-in reading of public web pages (private and local addresses are
    // refused). Web search is the preset 联网搜索 service below.
    WebTools(registry: tools.registry, canExecute: accepting);
    // External capabilities (AI → 外部能力): tools of MCP services, the
    // user's and the App's presets (联网搜索 / mcp-tavily).
    final externalRegistry = ExternalServiceRegistry.forDb(
      library.configuration,
    );
    final external = externalTools = ExternalTools(
      registry: tools.registry,
      setup: ExternalServiceSetup(registry: externalRegistry),
      canExecute: accepting,
    );
    unawaited(
      ExternalPresets.ensure(externalRegistry, InstallId(library.configuration))
          .then((_) {}, onError: (_) {})
          .then((_) => external.start())
          .catchError((_) {}),
    );
    if (plugins != null) {
      // One tool catalog; the plugin policy narrows it per request and the
      // gateway re-checks it before every execution.
      tools.registry.policy = plugins;
      plugins.externalSummary = () => [
        for (final s in external.services.services)
          {
            'name': s.name,
            'service': s.label,
            'available': s.available,
            'tools': [
              for (final t in s.tools)
                if (external.unsupported[s.id]?[t] == null)
                  ExternalTools.alias(s, t),
            ],
          },
      ];
      PluginTools(registry: tools.registry, plugins: plugins);
    }
    coordinator = _coordinator = ConversationCoordinator(
      store: store,
      gateway: ToolGateway(tools.registry, journal: store),
      context: context,
      confirmationTarget: (tool, arguments) {
        final described = external.describe(tool);
        if (described != null) return described;
        final id = arguments['media_id'];
        if (id is! String) return null;
        final title = library.mediaTitle(id);
        return title == null ? null : MediaTools.safeText(title);
      },
      model: model ?? _configuredModel,
    );
  }

  late final AssistantStore store;
  late final MediaTools mediaTools;
  late final ExternalTools externalTools;
  late final ConversationCoordinator coordinator;
  ConversationCoordinator? _coordinator;

  /// The model the user configured on the AI page.
  Future<TextModelCapability> _configuredModel() async {
    final config = store.loadConfig();
    config.validate();
    final key = await store.key(config);
    if (key.isEmpty) throw const ModelFailure('configurationRequired');
    return LangChainModel(
      apiKey: key,
      endpoint: config.endpoint,
      model: config.model,
      maxTokens: config.maxTokens,
      streaming: config.streamVerified || !config.textVerified,
    );
  }

  /// A playback command; the player's reason codes become tool failures.
  static Future<Map<String, dynamic>> _control(
    PlaybackPort playback,
    String command,
    Map<String, dynamic> args,
  ) async {
    try {
      return await playback.control(command, args);
    } on StateError catch (e) {
      // Short codes such as staleSession or noSavedSubtitle.
      throw ToolFailure(
        RegExp(r'^[a-zA-Z]{1,40}$').hasMatch(e.message)
            ? e.message
            : 'playbackRejected',
      );
    } catch (_) {
      throw const ToolFailure('playbackRejected');
    }
  }

  /// Opens [entry] in the player for a tool call.
  static Future<Map<String, dynamic>> _open(
    PlaybackPort playback,
    PlaybackLauncher launcher,
    SourceEntry entry,
    bool Function() accepting,
  ) async {
    if (!ToolExecution.active || !playback.ready) {
      throw const ToolFailure('playerBusy');
    }
    final selection = await () async {
      try {
        return await launcher.select(
          entry.ref,
          entry.name,
          entry: entry,
          // The user may stop generation or open something else meanwhile.
          wanted: () => ToolExecution.active && accepting() && playback.ready,
        );
      } on MediaUnavailable {
        throw const ToolFailure('notFound');
      }
    }();
    if (selection == null) throw const ToolFailure('cancelled');
    await playback.play(selection);
    final result = await playback.snapshot(waitForSession: true);
    if (result['status'] == 'error') {
      throw const ToolFailure('playbackFailed');
    }
    return {'command_status': 'submitted', 'playback': result};
  }

  void dispose() {
    coordinator.dispose();
    store.close();
    externalTools.dispose();
  }
}
