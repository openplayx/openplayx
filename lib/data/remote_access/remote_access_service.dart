import 'dart:async';

import 'package:sqlite3/sqlite3.dart';

import '../configuration/configuration_database.dart';
import '../sources/source_config.dart';
import 'remote_config.dart';
import 'remote_transport.dart';

/// The App's network layer, in sing-box / frp terms: one Relay entry point
/// (a sing-box [outbound] without `uuid`, plus the App user's [credential]
/// `{"uuid": ...}`) and the frpc [proxies] Home registered there.
/// Sources only name a proxy; see [SourceRemote].
class RemoteNetwork {
  const RemoteNetwork({
    this.outbound,
    this.credential,
    this.proxies = const [],
    this.probeTimeoutMs = 2000,
    this.stabilitySeconds = 30,
    this.reconnectAttempts = 2,
    this.reconnectDelayMs = 1000,
    this.allowCellular = true,
  });
  static const schemaVersion = 3;

  final Map<String, dynamic>? outbound;
  final Map<String, dynamic>? credential;
  final List<RemoteProxy> proxies;
  final int probeTimeoutMs,
      stabilitySeconds,
      reconnectAttempts,
      reconnectDelayMs;
  final bool allowCellular;

  bool get configured => outbound != null && credential != null;

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
    if (credential != null) 'credential': credential,
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
      'credential',
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
      credential: j['credential'] == null
          ? null
          : Map<String, dynamic>.from(j['credential'] as Map),
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
    if ((outbound == null) != (credential == null)) {
      throw const FormatException('outbound 与凭据必须同时存在。');
    }
    if (outbound != null) {
      if (outbound!.containsKey('uuid')) {
        throw const FormatException('UUID 只能保存在 credential 中。');
      }
      RemotePairing.validateOutbound({
        ...outbound!,
        'uuid': '11111111-1111-4111-8111-111111111111',
      });
      if (credential!['uuid'] is! String) {
        throw const FormatException('远程凭据无效。');
      }
    }
    if (proxies.map((p) => p.name).toSet().length != proxies.length ||
        proxies.any(
          (p) =>
              p.name.trim().isEmpty || p.remotePort < 1 || p.remotePort > 65535,
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
    credential: credential,
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
      credential: credential!,
      outbound: outbound!,
      mode: remote.mode,
      localAddress: remote.localAddress,
      localTlsSha256: remote.localTlsSha256,
    );
  }
}

/// Owns the App-wide network layer, stored as the `remote_access / network`
/// settings document in configuration.sqlite3 (the credential itself is in
/// its `secrets` table). Changes take effect when saved; there is no
/// separate apply step.
class RemoteAccessService {
  RemoteAccessService(this.db) {
    ConfigurationDatabase.initialize(db);
  }

  /// A throwaway configuration (tests, and managers without one).
  RemoteAccessService.memory() : this(sqlite3.openInMemory());

  final Database db;
  RemoteNetwork network = const RemoteNetwork();
  bool _loaded = false;

  static const _namespace = 'remote_access';
  static const _key = 'network';

  static Future<RemoteAccessService> locate() async =>
      RemoteAccessService(await ConfigurationDatabase.open());

  Future<void> load() async {
    if (_loaded) return;
    final value = ConfigurationDatabase.readSetting(db, _namespace, _key);
    if (value is Map) {
      try {
        network = RemoteNetwork.fromJson(Map<String, dynamic>.from(value));
      } catch (_) {
        // Unreadable or incompatible settings are dropped: remote access
        // starts unconfigured.
        network = const RemoteNetwork();
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
    ConfigurationDatabase.writeSetting(db, _namespace, _key, next.toJson());
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
    await _write(
      RemoteNetwork(
        outbound: {...pair.outbound}..remove('uuid'),
        credential: {'uuid': pair.outbound['uuid']},
        proxies: pair.proxies,
      ),
    );
    return network;
  }

  /// Removes the Relay connection and its credential, resetting local defaults.
  Future<RemoteNetwork> clear() async {
    await load();
    await _write(network.cleared());
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
