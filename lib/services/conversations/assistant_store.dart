import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/models/text_model.dart';
import '../ai_tools/tool_registry.dart';

class AssistantConfig {
  const AssistantConfig({
    this.endpoint = 'https://api.openai.com/v1',
    this.model = 'gpt-5-mini',
    this.credentialRef,
    this.cloudAllowed = false,
    this.toolsSupported = false,
    this.textVerified = false,
    this.streamVerified = false,
    this.maxTokens = 2048,
  });
  final String endpoint;
  final String model;
  final String? credentialRef;
  final bool cloudAllowed;
  final bool toolsSupported;
  final bool textVerified;
  final bool streamVerified;
  final int maxTokens;
  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    'model': model,
    'credentialRef': credentialRef,
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
        credentialRef: json['credentialRef'] as String?,
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
  AssistantStore(this.db, {FlutterSecureStorage? credentials})
    : credentials =
          credentials ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          ) {
    db.execute(
      'CREATE TABLE IF NOT EXISTS assistant_config (id INTEGER PRIMARY KEY, value TEXT NOT NULL)',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS assistant_operations (id TEXT PRIMARY KEY, result TEXT NOT NULL)',
    );
    db.execute('''CREATE TABLE IF NOT EXISTS assistant_turns (
      id TEXT PRIMARY KEY, status TEXT NOT NULL, messages TEXT NOT NULL,
      error TEXT, tokens INTEGER, created INTEGER NOT NULL)''');
    db.execute(
      "UPDATE assistant_turns SET status='interrupted' WHERE status IN ('running','waiting')",
    );
  }
  final Database db;
  final FlutterSecureStorage credentials;
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
  AssistantConfig loadConfig() {
    final rows = db.select('SELECT value FROM assistant_config WHERE id=1');
    return rows.isEmpty
        ? const AssistantConfig()
        : AssistantConfig.fromJson(
            jsonDecode(rows.first['value'] as String) as Map<String, dynamic>,
          );
  }

  Future<String> key(AssistantConfig config) async {
    final ref = config.credentialRef;
    if (ref == null || !ref.startsWith('assistant.')) return '';
    return await credentials.read(key: ref) ?? '';
  }

  Future<void> saveConfig(AssistantConfig config, String secret) async {
    config.validate();
    final old = loadConfig();
    String? staged;
    try {
      if (secret.isNotEmpty) {
        staged = 'assistant.${newId()}';
        await credentials.write(key: staged, value: secret);
      }
      final json = config.toJson()
        ..['credentialRef'] = staged ?? old.credentialRef;
      db.execute('INSERT OR REPLACE INTO assistant_config VALUES (1,?)', [
        jsonEncode(json),
      ]);
    } catch (_) {
      if (staged != null) await credentials.delete(key: staged);
      rethrow;
    }
    if (staged != null && old.credentialRef != null) {
      // A failed cleanup must not undo an already saved configuration.
      try {
        await credentials.delete(key: old.credentialRef!);
      } catch (_) {}
    }
  }

  List<Row> turns() =>
      db.select('SELECT * FROM assistant_turns ORDER BY created,id');
  void saveTurn(
    String id,
    String status,
    List<ModelMessage> messages, {
    String? error,
    int? tokens,
  }) => db.execute(
    '''INSERT INTO assistant_turns VALUES (?,?,?,?,?,?) ON CONFLICT(id)
    DO UPDATE SET status=excluded.status,messages=excluded.messages,error=excluded.error,tokens=excluded.tokens''',
    [
      id,
      status,
      jsonEncode(messages.map((m) => m.toJson()).toList()),
      error,
      tokens,
      DateTime.now().microsecondsSinceEpoch,
    ],
  );
}
