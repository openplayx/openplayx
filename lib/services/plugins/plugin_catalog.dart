import 'package:flutter/widgets.dart';

import '../../data/sources/source_config.dart';
import '../../data/sources/source_schema.dart';
import '../../ui/icons/app_icons.dart';

/// Display grouping only; a plugin may implement several interfaces.
enum PluginCategory {
  source('媒体来源'),
  metadata('元数据'),
  mediaProcessing('媒体处理'),
  speech('字幕识别'),
  model('模型');

  const PluginCategory(this.label);
  final String label;
}

/// Where the work actually runs. The App adapter always runs on this device.
enum ExecutionLocation {
  device('本机'),
  network('网络存储'),
  selfHosted('自建服务'),
  cloudApi('云 API');

  const ExecutionLocation(this.label);
  final String label;
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
    this.label,
    this.description, {
    this.tools = const [],
    this.routedTools = const [],
    this.taskTools = const [],
    this.uploads = false,
    this.writes = false,
  });
  final String id;
  final String label;
  final String description;
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
    required this.name,
    required this.summary,
    required this.category,
    required this.location,
    required this.icon,
    required this.capabilities,
    this.version = '1.0.0',
    this.multiInstance = true,
    this.toggleable = true,
    this.toggleNote,
    this.dependsOn = const [],
    this.dataNote,
    this.sourceKind,
    this.deprecated = false,
  });
  final String id;
  final String name;
  final String summary;
  final PluginCategory category;
  final ExecutionLocation location;
  final IconData icon;
  final String version;
  final List<PluginCapabilityInfo> capabilities;

  /// Several configured instances (accounts, servers) vs. one built-in one.
  final bool multiInstance;

  /// Whether a plugin-wide switch is enforced on every business path. Plugins
  /// without enforcement show [toggleNote] instead of a switch that would lie.
  final bool toggleable;
  final String? toggleNote;

  /// Other plugins this one needs. Expressed as dependencies, never
  /// auto-enabled.
  final List<String> dependsOn;

  /// What leaves the device / what the plugin can read.
  final String? dataNote;

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
/// page context, generic task tools, plugin status).
const hostToolNames = {
  'context_get',
  'library_query',
  'media_get',
  'progress_query',
  'media_set_favorite',
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
};

const _sourceCapabilities = {
  'source.browse': PluginCapabilityInfo(
    'source.browse',
    '浏览目录',
    '列出该来源的文件夹与文件',
    routedTools: ['source_list', 'source_browse'],
  ),
  'source.resolve': PluginCapabilityInfo(
    'source.resolve',
    '播放',
    '把选中的资源交给播放器；严格绑定资源所属实例',
    routedTools: ['playback_open'],
  ),
  'source.attachments': PluginCapabilityInfo(
    'source.attachments',
    '读取附件',
    '读取 NFO、外挂字幕等小文件（有大小上限）',
  ),
  'search.media': PluginCapabilityInfo(
    'search.media',
    '搜索媒体',
    '在服务端搜索影片与剧集',
    routedTools: ['search_media'],
  ),
  'metadata.lookup': PluginCapabilityInfo(
    'metadata.lookup',
    '影视信息',
    '读取媒体服务器整理好的影视信息',
  ),
  'source.write': PluginCapabilityInfo(
    'source.write',
    '写入新文件',
    '把 App 生成的片段写到同一共享的 OpenPlayX 文件夹；不覆盖、不删除，每次需确认',
    routedTools: ['media_save_to_source'],
    writes: true,
  ),
};

String _sourceSummary(SourceKind kind) => switch (kind) {
  SourceKind.local => '本机或已挂载的文件夹',
  SourceKind.smb => 'Windows 共享、NAS 的 SMB 共享目录',
  SourceKind.webdav => 'WebDAV 网盘或 NAS 目录',
  SourceKind.ftp => 'FTP 服务器目录',
  SourceKind.sftp => '通过 SSH 访问的服务器目录',
  SourceKind.s3 => 'S3 兼容对象存储桶',
  SourceKind.plex => 'Plex 媒体服务器',
  SourceKind.jellyfin => 'Jellyfin 媒体服务器',
  SourceKind.emby => 'Emby 媒体服务器',
  SourceKind.dlna => '局域网 DLNA 媒体服务器',
};

PluginDefinition _source(SourceKind kind) {
  final manifest = SourceSchemas.forKind(kind);
  return PluginDefinition(
    id: manifest.id,
    name: kind.label,
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
    icon: kind.files ? AppIcons.folder : AppIcons.server,
    version: manifest.version,
    sourceKind: kind,
    // Manifest capabilities are the source of truth; unknown ids are a
    // definition error caught by [PluginCatalog.validate].
    capabilities: [
      for (final id in manifest.capabilities)
        _sourceCapabilities[id] ??
            PluginCapabilityInfo(id, id, '未登记的能力', tools: const []),
    ],
    dataNote: kind == SourceKind.local
        ? '只读取你授权的文件夹。'
        : 'App 在本机连接你配置的服务器；文件名和目录名会出现在 AI 对话中（仅当允许 AI 使用时）。',
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
      name: 'NFO 元数据',
      summary: '读取媒体旁边的 .nfo 文件',
      category: PluginCategory.metadata,
      location: ExecutionLocation.device,
      icon: AppIcons.info,
      multiInstance: false,
      toggleable: false,
      toggleNote: '由“刮削管理”控制是否刮削；后台刮削独立运行，暂不支持单独停用。',
      capabilities: [
        PluginCapabilityInfo('metadata.local', '本地元数据', '按邻近文件规则匹配影片信息'),
      ],
    ),
    const PluginDefinition(
      id: 'metadata.tmdb',
      name: 'TMDB',
      summary: '从 The Movie Database 查询影片与剧集信息',
      category: PluginCategory.metadata,
      location: ExecutionLocation.cloudApi,
      icon: AppIcons.movie,
      multiInstance: false,
      toggleable: false,
      toggleNote: '清除访问令牌即停止使用；后台刮削独立运行，暂不支持单独停用。',
      dataNote: '查询时向 TMDB 发送解析出的片名与年份，不发送文件内容。',
      capabilities: [
        PluginCapabilityInfo(
          'metadata.lookup',
          '查询元数据',
          '搜索、匹配影片与剧集信息；写入由宿主完成',
        ),
      ],
    ),
    const PluginDefinition(
      id: 'media.ffmpeg',
      name: 'FFmpeg 媒体处理',
      summary: '截图、探测、转码与音频提取',
      category: PluginCategory.mediaProcessing,
      location: ExecutionLocation.device,
      icon: AppIcons.openFile,
      multiInstance: false,
      dataNote: '在本机处理媒体，产物保存在应用目录。',
      capabilities: [
        PluginCapabilityInfo(
          'media.probe',
          '探测',
          '读取时长、编码与音轨',
          tools: ['media_processing_capabilities', 'media_probe'],
        ),
        PluginCapabilityInfo(
          'media.transcode',
          '转码',
          '按预设转码为新文件',
          tools: ['media_transcode'],
        ),
        PluginCapabilityInfo(
          'media.extract_audio',
          '提取音频',
          '导出音轨用于识别或保存',
          tools: ['media_extract_audio'],
        ),
        PluginCapabilityInfo(
          'media.snapshot',
          '截图',
          '截取指定时间的画面',
          tools: ['media_snapshot'],
        ),
      ],
    ),
    const PluginDefinition(
      // One speech capability over every backend (on-device Whisper or the
      // user's recognition service); which one runs is a host detail.
      id: 'asr.whisper',
      name: '语音识别',
      summary: '为视频生成原语言字幕与转录',
      category: PluginCategory.speech,
      location: ExecutionLocation.device,
      icon: AppIcons.captions,
      dependsOn: ['media.ffmpeg'],
      capabilities: [
        PluginCapabilityInfo(
          'speech.transcribe',
          '语音识别',
          '生成原语言字幕/转录；不包含翻译',
          tools: _speechTools,
          taskTools: _speechTaskTools,
          writes: true,
        ),
      ],
    ),
    const PluginDefinition(
      id: 'model.llm',
      name: '对话模型',
      summary: '为 AI 助手提供大语言模型',
      category: PluginCategory.model,
      location: ExecutionLocation.cloudApi,
      icon: AppIcons.assistant,
      multiInstance: false,
      toggleable: false,
      toggleNote: '在“AI 与模型”中配置或清除模型；不会生成可递归调用自身的推理工具。',
      dataNote: '对话内容、页面摘要与工具结果会发送给所配置的模型服务，可能产生费用。',
      capabilities: [
        PluginCapabilityInfo('model.chat', '对话推理', '为 AI 助手生成回复与工具调用'),
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
        if (c.description == '未登记的能力') {
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
