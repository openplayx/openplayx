import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/core/plugins/plugin_gate.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/configuration/source_credential_broker.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/services/ai_tools/media_tools.dart';
import 'package:openplayx/services/ai_tools/plugin_tools.dart';
import 'package:openplayx/services/ai_tools/tool_registry.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/services/plugins/plugin_ai_policy.dart';
import 'package:openplayx/services/plugins/plugin_catalog.dart';
import 'package:openplayx/services/plugins/plugin_manager.dart';
import 'package:sqlite3/sqlite3.dart';

class FakeSources extends SourceManager {
  final list = <SourceConfig>[
    const SourceConfig(
      id: 'home',
      name: '家里 NAS',
      kind: SourceKind.smb,
      address: 'smb://nas.home/media',
    ),
    const SourceConfig(
      id: 'office',
      name: '办公室 NAS',
      kind: SourceKind.smb,
      address: 'smb://nas.office/media',
    ),
  ];
  var playing = 0;
  @override
  List<SourceConfig> get configs => List.unmodifiable(list);
  @override
  Future<void> load() async {}
  @override
  SourceInstanceImpact impact(String id) =>
      SourceInstanceImpact(playing: id == 'home' ? playing : 0);
  @override
  Map<String, Object?>? application(String id) => null;
  @override
  SourceCredentialStatus credentialStatus(String id) =>
      const SourceCredentialStatus(SourceAuthorization.configured);
  @override
  SourceApplicationStatus applicationStatus(String id) =>
      SourceApplicationStatus.saved;
  @override
  String applicationLabel(String id) => '已保存';
  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async =>
      BrowseResult([
        SourceEntry(ResourceRef(id, '/film.mp4'), 'Film', isFolder: false),
      ]);
}

PluginCatalog _catalog() => PluginCatalog.builtIn();

Future<PluginManager> _manager({
  FakeSources? sources,
  PluginPolicyStore? store,
}) async {
  final manager = PluginManager(
    catalog: _catalog(),
    sources: sources ?? FakeSources(),
    store: store ?? MemoryPolicyStore(),
  )..install();
  addTearDown(manager.dispose);
  await manager.refresh();
  return manager;
}

ModelToolCall _call(String name, [Map<String, dynamic> args = const {}]) =>
    ModelToolCall('c-$name', name, jsonEncode(args));

void main() {
  group('catalog', () {
    test('built-in definitions validate and match source manifests', () {
      final catalog = _catalog();
      expect(catalog['source.smb']!.capability('source.browse'), isNotNull);
      // DLNA does not implement attachments; no empty implementation listed.
      expect(catalog['source.dlna']!.capability('source.attachments'), isNull);
      expect(catalog['asr.whisper']!.dependsOn, ['media.ffmpeg']);
      expect(catalog.exclusiveTools['media_probe'], [
        ('media.ffmpeg', 'media.probe'),
      ]);
    });

    test('rejects dependency cycles and host tools bound to plugins', () {
      PluginDefinition def(String id, List<String> deps, {List<String>? t}) =>
          PluginDefinition(
            id: id,
            name: id,
            summary: id,
            category: PluginCategory.model,
            location: ExecutionLocation.device,
            icon: _catalog().definitions.first.icon,
            dependsOn: deps,
            capabilities: [
              PluginCapabilityInfo('x.cap', 'cap', 'd', tools: t ?? const []),
            ],
          );
      expect(
        () => PluginCatalog([
          def('a.one', ['b.two']),
          def('b.two', ['a.one']),
        ]),
        throwsStateError,
      );
      expect(
        () => PluginCatalog([
          def('a.one', [], t: ['context_get']),
        ]),
        throwsStateError,
      );
    });
  });

  group('policy', () {
    tearDown(() => PluginGate.current = null);

    test('first run keeps existing access; new instances start outside AI '
        'scope', () async {
      final sources = FakeSources();
      final store = MemoryPolicyStore();
      var manager = await _manager(sources: sources, store: store);
      expect(manager.aiAllows('source.smb', instanceId: 'home'), isTrue);
      expect(manager.aiAllows('source.smb', instanceId: 'office'), isTrue);

      sources.list.add(
        const SourceConfig(
          id: 'new',
          name: '新 NAS',
          kind: SourceKind.smb,
          address: 'smb://new/media',
        ),
      );
      manager = await _manager(sources: sources, store: store);
      expect(manager.aiAllows('source.smb', instanceId: 'new'), isFalse);
      expect(manager.aiAllows('source.smb', instanceId: 'home'), isTrue);
    });

    test('three switches are independent; re-enabling keeps instance '
        'grants', () async {
      final manager = await _manager();
      manager.setAiInstance('source.smb', 'office', false);
      expect(manager.aiAllows('source.smb', instanceId: 'home'), isTrue);
      expect(manager.aiAllows('source.smb', instanceId: 'office'), isFalse);
      // AI off does not disable business use.
      manager.setAiAllowed('source.smb', false);
      expect(manager.pluginEnabled('source.smb'), isTrue);
      expect(PluginGate.ai('source.smb', instanceId: 'home'), isFalse);
      manager.setAiAllowed('source.smb', true);

      manager.setPluginEnabled('source.smb', false);
      expect(PluginGate.enabled('source.smb'), isFalse);
      expect(manager.aiAllows('source.smb', instanceId: 'home'), isFalse);
      manager.setPluginEnabled('source.smb', true);
      expect(manager.aiAllows('source.smb', instanceId: 'home'), isTrue);
      expect(manager.aiAllows('source.smb', instanceId: 'office'), isFalse);

      manager.setAiCapability('source.smb', 'search.media', false);
      expect(
        manager.aiAllows(
          'source.smb',
          instanceId: 'home',
          capability: 'search.media',
        ),
        isFalse,
      );
      expect(
        manager.aiAllows(
          'source.smb',
          instanceId: 'home',
          capability: 'source.browse',
        ),
        isTrue,
      );
    });

    test('a disabled dependency blocks dependants without enabling or '
        'disabling them', () async {
      final manager = PluginManager(
        catalog: _catalog(),
        store: MemoryPolicyStore(),
      );
      addTearDown(manager.dispose);
      await manager.refresh();
      // No media service in this build → FFmpeg unsupported → ASR blocked.
      expect(manager.pluginEnabled('media.ffmpeg'), isFalse);
      expect(manager.pluginEnabled('asr.whisper'), isFalse);
      expect(manager.snapshot('media.ffmpeg')!.platformSupported, isFalse);
      expect(manager.policy.pluginEnabled('asr.whisper'), isTrue);
      expect(manager.decide('media_probe'), ToolDecision.capabilityUnavailable);
      // Task query/cancel channel stays; host tools are never gated.
      expect(manager.decide('subtitle_task_get'), ToolDecision.allowed);
      expect(manager.decide('library_query'), ToolDecision.allowed);
      // Unknown ids never activate.
      expect(manager.pluginEnabled('source.unknown'), isFalse);
    });

    test('disabling a plugin with active playback reports impact and '
        'drains', () async {
      final sources = FakeSources()..playing = 1;
      final manager = await _manager(sources: sources);
      final impact = manager.impact('source.smb');
      expect(impact.playing, 1);
      expect(impact.instances, ['家里 NAS']);
      manager.setPluginEnabled('source.smb', false);
      await manager.refresh();
      expect(
        manager.snapshot('source.smb')!.state,
        PluginRuntimeState.draining,
      );
    });

    test('writing files is opt-in even for instances the AI already '
        'uses', () async {
      final manager = await _manager();
      bool write() => manager.aiAllows(
        'source.smb',
        instanceId: 'home',
        capability: 'source.write',
      );
      expect(manager.aiAllows('source.smb', instanceId: 'home'), isTrue);
      expect(write(), isFalse);
      manager.setAiCapability('source.smb', 'source.write', true);
      expect(write(), isTrue);
      manager.setAiCapability('source.smb', 'source.write', false);
      expect(write(), isFalse);
    });

    test('stale writes conflict instead of overwriting', () async {
      final store = MemoryPolicyStore();
      final manager = await _manager(store: store);
      store.value = store.value!.copyWith(revision: store.value!.revision + 1);
      expect(
        () => manager.setAiAllowed('source.smb', false),
        throwsA(isA<PluginException>()),
      );
    });
  });

  group('AI tools', () {
    tearDown(() => PluginGate.current = null);

    test('gateway rejects a tool whose policy changed after listing', () async {
      final manager = await _manager();
      final registry = ToolRegistry()..policy = manager;
      var runs = 0;
      registry.register(
        RegisteredTool('torrent_search', 'search', const {}, (_) async {
          runs++;
          return {};
        }),
      );
      // No torrent search service in this build → not offered.
      expect(registry.available, isEmpty);
      final result = await ToolGateway(registry).invoke(
        turn: 't',
        call: _call('torrent_search'),
        allowed: {'torrent_search'},
        active: () => true,
        confirm: (_, _) async => true,
      );
      expect(result.status, 'failed');
      expect(result.error, 'capabilityUnavailable');
      expect(runs, 0);
    });

    test(
      'a confirmation is voided when the policy changes meanwhile',
      () async {
        final manager = await _manager();
        final registry = ToolRegistry()..policy = manager;
        var runs = 0;
        registry.register(
          RegisteredTool(
            'write_thing',
            'write',
            const {},
            (_) async {
              runs++;
              return {};
            },
            readOnly: false,
            confirmation: true,
          ),
        );
        final result = await ToolGateway(registry).invoke(
          turn: 't',
          call: _call('write_thing'),
          allowed: {'write_thing'},
          active: () => true,
          confirm: (_, _) async {
            manager.setAiInstance('source.smb', 'office', false);
            return true;
          },
        );
        expect(result.error, 'policyChanged');
        expect(runs, 0);
      },
    );

    test('media tools only expose and route to AI-granted instances', () async {
      final manager = await _manager();
      manager.setAiInstance('source.smb', 'office', false);
      final library = LibraryService(sqlite3.openInMemory());
      addTearDown(library.close);
      final tools = MediaTools(
        library: library,
        sources: manager.sources!,
        context: () => {},
      );
      tools.registry.policy = manager;
      PluginTools(registry: tools.registry, plugins: manager);
      final gateway = ToolGateway(tools.registry);
      Future<ToolResult> call(String name, Map<String, dynamic> args) =>
          gateway.invoke(
            turn: 't',
            call: _call(name, args),
            allowed: tools.registry.available.map((t) => t.name).toSet(),
            active: () => true,
            confirm: (_, _) async => true,
          );

      final list = await call('source_list', {});
      expect((list.data['sources'] as List).map((s) => s['source_id']), [
        'home',
      ]);
      // Traditional pages still browse the instance; the AI cannot.
      expect(
        (await manager.sources!.browse(
          'office',
          const BrowseRequest(),
        )).entries,
        isNotEmpty,
      );
      final denied = await call('source_browse', {'source_id': 'office'});
      expect(denied.error, 'unavailable');
      final allowed = await call('source_browse', {'source_id': 'home'});
      expect(allowed.status, 'success');

      final status = await call('plugin_status', {});
      final text = jsonEncode(status.data);
      // Hidden instances, addresses and accounts are never disclosed.
      expect(text, isNot(contains('办公室')));
      expect(text, isNot(contains('nas.home')));
      expect(text, contains('设置 → 插件管理'));
    });
  });

  test('policy document round-trips', () {
    final policy = const PluginPolicy()
        .withPluginEnabled('source.smb', false)
        .withAi(
          'source.smb',
          const PluginAiPolicy(
            allowed: true,
            instances: {'home'},
            deniedCapabilities: {'search.media'},
          ),
        );
    final back = PluginPolicy.fromJson(
      jsonDecode(jsonEncode(policy.toJson())) as Map<String, dynamic>,
      3,
    );
    expect(back.pluginEnabled('source.smb'), isFalse);
    expect(back.aiFor('source.smb').instances, {'home'});
    expect(back.aiFor('source.smb').deniedCapabilities, {'search.media'});
    expect(back.revision, 3);
  });
}
