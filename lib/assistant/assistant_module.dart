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
import 'plugins/external/external_file_transfer.dart';
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
    final externalRegistry = ExternalServiceRegistry.forDb(
      library.configuration,
    );
    transfers = ExternalFileTransfers(
      db: library.db,
      services: externalRegistry,
      sources: sources,
      access: plugins,
      issueReference: tools.issueReference,
    );
    tools.registry.register(
      RegisteredTool(
        'external_file_save_to_source',
        'Save a completed external download to a writable source after user confirmation. '
            'Use service_id from the external tool result, job_id and zero-based file_index. '
            'Target needs source.write enabled in plugin management. folder is relative to '
            'the source root (empty string means root; default OpenPlayX/Downloads). '
            'Never overwrites. transfer_mode stream (default) writes directly without local '
            'disk space; cache downloads to temporary App storage first and checks space. '
            'Returns a background task immediately. Use task_get to wait and task_cancel to cancel. '
            'Data passes through this device; do not claim success until status succeeded.',
        {
          'service_id': const ToolField(
            'string',
            required: true,
            maxLength: 128,
          ),
          'job_id': const ToolField('string', required: true, maxLength: 64),
          'file_index': const ToolField('integer', required: true, minimum: 0),
          'target_instance_id': const ToolField(
            'string',
            required: true,
            maxLength: 128,
          ),
          'folder': const ToolField('string', minLength: 0, maxLength: 1024),
          'transfer_mode': const ToolField(
            'string',
            values: ['stream', 'cache'],
          ),
        },
        (a) async {
          if (!ToolExecution.active || !accepting()) {
            throw const ToolFailure('cancelled');
          }
          return transfers.submit(a);
        },
        readOnly: false,
        confirmation: true,
      ),
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
        transfers: transfers,
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
    transfers.registerFallbackTaskTools(tools.registry, accepting);
    // Built-in reading of public web pages (private and local addresses are
    // refused). Web search is the preset 联网搜索 service below.
    WebTools(registry: tools.registry, canExecute: accepting);
    // External capabilities (AI → 外部能力): tools of MCP services, the
    // user's and the App's presets (联网搜索 / mcp-tavily).
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
            'service_id': s.id,
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
      transfers: transfers,
      confirmationTarget: (tool, arguments) {
        final described = external.describe(tool);
        if (described != null) return described;
        if (tool == 'external_file_save_to_source') {
          final target = sources.configs
              .where((c) => c.id == arguments['target_instance_id'])
              .firstOrNull;
          return '${target?.name ?? arguments['target_instance_id']} · ${arguments['folder'] ?? 'OpenPlayX/Downloads'}';
        }
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
  late final ExternalFileTransfers transfers;
  late final ConversationCoordinator coordinator;
  ConversationCoordinator? _coordinator;

  /// The model the user configured on the AI page.
  Future<TextModelCapability> _configuredModel() async {
    final config = store.loadConfig();
    config.validate();
    final key = config.usePlatform ? 'platform' : await store.key(config);
    if (key.isEmpty) throw const ModelFailure('configurationRequired');
    return LangChainModel(
      apiKey: key,
      endpoint: config.effectiveEndpoint,
      model: config.effectiveModel,
      maxTokens: config.effectiveMaxTokens,
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
    unawaited(transfers.dispose());
  }
}
