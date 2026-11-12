import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../sources/source_config.dart';
import 'remote_config.dart';
import 'remote_transport.dart';

/// The App's network layer, in sing-box / frp terms: one Relay entry point
/// (a sing-box [outbound] without `uuid`; the credential is in secure storage
/// under [credentialRef]) and the frpc [proxies] Home registered there.
/// Sources only name a proxy; see [SourceRemote].
class RemoteNetwork {
  const RemoteNetwork({
    this.outbound,
    this.credentialRef,
    this.proxies = const [],
    this.probeTimeoutMs = 2000,
    this.stabilitySeconds = 30,
    this.reconnectAttempts = 2,
    this.reconnectDelayMs = 1000,
    this.allowCellular = true,
  });
  static const schemaVersion = 3;

  final Map<String, dynamic>? outbound;
  final String? credentialRef;
  final List<RemoteProxy> proxies;
  final int probeTimeoutMs, stabilitySeconds, reconnectAttempts, reconnectDelayMs;
  final bool allowCellular;

  bool get configured => outbound != null && credentialRef != null;

  RemoteRuntimePolicy get runtimePolicy => RemoteRuntimePolicy(
    probeTimeoutMs: probeTimeoutMs,
    stabilitySeconds: stabilitySeconds,
    reconnectAttempts: reconnectAttempts,
    reconnectDelayMs: reconnectDelayMs,
    allowCellular: allowCellular,
  );

  RemoteProxy? proxy(String name) =>
      proxies.where((p) => p.name == name).firstOrNull;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    if (outbound != null) 'outbound': outbound,
    if (credentialRef != null) 'credentialRef': credentialRef,
    'proxies': proxies.map((p) => p.toJson()).toList(),
    'policy': {
      'probeTimeoutMs': probeTimeoutMs,
      'stabilitySeconds': stabilitySeconds,
      'reconnectAttempts': reconnectAttempts,
      'reconnectDelayMs': reconnectDelayMs,
      'allowCellular': allowCellular,
    },
  };

  factory RemoteNetwork.fromJson(Map<String, dynamic> j) {
    const keys = {
      'schemaVersion',
      'outbound',
      'credentialRef',
      'proxies',
      'policy',
    };
    if (j['schemaVersion'] != schemaVersion ||
        j.keys.any((k) => !keys.contains(k))) {
      throw const FormatException('远程访问配置版本不兼容或包含未知字段。');
    }
    final p = j['policy'] as Map<String, dynamic>;
    final network = RemoteNetwork(
      outbound: j['outbound'] as Map<String, dynamic>?,
      credentialRef: j['credentialRef'] as String?,
      proxies: [
        for (final item in j['proxies'] as List)
          RemoteProxy(
            (item as Map)['name'] as String,
            item['remotePort'] as int,
          ),
      ],
      probeTimeoutMs: p['probeTimeoutMs'] as int,
      stabilitySeconds: p['stabilitySeconds'] as int,
      reconnectAttempts: p['reconnectAttempts'] as int,
      reconnectDelayMs: p['reconnectDelayMs'] as int,
      // Cellular access is always enabled, including for older saved settings.
      allowCellular: true,
    );
    network.validate();
    return network;
  }

  void validate() {
    if ((outbound == null) != (credentialRef == null)) {
      throw const FormatException('outbound 与凭据必须同时存在。');
    }
    if (outbound != null) {
      if (outbound!.containsKey('uuid')) {
        throw const FormatException('实际 UUID 只能保存在安全存储。');
      }
      RemotePairing.validateOutbound({
        ...outbound!,
        'uuid': '11111111-1111-4111-8111-111111111111',
      });
      if (!RemoteCredentialStore.owns(credentialRef!)) {
        throw const FormatException('远程凭据引用无效。');
      }
    }
    if (proxies.map((p) => p.name).toSet().length != proxies.length ||
        proxies.any(
          (p) => p.name.trim().isEmpty || p.remotePort < 1 || p.remotePort > 65535,
        )) {
      throw const FormatException('proxies 的 name 不能为空或重复，remotePort 须为有效端口。');
    }
    if (probeTimeoutMs < 200 ||
        probeTimeoutMs > 10000 ||
        stabilitySeconds < 5 ||
        stabilitySeconds > 300 ||
        reconnectAttempts < 0 ||
        reconnectAttempts > 5 ||
        reconnectDelayMs < 100 ||
        reconnectDelayMs > 10000) {
      throw const FormatException('远程连接策略超出支持范围。');
    }
  }

  RemoteNetwork copyWith({
    int? probeTimeoutMs,
    int? stabilitySeconds,
    int? reconnectAttempts,
    int? reconnectDelayMs,
    bool? allowCellular,
  }) => RemoteNetwork(
    outbound: outbound,
    credentialRef: credentialRef,
    proxies: proxies,
    probeTimeoutMs: probeTimeoutMs ?? this.probeTimeoutMs,
    stabilitySeconds: stabilitySeconds ?? this.stabilitySeconds,
    reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
    reconnectDelayMs: reconnectDelayMs ?? this.reconnectDelayMs,
    allowCellular: allowCellular ?? this.allowCellular,
  );

  /// Resets the local remote configuration, including connection defaults.
  RemoteNetwork cleared() => const RemoteNetwork();

  /// The route a source uses, or null when it has no remote access or its
  /// proxy is not (or no longer) available.
  RemoteAccessConfig? routeFor(SourceRemote? remote) {
    if (remote == null || !configured) return null;
    final match = proxy(remote.proxy);
    if (match == null) return null;
    return RemoteAccessConfig(
      proxy: match.name,
      remotePort: match.remotePort,
      credentialRef: credentialRef!,
      outbound: outbound!,
      mode: remote.mode,
      localAddress: remote.localAddress,
      localTlsSha256: remote.localTlsSha256,
    );
  }
}

/// Owns remote_access.json, the App-wide network layer. Changes take effect
/// when saved; there is no separate apply step.
class RemoteAccessService {
  RemoteAccessService(Directory directory) : _directory = directory;
  RemoteAccessService.memory() : _directory = null;
  final Directory? _directory;
  RemoteNetwork network = const RemoteNetwork();
  bool _loaded = false;

  static Future<RemoteAccessService> locate() async =>
      RemoteAccessService(await getApplicationSupportDirectory());

  File _file(String name) =>
      File('${_directory!.path}${Platform.pathSeparator}$name');

  static const _obsolete = [
    'remote_access.state.json',
    'remote_access.backup.json',
    'remote_access.revision.json',
    'remote_access.lock',
  ];

  Future<void> load() async {
    if (_loaded) return;
    final directory = _directory;
    if (directory != null) {
      final file = _file('remote_access.json');
      if (await file.exists()) {
        try {
          network = RemoteNetwork.fromJson(
            jsonDecode(await file.readAsString()) as Map<String, dynamic>,
          );
        } catch (_) {
          // Earlier schemas and unreadable files are not converted: they are
          // kept aside and remote access starts unconfigured.
          await file.rename(
            _file(
              'remote_access.discarded.${DateTime.now().microsecondsSinceEpoch}.json',
            ).path,
          );
          network = const RemoteNetwork();
        }
      }
      for (final name in _obsolete) {
        final old = _file(name);
        if (await old.exists()) await old.delete();
      }
    }
    _configureTransport();
    _loaded = true;
  }

  void _configureTransport() => RemoteTransport.configurePolicy(
    probeTimeoutMs: network.probeTimeoutMs,
    stabilitySeconds: network.stabilitySeconds,
    allowCellular: network.allowCellular,
    reconnectAttempts: network.reconnectAttempts,
    reconnectDelayMs: network.reconnectDelayMs,
  );

  Future<void> _write(RemoteNetwork next) async {
    next.validate();
    final directory = _directory;
    if (directory != null) {
      await directory.create(recursive: true);
      final destination = _file('remote_access.json');
      final temporary = File(
        '${destination.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      try {
        await temporary.writeAsString(
          '${jsonEncode(next.toJson())}\n',
          flush: true,
        );
        await temporary.rename(destination.path);
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    }
    network = next;
    _configureTransport();
  }

  /// Replaces the Relay connection with the App file exported by Relay
  /// (`{"outbound", "proxies"}`). [check] may verify the outbound (with
  /// `uuid`) before anything is saved.
  Future<RemoteNetwork> importPairing(
    String text, {
    Future<void> Function(Map<String, dynamic> outbound, int port)? check,
  }) async {
    await load();
    final pair = RemotePairing.parse(text.trim());
    await check?.call(pair.outbound, pair.proxies.first.remotePort);
    final ref = await RemoteCredentialStore.stage({
      'uuid': pair.outbound['uuid'],
    });
    final previous = network.credentialRef;
    try {
      await _write(
        RemoteNetwork(
          outbound: {...pair.outbound}..remove('uuid'),
          credentialRef: ref,
          proxies: pair.proxies,
        ),
      );
    } catch (_) {
      await RemoteCredentialStore.delete(ref);
      rethrow;
    }
    if (previous != null && previous != ref) {
      try {
        await RemoteCredentialStore.delete(previous);
      } catch (_) {}
    }
    return network;
  }

  /// Removes the Relay connection and its credential, resetting local defaults.
  Future<RemoteNetwork> clear() async {
    await load();
    final previous = network.credentialRef;
    await _write(network.cleared());
    if (previous != null) {
      try {
        await RemoteCredentialStore.delete(previous);
      } catch (_) {}
    }
    return network;
  }

  Future<RemoteNetwork> savePolicy(RemoteNetwork next) async {
    await load();
    await _write(
      network.copyWith(
        probeTimeoutMs: next.probeTimeoutMs,
        stabilitySeconds: next.stabilitySeconds,
        reconnectAttempts: next.reconnectAttempts,
        reconnectDelayMs: next.reconnectDelayMs,
        allowCellular: next.allowCellular,
      ),
    );
    return network;
  }

  /// Joins a source with the network layer for its runtime.
  SourceConfig attach(SourceConfig source) {
    final route = network.routeFor(source.remote);
    return source.copyWith(
      remoteAccess: route,
      clearRemoteAccess: route == null,
      remoteRuntimePolicy: network.runtimePolicy,
    );
  }
}
