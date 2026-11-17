/// What AI tools ask before using a capability. The plugin manager
/// implements it; without one (tests) everything is allowed.
abstract interface class PluginAccess {
  /// Whether [pluginId]'s capability may take new work: its capability
  /// switch is on, its dependencies too, and this device supports it.
  bool pluginEnabled(String pluginId);

  /// Whether an AI tool call may use [pluginId] — optionally one instance
  /// and one capability. Always implies [pluginEnabled].
  bool aiAllows(String pluginId, {String? instanceId, String? capability});
}
