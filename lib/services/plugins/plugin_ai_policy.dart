import '../../core/plugins/source_capability.dart';
import '../../data/configuration/source_configuration_service.dart';

/// Device-local plugin policy document: plugin switches only. Every
/// capability of an enabled plugin is AI-callable; there are no AI grants.
/// Older documents may still carry an `ai` section, which is ignored.
class PluginPolicy {
  const PluginPolicy({this.disabledPlugins = const {}, this.revision = 0});

  final Set<String> disabledPlugins;
  final int revision;

  bool pluginEnabled(String pluginId) => !disabledPlugins.contains(pluginId);

  PluginPolicy copyWith({Set<String>? disabledPlugins, int? revision}) =>
      PluginPolicy(
        disabledPlugins: disabledPlugins ?? this.disabledPlugins,
        revision: revision ?? this.revision,
      );

  PluginPolicy withPluginEnabled(String pluginId, bool enabled) => copyWith(
    disabledPlugins: enabled
        ? (disabledPlugins.toSet()..remove(pluginId))
        : {...disabledPlugins, pluginId},
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'disabledPlugins': (disabledPlugins.toList()..sort()),
  };

  factory PluginPolicy.fromJson(Map<String, dynamic> j, int revision) =>
      PluginPolicy(
        disabledPlugins: {
          ...(j['disabledPlugins'] as List? ?? const []).cast<String>(),
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
