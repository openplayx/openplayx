import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../capabilities/capability_switches.dart';
import '../../data/configuration/source_credential_broker.dart';
import '../../data/sources/source_config.dart';
import '../../capabilities/sources/source_manager.dart';
import 'tools/tool_registry.dart';
import '../../capabilities/media_processing/media_processing_service.dart';
import '../../capabilities/speech/asr_backend_config.dart';
import 'capability_registry.dart';
import 'plugin_access.dart';
import 'plugin_catalog.dart';
import '../../l10n/l10n.dart';

/// Actual (not desired) state. `blocked` names missing configuration,
/// permission or dependency; connection health is tracked separately.
enum PluginRuntimeState {
  disabled,
  validating,
  starting,
  ready,
  blocked,
  error,
  draining;

  String get label => switch (this) {
    disabled => appStrings.rtDisabled,
    validating => appStrings.rtUnchecked,
    starting => appStrings.rtStarting,
    ready => appStrings.statusAvailable,
    blocked => appStrings.rtBlocked,
    error => appStrings.rtError,
    draining => appStrings.rtDraining,
  };
  bool get needsAttention => this == blocked || this == error;
}

/// Connection health, kept apart from the switches: offline is not disabled.
enum InstanceHealth {
  unchecked,
  lastOk,
  failing,
  local;

  String get label => switch (this) {
    unchecked => appStrings.rtUnchecked,
    lastOk => appStrings.healthLastOk,
    failing => appStrings.srcStatusFailed,
    local => appStrings.healthLocal,
  };
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
    this.configured = true,
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

  /// Has everything it needs to run (address, token, model…).
  final bool configured;

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

  /// Capabilities that can run now. The AI may use every one of them.
  final List<String> aiCapabilities;

  String get id => definition.id;

  /// First status dimension: at least one instance has what it needs.
  bool get configured => instances.any((i) => i.configured);

  /// Second status dimension: usable right now ([reason] says why not).
  bool get available =>
      platformSupported &&
      const {
        PluginRuntimeState.ready,
        PluginRuntimeState.validating,
        PluginRuntimeState.starting,
      }.contains(state);
  int get enabledInstances => instances.where((i) => i.enabled).length;
  bool get busy => instances.any((i) => i.busy);
}

/// What disabling a plugin or instance would affect, for the confirm panel.
class PluginImpact {
  const PluginImpact({
    this.playing = 0,
    this.running = 0,
    this.instances = const [],
  });
  final int playing;
  final int running;
  final List<String> instances;

  bool get isEmpty => playing == 0 && running == 0;
}

/// Plugin Manager: the AI's view of the capabilities. Compiled catalog +
/// configured instances + capability switches → runtime snapshots,
/// capability registry and the AI tool policy.
///
/// It adapts the capability services (SourceManager, ASR, …) instead of
/// re-implementing them and owns no copy of their configuration or of the
/// switches: instance data stays where those services store it, and the
/// switches belong to the capability layer ([CapabilitySwitches]).
class PluginManager extends ChangeNotifier implements PluginAccess, ToolPolicy {
  PluginManager({
    PluginCatalog? catalog,
    this.sources,
    this.asr,
    this.media,
    this.tmdbConfigured,
    this.model,
    CapabilitySwitches? switches,
  }) : catalog = catalog ?? PluginCatalog.builtIn(),
       switches = switches ?? sources?.switches ?? CapabilitySwitches.memory() {
    this.switches.addListener(_switchesChanged);
  }

  /// App-wide capability switches the plugins follow.
  final CapabilitySwitches switches;

  void _switchesChanged() {
    _rebuild();
    // Instance views (e.g. draining) depend on the new switches.
    unawaited(refresh());
  }

  final PluginCatalog catalog;
  final SourceManager? sources;
  final AsrBackendRegistry? Function()? asr;
  final MediaProcessingService? Function()? media;
  final Future<bool> Function()? tmdbConfigured;

  /// Configured assistant model: (display name, configured).
  final (String, bool)? Function()? model;

  /// Summary of user-configured external capabilities (AI → 外部能力) for
  /// [describeForAi]; set by the shell once the external tools are bound.
  List<Map<String, dynamic>> Function()? externalSummary;

  List<PluginSnapshot> _snapshots = const [];
  CapabilityRegistry _capabilities = const CapabilityRegistry.empty();
  final _unsupported = <String, String>{};
  int _revision = 0;
  String _fingerprint = '';
  bool _disposed = false;
  Future<void>? _refreshing;

  List<PluginSnapshot> get snapshots => _snapshots;
  CapabilityRegistry get capabilities => _capabilities;

  /// Bumped on every plugin, instance or policy change (registry/policy
  /// revision). Old tool lists and confirmations are bound to it.
  @override
  int get revision => _revision;

  PluginSnapshot? snapshot(String pluginId) =>
      _snapshots.where((s) => s.id == pluginId).firstOrNull;

  /// Reloads instances and runtime state from every family service.
  /// Concurrent callers share one refresh.
  Future<void> refresh() => _refreshing ??= _refresh().whenComplete(() {
    _refreshing = null;
  });

  Future<void> _refresh() async {
    try {
      await sources?.load();
    } catch (_) {}
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
      switches.revision,
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
    final enabled = switches.isOn(d.id);
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
      reason = busy ? appStrings.plgDraining : null;
    } else if (blockedDependency != null) {
      state = PluginRuntimeState.blocked;
      reason = appStrings.plgDependencyBlocked(blockedDependency);
    } else if (instances.isEmpty && d.multiInstance) {
      state = PluginRuntimeState.blocked;
      reason = appStrings.plgNoInstanceAdded;
    } else if (active.isEmpty) {
      state = PluginRuntimeState.disabled;
      reason = appStrings.plgAllInstancesDisabled;
    } else if (active.any((i) => i.state == PluginRuntimeState.error)) {
      state = PluginRuntimeState.error;
      reason = appStrings.plgInstanceFailing;
    } else if (active.every((i) => i.state == PluginRuntimeState.blocked)) {
      state = PluginRuntimeState.blocked;
      reason = active.first.detail;
    } else if (active.any((i) => i.state == PluginRuntimeState.ready)) {
      state = PluginRuntimeState.ready;
      if (active.any((i) => i.state == PluginRuntimeState.blocked)) {
        reason = appStrings.plgSomeInstancesBlocked;
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
    if (!pluginEnabled(d.id)) return false;
    if (!d.multiInstance) return true;
    return instances.any(
      (i) => i.enabled && i.state != PluginRuntimeState.blocked,
    );
  }

  // ---- Family adapters: read existing services, never duplicate config ----

  Future<List<PluginInstanceView>> _instances(PluginDefinition d) async {
    final kind = d.sourceKind;
    if (kind != null) return _sourceInstances(d, kind);
    switch (d.id) {
      case 'metadata.nfo':
        return [
          _builtin(d, appStrings.plgNfoInstance, PluginRuntimeState.ready),
        ];
      case 'metadata.tmdb':
        final configured = await tmdbConfigured?.call();
        if (configured == null) {
          _unsupported[d.id] = appStrings.plgNoTmdb;
          return const [];
        }
        _unsupported.remove(d.id);
        return [
          _builtin(
            d,
            appStrings.plgTmdbInstance,
            configured
                ? PluginRuntimeState.validating
                : PluginRuntimeState.blocked,
            detail: configured ? null : appStrings.plgTmdbNoToken,
            configured: configured,
            health: InstanceHealth.unchecked,
          ),
        ];
      case 'media.ffmpeg':
        final service = media?.call();
        if (service == null || !service.nativeAvailable) {
          _unsupported[d.id] = appStrings.plgNoFfmpeg;
          return const [];
        }
        _unsupported.remove(d.id);
        return [
          _builtin(d, appStrings.plgFfmpegInstance, PluginRuntimeState.ready),
        ];
      case 'asr.whisper':
        return _asrInstances(d);
      case 'model.llm':
        final config = model?.call();
        if (config == null) {
          _unsupported[d.id] = appStrings.plgNoAssistant;
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
            detail: configured ? null : appStrings.plgModelNotConfigured,
            configured: configured,
            health: InstanceHealth.unchecked,
          ),
        ];
    }
    return const [];
  }

  PluginInstanceView _builtin(
    PluginDefinition d,
    String name,
    PluginRuntimeState state, {
    String? detail,
    bool configured = true,
    InstanceHealth health = InstanceHealth.local,
  }) => PluginInstanceView(
    id: d.builtinInstanceId,
    pluginId: d.id,
    name: name,
    enabled: true,
    state: state,
    detail: detail,
    configured: configured,
    health: health,
  );

  List<PluginInstanceView> _sourceInstances(
    PluginDefinition d,
    SourceKind kind,
  ) {
    final manager = sources;
    if (manager == null) {
      _unsupported[d.id] = appStrings.plgNoSources;
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
    final configured = credential != SourceAuthorization.missing;
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
      configured: configured,
    );
  }

  Future<List<PluginInstanceView>> _asrInstances(PluginDefinition d) async {
    final registry = asr?.call();
    if (registry == null) {
      _unsupported[d.id] = appStrings.plgNoAsr;
      return const [];
    }
    _unsupported.remove(d.id);
    final result = <PluginInstanceView>[];
    for (final c in registry.list()) {
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
          detail = status.available
              ? appStrings.plgModelDetail(c.modelId)
              : status.reason;
        } catch (_) {
          state = PluginRuntimeState.blocked;
          detail = appStrings.plgLocalAsrUnavailable;
        }
      } else {
        detail = appStrings.plgModelDetail(c.modelId);
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
        ),
      );
    }
    return result;
  }

  // ---- PluginAccess / ToolPolicy: derived from the capability switches ----

  @override
  bool pluginEnabled(String pluginId) => _pluginEnabled(pluginId, 0);

  bool _pluginEnabled(String pluginId, int depth) {
    final d = catalog[pluginId];
    // Unknown ids (e.g. configuration of an implementation this build does
    // not contain) can never be activated.
    if (d == null || depth > catalog.definitions.length) return false;
    if (_unsupported.containsKey(pluginId)) return false;
    if (!switches.isOn(pluginId)) return false;
    return d.dependsOn.every((dep) => _pluginEnabled(dep, depth + 1));
  }

  /// Every capability of an enabled plugin (and enabled instance) is
  /// AI-callable: there are no separate AI grants.
  @override
  bool aiAllows(String pluginId, {String? instanceId, String? capability}) {
    if (!pluginEnabled(pluginId)) return false;
    if (catalog[pluginId]?.deprecated ?? true) return false;
    if (instanceId == null) return true;
    final instance = snapshot(pluginId)?.instances
        .where((i) => i.id == instanceId)
        .firstOrNull;
    return instance == null || instance.enabled;
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
      // Pending removal: its tools are never offered to the AI.
      if (catalog[pluginId]!.deprecated) continue;
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

  /// Re-reads the stored switches (another window may have saved).
  void reloadPolicy() => switches.reload();

  /// The capability switch of [pluginId] (App-wide). Instance switches are
  /// kept: switching back on restores each instance's previous state.
  void setPluginEnabled(String pluginId, bool enabled) {
    final d = catalog[pluginId];
    if (d == null || !d.toggleable) {
      throw StateError('Plugin $pluginId cannot be toggled');
    }
    switches.set(pluginId, enabled);
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
      'policyRevision': switches.revision,
      'configured': s.configured,
      'available': s.available,
      'capabilities': s.aiCapabilities,
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
    );
  }

  /// Read-only summary the AI may see: no hidden instances, addresses,
  /// accounts, keys or configuration. Settings targets are host-generated.
  Map<String, dynamic> describeForAi() => {
    'plugins': [
      for (final s in _snapshots)
        if (!s.definition.deprecated)
          {
            'plugin_id': s.id,
            'name': s.definition.name,
            'category': s.definition.category.label,
            'runs_on': s.definition.location.label,
            'configured': s.configured,
            'available': s.available,
            if (!s.available)
              'reason':
                  s.reason ??
                  (!s.platformSupported
                      ? appStrings.plgDeviceUnsupported
                      : !s.enabled
                      ? appStrings.plgDisabled
                      : appStrings.plgTemporarilyUnavailable),
            'capabilities': [
              for (final c in s.aiCapabilities)
                CapabilityRegistry.label(catalog, c),
            ],
            'instances': [
              for (final i in s.instances)
                if (s.definition.multiInstance && i.enabled)
                  {'instance_id': i.id, 'name': i.name},
            ],
            'settings_target': 'plugins/${s.id}',
            'settings_path': 'AI → ${s.definition.name}',
          },
    ],
    'external_capabilities': externalSummary?.call() ?? const [],
    'note': 'Read-only. Built-in capabilities are listed under plugins; services the user added under AI → External capabilities are listed under external_capabilities, and their tools are offered directly (names start with mcp_). Credentials and servers can only be changed by the user on the AI page.',
  };

  @override
  void dispose() {
    _disposed = true;
    switches.removeListener(_switchesChanged);
    super.dispose();
  }
}
