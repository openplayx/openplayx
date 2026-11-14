import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/configuration/source_credential_broker.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late SourceConfigurationService service;
  setUp(() {
    db = sqlite3.openInMemory();
    service = SourceConfigurationService(db);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('openplayx/source_access'),
          (call) async => call.method == 'restore' ? '/tmp' : 'test-bookmark',
        );
  });
  tearDown(() => service.close());
  SourceManager manager() => SourceManager(configuration: service);
  const plex = SourceConfig(
    id: 'one',
    kind: SourceKind.plex,
    name: 'Plex',
    address: 'http://localhost:32400',
  );

  test('bookmark permission failure asks to select the folder again', () async {
    if (!Platform.isMacOS) return;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('openplayx/source_access'),
          (_) async => throw PlatformException(code: 'permissionDenied'),
        );
    service.save(
      const SourceConfig(
        id: 'local',
        kind: SourceKind.local,
        name: 'Local',
        address: '/tmp',
        bookmark: 'unavailable-bookmark',
      ),
      expectedRevision: 0,
    );
    final host = manager();
    addTearDown(host.dispose);
    await expectLater(
      host.browse('local', const BrowseRequest()),
      throwsA(
        isA<PluginException>()
            .having((e) => e.code, 'code', 'permissionDenied')
            .having((e) => e.message, 'message', contains('重新选择')),
      ),
    );
  });

  test('SQLite owns configuration; secure refs survive reload, edit preserves or rotates secrets', () async {
    final first = manager();
    await first.save(plex, 'private-token');
    final saved = first.configs.single;
    expect(saved.revision, 1);
    final persisted =
        db
                .select('SELECT config_json FROM plugin_instance_configs')
                .single['config_json']
            as String;
    expect(persisted, isNot(contains('private-token')));
    final broker = SourceCredentialBroker(() => service);
    expect(await broker.readForHost(saved), 'private-token');
    final reloaded = manager();
    await reloaded.load();
    await reloaded.save(
      reloaded.configs.single.copyWith(
        name: 'New Plex',
        address: 'http://localhost:32401',
      ),
      '',
    );
    expect(reloaded.configs.single.revision, 2);
    expect(await broker.readForHost(reloaded.configs.single), 'private-token');
    await reloaded.save(reloaded.configs.single, 'replacement');
    expect(service.readSecret('one'), 'replacement');
    expect(await broker.readForHost(reloaded.configs.single), 'replacement');
    await reloaded.remove('one');
    expect(service.load(), isEmpty);
    expect(db.select('SELECT 1 FROM plugin_instance_configs'), isEmpty);
    await first.dispose();
    await reloaded.dispose();
  });

  test(
    'a revision conflict saves neither the stale config nor its credential',
    () async {
      final first = manager();
      final second = manager();
      await first.save(plex, 'original');
      await second.load();
      await first.save(
        first.configs.single.copyWith(name: 'Updated'),
        'new-token',
      );
      await expectLater(
        second.save(
          second.configs.single.copyWith(name: 'Stale'),
          'uncommitted',
        ),
        throwsA(
          isA<PluginException>().having((e) => e.code, 'code', 'conflict'),
        ),
      );
      expect(
        await SourceCredentialBroker(() => service)
            .readForHost(service.load().single),
        'new-token',
      );
      expect(service.load().single.name, 'Updated');
      await first.dispose();
      await second.dispose();
    },
  );

  test('a source credential is kept on its row and unknown or damaged rows '
      'are isolated', () async {
    void insert(String id, String plugin, Map<String, dynamic> data) => db
        .execute('INSERT INTO plugin_instance_configs VALUES (?,?,?,?,?,?,?)', [
          id,
          plugin,
          jsonEncode(data),
          data['configVersion'] is int ? data['configVersion'] : 2,
          1,
          1,
          id == 'legacy' ? 'legacy-secret' : null,
        ]);
    insert('legacy', 'source.plex', {
      ...plex.copyWith(revision: 1).toJson(),
      'id': 'legacy',
      'name': 'Legacy',
    });
    insert('future', 'source.plex', {
      ...plex.toJson(),
      'id': 'future',
      'configVersion': 99,
    });
    insert('broken', 'source.unknown', {'id': 'broken', 'kind': 'unknown'});
    final configs = service.load();
    expect(configs.single.id, 'legacy');
    expect(configs.single.hasSecret, isTrue);
    expect(
      await SourceCredentialBroker(() => service).readForHost(configs.single),
      'legacy-secret',
    );
    expect(
      service.issues.map((i) => i.instanceId),
      containsAll(['future', 'broken']),
    );
    expect(
      db
          .select(
            "SELECT config_json FROM plugin_instance_configs WHERE instance_id='future'",
          )
          .single['config_json'],
      contains('99'),
    );
  });

  test('disabled instances preserve data and reject calls', () async {
    final host = manager();
    await host.save(plex, 'secret');
    await host.setEnabled('one', false);
    expect(host.configs.single.enabled, isFalse);
    expect(
      await SourceCredentialBroker(() => service)
          .readForHost(host.configs.single),
      'secret',
    );
    await expectLater(
      host.browse('one', const BrowseRequest()),
      throwsA(isA<PluginException>().having((e) => e.code, 'code', 'disabled')),
    );
    await host.setEnabled('one', true);
    expect(host.configs.single.enabled, isTrue);
    await host.dispose();
  });

  test('credential references cannot cross instances and expiry is enforced before network access', () async {
    final host = manager();
    await host.save(
      plex.copyWith(
        credentialExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      'secret',
    );
    expect(
      host.credentialStatus('one').authorization,
      SourceAuthorization.expired,
    );
    await expectLater(
      host.browse('one', const BrowseRequest()),
      throwsA(
        isA<PluginException>().having((e) => e.code, 'code', 'authRequired'),
      ),
    );
    await expectLater(
      host.save(
        const SourceConfig(
          id: 'two',
          kind: SourceKind.plex,
          name: 'Two',
          address: 'http://localhost',
        ),
        '',
      ),
      throwsA(isA<PluginException>()),
    );
    await host.dispose();
  });

  test(
    'concurrency includes timed out work; stale application result does not overwrite new revision',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final entered = <HttpRequest>[];
      var active = 0;
      var peak = 0;
      server.listen((request) async {
        entered.add(request);
        active++;
        if (active > peak) peak = active;
        await Future<void>.delayed(const Duration(milliseconds: 1400));
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'MediaContainer': {'Directory': [], 'size': 0},
          }),
        );
        await request.response.close();
        active--;
      });
      addTearDown(() => server.close(force: true));
      final host = manager();
      await host.save(
        plex.copyWith(
          address: 'http://127.0.0.1:${server.port}',
          maxConcurrentRequests: 1,
          requestTimeoutSeconds: 1,
        ),
        'secret',
      );
      final calls = List.generate(
        3,
        (_) => host
            .browse('one', const BrowseRequest())
            .then(
              (_) => 'ok',
              onError: (Object e) => (e as PluginException).code,
            ),
      );
      expect(await Future.wait(calls), everyElement('timeout'));
      expect(entered.length, 1);
      await host.setEnabled('one', false);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(peak, 1);
      expect(host.application('one')?['status'], 'disabled');
      await host.dispose();
    }, _RealHttp()),
  );

  test('active stream remains usable after disable and new resolutions are blocked', () async {
    final directory = await Directory.systemTemp.createTemp('instance-stream-');
    await File('${directory.path}/video.mp4').writeAsBytes([1, 2, 3]);
    addTearDown(() => directory.delete(recursive: true));
    final host = manager();
    await host.save(
      SourceConfig(
        id: 'smb-like-local',
        kind: SourceKind.local,
        name: 'Local',
        address: directory.path,
      ),
      '',
    );
    // Use no external directory bookmark in this unit test.
    final stored = host.configs.single;
    db.execute(
      'UPDATE plugin_instance_configs SET config_json=? WHERE instance_id=?',
      [
        jsonEncode({...stored.toJson(), 'bookmark': null}),
        stored.id,
      ],
    );
    await host.reload();
    final page = await host.browse(stored.id, const BrowseRequest());
    final stream = await host.resolve(page.entries.single.ref);
    expect(host.impact(stored.id).playing, 1);
    await host.setEnabled(stored.id, false);
    expect(host.application(stored.id)?['desired_revision'], 2);
    expect(host.application(stored.id)?['applied_revision'], 1);
    expect(host.impact(stored.id).playing, 1);
    expect(await File.fromUri(stream.uri).readAsBytes(), [1, 2, 3]);
    await expectLater(
      host.resolve(page.entries.single.ref),
      throwsA(isA<PluginException>()),
    );
    await stream.release();
    expect(host.impact(stored.id).playing, 0);
    await host.dispose();
  });
}

class _RealHttp extends HttpOverrides {}
