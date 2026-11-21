import 'dart:convert';
import 'dart:io';

import '../../l10n/l10n.dart';

class RemoteRuntimePolicy {
  const RemoteRuntimePolicy({
    this.probeTimeoutMs = 2000,
    this.stabilitySeconds = 30,
    this.reconnectAttempts = 2,
    this.reconnectDelayMs = 1000,
    this.allowCellular = true,
  });
  final int probeTimeoutMs,
      stabilitySeconds,
      reconnectAttempts,
      reconnectDelayMs;
  final bool allowCellular;
}

enum RemoteConnectionMode { automatic, localOnly, remoteOnly }

void _validateLocal(
  RemoteConnectionMode mode,
  String? localAddress,
  String? localTlsSha256,
) {
  if (mode == RemoteConnectionMode.remoteOnly) return;
  if (localAddress == null ||
      RemoteAccessConfig.endpoint(localAddress).scheme != 'https' ||
      !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(localTlsSha256 ?? '')) {
    throw FormatException(appStrings.errRemoteLanNeedsHttps);
  }
}

/// What a source stores about remote access: which frpc [proxy] (registered
/// by Home on the Relay's frps) it goes through, plus optional LAN switching.
/// The Relay connection itself is App-wide, see `RemoteNetwork`.
class SourceRemote {
  const SourceRemote({
    required this.proxy,
    this.mode = RemoteConnectionMode.remoteOnly,
    this.localAddress,
    this.localTlsSha256,
  });
  final String proxy;
  final RemoteConnectionMode mode;
  final String? localAddress, localTlsSha256;

  Map<String, dynamic> toJson() => {
    'proxy': proxy,
    'mode': mode.name,
    if (localAddress?.isNotEmpty == true) 'localAddress': localAddress,
    if (localTlsSha256?.isNotEmpty == true) 'localTlsSha256': localTlsSha256,
  };

  factory SourceRemote.fromJson(Map<String, dynamic> j) {
    const keys = {'proxy', 'mode', 'localAddress', 'localTlsSha256'};
    if (j.keys.any((k) => !keys.contains(k))) {
      throw FormatException(appStrings.errRemoteUnknownField);
    }
    final value = SourceRemote(
      proxy: j['proxy'] as String,
      mode: RemoteConnectionMode.values.byName(
        j['mode'] as String? ?? 'remoteOnly',
      ),
      localAddress: j['localAddress'] as String?,
      localTlsSha256: j['localTlsSha256'] as String?,
    );
    value.validate();
    return value;
  }

  void validate() {
    if (proxy.trim().isEmpty) {
      throw FormatException(appStrings.errRemoteChooseProxy);
    }
    _validateLocal(mode, localAddress, localTlsSha256);
  }
}

/// The resolved route a runtime uses: the source's [SourceRemote] joined with
/// the App-wide Relay outbound and the proxy's [remotePort]. Built at load
/// time, never persisted. The media endpoint is the source's own address.
class RemoteAccessConfig {
  const RemoteAccessConfig({
    required this.proxy,
    required this.remotePort,
    required this.credential,
    required this.outbound,
    this.mode = RemoteConnectionMode.remoteOnly,
    this.localAddress,
    this.localTlsSha256,
  });

  /// frpc proxy name / remotePort on the Relay's loopback.
  final String proxy;
  final int remotePort;

  /// The App user's credential (`{"uuid": ...}`) for [outbound].
  final Map<String, dynamic> credential;

  /// Public sing-box outbound options (no `uuid`).
  final Map<String, dynamic> outbound;
  final RemoteConnectionMode mode;
  final String? localAddress, localTlsSha256;

  Map<String, dynamic> toJson() => {
    'proxy': proxy,
    'remotePort': remotePort,
    'credential': credential,
    'outbound': outbound,
    'mode': mode.name,
    if (localAddress?.isNotEmpty == true) 'localAddress': localAddress,
    if (localTlsSha256?.isNotEmpty == true) 'localTlsSha256': localTlsSha256,
  };

  static Uri endpoint(String address) {
    final u = Uri.parse(address);
    if (!['http', 'https', 'smb'].contains(u.scheme) ||
        u.host.isEmpty ||
        u.userInfo.isNotEmpty ||
        u.hasQuery ||
        u.hasFragment ||
        (u.scheme != 'smb' && u.port < 1) ||
        u.port > 65535 ||
        u.pathSegments.any((p) => p == '.' || p == '..' || p.contains('\\'))) {
      throw FormatException(appStrings.errRemoteEndpoint);
    }
    return u;
  }

  void validate() {
    if (outbound.containsKey('uuid')) {
      throw FormatException(appStrings.errRemoteUuidPlacement);
    }
    RemotePairing.validateOutbound({
      ...outbound,
      'uuid': '11111111-1111-4111-8111-111111111111',
    });
    if (proxy.trim().isEmpty ||
        credential['uuid'] is! String ||
        remotePort < 1 ||
        remotePort > 65535) {
      throw FormatException(appStrings.errRemoteProxyRef);
    }
    _validateLocal(mode, localAddress, localTlsSha256);
  }
}

/// One frpc proxy the App may use: Home registered it on Relay's frps under
/// [name], reachable on Relay loopback at [remotePort].
class RemoteProxy {
  const RemoteProxy(this.name, this.remotePort, {this.label, this.kind});
  final String name;
  final int remotePort;
  final String? label, kind;
  String get displayName => label ?? name;

  Map<String, dynamic> toJson() => {
    'name': name,
    'remotePort': remotePort,
    if (label != null) 'label': label,
    if (kind != null) 'kind': kind,
  };

  /// The proxy a new source of [kind] defaults to: the one named after the
  /// kind (jellyfin, smb...), else the only one.
  static RemoteProxy? defaultFor(List<RemoteProxy> proxies, String kind) =>
      proxies.where((p) => (p.kind ?? p.name) == kind).firstOrNull ??
      (proxies.length == 1 ? proxies.single : null);
}

/// The App file exported by Relay, in sing-box / frp terms:
/// `{"outbound": <sing-box VLESS outbound>, "proxies": [{"name", "remotePort"}]}`.
class RemotePairing {
  RemotePairing._(this.outbound, this.proxies);

  /// sing-box outbound including the App user's `uuid` (no `tag`).
  final Map<String, dynamic> outbound;
  final List<RemoteProxy> proxies;

  static void validateOutbound(Map<String, dynamic> out) {
    final server = out['server'];
    bool validHost(Object? value) =>
        value is String &&
        value.length <= 253 &&
        (InternetAddress.tryParse(value) != null ||
            RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$').hasMatch(value) ||
            RegExp(r'^[a-zA-Z0-9]$').hasMatch(value));
    if (jsonEncode(out).length > 65536 || !validHost(server)) {
      throw FormatException(appStrings.errRemoteProxyHost);
    }
    final tls = out['tls'] as Map<String, dynamic>?;
    if (!validHost(tls?['server_name'])) {
      throw FormatException(appStrings.errRemoteTlsName);
    }
    const keys = {
      'type',
      'server',
      'server_port',
      'uuid',
      'tls',
      'flow',
      'transport',
    };
    if (out.keys.any((k) => !keys.contains(k)) ||
        out['type'] != 'vless' ||
        (out['server'] as String? ?? '').isEmpty ||
        out['server_port'] is! int ||
        (out['server_port'] as int) < 1 ||
        (out['server_port'] as int) > 65535 ||
        !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
            .hasMatch(out['uuid'] as String? ?? '') ||
        tls?['enabled'] != true ||
        tls?['insecure'] == true ||
        (tls?['server_name'] as String? ?? '').isEmpty) {
      throw FormatException(appStrings.errRemoteNeedsVless);
    }
    // No external paths, ECH key logs or embedded client keys from an import.
    final certificate = tls?['certificate'];
    if (certificate is String && certificate.contains('PRIVATE KEY') ||
        certificate is List &&
            certificate.any((c) => c is! String || c.contains('PRIVATE KEY'))) {
      throw FormatException(appStrings.errRemoteCaPrivateKey);
    }
    final reality = tls?['reality'];
    if (reality != null &&
        (reality is! Map ||
            reality.keys.any(
              (k) => !['enabled', 'public_key', 'short_id'].contains(k),
            ))) {
      throw FormatException(appStrings.errRemoteRealityPublic);
    }
    final transport = out['transport'];
    if (transport is Map) {
      final headers = transport['headers'];
      if (headers is Map &&
          headers.keys.any((k) => k.toString().toLowerCase() != 'host')) {
        throw FormatException(appStrings.errRemoteAuthHeader);
      }
    }
    const tlsKeys = {
      'enabled',
      'server_name',
      'certificate',
      'reality',
      'utls',
      'alpn',
      'min_version',
      'max_version',
    };
    if (tls!.keys.any((k) => !tlsKeys.contains(k))) {
      throw FormatException(appStrings.errRemoteTlsField);
    }
  }

  factory RemotePairing.parse(String text) {
    if (text.length > 65536) {
      throw FormatException(appStrings.errRemoteConfigTooLarge);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw FormatException(appStrings.errRemoteInvalidJson);
    }
    if (decoded is! Map<String, dynamic> ||
        decoded.keys.any((k) => k != 'outbound' && k != 'proxies') ||
        decoded['outbound'] is! Map<String, dynamic> ||
        decoded['proxies'] is! List) {
      throw FormatException(appStrings.errRemoteAppConfigShape);
    }
    // The sing-box tag only names the outbound inside one config file.
    final out = Map<String, dynamic>.of(
      decoded['outbound'] as Map<String, dynamic>,
    )..remove('tag');
    validateOutbound(out);
    final proxies = <RemoteProxy>[];
    for (final item in decoded['proxies'] as List) {
      if (item is! Map ||
          item.keys.any((k) => k != 'name' && k != 'remotePort') ||
          item['name'] is! String ||
          (item['name'] as String).trim().isEmpty ||
          item['remotePort'] is! int ||
          (item['remotePort'] as int) < 1 ||
          (item['remotePort'] as int) > 65535) {
        throw FormatException(appStrings.errRemoteProxyShape);
      }
      proxies.add(
        RemoteProxy(item['name'] as String, item['remotePort'] as int),
      );
    }
    if (proxies.isEmpty ||
        proxies.map((p) => p.name).toSet().length != proxies.length) {
      throw FormatException(appStrings.errRemoteProxiesEmpty);
    }
    return RemotePairing._(out, proxies);
  }
}
