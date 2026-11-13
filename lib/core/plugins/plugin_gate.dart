/// Host-wide checks business services and AI tool adapters consult before
/// starting a new call. The Plugin Manager installs the implementation; with
/// none installed (tests, early startup) everything is allowed, which matches
/// the behaviour before plugin management existed.
abstract interface class PluginAccess {
  /// Whether [pluginId] may accept new business calls (plugin enabled, not
  /// blocked by a disabled dependency). Instance switches are separate.
  bool pluginEnabled(String pluginId);

  /// Whether an AI tool call may use [pluginId] — optionally one instance and
  /// one capability. Always implies [pluginEnabled]. Traditional pages never
  /// consult this.
  bool aiAllows(String pluginId, {String? instanceId, String? capability});
}

abstract final class PluginGate {
  static PluginAccess? current;

  static bool enabled(String pluginId) =>
      current?.pluginEnabled(pluginId) ?? true;

  static bool ai(String pluginId, {String? instanceId, String? capability}) =>
      current?.aiAllows(
        pluginId,
        instanceId: instanceId,
        capability: capability,
      ) ??
      true;
}
