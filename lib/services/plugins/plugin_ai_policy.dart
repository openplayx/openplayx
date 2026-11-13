import '../../core/plugins/source_capability.dart';
import '../../data/configuration/source_configuration_service.dart';

/// AI scope of one plugin: the third switch after plugin and instance
/// enablement. Turning it off never affects traditional pages.
class PluginAiPolicy {
  const PluginAiPolicy({
    this.allowed = false,
    this.instances = const {},
    this.deniedCapabilities = const {},
  });

  /// Plugin-level permission for AI calls.
  final bool allowed;

  /// Instances of a multi-instance plugin the AI may use. New instances are
  /// not in the set, so they are never exposed until the user opts in.
  final Set<String> instances;

  /// Capabilities the user excluded from AI use.
  final Set<String> deniedCapabilities;

  PluginAiPolicy copyWith({
    bool? allowed,
    Set<String>? instances,
    Set<String>? deniedCapabilities,
  }) => PluginAiPolicy(
    allowed: allowed ?? this.allowed,
    instances: instances ?? this.instances,
    deniedCapabilities: deniedCapabilities ?? this.deniedCapabilities,
  );

  Map<String, dynamic> toJson() => {
    'allowed': allowed,
    'instances': (instances.toList()..sort()),
    'deniedCapabilities': (deniedCapabilities.toList()..sort()),
  };

  factory PluginAiPolicy.fromJson(Map<String, dynamic> j) => PluginAiPolicy(
    allowed: j['allowed'] == true,
    instances: {...(j['instances'] as List? ?? const []).cast<String>()},
    deniedCapabilities: {
      ...(j['deniedCapabilities'] as List? ?? const []).cast<String>(),
    },
  );
}

/// Device-local plugin policy document: plugin switches and AI scope. Plugin switches and AI grants are never synced or
/// widened by import.
class PluginPolicy {
  const PluginPolicy({
    this.disabledPlugins = const {},
    this.ai = const {},
    this.revision = 0,
  });

  final Set<String> disabledPlugins;
  final Map<String, PluginAiPolicy> ai;
  final int revision;

  bool pluginEnabled(String pluginId) => !disabledPlugins.contains(pluginId);
  PluginAiPolicy aiFor(String pluginId) =>
      ai[pluginId] ?? const PluginAiPolicy();

  PluginPolicy copyWith({
    Set<String>? disabledPlugins,
    Map<String, PluginAiPolicy>? ai,
    int? revision,
  }) => PluginPolicy(
    disabledPlugins: disabledPlugins ?? this.disabledPlugins,
    ai: ai ?? this.ai,
    revision: revision ?? this.revision,
  );

  PluginPolicy withAi(String pluginId, PluginAiPolicy value) =>
      copyWith(ai: {...ai, pluginId: value});

  PluginPolicy withPluginEnabled(String pluginId, bool enabled) => copyWith(
    disabledPlugins: enabled
        ? (disabledPlugins.toSet()..remove(pluginId))
        : {...disabledPlugins, pluginId},
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'disabledPlugins': (disabledPlugins.toList()..sort()),
    'ai': {for (final e in ai.entries) e.key: e.value.toJson()},
  };

  factory PluginPolicy.fromJson(Map<String, dynamic> j, int revision) =>
      PluginPolicy(
        disabledPlugins: {
          ...(j['disabledPlugins'] as List? ?? const []).cast<String>(),
        },
        ai: {
          for (final e in (j['ai'] as Map? ?? const {}).entries)
            e.key as String: PluginAiPolicy.fromJson(
              Map<String, dynamic>.from(e.value as Map),
            ),
        },
        revision: revision,
      );
}

/// Storage seam over the unified configuration service.
abstract interface class PluginPolicyStore {
  PluginPolicy? read();

  /// Compare-and-set; throws `PluginException('conflict')` on a stale write.
  PluginPolicy write(PluginPolicy next);
}

/// Stores the policy as a typed document in `configuration.sqlite3`
/// (`settings` namespace `plugins`), next to the instance configurations.
class ConfigurationPolicyStore implements PluginPolicyStore {
  ConfigurationPolicyStore(this._configuration);
  final SourceConfigurationService Function() _configuration;
  static const _namespace = 'plugins';
  static const _key = 'policy';

  @override
  PluginPolicy? read() {
    final (value, revision) = _configuration().readDocument(_namespace, _key);
    if (value == null) return null;
    return PluginPolicy.fromJson(value, revision);
  }

  @override
  PluginPolicy write(PluginPolicy next) {
    final revision = _configuration().writeDocument(
      _namespace,
      _key,
      next.toJson(),
      expectedRevision: next.revision,
    );
    return next.copyWith(revision: revision);
  }
}

/// In-memory store for tests and builds without a configuration database.
class MemoryPolicyStore implements PluginPolicyStore {
  PluginPolicy? value;
  @override
  PluginPolicy? read() => value;
  @override
  PluginPolicy write(PluginPolicy next) {
    if ((value?.revision ?? 0) != next.revision) {
      throw const PluginException('conflict', '设置已被其他窗口修改，请重新加载。');
    }
    return value = next.copyWith(revision: next.revision + 1);
  }
}
