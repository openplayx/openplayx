import 'dart:async';

import 'package:sqlite3/sqlite3.dart';

import '../configuration/configuration_database.dart';
import '../sources/source_config.dart';
import 'remote_config.dart';
import 'remote_transport.dart';
import 'relay_subscription.dart';
import 'discovered_source.dart';
import 'relay_node_probe.dart';
import '../../l10n/l10n.dart';

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
      throw FormatException(appStrings.errRemoteConfigVersion);
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
            label: item['label'] as String?,
            kind: item['kind'] as String?,
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
      throw FormatException(appStrings.errRemoteOutboundCredential);
    }
    if (outbound != null) {
      if (outbound!.containsKey('uuid')) {
        throw FormatException(appStrings.errRemoteUuidPlacement);
      }
      RemotePairing.validateOutbound({
        ...outbound!,
        'uuid': '11111111-1111-4111-8111-111111111111',
      });
      if (credential!['uuid'] is! String) {
        throw FormatException(appStrings.errRemoteCredentialInvalid);
      }
    }
    if (proxies.map((p) => p.name).toSet().length != proxies.length ||
        proxies.any(
          (p) =>
              p.name.trim().isEmpty || p.remotePort < 1 || p.remotePort > 65535,
        )) {
      throw FormatException(appStrings.errRemoteProxiesInvalid);
    }
    if (probeTimeoutMs < 200 ||
        probeTimeoutMs > 10000 ||
        stabilitySeconds < 5 ||
        stabilitySeconds > 300 ||
        reconnectAttempts < 0 ||
        reconnectAttempts > 5 ||
        reconnectDelayMs < 100 ||
        reconnectDelayMs > 10000) {
      throw FormatException(appStrings.errRemotePolicyUnsupported);
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
  RemoteAccessService(this.db, {RelaySubscription? subscription}) {
    account = subscription ?? RelaySubscription(db);
    ConfigurationDatabase.initialize(db);
  }

  /// A throwaway configuration (tests, and managers without one).
  RemoteAccessService.memory() : this(sqlite3.openInMemory());

  final Database db;
  RemoteNetwork _custom = const RemoteNetwork();
  late final RelaySubscription account;
  bool usePlatform = true;
  RelayDeviceProfile? platformProfile;
  String? platformError;
  Future<void> Function()? onChanged;
  Timer? _refreshTimer;
  Future<void>? _syncing;
  bool _closed = false;

  RemoteNetwork get network => usePlatform ? platformNetwork : _custom;

  List<DiscoveredSource> get discoveredSources {
    if (!usePlatform || !account.signedIn) return const [];
    final profile = platformProfile;
    if (profile == null ||
        account.userId != null && account.userId != profile.userId) {
      return const [];
    }
    return profile.sources;
  }

  bool isSourceHidden(DiscoveredSource source) {
    final value = ConfigurationDatabase.readSetting(
      db,
      'source_discovery',
      'hidden:${source.accountId}',
    );
    return value is List && value.contains(source.identity);
  }

  Future<void> setSourceHidden(DiscoveredSource source, bool hidden) async {
    final key = 'hidden:${source.accountId}';
    final saved = ConfigurationDatabase.readSetting(
      db,
      'source_discovery',
      key,
    );
    final ids = saved is List ? saved.whereType<String>().toSet() : <String>{};
    hidden ? ids.add(source.identity) : ids.remove(source.identity);
    ConfigurationDatabase.writeSetting(
      db,
      'source_discovery',
      key,
      ids.toList(),
    );
    await onChanged?.call();
  }

  bool ownsSource(SourceRemote? source) =>
      source?.accountId == null ||
      usePlatform &&
          account.signedIn &&
          platformProfile?.userId == source!.accountId &&
          (account.userId == null || account.userId == source.accountId);

  bool sourceAuthorized(SourceRemote source) =>
      ownsSource(source) &&
      platformProfile?.valid == true &&
      discoveredSources.any(
        (s) =>
            s.serviceId == source.proxy &&
            s.connectorId == source.connectorId &&
            s.enabled,
      );

  RemoteAccessConfig? routeFor(SourceRemote? source) {
    if (source == null) return null;
    if (!usePlatform) {
      return source.accountId == null ? _custom.routeFor(source) : null;
    }
    final profile = platformProfile;
    if (!account.signedIn ||
        profile == null ||
        !profile.valid ||
        source.accountId != null && !sourceAuthorized(source)) {
      return null;
    }
    final proxy = profile.proxies
        .where((p) => p.name == source.proxy)
        .firstOrNull;
    if (proxy == null) return null;
    var mode = source.mode;
    var localAddress = source.localAddress;
    var localPin = source.localTlsSha256;
    if (source.managedLocal) {
      final entry = discoveredSources
          .where(
            (s) =>
                s.serviceId == source.proxy &&
                s.connectorId == source.connectorId,
          )
          .firstOrNull;
      if (entry?.supportsLocal != true) {
        if (mode == RemoteConnectionMode.localOnly) return null;
        mode = RemoteConnectionMode.remoteOnly;
        localAddress = null;
        localPin = null;
      } else {
        localAddress = entry!.localAccess!['endpoint'] as String;
        localPin = (entry.localAccess!['identity'] as Map)['value'] as String;
      }
    }
    final observations = profile.data['serviceStatus'];
    Map<String, dynamic>? node;
    if (observations is List) {
      final status = observations
          .whereType<Map<Object?, Object?>>()
          .where((s) => s['serviceId'] == source.proxy)
          .firstOrNull;
      final ids = status?['readyNodeIds'];
      if (ids is List) {
        node = profile.nodes
            .where((n) => ids.contains(n['nodeId']))
            .firstOrNull;
      }
    } else {
      // Older manually paired profiles did not report per-service nodes.
      node = activeNode;
    }
    if (node == null && mode == RemoteConnectionMode.remoteOnly) return null;
    return RemoteAccessConfig(
      proxy: proxy.name,
      remotePort: proxy.remotePort,
      credential: {'uuid': profile.uuid},
      remoteReady: node != null,
      outbound: node == null
          ? const {}
          : {
              'type': 'vless',
              'server': node['host'],
              'server_port': node['port'],
              'tls': {'enabled': true, 'server_name': node['tlsServerName']},
            },
      mode: mode,
      localAddress: localAddress,
      localTlsSha256: localPin,
    );
  }

  /// The locally imported configuration, whether or not it is in use.
  RemoteNetwork get customNetwork => _custom;

  /// The configuration the platform account provides, whether or not it is
  /// in use.
  RemoteNetwork get platformNetwork {
    final p = platformProfile;
    if (p == null || !account.signedIn) {
      return const RemoteNetwork();
    }
    final node = activeNode;
    if (node == null) return const RemoteNetwork();
    return RemoteNetwork(
      outbound: {
        'type': 'vless',
        'server': node['host'],
        'server_port': node['port'],
        'tls': {'enabled': true, 'server_name': node['tlsServerName']},
      },
      credential: {'uuid': p.uuid},
      proxies: p.proxies,
      probeTimeoutMs: _custom.probeTimeoutMs,
      stabilitySeconds: _custom.stabilitySeconds,
      reconnectAttempts: _custom.reconnectAttempts,
      reconnectDelayMs: _custom.reconnectDelayMs,
    );
  }

  /// The node this device uses: the one the Connector reported, else the
  /// first listed node until a report arrives. There is no manual choice.
  Map<String, dynamic>? get activeNode {
    final p = platformProfile;
    if (p == null) return null;
    final id = p.activeNodeId;
    return (id == null
            ? null
            : p.nodes.where((n) => n['nodeId'] == id).firstOrNull) ??
        p.nodes.firstOrNull;
  }

  /// True when [activeNode] comes from a Connector report.
  bool get followsConnector => platformProfile?.activeNodeId != null;

  void _preferences() => ConfigurationDatabase.writeSetting(
    db,
    _namespace,
    'platform',
    {'enabled': usePlatform},
  );

  void startSubscription() {
    if (_closed || _refreshTimer != null || !account.signedIn) return;
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(refreshPlatform().catchError((Object _) {}));
    });
    unawaited(refreshPlatform().catchError((Object _) {}));
  }

  Future<void> refreshPlatform() =>
      _syncing ??= _refreshPlatform().whenComplete(() => _syncing = null);
  Future<void> _refreshPlatform() async {
    try {
      final next = await account.fetchProfile();
      if (_closed) return;
      final old = platformProfile;
      if (old != null &&
          (next.userId != old.userId ||
              next.deviceId != old.deviceId ||
              next.revision < old.revision)) {
        throw const FormatException('Invalid Relay profile revision or lease');
      }
      platformProfile = next;
      platformError = null;
      ConfigurationDatabase.writeSetting(db, _namespace, 'profile', next.data);
    } catch (e) {
      platformError = e is RelayApiException ? e.code : 'profile_unavailable';
      if (!account.signedIn) {
        platformProfile = null;
        ConfigurationDatabase.writeSetting(db, _namespace, 'profile', null);
        _refreshTimer?.cancel();
        _refreshTimer = null;
      }
      rethrow;
    } finally {
      if (!_closed) {
        _configureTransport();
        await onChanged?.call();
      }
    }
  }

  Future<void> loginPlatform(String email, String password) async {
    await load();
    // Serialize with an in-flight refresh before replacing the account.
    try {
      await _syncing;
    } catch (_) {}
    await account.login(email, password);
    platformProfile = null;
    ConfigurationDatabase.writeSetting(db, _namespace, 'profile', null);
    try {
      await refreshPlatform();
    } finally {
      startSubscription();
    }
  }

  Future<void> selectPlatform() async {
    await load();
    usePlatform = true;
    _preferences();
    _configureTransport();
    await onChanged?.call();
  }

  /// Switches back to the locally imported configuration; the platform
  /// configuration stops being used.
  Future<void> selectCustom() async {
    await load();
    if (!_custom.configured) {
      throw const FormatException('No imported configuration');
    }
    usePlatform = false;
    _preferences();
    _configureTransport();
    await onChanged?.call();
  }

  final Map<String, int?> nodeLatencyMs = {};

  Future<void> testPlatformNodes({
    Future<Duration> Function(Map<String, dynamic>)? probe,
  }) async {
    final nodes = platformProfile?.nodes.toList() ?? [];
    final measure = probe ?? probeRelayNode;
    final results = <String, int?>{};
    // Bound concurrent handshakes; results are informational only.
    for (var offset = 0; offset < nodes.length; offset += 4) {
      await Future.wait(
        nodes.skip(offset).take(4).map((node) async {
          final id = node['nodeId'] as String;
          try {
            results[id] = (await measure(node)).inMilliseconds;
          } catch (_) {
            results[id] = null;
          }
        }),
      );
    }
    if (!_closed) {
      nodeLatencyMs
        ..clear()
        ..addAll(results);
    }
  }

  Future<void> logoutPlatform() async {
    try {
      await _syncing;
    } catch (_) {}
    try {
      await account.logout();
    } finally {
      platformProfile = null;
      _refreshTimer?.cancel();
      _refreshTimer = null;
      ConfigurationDatabase.writeSetting(db, _namespace, 'profile', null);
      _configureTransport();
      await onChanged?.call();
    }
  }

  void dispose() {
    _closed = true;
    _refreshTimer?.cancel();
    account.close();
  }

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
        _custom = RemoteNetwork.fromJson(Map<String, dynamic>.from(value));
      } catch (_) {
        // Unreadable or incompatible settings are dropped: remote access
        // starts unconfigured.
        _custom = const RemoteNetwork();
      }
    }
    account.load();
    final preference = ConfigurationDatabase.readSetting(
      db,
      _namespace,
      'platform',
    );
    usePlatform = preference is Map
        ? preference['enabled'] != false
        : !_custom.configured;
    try {
      final cached = ConfigurationDatabase.readSetting(
        db,
        _namespace,
        'profile',
      );
      if (account.signedIn && cached is Map) {
        platformProfile = RelayDeviceProfile.parse(
          Map<String, dynamic>.from(cached),
        );
      }
    } catch (_) {
      platformProfile = null;
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
    _custom = next;
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
    usePlatform = false;
    _preferences();
    _configureTransport();
    return network;
  }

  /// Removes the Relay connection and its credential, resetting local defaults.
  Future<RemoteNetwork> clear() async {
    await load();
    await _write(_custom.cleared());
    usePlatform = true;
    _preferences();
    _configureTransport();
    return network;
  }

  Future<RemoteNetwork> savePolicy(RemoteNetwork next) async {
    await load();
    await _write(
      _custom.copyWith(
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
    final route = routeFor(source.remote);
    return source.copyWith(
      remoteAccess: route,
      clearRemoteAccess: route == null,
      remoteRuntimePolicy: network.runtimePolicy,
    );
  }
}
