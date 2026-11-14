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
        'List built-in capabilities (sources, metadata, media processing, speech recognition) and the external services the user added under AI → 外部能力 (their tools are offered directly, names start with mcp_), with availability and the reason a feature is unavailable. Read-only; only the user can add services or change settings on the AI page.',
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
