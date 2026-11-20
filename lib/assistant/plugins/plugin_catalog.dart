import '../../capabilities/capability_switches.dart';
import '../../data/sources/source_config.dart';
import '../../data/sources/source_schema.dart';
import '../../l10n/l10n.dart';

/// Display grouping only; a plugin may implement several interfaces.
enum PluginCategory {
  source,
  metadata,
  mediaProcessing,
  speech,
  model;

  String get label => switch (this) {
    source => appStrings.catCategorySource,
    metadata => appStrings.catCategoryMetadata,
    mediaProcessing => appStrings.catCategoryMediaProcessing,
    speech => appStrings.catCategorySpeech,
    model => appStrings.plgGroupModel,
  };
}

/// Where the work actually runs. The App adapter always runs on this device.
enum ExecutionLocation {
  device,
  network,
  selfHosted,
  cloudApi;

  String get label => switch (this) {
    device => appStrings.healthLocal,
    network => appStrings.catLocationNetwork,
    selfHosted => appStrings.catLocationSelfHosted,
    cloudApi => appStrings.catLocationCloudApi,
  };
}

/// One typed capability a plugin really implements.
///
/// [tools] are AI tools bound exclusively to this capability: they are only
/// offered while at least one providing plugin allows AI for it. [routedTools]
/// are host tools shared by many plugins; they stay registered and each call
/// is routed (and checked) per instance. [taskTools] are the bounded
/// query/cancel channel kept while tasks may still run.
class PluginCapabilityInfo {
  const PluginCapabilityInfo(
    this.id,
    this._label,
    this._description, {
    this.tools = const [],
    this.routedTools = const [],
    this.taskTools = const [],
    this.uploads = false,
    this.writes = false,
  });
  final String id;
  final String _label;
  final String _description;

  /// Display texts; the definitions hold catalog text keys (see
  /// [catalogText]) so the language follows the App at read time.
  String get label => catalogText(_label);
  String get description => catalogText(_description);
  final List<String> tools;
  final List<String> routedTools;
  final List<String> taskTools;

  /// Sends media or audio off this device.
  final bool uploads;

  /// Changes state outside the App (downloads, deletions on a server).
  final bool writes;

  bool get hasAiTools =>
      tools.isNotEmpty || routedTools.isNotEmpty || taskTools.isNotEmpty;
}

/// Compiled-in plugin definition. Only implementations this build contains
/// are listed; there is no runtime code download.
class PluginDefinition {
  const PluginDefinition({
    required this.id,
    required this._name,
    required this._summary,
    required this.category,
    required this.location,
    required this.capabilities,
    this.version = '1.0.0',
    this.multiInstance = true,
    this.toggleable = true,
    this._toggleNote,
    this.dependsOn = const [],
    this._dataNote,
    this.sourceKind,
    this.deprecated = false,
  });
  final String id;
  final String _name;
  final String _summary;
  final String? _toggleNote;
  final String? _dataNote;

  /// Display texts, resolved from catalog text keys (see [catalogText]).
  String get name => catalogText(_name);
  String get summary => catalogText(_summary);
  String? get toggleNote =>
      _toggleNote == null ? null : catalogText(_toggleNote);
  String? get dataNote => _dataNote == null ? null : catalogText(_dataNote);
  final PluginCategory category;
  final ExecutionLocation location;
  final String version;
  final List<PluginCapabilityInfo> capabilities;

  /// Several configured instances (accounts, servers) vs. one built-in one.
  final bool multiInstance;

  /// Whether a plugin-wide switch is enforced on every business path. Plugins
  /// without enforcement show [toggleNote] instead of a switch that would lie.
  final bool toggleable;

  /// Other plugins this one needs. Expressed as dependencies, never
  /// auto-enabled.
  final List<String> dependsOn;

  /// Set for source-family plugins backed by SourceManager.
  final SourceKind? sourceKind;

  /// Pending removal: hidden from the AI page and never offered to the AI.
  /// Its legacy settings page keeps working on its own.
  final bool deprecated;

  /// Id used for a single-instance plugin's only instance.
  String get builtinInstanceId => id;

  PluginCapabilityInfo? capability(String id) =>
      capabilities.where((c) => c.id == id).firstOrNull;

  int get aiCapabilityCount => capabilities.where((c) => c.hasAiTools).length;
}

/// Host tools that are never gated by a plugin switch (library, playback,
/// page context, generic task tools, plugin status, web access).
const hostToolNames = {
  'context_get',
  'library_query',
  'media_get',
  'progress_query',
  'playback_get',
  'playback_pause',
  'playback_resume',
  'playback_stop',
  'playback_seek',
  'playback_set_speed',
  'playback_set_volume',
  'task_get',
  'task_list',
  'task_cancel',
  'task_retry',
  'plugin_status',
  'web_fetch',
};

const _sourceCapabilities = {
  'source.browse': PluginCapabilityInfo(
    'source.browse',
    'catSourceBrowse',
    'catSourceBrowseDesc',
    routedTools: ['source_list', 'source_browse'],
  ),
  'source.resolve': PluginCapabilityInfo(
    'source.resolve',
    'catSourceResolve',
    'catSourceResolveDesc',
    routedTools: ['playback_open'],
  ),
  'source.attachments': PluginCapabilityInfo(
    'source.attachments',
    'catSourceAttachments',
    'catSourceAttachmentsDesc',
  ),
  'search.media': PluginCapabilityInfo(
    'search.media',
    'catSearchMedia',
    'catSearchMediaDesc',
    routedTools: ['search_media'],
  ),
  'metadata.lookup': PluginCapabilityInfo(
    'metadata.lookup',
    'catMetadataLookup',
    'catMetadataLookupDesc',
  ),
  'source.write': PluginCapabilityInfo(
    'source.write',
    'catSourceWrite',
    'catSourceWriteDesc',
    routedTools: ['media_save_to_source', 'external_file_save_to_source'],
    writes: true,
  ),
};

String _sourceSummary(SourceKind kind) => switch (kind) {
  SourceKind.local => 'catSummaryLocal',
  SourceKind.smb => 'catSummarySmb',
  SourceKind.webdav => 'catSummaryWebdav',
  SourceKind.onedrive ||
  SourceKind.dropbox ||
  SourceKind.baidu => 'catSummaryCloudDrive',
  SourceKind.ftp => 'catSummaryFtp',
  SourceKind.sftp => 'catSummarySftp',
  SourceKind.s3 => 'catSummaryS3',
  SourceKind.plex => 'catSummaryPlex',
  SourceKind.jellyfin => 'catSummaryJellyfin',
  SourceKind.emby => 'catSummaryEmby',
  SourceKind.dlna => 'catSummaryDlna',
};

PluginDefinition _source(SourceKind kind) {
  final manifest = SourceSchemas.forKind(kind);
  return PluginDefinition(
    id: manifest.id,
    name: 'source:${kind.name}',
    summary: _sourceSummary(kind),
    category: PluginCategory.source,
    location: switch (kind) {
      SourceKind.local => ExecutionLocation.device,
      SourceKind.plex ||
      SourceKind.jellyfin ||
      SourceKind.emby ||
      SourceKind.dlna => ExecutionLocation.selfHosted,
      _ => ExecutionLocation.network,
    },
    version: manifest.version,
    sourceKind: kind,
    // Manifest capabilities are the source of truth; unknown ids are a
    // definition error caught by [PluginCatalog.validate].
    capabilities: [
      for (final id in manifest.capabilities)
        _sourceCapabilities[id] ??
            PluginCapabilityInfo(id, id, _unregistered, tools: const []),
    ],
    dataNote: kind == SourceKind.local ? 'catDataLocal' : 'catDataRemote',
  );
}

const _speechTools = [
  'speech_recognition_status',
  'subtitle_generate',
  'transcript_generate',
  'subtitle_save',
];
const _speechTaskTools = ['subtitle_task_get', 'subtitle_task_cancel'];

/// The compiled registry: every plugin this build contains.
class PluginCatalog {
  PluginCatalog(List<PluginDefinition> definitions)
    : definitions = List.unmodifiable(definitions) {
    validate();
  }

  factory PluginCatalog.builtIn() => PluginCatalog([
    for (final kind in SourceKind.values) _source(kind),
    const PluginDefinition(
      id: 'metadata.nfo',
      name: 'catNfoName',
      summary: 'catNfoSummary',
      category: PluginCategory.metadata,
      location: ExecutionLocation.device,
      multiInstance: false,
      toggleable: false,
      toggleNote: 'catNfoToggle',
      capabilities: [
        PluginCapabilityInfo('metadata.local', 'catNfoCap', 'catNfoCapDesc'),
      ],
    ),
    const PluginDefinition(
      id: 'metadata.tmdb',
      name: 'TMDB',
      summary: 'catTmdbSummary',
      category: PluginCategory.metadata,
      location: ExecutionLocation.cloudApi,
      multiInstance: false,
      toggleable: false,
      toggleNote: 'catTmdbToggle',
      dataNote: 'catTmdbData',
      capabilities: [
        PluginCapabilityInfo('metadata.lookup', 'catTmdbCap', 'catTmdbCapDesc'),
      ],
    ),
    const PluginDefinition(
      id: 'media.ffmpeg',
      name: 'catFfmpegName',
      summary: 'catFfmpegSummary',
      category: PluginCategory.mediaProcessing,
      location: ExecutionLocation.device,
      multiInstance: false,
      dataNote: 'catFfmpegData',
      capabilities: [
        PluginCapabilityInfo(
          'media.probe',
          'catProbe',
          'catProbeDesc',
          tools: ['media_processing_capabilities', 'media_probe'],
        ),
        PluginCapabilityInfo(
          'media.transcode',
          'catTranscode',
          'catTranscodeDesc',
          tools: ['media_transcode'],
        ),
        PluginCapabilityInfo(
          'media.extract_audio',
          'catExtractAudio',
          'catExtractAudioDesc',
          tools: ['media_extract_audio'],
        ),
        PluginCapabilityInfo(
          'media.snapshot',
          'catSnapshot',
          'catSnapshotDesc',
          tools: ['media_snapshot'],
        ),
      ],
    ),
    const PluginDefinition(
      // One speech capability over every backend (on-device Whisper or the
      // user's recognition service); which one runs is a host detail.
      id: 'asr.whisper',
      name: 'catAsrName',
      summary: 'catAsrSummary',
      category: PluginCategory.speech,
      location: ExecutionLocation.device,
      dependsOn: asrWhisperDependencies,
      capabilities: [
        PluginCapabilityInfo(
          'speech.transcribe',
          'catAsrName',
          'catAsrCapDesc',
          tools: _speechTools,
          taskTools: _speechTaskTools,
          writes: true,
        ),
      ],
    ),
    const PluginDefinition(
      id: 'model.llm',
      name: 'catLlmName',
      summary: 'catLlmSummary',
      category: PluginCategory.model,
      location: ExecutionLocation.cloudApi,
      multiInstance: false,
      toggleable: false,
      toggleNote: 'catLlmToggle',
      dataNote: 'catLlmData',
      capabilities: [
        PluginCapabilityInfo('model.chat', 'catLlmCap', 'catLlmCapDesc'),
      ],
    ),
  ]);

  final List<PluginDefinition> definitions;

  PluginDefinition? operator [](String id) =>
      definitions.where((d) => d.id == id).firstOrNull;

  /// Exclusive tool → providing (pluginId, capabilityId) pairs.
  late final Map<String, List<(String, String)>> exclusiveTools = () {
    final map = <String, List<(String, String)>>{};
    for (final d in definitions) {
      for (final c in d.capabilities) {
        for (final t in c.tools) {
          (map[t] ??= []).add((d.id, c.id));
        }
      }
    }
    return map;
  }();

  late final Map<String, List<(String, String)>> taskTools = () {
    final map = <String, List<(String, String)>>{};
    for (final d in definitions) {
      for (final c in d.capabilities) {
        for (final t in c.taskTools) {
          (map[t] ??= []).add((d.id, c.id));
        }
      }
    }
    return map;
  }();

  /// Definition checks: stable unique ids, capabilities declared once, known
  /// source capabilities, no unknown or cyclic dependencies, and no tool that
  /// is both host-owned and plugin-bound.
  void validate() {
    final ids = <String>{};
    for (final d in definitions) {
      if (!RegExp(r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9_]*)+$').hasMatch(d.id) ||
          !ids.add(d.id)) {
        throw StateError('Invalid or duplicate plugin id ${d.id}');
      }
      final caps = <String>{};
      for (final c in d.capabilities) {
        if (!caps.add(c.id)) {
          throw StateError('Duplicate capability ${c.id} in ${d.id}');
        }
        if (c._description == _unregistered) {
          throw StateError('Unregistered capability ${c.id} in ${d.id}');
        }
        for (final t in [...c.tools, ...c.taskTools]) {
          if (hostToolNames.contains(t)) {
            throw StateError('Host tool $t bound to plugin ${d.id}');
          }
        }
      }
    }
    for (final d in definitions) {
      for (final dep in d.dependsOn) {
        if (!ids.contains(dep)) {
          throw StateError('Unknown dependency $dep of ${d.id}');
        }
      }
    }
    final visiting = <String>{};
    final done = <String>{};
    void visit(String id) {
      if (done.contains(id)) return;
      if (!visiting.add(id)) throw StateError('Dependency cycle at $id');
      for (final dep in this[id]!.dependsOn) {
        visit(dep);
      }
      visiting.remove(id);
      done.add(id);
    }

    for (final d in definitions) {
      visit(d.id);
    }
  }
}

const _unregistered = 'unregistered';

/// Resolves a catalog text key to the App's current language. Unknown keys
/// (ids used as their own label, test definitions) are returned unchanged.
String catalogText(String key) => switch (key) {
  'catSourceBrowse' => appStrings.catSourceBrowse,
  'catSourceBrowseDesc' => appStrings.catSourceBrowseDesc,
  'catSourceResolve' => appStrings.catSourceResolve,
  'catSourceResolveDesc' => appStrings.catSourceResolveDesc,
  'catSourceAttachments' => appStrings.catSourceAttachments,
  'catSourceAttachmentsDesc' => appStrings.catSourceAttachmentsDesc,
  'catSearchMedia' => appStrings.catSearchMedia,
  'catSearchMediaDesc' => appStrings.catSearchMediaDesc,
  'catMetadataLookup' => appStrings.catMetadataLookup,
  'catMetadataLookupDesc' => appStrings.catMetadataLookupDesc,
  'catSourceWrite' => appStrings.catSourceWrite,
  'catSourceWriteDesc' => appStrings.catSourceWriteDesc,
  'catSummaryLocal' => appStrings.catSummaryLocal,
  'catSummarySmb' => appStrings.catSummarySmb,
  'catSummaryWebdav' => appStrings.catSummaryWebdav,
  'catSummaryFtp' => appStrings.catSummaryFtp,
  'catSummarySftp' => appStrings.catSummarySftp,
  'catSummaryS3' => appStrings.catSummaryS3,
  'catSummaryPlex' => appStrings.catSummaryPlex,
  'catSummaryJellyfin' => appStrings.catSummaryJellyfin,
  'catSummaryEmby' => appStrings.catSummaryEmby,
  'catSummaryDlna' => appStrings.catSummaryDlna,
  'catDataLocal' => appStrings.catDataLocal,
  'catDataRemote' => appStrings.catDataRemote,
  'catNfoName' => appStrings.catNfoName,
  'catNfoSummary' => appStrings.catNfoSummary,
  'catNfoToggle' => appStrings.catNfoToggle,
  'catNfoCap' => appStrings.catNfoCap,
  'catNfoCapDesc' => appStrings.catNfoCapDesc,
  'catTmdbSummary' => appStrings.catTmdbSummary,
  'catTmdbToggle' => appStrings.catTmdbToggle,
  'catTmdbData' => appStrings.catTmdbData,
  'catTmdbCap' => appStrings.catTmdbCap,
  'catTmdbCapDesc' => appStrings.catTmdbCapDesc,
  'catFfmpegName' => appStrings.catFfmpegName,
  'catFfmpegSummary' => appStrings.catFfmpegSummary,
  'catFfmpegData' => appStrings.catFfmpegData,
  'catProbe' => appStrings.catProbe,
  'catProbeDesc' => appStrings.catProbeDesc,
  'catTranscode' => appStrings.catTranscode,
  'catTranscodeDesc' => appStrings.catTranscodeDesc,
  'catExtractAudio' => appStrings.catExtractAudio,
  'catExtractAudioDesc' => appStrings.catExtractAudioDesc,
  'catSnapshot' => appStrings.catSnapshot,
  'catSnapshotDesc' => appStrings.catSnapshotDesc,
  'catAsrName' => appStrings.catAsrName,
  'catAsrSummary' => appStrings.catAsrSummary,
  'catAsrCapDesc' => appStrings.catAsrCapDesc,
  'catLlmName' => appStrings.catLlmName,
  'catLlmSummary' => appStrings.catLlmSummary,
  'catLlmToggle' => appStrings.catLlmToggle,
  'catLlmData' => appStrings.catLlmData,
  'catLlmCap' => appStrings.catLlmCap,
  'catLlmCapDesc' => appStrings.catLlmCapDesc,
  _ when key.startsWith('source:') =>
    SourceKind.values.byName(key.substring(7)).label,
  _ => key,
};
