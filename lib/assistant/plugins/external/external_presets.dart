import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../../../data/configuration/configuration_database.dart';
import 'external_service_registry.dart';
import '../../../l10n/l10n.dart';

/// Random anonymous installation id, created once and kept in
/// `configuration.sqlite3`. It identifies nothing about the user; preset
/// services use it as their bearer token, for per-install quotas.
class InstallId {
  InstallId(this.db);
  final Database db;
  String? _value;

  String get value => _value ??= () {
    final stored = ConfigurationDatabase.readSetting(db, 'app', 'install_id');
    if (stored is String && RegExp(r'^[a-z0-9-]{16,64}$').hasMatch(stored)) {
      return stored;
    }
    final r = Random.secure();
    final id = List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    ConfigurationDatabase.writeSetting(db, 'app', 'install_id', id);
    return id;
  }();
}

/// External capabilities (MCP services) that ship with the App.
///
/// Each is added to [ExternalServiceRegistry] once, like a service the user
/// configured, so it shows under AI → 外部能力 and its tools reach the
/// assistant through the normal external-tool path. A user who removes one
/// keeps it removed. The tool definitions are bundled so the tools exist
/// before the first online check, which then refreshes them.
abstract final class ExternalPresets {
  /// mcp-tavily (repository `mcp-tavily`): web search on OpenPlayX's
  /// Cloudflare Worker; the search provider's key stays on the server.
  /// The id ends in `tavily`, so its tools are offered as
  /// `mcp_tavily_<tool>` (see ExternalTools.alias).
  static const tavilyId = 'preset-tavily';

  // A getter so a fresh seed is named in the App's current language.
  static ExternalService get tavily => ExternalService(
    id: tavilyId,
    name: appStrings.webSearchPresetName,
    baseUrl: 'https://mcp-tavily.openplayx.com',
    endpoint: 'https://mcp-tavily.openplayx.com/mcp',
    serverName: 'mcp-tavily',
    serverTitle: 'Web search',
    tools: const ['web_search'],
    toolDefs: const [
      {
        'name': 'web_search',
        'title': 'Web search',
        'description':
            'Searches the web and returns up to `count` results (title, url, '
            'snippet, date). Use `time_range` for recent events. Write the '
            'query in the language most likely to find good sources. Fails '
            "with quota_exceeded when today's free searches are used up.",
        'inputSchema': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'minLength': 1, 'maxLength': 300},
            'count': {
              'type': 'integer',
              'description': 'Number of results.',
              'default': 8,
              'minimum': 1,
              'maximum': 10,
            },
            'time_range': {
              'type': 'string',
              'description': 'Only results published within this period.',
              'enum': ['day', 'week', 'month', 'year'],
            },
          },
          'required': ['query'],
          'additionalProperties': false,
        },
        'annotations': {
          'title': 'Web search',
          'readOnlyHint': true,
          'destructiveHint': false,
          'idempotentHint': true,
          'openWorldHint': true,
        },
      },
    ],
    available: true,
  );

  static List<ExternalService> get all => [tavily];

  static const _namespace = 'external_presets';

  /// Adds presets not added before. Returns the ids it added.
  static Future<List<String>> ensure(
    ExternalServiceRegistry registry,
    InstallId installId,
  ) async {
    if (!registry.loaded) await registry.load();
    final added = <String>[];
    for (final preset in all) {
      final seeded = ConfigurationDatabase.readSetting(
        registry.db,
        _namespace,
        preset.id,
      );
      if (seeded == true) continue;
      if (registry.get(preset.id) == null &&
          registry.byBaseUrl(preset.baseUrl) == null) {
        await registry.save(preset, token: installId.value);
        added.add(preset.id);
      }
      ConfigurationDatabase.writeSetting(
        registry.db,
        _namespace,
        preset.id,
        true,
      );
    }
    return added;
  }
}
