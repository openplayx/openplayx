import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/plugins/plugin_gate.dart';
import '../../data/configuration/source_credential_broker.dart';
import '../../data/sources/source_config.dart';
import '../../data/sources/source_manager.dart';
import '../ai_tools/tool_registry.dart';
import '../media_processing/media_processing_service.dart';
import '../subtitles/asr_backend_config.dart';
import '../torrent/torrent_service.dart';
import '../torrent_search/torrent_search_config.dart';
import 'capability_registry.dart';
import 'plugin_ai_policy.dart';
import 'plugin_catalog.dart';

/// Actual (not desired) state. `blocked` names missing configuration,
/// permission or dependency; connection health is tracked separately.
enum PluginRuntimeState {
  disabled('已停用'),
  validating('未检测'),
  starting('启动中'),
  ready('可用'),
  blocked('需处理'),
  error('出错'),
  draining('收尾中');

  const PluginRuntimeState(this.label);
  final String label;
  bool get needsAttention => this == blocked || this == error;
}

/// Connection health, kept apart from the switches: offline is not disabled.
enum InstanceHealth {
  unchecked('未检测'),
  lastOk('上次连接成功'),
  failing('连接失败'),
  local('本机');

  const InstanceHealth(this.label);
  final String label;
}

class PluginInstanceView {
  const PluginInstanceView({
    required this.id,
    required this.pluginId,
    required this.name,
    required this.enabled,
    required this.state,
    this.health = InstanceHealth.unchecked,
    this.detail,
    this.savedRevision,
    this.appliedRevision,
    this.errorCode,
    this.playing = 0,
    this.running = 0,
    this.networkTarget,
    this.uploadAuthorized,
  });
  final String id;
  final String pluginId;
  final String name;

  /// User's desired switch, persisted.
  final bool enabled;
  final PluginRuntimeState state;
  final InstanceHealth health;
  final String? detail;
  final int? savedRevision;
  final int? appliedRevision;
  final String? errorCode;
  final int playing;
  final int running;

  /// Host only (no credentials, paths or queries) for the permission view.
  final String? networkTarget;

  /// Upload consent of an uploading backend; null when not applicable.
  final bool? uploadAuthorized;

  bool get busy => playing > 0 || running > 0;

  /// A saved revision that has not (yet) been applied by a runtime.
  bool get pendingApply =>
      savedRevision != null &&
      appliedRevision != null &&
      savedRevision != appliedRevision;
}

class PluginSnapshot {
  const PluginSnapshot({
    required this.definition,
    required this.enabled,
    required this.state,
    required this.instances,
    this.reason,
    this.platformSupported = true,
    this.aiCapabilities = const [],
  });
  final PluginDefinition definition;

  /// Desired plugin switch.
  final bool enabled;
  final PluginRuntimeState state;
  final String? reason;
  final List<PluginInstanceView> instances;
  final bool platformSupported;

  /// Capabilities the AI may currently use (after all three switches).
  final List<String> aiCapabilities;

  String get id => definition.id;

  /// A multi-instance plugin nobody has configured: shown as "未配置", not
  /// as something that needs attention.
  bool get unconfigured =>
      definition.multiInstance && instances.isEmpty && platformSupported;

  /// Errors, missing configuration of used plugins, pending authorization.
  bool get needsAttention => state.needsAttention && !unconfigured;
  int get enabledInstances => instances.where((i) => i.enabled).length;
  bool get busy => instances.any((i) => i.busy);
}

/// What disabling a plugin or instance would affect, for the confirm panel.
class PluginImpact {
  const PluginImpact({
    this.playing = 0,
    this.running = 0,
    this.instances = const [],
    this.remoteTasks = false,
  });
  final int playing;
  final int running;
  final List<String> instances;

  /// Work may continue on a server after the App adapter stops.
  final bool remoteTasks;
  bool get isEmpty => playing == 0 && running == 0 && !remoteTasks;
}

/// Plugin Manager: compiled catalog + configured instances + policy →
/// runtime snapshots, capability registry and the AI tool policy.
///
/// It adapts the existing family services (SourceManager, ASR, Torrent, …)
/// instead of re-implementing them, and owns no second copy of their
/// configuration: instance data stays where those services store it.
class PluginManager extends ChangeNotifier implements PluginAccess, ToolPolicy {
  PluginManager({
    PluginCatalog? catalog,
    this.sources,
    this.asr,
    this.torrent,
    this.torrentSearch,
    this.media,
    this.tmdbConfigured,
    this.model,
    PluginPolicyStore? store,
  }) : catalog = catalog ?? PluginCatalog.builtIn() {
    _store = store;
  }

  final PluginCatalog catalog;
  final SourceManager? sources;
  final AsrBackendRegistry? Function()? asr;
  final TorrentServiceStore? Function()? torrent;
  final TorrentSearchRegistry? Function()? torrentSearch;
  final MediaProcessingService? Function()? media;
  final Future<bool> Function()? tmdbConfigured;

  /// Configured assistant model: (display name, configured).
  final (String, bool)? Function()? model;

  PluginPolicyStore? _store;
  PluginPolicy _policy = const PluginPolicy();
  List<PluginSnapshot> _snapshots = const [];
  CapabilityRegistry _capabilities = const CapabilityRegistry.empty();
  final _unsupported = <String, String>{};
  int _revision = 0;
  String _fingerprint = '';
  bool _disposed = false;
  Future<void>? _refreshing;
  StreamSubscription<void>? _torrentChanges;

  /// Registers this manager as the host gate for business services.
  void install() => PluginGate.current = this;

  PluginPolicy get policy => _policy;
  List<PluginSnapshot> get snapshots => _snapshots;
  CapabilityRegistry get capabilities => _capabilities;

  /// Bumped on every plugin, instance or policy change (registry/policy
  /// revision). Old tool lists and confirmations are bound to it.
  @override
  int get revision => _revision;

  PluginSnapshot? snapshot(String pluginId) =>
      _snapshots.where((s) => s.id == pluginId).firstOrNull;

  PluginPolicyStore _defaultStore() {
    final configuration = sources?.configuration;
    return configuration == null
        ? MemoryPolicyStore()
        : ConfigurationPolicyStore(() => sources!.configuration!);
  }

  /// Reloads instances and runtime state from every family service.
  /// Concurrent callers share one refresh.
  Future<void> refresh() => _refreshing ??= _refresh().whenComplete(() {
    _refreshing = null;
  });

  Future<void> _refresh() async {
    try {
      await sources?.load();
    } catch (_) {}
    _torrentChanges ??= torrent?.call()?.changes.stream.listen(
      (_) => unawaited(refresh()),
    );
    final store = _store ??= _defaultStore();
    final stored = store.read();
    if (stored != null) _policy = stored;
    final instances = <String, List<PluginInstanceView>>{};
    for (final d in catalog.definitions) {
      try {
        instances[d.id] = await _instances(d);
      } catch (_) {
        // A failing family is isolated; others still load.
        instances[d.id] = const [];
        _unsupported.remove(d.id);
      }
    }
    if (stored == null) {
      // First run with plugin management: keep what the assistant could do
      // before (existing plugins and instances stay AI-usable). Anything
      // added afterwards starts outside the AI scope.
      _policy = store.write(
        PluginPolicy(
          ai: {
            for (final d in catalog.definitions)
              d.id: PluginAiPolicy(
                allowed: true,
                instances: {for (final i in instances[d.id]!) i.id},
              ),
          },
        ),
      );
    }
    _rebuild(instances);
  }

  void _rebuild([Map<String, List<PluginInstanceView>>? fresh]) {
    final instances = fresh ?? {for (final s in _snapshots) s.id: s.instances};
    final next = <PluginSnapshot>[];
    for (final d in catalog.definitions) {
      next.add(_snapshotFor(d, instances[d.id] ?? const []));
    }
    _snapshots = List.unmodifiable(next);
    final registrations = <CapabilityRegistration>[];
    for (final s in _snapshots) {
      if (!pluginEnabled(s.id)) continue;
      for (final c in s.definition.capabilities) {
        for (final i in s.instances) {
          if (!i.enabled ||
              i.state == PluginRuntimeState.blocked ||
              i.state == PluginRuntimeState.disabled) {
            continue;
          }
          registrations.add(
            CapabilityRegistration(
              capabilityId: c.id,
              pluginId: s.id,
              instanceId: i.id,
              instanceName: i.name,
              ai: aiAllows(s.id, instanceId: i.id, capability: c.id),
            ),
          );
        }
      }
    }
    final fingerprint = jsonEncode([
      _policy.revision,
      for (final s in _snapshots)
        [
          s.id,
          s.enabled,
          s.state.name,
          s.reason,
          for (final i in s.instances)
            [i.id, i.name, i.enabled, i.state.name, i.savedRevision, i.busy],
        ],
    ]);
    if (fingerprint != _fingerprint) {
      _fingerprint = fingerprint;
      _revision++;
    }
    _capabilities = CapabilityRegistry(registrations, _revision);
    if (!_disposed) notifyListeners();
  }

  PluginSnapshot _snapshotFor(
    PluginDefinition d,
    List<PluginInstanceView> instances,
  ) {
    final enabled = _policy.pluginEnabled(d.id);
    final platform = _unsupported[d.id];
    final busy = instances.any((i) => i.busy);
    PluginRuntimeState state;
    String? reason;
    final active = instances.where((i) => i.enabled).toList();
    final blockedDependency = d.dependsOn
        .where((dep) => !pluginEnabled(dep))
        .map((dep) => catalog[dep]!.name)
        .firstOrNull;
    if (platform != null) {
      state = PluginRuntimeState.blocked;
      reason = platform;
    } else if (!enabled) {
      state = busy ? PluginRuntimeState.draining : PluginRuntimeState.disabled;
      reason = busy ? '已阻止新调用，正在等待播放或任务结束' : null;
    } else if (blockedDependency != null) {
      state = PluginRuntimeState.blocked;
      reason = '依赖的「$blockedDependency」已停用或不可用';
    } else if (instances.isEmpty && d.multiInstance) {
      state = PluginRuntimeState.blocked;
      reason = '尚未添加实例';
    } else if (active.isEmpty) {
      state = PluginRuntimeState.disabled;
      reason = '所有实例均已停用';
    } else if (active.any((i) => i.state == PluginRuntimeState.error)) {
      state = PluginRuntimeState.error;
      reason = '有实例连接失败';
    } else if (active.every((i) => i.state == PluginRuntimeState.blocked)) {
      state = PluginRuntimeState.blocked;
      reason = active.first.detail;
    } else if (active.any((i) => i.state == PluginRuntimeState.ready)) {
      state = PluginRuntimeState.ready;
      if (active.any((i) => i.state == PluginRuntimeState.blocked)) {
        reason = '部分实例需处理';
      }
    } else if (active.any((i) => i.state == PluginRuntimeState.starting)) {
      state = PluginRuntimeState.starting;
    } else {
      state = PluginRuntimeState.validating;
    }
    return PluginSnapshot(
      definition: d,
      enabled: enabled,
      state: state,
      reason: reason,
      instances: List.unmodifiable(instances),
      platformSupported: platform == null,
      aiCapabilities: [
        for (final c in d.capabilities)
          if (c.hasAiTools && _aiCapabilityUsable(d, c.id, instances)) c.id,
      ],
    );
  }

  bool _aiCapabilityUsable(
    PluginDefinition d,
    String capability,
    List<PluginInstanceView> instances,
  ) {
    if (!aiAllows(d.id, capability: capability)) return false;
    if (!d.multiInstance) return true;
    return instances.any(
      (i) =>
          i.enabled &&
          i.state != PluginRuntimeState.blocked &&
          aiAllows(d.id, instanceId: i.id, capability: capability),
    );
  }

  // ---- Family adapters: read existing services, never duplicate config ----

  Future<List<PluginInstanceView>> _instances(PluginDefinition d) async {
    final kind = d.sourceKind;
    if (kind != null) return _sourceInstances(d, kind);
    switch (d.id) {
      case 'metadata.nfo':
        return [_builtin(d, '邻近文件规则', PluginRuntimeState.ready)];
      case 'metadata.tmdb':
        final configured = await tmdbConfigured?.call();
        if (configured == null) {
          _unsupported[d.id] = '此构建未接入 TMDB 设置';
          return const [];
        }
        _unsupported.remove(d.id);
        return [
          _builtin(
            d,
            'TMDB 配置',
            configured
                ? PluginRuntimeState.validating
                : PluginRuntimeState.blocked,
            detail: configured ? '令牌已保存 · 未检测' : '未配置访问令牌',
            networkTarget: 'api.themoviedb.org',
            health: InstanceHealth.unchecked,
          ),
        ];
      case 'media.ffmpeg':
        final service = media?.call();
        if (service == null || !service.nativeAvailable) {
          _unsupported[d.id] = '当前平台或构建未包含 FFmpeg 媒体处理';
          return const [];
        }
        _unsupported.remove(d.id);
        return [_builtin(d, '设备内处理', PluginRuntimeState.ready)];
      case 'asr.whisper':
      case 'asr.http':
        return _asrInstances(d);
      case 'model.llm':
        final config = model?.call();
        if (config == null) {
          _unsupported[d.id] = '此构建未接入 AI 助手';
          return const [];
        }
        _unsupported.remove(d.id);
        final (name, configured) = config;
        return [
          _builtin(
            d,
            name,
            configured
                ? PluginRuntimeState.validating
                : PluginRuntimeState.blocked,
            detail: configured ? '已配置 · 未检测' : '未配置模型或密钥',
            health: InstanceHealth.unchecked,
          ),
        ];
      case 'torrent.search':
        return _torrentSearchInstances(d);
      case 'torrent.download':
        return _torrentInstances(d);
    }
    return const [];
  }

  PluginInstanceView _builtin(
    PluginDefinition d,
    String name,
    PluginRuntimeState state, {
    String? detail,
    String? networkTarget,
    InstanceHealth health = InstanceHealth.local,
  }) => PluginInstanceView(
    id: d.builtinInstanceId,
    pluginId: d.id,
    name: name,
    enabled: true,
    state: state,
    detail: detail,
    networkTarget: networkTarget,
    health: health,
  );

  List<PluginInstanceView> _sourceInstances(
    PluginDefinition d,
    SourceKind kind,
  ) {
    final manager = sources;
    if (manager == null) {
      _unsupported[d.id] = '此构建未接入媒体来源';
      return const [];
    }
    _unsupported.remove(d.id);
    return [
      for (final c in manager.configs.where((c) => c.kind == kind))
        _sourceInstance(manager, d, c),
    ];
  }

  PluginInstanceView _sourceInstance(
    SourceManager manager,
    PluginDefinition d,
    SourceConfig c,
  ) {
    final impact = manager.impact(c.id);
    final app = manager.application(c.id);
    final credential = manager.credentialStatus(c.id).authorization;
    final status = manager.applicationStatus(c.id);
    var state = switch (status) {
      SourceApplicationStatus.disabled => PluginRuntimeState.disabled,
      SourceApplicationStatus.ready => PluginRuntimeState.ready,
      SourceApplicationStatus.failed => PluginRuntimeState.error,
      SourceApplicationStatus.initialized => PluginRuntimeState.starting,
      SourceApplicationStatus.saved => PluginRuntimeState.validating,
    };
    String? detail = manager.applicationLabel(c.id);
    if (c.enabled &&
        const [
          SourceAuthorization.missing,
          SourceAuthorization.expired,
          SourceAuthorization.rejected,
        ].contains(credential)) {
      state = PluginRuntimeState.blocked;
      detail = manager.credentialStatus(c.id).label;
    }
    if (!pluginEnabled(d.id) && impact.playing + impact.running > 0) {
      state = PluginRuntimeState.draining;
    }
    return PluginInstanceView(
      id: c.id,
      pluginId: d.id,
      name: c.name.trim().isEmpty ? c.kind.label : c.name,
      enabled: c.enabled,
      state: state,
      health: c.kind == SourceKind.local
          ? InstanceHealth.local
          : switch (status) {
              SourceApplicationStatus.ready => InstanceHealth.lastOk,
              SourceApplicationStatus.failed => InstanceHealth.failing,
              _ => InstanceHealth.unchecked,
            },
      detail: detail,
      savedRevision: c.revision,
      appliedRevision: app?['applied_revision'] as int?,
      errorCode: app?['error_code'] as String?,
      playing: impact.playing,
      running: impact.running,
      networkTarget: c.kind == SourceKind.local
          ? null
          : Uri.tryParse(c.address)?.host.isNotEmpty == true
          ? Uri.parse(c.address).host
          : c.address.replaceFirst(RegExp(r'^[a-z]+://'), '').split('/').first,
    );
  }

  Future<List<PluginInstanceView>> _asrInstances(PluginDefinition d) async {
    final registry = asr?.call();
    if (registry == null) {
      _unsupported[d.id] = '此构建未接入语音识别';
      return const [];
    }
    _unsupported.remove(d.id);
    final wantKind = d.id == 'asr.http' ? 'http' : 'embedded';
    final result = <PluginInstanceView>[];
    for (final c in registry.list().where((c) => c.kind == wantKind)) {
      var state = PluginRuntimeState.validating;
      String? detail;
      var health = InstanceHealth.unchecked;
      if (c.kind == 'embedded') {
        health = InstanceHealth.local;
        try {
          final status = await registry.backend(c.id).status();
          state = status.available
              ? PluginRuntimeState.ready
              : PluginRuntimeState.blocked;
          detail = status.available ? '模型 ${c.modelId}' : status.reason;
        } catch (_) {
          state = PluginRuntimeState.blocked;
          detail = '本地识别引擎不可用';
        }
      } else if (c.uploadConsentAt == null) {
        state = PluginRuntimeState.blocked;
        detail = '待授权上传音频到 ${c.host}';
      } else {
        detail = '模型 ${c.modelId} · 未检测';
      }
      result.add(
        PluginInstanceView(
          id: c.id,
          pluginId: d.id,
          name: c.name,
          enabled: true,
          state: state,
          detail: detail,
          health: health,
          networkTarget: c.kind == 'http' ? c.host : null,
          uploadAuthorized: c.uploads ? c.uploadConsentAt != null : null,
        ),
      );
    }
    return result;
  }

  Future<List<PluginInstanceView>> _torrentSearchInstances(
    PluginDefinition d,
  ) async {
    final registry = torrentSearch?.call();
    if (registry == null) {
      _unsupported[d.id] = '此构建未接入 Torrent 搜索';
      return const [];
    }
    _unsupported.remove(d.id);
    return [
      for (final c in registry.list())
        await () async {
          final token = await registry.hasToken(c);
          return PluginInstanceView(
            id: c.id,
            pluginId: d.id,
            name: c.name,
            enabled: c.enabled,
            state: !c.enabled
                ? PluginRuntimeState.disabled
                : token
                ? PluginRuntimeState.validating
                : PluginRuntimeState.blocked,
            detail: token ? '令牌已保存 · 未检测' : '缺少访问令牌',
            networkTarget: c.host,
          );
        }(),
    ];
  }

  Future<List<PluginInstanceView>> _torrentInstances(PluginDefinition d) async {
    final store = torrent?.call();
    if (store == null) {
      _unsupported[d.id] = '此构建未接入 BitTorrent 服务';
      return const [];
    }
    _unsupported.remove(d.id);
    if (!store.loaded) await store.load();
    return [
      for (final c in store.configs)
        await () async {
          final token = await store.hasToken(c.id);
          return PluginInstanceView(
            id: c.id,
            pluginId: d.id,
            name: c.name,
            enabled: c.enabled,
            state: !c.enabled
                ? PluginRuntimeState.disabled
                : token
                ? PluginRuntimeState.validating
                : PluginRuntimeState.blocked,
            detail: token ? '令牌已保存 · 未检测' : '缺少 API 令牌',
            networkTarget: Uri.tryParse(c.baseUrl)?.host,
          );
        }(),
    ];
  }

  // ---- PluginAccess / ToolPolicy ----

  @override
  bool pluginEnabled(String pluginId) => _pluginEnabled(pluginId, 0);

  bool _pluginEnabled(String pluginId, int depth) {
    final d = catalog[pluginId];
    // Unknown ids (e.g. configuration of an implementation this build does
    // not contain) can never be activated.
    if (d == null || depth > catalog.definitions.length) return false;
    if (_unsupported.containsKey(pluginId)) return false;
    if (!_policy.pluginEnabled(pluginId)) return false;
    return d.dependsOn.every((dep) => _pluginEnabled(dep, depth + 1));
  }

  @override
  bool aiAllows(String pluginId, {String? instanceId, String? capability}) {
    if (!pluginEnabled(pluginId)) return false;
    final d = catalog[pluginId]!;
    final ai = _policy.aiFor(pluginId);
    if (!ai.allowed) return false;
    if (capability != null) {
      final optIn = d.capability(capability)?.optIn ?? false;
      if (optIn
          ? !ai.grantedCapabilities.contains(capability)
          : ai.deniedCapabilities.contains(capability)) {
        return false;
      }
    }
    if (d.multiInstance && instanceId != null) {
      return ai.instances.contains(instanceId);
    }
    return true;
  }

  @override
  ToolDecision decide(String tool) {
    if (catalog.taskTools.containsKey(tool)) {
      // Bounded query/cancel channel stays while tasks may still run.
      return ToolDecision.allowed;
    }
    final providers = catalog.exclusiveTools[tool];
    if (providers == null) return ToolDecision.allowed; // host or routed
    var usable = false;
    for (final (pluginId, capability) in providers) {
      if (!pluginEnabled(pluginId)) continue;
      usable = true;
      final d = catalog[pluginId]!;
      final instances = snapshot(pluginId)?.instances ?? const [];
      if (_aiCapabilityUsable(d, capability, instances)) {
        return ToolDecision.allowed;
      }
    }
    return usable
        ? ToolDecision.policyChanged
        : ToolDecision.capabilityUnavailable;
  }

  // ---- Mutations (trusted settings pages only; never exposed as AI tools) --

  void _write(PluginPolicy next) {
    _policy = (_store ??= _defaultStore()).write(next);
    _rebuild();
    // Instance views (e.g. draining) depend on the new switches.
    unawaited(refresh());
  }

  /// Re-reads the stored policy (another window may have saved).
  void reloadPolicy() {
    final stored = (_store ??= _defaultStore()).read();
    if (stored != null) _policy = stored;
    _rebuild();
  }

  /// Plugin-wide switch. Instance switches are kept: re-enabling restores
  /// each instance's previous desired state.
  void setPluginEnabled(String pluginId, bool enabled) {
    final d = catalog[pluginId];
    if (d == null || !d.toggleable) {
      throw StateError('Plugin $pluginId cannot be toggled');
    }
    _write(_policy.withPluginEnabled(pluginId, enabled));
  }

  void setAiAllowed(String pluginId, bool allowed) => _write(
    _policy.withAi(
      pluginId,
      _policy.aiFor(pluginId).copyWith(allowed: allowed),
    ),
  );

  void setAiInstance(String pluginId, String instanceId, bool allowed) {
    final ai = _policy.aiFor(pluginId);
    final instances = ai.instances.toSet();
    allowed ? instances.add(instanceId) : instances.remove(instanceId);
    _write(_policy.withAi(pluginId, ai.copyWith(instances: instances)));
  }

  void setAiCapability(String pluginId, String capability, bool allowed) {
    final ai = _policy.aiFor(pluginId);
    final denied = ai.deniedCapabilities.toSet();
    final granted = ai.grantedCapabilities.toSet();
    if (allowed) {
      denied.remove(capability);
      granted.add(capability);
    } else {
      denied.add(capability);
      granted.remove(capability);
    }
    _write(
      _policy.withAi(
        pluginId,
        ai.copyWith(deniedCapabilities: denied, grantedCapabilities: granted),
      ),
    );
  }

  /// Revokes upload consent of an HTTP recognition instance. Takes effect
  /// for the next request; consent names one destination and is never
  /// restored by re-enabling.
  Future<void> revokeUploadConsent(String instanceId) async {
    final registry = asr?.call();
    final c = registry?.get(instanceId);
    if (registry == null || c == null || !c.uploads) return;
    registry.save(c.copyWith(clearConsent: true));
    await refresh();
  }

  /// Sanitised diagnostics: states, revisions and error codes only — no
  /// addresses, accounts, paths or secrets.
  Map<String, dynamic> diagnostics(String pluginId) {
    final s = snapshot(pluginId);
    if (s == null) return const {};
    return {
      'plugin': s.id,
      'version': s.definition.version,
      'enabled': s.enabled,
      'state': s.state.name,
      'platformSupported': s.platformSupported,
      'registryRevision': _revision,
      'policyRevision': _policy.revision,
      'ai': {
        'allowed': _policy.aiFor(s.id).allowed,
        'capabilities': s.aiCapabilities,
        'instances': _policy.aiFor(s.id).instances.length,
      },
      'instances': [
        for (final (index, i) in s.instances.indexed)
          {
            'index': index,
            'enabled': i.enabled,
            'state': i.state.name,
            'health': i.health.name,
            'savedRevision': ?i.savedRevision,
            'appliedRevision': ?i.appliedRevision,
            'errorCode': ?i.errorCode,
            'playing': i.playing,
            'running': i.running,
          },
      ],
    };
  }

  /// Affected playback and tasks before disabling [pluginId] or one instance.
  PluginImpact impact(String pluginId, {String? instanceId}) {
    final s = snapshot(pluginId);
    if (s == null) return const PluginImpact();
    final targets = s.instances.where(
      (i) => instanceId == null || i.id == instanceId,
    );
    return PluginImpact(
      playing: targets.fold(0, (sum, i) => sum + i.playing),
      running: targets.fold(0, (sum, i) => sum + i.running),
      instances: [
        for (final i in targets)
          if (i.busy) i.name,
      ],
      remoteTasks: pluginId == 'torrent.download' && targets.isNotEmpty,
    );
  }

  /// Read-only summary the AI may see: no hidden instances, addresses,
  /// accounts, keys or configuration. Settings targets are host-generated.
  Map<String, dynamic> describeForAi() => {
    'plugins': [
      for (final s in _snapshots)
        {
          'plugin_id': s.id,
          'name': s.definition.name,
          'category': s.definition.category.label,
          'runs_on': s.definition.location.label,
          'state': s.state.name,
          if (s.state != PluginRuntimeState.ready)
            'reason': switch (s.state) {
              PluginRuntimeState.disabled => s.enabled ? '所有实例均已停用' : '插件已停用',
              PluginRuntimeState.blocked =>
                s.platformSupported ? '需要在设置中完成配置或授权' : '当前设备不支持',
              PluginRuntimeState.error => '连接失败',
              PluginRuntimeState.draining => '插件已停用，正在收尾',
              _ => '尚未检测',
            },
          'ai_allowed': _policy.aiFor(s.id).allowed,
          'ai_capabilities': [
            for (final c in s.aiCapabilities)
              CapabilityRegistry.label(catalog, c),
          ],
          'ai_instances': [
            for (final i in s.instances)
              if (s.definition.multiInstance &&
                  aiAllows(s.id, instanceId: i.id))
                {'instance_id': i.id, 'name': i.name},
          ],
          'settings_target': 'plugins/${s.id}',
          'settings_path': '设置 → 插件管理 → ${s.definition.name}',
        },
    ],
    'note': 'Read-only. Enabling plugins, widening AI access, credentials and servers can only be changed by the user in Settings.',
  };

  @override
  void dispose() {
    _disposed = true;
    _torrentChanges?.cancel();
    if (identical(PluginGate.current, this)) PluginGate.current = null;
    super.dispose();
  }
}
