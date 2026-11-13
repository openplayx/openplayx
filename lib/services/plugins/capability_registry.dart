import 'plugin_catalog.dart';

/// One capability provided by one instance at runtime.
class CapabilityRegistration {
  const CapabilityRegistration({
    required this.capabilityId,
    required this.pluginId,
    required this.instanceId,
    required this.instanceName,
    required this.ai,
  });
  final String capabilityId;
  final String pluginId;
  final String instanceId;
  final String instanceName;

  /// The AI scope currently allows this registration.
  final bool ai;
}

/// Runtime view of which instances provide which typed capability. Built
/// from Plugin Manager snapshots; it is not user configuration and holds no
/// switches of its own.
class CapabilityRegistry {
  CapabilityRegistry(this.registrations, this.revision);
  const CapabilityRegistry.empty() : registrations = const [], revision = 0;

  final List<CapabilityRegistration> registrations;
  final int revision;

  /// Providers of [capabilityId]; [aiOnly] narrows to the AI scope.
  List<CapabilityRegistration> providers(
    String capabilityId, {
    bool aiOnly = false,
  }) => [
    for (final r in registrations)
      if (r.capabilityId == capabilityId && (!aiOnly || r.ai)) r,
  ];

  List<CapabilityRegistration> forPlugin(String pluginId) => [
    for (final r in registrations)
      if (r.pluginId == pluginId) r,
  ];

  /// Capabilities with at least one usable provider.
  Set<String> get capabilityIds => {
    for (final r in registrations) r.capabilityId,
  };

  /// Human label for a capability id, from the first definition declaring it.
  static String label(PluginCatalog catalog, String capabilityId) {
    for (final d in catalog.definitions) {
      final c = d.capability(capabilityId);
      if (c != null) return c.label;
    }
    return capabilityId;
  }
}
