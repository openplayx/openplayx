import '../plugins/plugin_manager.dart';
import 'tool_registry.dart';

/// Read-only view of plugin availability for the assistant: which features
/// work, why others do not, and where in Settings the user can fix it. There
/// is deliberately no write tool — enabling plugins, widening AI scope,
/// credentials and servers are changed only on trusted settings pages.
class PluginTools {
  PluginTools({required this.registry, required this.plugins}) {
    registry.register(
      RegisteredTool(
        'plugin_status',
        'List built-in plugins (sources, metadata, media processing, speech recognition, downloads) with their state, the reason a feature is unavailable, and the Settings path where the user can enable or configure it. Read-only; you cannot change plugin settings.',
        const {},
        (_) async {
          await plugins.refresh();
          return plugins.describeForAi();
        },
      ),
    );
  }

  final ToolRegistry registry;
  final PluginManager plugins;
}
