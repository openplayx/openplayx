import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/plugins/source_capability.dart';
import '../sources/source_config.dart';
import 'remote_config.dart';
import 'remote_transport.dart';

class RemoteAccessBinding {
  const RemoteAccessBinding(this.primary, {this.backups = const []});
  final RemoteAccessConfig primary;
  final List<RemoteAccessConfig> backups;
  Map<String, dynamic> toJson() => {
    'primary': primary.toJson(),
    'backups': backups.map((b) => b.toJson()).toList(),
  };
  factory RemoteAccessBinding.fromJson(Map<String, dynamic> j) {
    if (j.keys.any((k) => !['primary', 'backups'].contains(k))) {
      throw const FormatException('未知绑定字段。');
    }
    final value = RemoteAccessBinding(
      RemoteAccessConfig.fromJson(j['primary'] as Map<String, dynamic>),
      backups: (j['backups'] as List? ?? [])
          .map((v) => RemoteAccessConfig.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
    final routes = [value.primary, ...value.backups];
    if (routes.length > 5 ||
        routes.map((r) => r.lineId).toSet().length != routes.length ||
        routes.any(
          (r) =>
              r.homeId != value.primary.homeId ||
              r.serviceId != value.primary.serviceId,
        )) {
      throw const FormatException('备用线路必须对应同一家庭与服务，线路 ID 不重复，最多四条。');
    }
    return value;
  }
}

class RemoteAccessDocument {
  const RemoteAccessDocument({
    this.revision = 0,
    this.bindings = const {},
    this.probeTimeoutMs = 2000,
    this.stabilitySeconds = 30,
    this.reconnectAttempts = 2,
    this.reconnectDelayMs = 1000,
    this.allowCellular = true,
  });
  final int revision,
      probeTimeoutMs,
      stabilitySeconds,
      reconnectAttempts,
      reconnectDelayMs;
  final bool allowCellular;
  RemoteRuntimePolicy get runtimePolicy => RemoteRuntimePolicy(
    probeTimeoutMs: probeTimeoutMs,
    stabilitySeconds: stabilitySeconds,
    reconnectAttempts: reconnectAttempts,
    reconnectDelayMs: reconnectDelayMs,
    allowCellular: allowCellular,
  );
  final Map<String, RemoteAccessBinding> bindings;
  static Object? _sorted(Object? value) {
    if (value is Map<String, dynamic>) {
      final keys = value.keys.toList()..sort();
      return {for (final k in keys) k: _sorted(value[k])};
    }
    if (value is List) return value.map(_sorted).toList();
    return value;
  }

  Map<String, dynamic> get lines {
    final result = <String, dynamic>{};
    for (final binding in bindings.values) {
      for (final route in [binding.primary, ...binding.backups]) {
        if (route.outboundOptions == null) {
          throw const FormatException('线路缺少公开的代理配置。');
        }
        final existing = result[route.lineId];
        if (existing != null &&
            jsonEncode(_sorted(existing)) !=
                jsonEncode(_sorted(route.outboundOptions))) {
          throw const FormatException('同一线路 ID 的代理参数不一致，请在设置中统一编辑。');
        }
        result[route.lineId] = route.outboundOptions;
      }
    }
    return result;
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> reference(RemoteAccessConfig c) =>
        Map.of(c.toJson())..remove('outboundOptions');
    return {
      'schemaVersion': 1,
      'revision': revision,
      'lines': lines,
      'bindings': {
        for (final e in bindings.entries)
          e.key: {
            'primary': reference(e.value.primary),
            'backups': e.value.backups.map(reference).toList(),
          },
      },
      'policy': {
        'probeTimeoutMs': probeTimeoutMs,
        'stabilitySeconds': stabilitySeconds,
        'reconnectAttempts': reconnectAttempts,
        'reconnectDelayMs': reconnectDelayMs,
        'allowCellular': allowCellular,
      },
    };
  }

  factory RemoteAccessDocument.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 1 ||
        j.keys.any(
          (k) => ![
            'schemaVersion',
            'revision',
            'lines',
            'bindings',
            'policy',
          ].contains(k),
        )) {
      throw const FormatException('远程配置版本不兼容或包含未知字段，原文件已保留。');
    }
    final profiles = j['lines'] as Map<String, dynamic>? ?? {};
    Map<String, dynamic> route(Object? value) {
      final r = Map<String, dynamic>.from(value as Map);
      if (profiles.containsKey(r['lineId'])) {
        r['outboundOptions'] = profiles[r['lineId']];
      }
      return r;
    }

    final decoded = (j['bindings'] as Map<String, dynamic>).map((id, value) {
      final b = value as Map<String, dynamic>;
      return MapEntry(
        id,
        RemoteAccessBinding.fromJson({
          ...b,
          'primary': route(b['primary']),
          'backups': (b['backups'] as List? ?? []).map(route).toList(),
        }),
      );
    });
    final referenced = {
      for (final b in decoded.values)
        for (final r in [b.primary, ...b.backups]) r.lineId,
    };
    if (profiles.keys.any((id) => !referenced.contains(id))) {
      throw const FormatException('包含未绑定的线路；原配置已保留。');
    }
    final p = j['policy'] as Map<String, dynamic>;
    if (p.keys.any(
      (k) => ![
        'probeTimeoutMs',
        'stabilitySeconds',
        'reconnectAttempts',
        'reconnectDelayMs',
        'allowCellular',
      ].contains(k),
    )) {
      throw const FormatException('未知远程策略字段。');
    }
    final d = RemoteAccessDocument(
      revision: j['revision'] as int,
      bindings: decoded,
      probeTimeoutMs: p['probeTimeoutMs'] as int,
      stabilitySeconds: p['stabilitySeconds'] as int,
      reconnectAttempts: p['reconnectAttempts'] as int,
      reconnectDelayMs: p['reconnectDelayMs'] as int,
      allowCellular: p['allowCellular'] as bool,
    );
    d.validate();
    return d;
  }
  void validate() {
    lines; // Validate shared profile consistency before saving.
    if (revision < 0 ||
        probeTimeoutMs < 200 ||
        probeTimeoutMs > 10000 ||
        stabilitySeconds < 5 ||
        stabilitySeconds > 300 ||
        reconnectAttempts < 0 ||
        reconnectAttempts > 5 ||
        reconnectDelayMs < 100 ||
        reconnectDelayMs > 10000 ||
        bindings.length > 100) {
      throw const FormatException('远程配置策略超出支持范围。');
    }
    for (final entry in bindings.entries) {
      if (entry.key.isEmpty) throw const FormatException('来源引用不能为空。');
      RemoteAccessBinding.fromJson(entry.value.toJson());
      for (final route in [entry.value.primary, ...entry.value.backups]) {
        if (!route.credentialRef.startsWith('remote.${entry.key}.')) {
          throw const FormatException('远程凭据不属于此来源。');
        }
      }
    }
  }

  RemoteAccessDocument copyWith({
    int? revision,
    Map<String, RemoteAccessBinding>? bindings,
    int? probeTimeoutMs,
    int? stabilitySeconds,
    int? reconnectAttempts,
    int? reconnectDelayMs,
    bool? allowCellular,
  }) => RemoteAccessDocument(
    revision: revision ?? this.revision,
    bindings: bindings ?? this.bindings,
    probeTimeoutMs: probeTimeoutMs ?? this.probeTimeoutMs,
    stabilitySeconds: stabilitySeconds ?? this.stabilitySeconds,
    reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
    reconnectDelayMs: reconnectDelayMs ?? this.reconnectDelayMs,
    allowCellular: allowCellular ?? this.allowCellular,
  );
}

/// Owns remote_access.json. Source SQLite stores no editable remote settings.
/// The state file is a derived last-applied snapshot, never a second edit API.
class RemoteAccessService {
  RemoteAccessService(Directory directory) : _directory = directory;
  RemoteAccessService.memory() : _directory = null;
  final Directory? _directory;
  static final _queues = <String, Future<void>>{};
  RemoteAccessDocument desired = const RemoteAccessDocument();
  RemoteAccessDocument active = const RemoteAccessDocument();
  String? error;
  bool _loaded = false;
  static Future<RemoteAccessService> locate() async =>
      RemoteAccessService(await getApplicationSupportDirectory());
  static Future<RemoteAccessService> open() async {
    final directory = await getApplicationSupportDirectory();
    final service = RemoteAccessService(directory);
    await service.load();
    return service;
  }

  File _file(String name) =>
      File('${_directory!.path}${Platform.pathSeparator}$name');
  Future<T> _locked<T>(Future<T> Function() action) async {
    if (_directory == null) return action();
    final key = _directory.absolute.path;
    final previous = _queues[key] ?? Future.value();
    final done = Completer<void>();
    _queues[key] = done.future;
    await previous;
    RandomAccessFile? lock;
    try {
      await _directory.create(recursive: true);
      lock = await _file('remote_access.lock').open(mode: FileMode.append);
      await lock.lock(FileLock.exclusive);
      return await action();
    } finally {
      if (lock != null) {
        await lock.unlock();
        await lock.close();
      }
      done.complete();
      if (identical(_queues[key], done.future)) _queues.remove(key);
    }
  }

  Future<void> _atomic(File destination, Map<String, dynamic> value) async {
    final temporary = File(
      '${destination.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsString('${jsonEncode(value)}\n', flush: true);
      await temporary.rename(destination.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<RemoteAccessDocument> _read(File file) async {
    try {
      return RemoteAccessDocument.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const FormatException('远程访问配置损坏或版本较新，已保留原文件，请恢复备份或升级。');
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    await _locked(() async {
      if (_directory != null) {
        if (await _file('remote_access.json').exists()) {
          desired = await _read(_file('remote_access.json'));
        }
        if (await _file('remote_access.state.json').exists()) {
          final j = jsonDecode(
            await _file('remote_access.state.json').readAsString(),
          ) as Map<String, dynamic>;
          active = RemoteAccessDocument.fromJson(
            j['applied'] as Map<String, dynamic>,
          );
          error = j['error'] as String?;
        }
      }
      if (_directory != null &&
          await _file('remote_access.state.json').exists() &&
          !await _file('remote_access.json').exists()) {
        throw const FormatException('权威远程配置丢失，已阻止使用旧运行快照。');
      }
      RemoteTransport.configurePolicy(
        probeTimeoutMs: active.probeTimeoutMs,
        stabilitySeconds: active.stabilitySeconds,
        allowCellular: active.allowCellular,
        reconnectAttempts: active.reconnectAttempts,
        reconnectDelayMs: active.reconnectDelayMs,
      );
      _loaded = true;
    });
  }

  Future<RemoteAccessDocument> refresh() async {
    await load();
    return _locked(() async {
      if (_directory != null) {
        if (await _file('remote_access.json').exists()) {
          desired = await _read(_file('remote_access.json'));
        }
        if (await _file('remote_access.state.json').exists()) {
          final j = jsonDecode(
            await _file('remote_access.state.json').readAsString(),
          ) as Map<String, dynamic>;
          active = RemoteAccessDocument.fromJson(
            j['applied'] as Map<String, dynamic>,
          );
          error = j['error'] as String?;
        }
      }
      RemoteTransport.configurePolicy(
        probeTimeoutMs: active.probeTimeoutMs,
        stabilitySeconds: active.stabilitySeconds,
        allowCellular: active.allowCellular,
        reconnectAttempts: active.reconnectAttempts,
        reconnectDelayMs: active.reconnectDelayMs,
      );
      return desired;
    });
  }

  Future<RemoteAccessDocument> save(
    RemoteAccessDocument draft, {
    required int expectedRevision,
  }) async {
    await load();
    draft.validate();
    return _locked(() async {
      final current =
          _directory != null && await _file('remote_access.json').exists()
          ? await _read(_file('remote_access.json'))
          : desired;
      if (current.revision != expectedRevision ||
          draft.revision != expectedRevision) {
        throw const PluginException('conflict', '远程配置已被其他窗口修改，请重新加载。');
      }
      var clock = current.revision;
      if (_directory != null &&
          await _file('remote_access.revision.json').exists()) {
        final j = jsonDecode(
          await _file('remote_access.revision.json').readAsString(),
        ) as Map<String, dynamic>;
        final number = j['lastIssuedRevision'];
        if (number is! int || number < 0) {
          throw const FormatException('修订元数据损坏，原文件已保留。');
        }
        if (number > clock) clock = number;
      }
      final next = draft.copyWith(revision: clock + 1);
      if (_directory != null) {
        await _atomic(_file('remote_access.revision.json'), {
          'lastIssuedRevision': next.revision,
        });
        if (await _file('remote_access.json').exists()) {
          await _atomic(_file('remote_access.backup.json'), current.toJson());
        }
        await _atomic(_file('remote_access.json'), next.toJson());
      }
      desired = next;
      return next;
    });
  }

  Future<void> apply({
    required int expectedRevision,
    required Iterable<SourceConfig> sources,
    Future<void> Function(RemoteAccessDocument)? check,
  }) async {
    await load();
    await _locked(() async {
      final current =
          _directory != null && await _file('remote_access.json').exists()
          ? await _read(_file('remote_access.json'))
          : desired;
      if (current.revision != expectedRevision) {
        throw const PluginException('conflict', '远程配置已变化，未应用其他修订。');
      }
      try {
        current.validate();
        final known = {for (final source in sources) source.id: source};
        for (final entry in current.bindings.entries) {
          final source = known[entry.key];
          if (source == null) throw const FormatException('绑定的媒体来源不存在。');
          source.copyWith(remoteAccess: entry.value.primary).validate();
          for (final route in [entry.value.primary, ...entry.value.backups]) {
            source.copyWith(remoteAccess: route).validate();
            final out = await RemoteCredentialStore.read(
              source.id,
              route.credentialRef,
            );
            RemotePairing.validateOutbound({...out, ...?route.outboundOptions});
          }
        }
        await check?.call(current);
        if (_directory != null) {
          await _atomic(_file('remote_access.state.json'), {
            'applied': current.toJson(),
            'error': null,
          });
        }
        desired = current;
        active = current;
        error = null;
        RemoteTransport.configurePolicy(
          probeTimeoutMs: active.probeTimeoutMs,
          stabilitySeconds: active.stabilitySeconds,
          allowCellular: active.allowCellular,
          reconnectAttempts: active.reconnectAttempts,
          reconnectDelayMs: active.reconnectDelayMs,
        );
      } catch (_) {
        error = 'applyFailed';
        if (_directory != null) {
          await _atomic(_file('remote_access.state.json'), {
            'applied': active.toJson(),
            'error': error,
          });
        }
        rethrow;
      }
    });
  }

  Future<RemoteAccessDocument> restore({required int expectedRevision}) async {
    if (_directory == null ||
        !await _file('remote_access.backup.json').exists()) {
      throw const FormatException('没有可恢复的远程配置备份。');
    }
    final backup = await _read(_file('remote_access.backup.json'));
    return save(
      backup.copyWith(revision: expectedRevision),
      expectedRevision: expectedRevision,
    );
  }

  Future<void> recoverFromBackup() async {
    if (_directory == null) throw const FormatException('没有磁盘备份。');
    await _locked(() async {
      final backup = await _read(_file('remote_access.backup.json'));
      var revision = backup.revision > active.revision
          ? backup.revision
          : active.revision;
      if (await _file('remote_access.json').exists()) {
        final raw = await _file('remote_access.json').readAsString();
        try {
          final value = jsonDecode(raw);
          if (value is Map &&
              value['revision'] is int &&
              value['revision'] > revision) {
            revision = value['revision'] as int;
          }
        } catch (_) {}
        await _file('remote_access.json').copy(
          _file(
            'remote_access.damaged.${DateTime.now().microsecondsSinceEpoch}.json',
          ).path,
        );
      }
      if (await _file('remote_access.revision.json').exists()) {
        final j = jsonDecode(
          await _file('remote_access.revision.json').readAsString(),
        ) as Map<String, dynamic>;
        final clock = j['lastIssuedRevision'];
        if (clock is! int || clock < 0) {
          throw const FormatException('修订元数据损坏，原文件已保留。');
        }
        if (clock > revision) revision = clock;
      }
      final restored = backup.copyWith(revision: revision + 1);
      await _atomic(_file('remote_access.revision.json'), {
        'lastIssuedRevision': restored.revision,
      });
      await _atomic(_file('remote_access.json'), restored.toJson());
      await _atomic(_file('remote_access.state.json'), {
        'applied': active.toJson(),
        'error': null,
      });
      desired = restored;
      error = null;
      _loaded = true;
    });
  }

  Future<void> migrate(Map<String, RemoteAccessConfig> legacy) async {
    await load();
    final missing = legacy.entries.where(
      (e) => !desired.bindings.containsKey(e.key),
    );
    if (missing.isEmpty) return;
    final wasApplied = desired.revision == active.revision;
    final bindings = Map<String, RemoteAccessBinding>.of(desired.bindings);
    final migrated = Map<String, RemoteAccessBinding>.of(active.bindings);
    for (final entry in missing) {
      final old = entry.value;
      final outbound =
          old.outboundOptions ??
          ({...await RemoteCredentialStore.read(entry.key, old.credentialRef)}
            ..remove('uuid'));
      bindings[entry.key] = RemoteAccessBinding(
        RemoteAccessConfig.fromJson({
          ...old.toJson(),
          'outboundOptions': outbound,
        }),
      );
    }
    for (final entry in missing) {
      migrated[entry.key] = bindings[entry.key]!;
    }
    await save(
      desired.copyWith(bindings: bindings),
      expectedRevision: desired.revision,
    );
    // Preserve an already-running legacy setup as applied; migration does not
    // test a new network or change service identities.
    active = wasApplied ? desired : active.copyWith(bindings: migrated);
    if (_directory != null) {
      await _atomic(_file('remote_access.state.json'), {
        'applied': active.toJson(),
        'error': null,
      });
    }
  }

  SourceConfig attach(SourceConfig source) => source.copyWith(
    remoteAccess: active.revision >= source.remoteRequiredRevision
        ? active.bindings[source.id]?.primary
        : null,
    remoteRuntimePolicy: active.runtimePolicy,
    clearRemoteAccess:
        active.revision < source.remoteRequiredRevision ||
        !active.bindings.containsKey(source.id),
  );
  Future<void> cleanupStaged(Iterable<(String, String)> staged) async {
    final retained = <String>{};
    void collect(RemoteAccessDocument doc) {
      for (final binding in doc.bindings.values) {
        for (final route in [binding.primary, ...binding.backups]) {
          retained.add(route.credentialRef);
        }
      }
    }

    collect(desired);
    collect(active);
    if (_directory != null) {
      try {
        if (await _file('remote_access.backup.json').exists()) {
          collect(await _read(_file('remote_access.backup.json')));
        }
      } catch (_) {
        return;
      }
    }
    for (final (source, ref) in staged) {
      if (!retained.contains(ref)) {
        try {
          await RemoteCredentialStore.delete(source, ref);
        } catch (_) {}
      }
    }
  }

  String exportRedacted() =>
      const JsonEncoder.withIndent('  ').convert(desired.toJson());
}
