import 'dart:convert';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../../core/models/text_model.dart';
import '../../data/configuration/configuration_database.dart';
import '../ai_tools/tool_registry.dart';

class AssistantConfig {
  const AssistantConfig({
    this.endpoint = exampleEndpoint,
    this.model = exampleModel,
    this.hasKey = false,
    this.cloudAllowed = false,
    this.toolsSupported = false,
    this.textVerified = false,
    this.streamVerified = false,
    this.maxTokens = 2048,
  });

  /// Shown as hints in the settings form; the user enters their own.
  static const exampleEndpoint = 'https://api.deepseek.com';
  static const exampleModel = 'deepseek-v4-pro';

  final String endpoint;
  final String model;

  /// An API key is saved (with the settings document; never in [toJson]).
  final bool hasKey;
  final bool cloudAllowed;
  final bool toolsSupported;
  final bool textVerified;
  final bool streamVerified;
  final int maxTokens;

  /// A saved key is all the assistant needs to start.
  bool get configured => hasKey;
  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    'model': model,
    'cloudAllowed': cloudAllowed,
    'toolsSupported': toolsSupported,
    'textVerified': textVerified,
    'streamVerified': streamVerified,
    'maxTokens': maxTokens,
  };
  factory AssistantConfig.fromJson(Map<String, dynamic> json) =>
      AssistantConfig(
        endpoint: json['endpoint'] as String,
        model: json['model'] as String,
        hasKey: (json['apiKey'] as String?)?.isNotEmpty == true,
        cloudAllowed: json['cloudAllowed'] == true,
        toolsSupported: json['toolsSupported'] == true,
        textVerified: json['textVerified'] == true,
        streamVerified: json['streamVerified'] == true,
        maxTokens: json['maxTokens'] as int? ?? 2048,
      );
  void validate() {
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        model.trim().isEmpty ||
        model.length > 200 ||
        maxTokens < 128 ||
        maxTokens > 16384) {
      throw const FormatException('请填写有效的 HTTPS API 基址、模型和输出上限（128–16384）');
    }
  }
}

class AssistantStore implements ToolJournal {
  /// [db] holds conversations and tool records (library database);
  /// [configuration] holds the model settings (`configuration.sqlite3`).
  AssistantStore(this.db, {required this.configuration}) {
    ConfigurationDatabase.initialize(configuration);
    db.execute(
      'CREATE TABLE IF NOT EXISTS assistant_operations (id TEXT PRIMARY KEY, result TEXT NOT NULL)',
    );
    db.execute('''CREATE TABLE IF NOT EXISTS assistant_turns (
      id TEXT PRIMARY KEY, status TEXT NOT NULL, messages TEXT NOT NULL,
      error TEXT, tokens INTEGER, created INTEGER NOT NULL)''');
    _ensureConversations();
    db.execute(
      "UPDATE assistant_turns SET status='interrupted' WHERE status IN ('running','waiting')",
    );
  }
  final Database db;
  final Database configuration;
  bool _closed = false;
  void close() {
    _closed = true;
  }

  @override
  ToolResult? previous(String operation, String callId) {
    final rows = db.select(
      'SELECT result FROM assistant_operations WHERE id=?',
      [operation],
    );
    if (rows.isEmpty) return null;
    final json =
        jsonDecode(rows.first['result'] as String) as Map<String, dynamic>;
    if (json['status'] == 'pending') {
      return ToolResult(callId, 'failed', error: 'executionUnknown');
    }
    return ToolResult(
      callId,
      json['status'] as String,
      data: json['data'] as Map<String, dynamic>,
      error: json['error_code'] as String?,
      retryable: json['retryable'] == true,
    );
  }

  @override
  void record(String operation, ToolResult result) {
    if (_closed) return;
    db.execute('INSERT OR REPLACE INTO assistant_operations VALUES (?,?)', [
      operation,
      jsonEncode(result.toJson()),
    ]);
  }

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  static const _settingsNamespace = 'assistant';
  static const _settingsKey = 'config';

  /// The `assistant / config` settings document: [AssistantConfig.toJson]
  /// plus the API key under `apiKey`.
  Map<String, dynamic>? _document() {
    final value = ConfigurationDatabase.readSetting(
      configuration,
      _settingsNamespace,
      _settingsKey,
    );
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  AssistantConfig loadConfig() {
    final document = _document();
    return document == null
        ? const AssistantConfig()
        : AssistantConfig.fromJson(document);
  }

  /// The saved API key; empty when none is saved.
  Future<String> key([AssistantConfig? _]) async =>
      _document()?['apiKey'] as String? ?? '';

  /// Saves [config]; a non-empty [secret] replaces the API key, an empty
  /// one keeps the saved key.
  Future<void> saveConfig(AssistantConfig config, String secret) async =>
      writeConfig(
        configuration,
        config,
        secret.isNotEmpty ? secret : await key(),
      );

  /// Validates [config] and stores it with [apiKey] (empty: none) as the
  /// assistant settings document of [configuration].
  static void writeConfig(
    Database configuration,
    AssistantConfig config,
    String apiKey,
  ) {
    config.validate();
    ConfigurationDatabase.writeSetting(
      configuration,
      _settingsNamespace,
      _settingsKey,
      {...config.toJson(), if (apiKey.isNotEmpty) 'apiKey': apiKey},
    );
  }

  void _ensureConversations() {
    db.execute(
      'CREATE TABLE IF NOT EXISTS assistant_conversations (id TEXT PRIMARY KEY, title TEXT NOT NULL, created INTEGER NOT NULL)',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS assistant_chat_state (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    if (!db
        .select('PRAGMA table_info(assistant_turns)')
        .any((r) => r['name'] == 'conversation_id')) {
      db.execute(
        "ALTER TABLE assistant_turns ADD COLUMN conversation_id TEXT NOT NULL DEFAULT 'legacy'",
      );
    }
    if (db.select('SELECT 1 FROM assistant_conversations').isEmpty) {
      final hasLegacy = db
          .select('SELECT 1 FROM assistant_turns LIMIT 1')
          .isNotEmpty;
      final id = hasLegacy ? 'legacy' : newId();
      db.execute('INSERT INTO assistant_conversations VALUES (?,?,?)', [
        id,
        '',
        DateTime.now().microsecondsSinceEpoch,
      ]);
    }
    if (db
        .select("SELECT 1 FROM assistant_chat_state WHERE key='active'")
        .isEmpty) {
      _setLocal(
        'active',
        db
                .select(
                  'SELECT id FROM assistant_conversations ORDER BY created DESC LIMIT 1',
                )
                .first['id']
            as String,
      );
    }
  }

  void _setLocal(String key, String value) => db.execute(
    'INSERT INTO assistant_chat_state VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
    [key, value],
  );
  String get conversationId =>
      db
              .select(
                "SELECT value FROM assistant_chat_state WHERE key='active'",
              )
              .first['value']
          as String;
  List<Row> get conversations =>
      db.select('SELECT * FROM assistant_conversations ORDER BY created DESC');
  String get draft {
    final rows = db.select(
      'SELECT value FROM assistant_chat_state WHERE key=?',
      ['draft:$conversationId'],
    );
    return rows.isEmpty ? '' : rows.first['value'] as String;
  }

  void saveDraft(String value) {
    if (!_closed) _setLocal('draft:$conversationId', value);
  }

  void selectConversation(String id) {
    if (db.select('SELECT 1 FROM assistant_conversations WHERE id=?', [
      id,
    ]).isEmpty) {
      return;
    }
    _setLocal('active', id);
  }

  String createConversation() {
    final id = newId();
    db.execute('INSERT INTO assistant_conversations VALUES (?,?,?)', [
      id,
      '',
      DateTime.now().microsecondsSinceEpoch,
    ]);
    selectConversation(id);
    return id;
  }

  List<Row> turns({int? limit, int offset = 0}) {
    if (limit == null) {
      return db.select(
        'SELECT * FROM assistant_turns WHERE conversation_id=? ORDER BY created,id',
        [conversationId],
      );
    }
    return db
        .select(
          'SELECT * FROM assistant_turns WHERE conversation_id=? ORDER BY created DESC,id DESC LIMIT ? OFFSET ?',
          [conversationId, limit, offset],
        )
        .reversed
        .toList();
  }

  bool hasEarlier(int loaded) =>
      (db.select(
            'SELECT COUNT(*) AS total FROM assistant_turns WHERE conversation_id=?',
            [conversationId],
          ).first['total']
          as int) >
      loaded;
  void saveTurn(
    String id,
    String status,
    List<ModelMessage> messages, {
    String? error,
    int? tokens,
  }) {
    db.execute(
      'INSERT INTO assistant_turns (id,status,messages,error,tokens,created,conversation_id) VALUES (?,?,?,?,?,?,?) ON CONFLICT(id) '
      'DO UPDATE SET status=excluded.status,messages=excluded.messages,error=excluded.error,tokens=excluded.tokens',
      [
        id,
        status,
        jsonEncode(messages.map((m) => m.toJson()).toList()),
        error,
        tokens,
        DateTime.now().microsecondsSinceEpoch,
        conversationId,
      ],
    );
    final title = messages.where((m) => m.role == 'user').firstOrNull?.text;
    if (title != null) {
      db.execute(
        "UPDATE assistant_conversations SET title=? WHERE id=? AND title=''",
        [title.substring(0, min(60, title.length)), conversationId],
      );
    }
  }
}
