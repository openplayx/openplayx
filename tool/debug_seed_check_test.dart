// Checks that build/debug-seed.json is usable, against the real services:
// imports it into a throwaway configuration with the App's own code, then
// browses every media source and file source, handshakes every external
// service and makes one free read-only call with the TMDB token and the
// assistant API key. Run with `make seed-check` (docs/debug_seed.md).
//
// Not part of `flutter test` (it lives in tool/ and needs the network).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/debug_seed/debug_seed.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/configuration/configuration_database.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/plugins/metadata_tmdb/tmdb_metadata_plugin.dart';
import 'package:openplayx/services/conversations/assistant_store.dart';
import 'package:openplayx/services/external/external_service_registry.dart';
import 'package:openplayx/services/external/external_service_setup.dart';
import 'package:sqlite3/sqlite3.dart';

const _timeout = Duration(seconds: 20);

void main() {
  final file = File('build/debug-seed.json');
  final text = file.existsSync() ? file.readAsStringSync() : null;
  late Database db;

  setUpAll(() async {
    if (text == null) fail('build/debug-seed.json not found; run make seed');
    db = sqlite3.openInMemory();
    final report = await DebugSeed.apply(db, text);
    expect(report.failed, isEmpty, reason: 'import: $report');
  });

  final seed = text == null ? const {} : jsonDecode(text) as Map;
  List<Map> list(String key) => [
    for (final e in seed[key] as List? ?? const []) e as Map,
  ];

  group('media sources', () {
    for (final s in list('sources')) {
      test('${s['id']} (${s['kind']})', () async {
        final sources = SourceManager(
          configuration: SourceConfigurationService(db),
        );
        try {
          final page = await sources
              .browse(s['id'] as String, const BrowseRequest())
              .timeout(_timeout);
          printOnFailure('entries: ${page.entries.map((e) => e.name)}');
          expect(page.entries, isNotEmpty, reason: 'root lists nothing');
        } finally {
          await sources.dispose();
        }
      });
    }
  });

  group('file sources', () {
    for (final f in list('fileSources')) {
      test('${f['id']}', () async {
        final sources = SourceManager(
          configuration: SourceConfigurationService(db),
        );
        try {
          final root = f['root'] as String?;
          final page = await sources
              .browse(
                f['source'] as String,
                BrowseRequest(
                  node: root == null
                      ? null
                      : ResourceRef(f['source'] as String, root),
                ),
              )
              .timeout(_timeout);
          expect(page.entries, isNotEmpty, reason: 'folder lists nothing');
        } finally {
          await sources.dispose();
        }
      });
    }
  });

  group('external services', () {
    for (final e in list('externalServices')) {
      test('${e['id']}', () async {
        final registry = ExternalServiceRegistry(db: db);
        await registry.load();
        final service = registry.get(e['id'] as String)!;
        final probe = await ExternalServiceSetup(registry: registry)
            .probe(service.baseUrl, await registry.token(service.id) ?? '')
            .timeout(_timeout);
        printOnFailure('${probe.endpoint}: ${probe.tools}');
        expect(probe.tools, isNotEmpty, reason: 'no MCP tools');
      });
    }
  });

  if (seed['metadata'] case {'tmdbToken': final String _}) {
    test('TMDB token', () async {
      final token =
          ConfigurationDatabase.readSetting(db, 'metadata', 'tmdbToken')
              as String;
      final config = await TmdbTransport(
        token,
      ).get('/configuration', const {}).timeout(_timeout);
      expect(config['images'], isNotNull);
    });
  }

  if (seed['assistant'] case final Map _) {
    test('assistant API key', () async {
      final store = AssistantStore(sqlite3.openInMemory(), configuration: db);
      final config = store.loadConfig();
      final client = HttpClient();
      try {
        // Lists models: authenticated, free, no tokens spent.
        final request = await client
            .getUrl(Uri.parse('${config.endpoint}/models'))
            .timeout(_timeout);
        request.headers.set('Authorization', 'Bearer ${await store.key()}');
        final response = await request.close().timeout(_timeout);
        final body = await utf8.decodeStream(response);
        expect(response.statusCode, 200, reason: body);
        final models = [
          for (final m in (jsonDecode(body)['data'] as List? ?? const []))
            (m as Map)['id'],
        ];
        expect(
          models,
          contains(config.model),
          reason: 'model "${config.model}" not offered; have $models',
        );
      } finally {
        client.close(force: true);
      }
    });
  }
}
