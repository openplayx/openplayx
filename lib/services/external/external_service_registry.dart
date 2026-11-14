import 'dart:async';
import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../data/configuration/configuration_database.dart';

/// One user-configured external capability: an MCP server (Streamable HTTP)
/// added from the AI page's 外部能力 → 配置.
class ExternalService {
  const ExternalService({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.endpoint,
    required this.serverName,
    this.serverTitle = '',
    this.version = '',
    this.tools = const [],
    this.toolDefs = const [],
    this.available = false,
    this.checkedAt,
  });

  final String id;
  final String name;

  /// Service root as entered (normalised).
  final String baseUrl;

  /// MCP endpoint that answered (e.g. `https://bt.example.com/api/mcp`).
  final String endpoint;

  /// `serverInfo.name` / `title` / `version` from the last handshake.
  final String serverName;
  final String serverTitle;
  final String version;

  /// Tool names from the last `tools/list`.
  final List<String> tools;

  /// Full tool definitions (name, description, inputSchema, annotations)
  /// from the last `tools/list`; what the AI is offered.
  final List<Map<String, dynamic>> toolDefs;

  /// The last check connected and listed tools.
  final bool available;
  final DateTime? checkedAt;

  String get label => serverTitle.isNotEmpty ? serverTitle : serverName;

  ExternalService copyWith({
    String? name,
    String? endpoint,
    String? serverName,
    String? serverTitle,
    String? version,
    List<String>? tools,
    List<Map<String, dynamic>>? toolDefs,
    bool? available,
    DateTime? checkedAt,
  }) => ExternalService(
    id: id,
    name: name ?? this.name,
    baseUrl: baseUrl,
    endpoint: endpoint ?? this.endpoint,
    serverName: serverName ?? this.serverName,
    serverTitle: serverTitle ?? this.serverTitle,
    version: version ?? this.version,
    tools: tools ?? this.tools,
    toolDefs: toolDefs ?? this.toolDefs,
    available: available ?? this.available,
    checkedAt: checkedAt ?? this.checkedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'base_url': baseUrl,
    'endpoint': endpoint,
    'server_name': serverName,
    'server_title': serverTitle,
    'version': version,
    'tools': tools,
    'tool_defs': toolDefs,
    'available': available,
    'checked_at': checkedAt?.toUtc().toIso8601String(),
  };

  factory ExternalService.fromJson(Map<String, dynamic> j) => ExternalService(
    id: j['id'] as String,
    name: j['name'] as String,
    baseUrl: j['base_url'] as String,
    endpoint: j['endpoint'] as String,
    serverName: j['server_name'] as String? ?? '',
    serverTitle: j['server_title'] as String? ?? '',
    version: j['version'] as String? ?? '',
    tools: [...(j['tools'] as List? ?? const []).whereType<String>()],
    toolDefs: [
      for (final t in (j['tool_defs'] as List? ?? const []))
        if (t is Map) Map<String, dynamic>.from(t),
    ],
    available: j['available'] as bool? ?? false,
    checkedAt: DateTime.tryParse(j['checked_at'] as String? ?? ''),
  );
}

/// Persists external services, with their access token, in the
/// `external_services` table of `configuration.sqlite3`.
class ExternalServiceRegistry {
  ExternalServiceRegistry({required this.db}) {
    ConfigurationDatabase.initialize(db);
  }

  /// Shared by the AI page, its detail views and the external tools.
  static ExternalServiceRegistry? current;

  /// The shared instance for [db]; replaced when the configuration
  /// database changes (a closed database is never reused).
  static ExternalServiceRegistry forDb(Database db) {
    final c = current;
    if (c != null && identical(c.db, db)) return c;
    return current = ExternalServiceRegistry(db: db);
  }

  final Database db;
  List<ExternalService> services = const [];
  bool loaded = false;
  final changes = StreamController<void>.broadcast();

  static String newId() =>
      'ext-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  Future<void> load() async {
    _reload();
    loaded = true;
  }

  void _reload() => services = [
    for (final r in db.select(
      'SELECT * FROM external_services ORDER BY created, id',
    ))
      _row(r),
  ];

  static ExternalService _row(Row r) => ExternalService(
    id: r['id'] as String,
    name: r['name'] as String,
    baseUrl: r['base_url'] as String,
    endpoint: r['endpoint'] as String,
    serverName: r['server_name'] as String,
    serverTitle: r['server_title'] as String,
    version: r['version'] as String,
    tools: [
      ...(jsonDecode(r['tools_json'] as String) as List).whereType<String>(),
    ],
    toolDefs: [
      for (final t in jsonDecode(r['tool_defs_json'] as String) as List)
        if (t is Map) Map<String, dynamic>.from(t),
    ],
    available: r['available'] == 1,
    checkedAt: DateTime.tryParse(r['checked_at'] as String? ?? ''),
  );

  /// Inserts or updates by id; an update keeps the row's position.
  void _upsert(ExternalService s, {required int created}) => db.execute(
    '''INSERT INTO external_services (id,name,base_url,endpoint,server_name,
       server_title,version,tools_json,tool_defs_json,available,checked_at,
       created) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
       ON CONFLICT(id) DO UPDATE SET name=excluded.name,
       base_url=excluded.base_url,endpoint=excluded.endpoint,
       server_name=excluded.server_name,server_title=excluded.server_title,
       version=excluded.version,tools_json=excluded.tools_json,
       tool_defs_json=excluded.tool_defs_json,available=excluded.available,
       checked_at=excluded.checked_at''',
    [
      s.id,
      s.name,
      s.baseUrl,
      s.endpoint,
      s.serverName,
      s.serverTitle,
      s.version,
      jsonEncode(s.tools),
      jsonEncode(s.toolDefs),
      s.available ? 1 : 0,
      s.checkedAt?.toUtc().toIso8601String(),
      created,
    ],
  );

  ExternalService? get(String id) =>
      services.where((s) => s.id == id).firstOrNull;

  ExternalService? byBaseUrl(String baseUrl) =>
      services.where((s) => s.baseUrl == baseUrl).firstOrNull;

  /// Saves [service] (insert or update by id); [token] null keeps the
  /// stored one.
  Future<void> save(ExternalService service, {String? token}) async {
    if (!loaded) await load();
    _upsert(service, created: DateTime.now().microsecondsSinceEpoch);
    if (token != null) {
      db.execute('UPDATE external_services SET token=? WHERE id=?', [
        token.trim(),
        service.id,
      ]);
    }
    _reload();
    changes.add(null);
  }

  Future<String?> token(String id) async =>
      db.select('SELECT token FROM external_services WHERE id=?', [
            id,
          ]).firstOrNull?['token']
          as String?;

  Future<void> remove(String id) async {
    db.execute('DELETE FROM external_services WHERE id=?', [id]);
    _reload();
    changes.add(null);
  }
}
