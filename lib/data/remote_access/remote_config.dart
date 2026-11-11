import 'dart:convert';
import 'dart:io';

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

/// Stable references and public endpoints only. The outbound (including its
/// UUID) lives in secure storage under [credentialRef], never in source JSON.
class RemoteAccessConfig {
  const RemoteAccessConfig({
    required this.lineId,
    required this.homeId,
    required this.serviceId,
    required this.remoteAddress,
    required this.remotePort,
    required this.credentialRef,
    this.mode = RemoteConnectionMode.remoteOnly,
    this.localAddress,
    this.localTlsSha256,
    this.outboundOptions,
  });
  final String lineId, homeId, serviceId, remoteAddress, credentialRef;
  final int remotePort;
  final RemoteConnectionMode mode;
  final String? localAddress, localTlsSha256;
  final Map<String, dynamic>? outboundOptions;
  Map<String, dynamic> toJson() => {
    'lineId': lineId,
    'homeId': homeId,
    'serviceId': serviceId,
    'remoteAddress': remoteAddress,
    'remotePort': remotePort,
    'credentialRef': credentialRef,
    'mode': mode.name,
    if (localAddress?.isNotEmpty == true) 'localAddress': localAddress,
    if (localTlsSha256?.isNotEmpty == true) 'localTlsSha256': localTlsSha256,
    if (outboundOptions != null) 'outboundOptions': outboundOptions,
  };
  factory RemoteAccessConfig.fromJson(Map<String, dynamic> j) {
    const keys = {
      'lineId',
      'homeId',
      'serviceId',
      'remoteAddress',
      'remotePort',
      'credentialRef',
      'mode',
      'localAddress',
      'localTlsSha256',
      'outboundOptions',
    };
    if (j.keys.any((k) => !keys.contains(k))) {
      throw const FormatException('未知远程连接字段。');
    }
    final c = RemoteAccessConfig(
      lineId: j['lineId'] as String,
      homeId: j['homeId'] as String,
      serviceId: j['serviceId'] as String,
      remoteAddress: j['remoteAddress'] as String,
      remotePort: j['remotePort'] as int,
      credentialRef: j['credentialRef'] as String,
      mode: RemoteConnectionMode.values.byName(
        j['mode'] as String? ?? 'remoteOnly',
      ),
      localAddress: j['localAddress'] as String?,
      localTlsSha256: j['localTlsSha256'] as String?,
      outboundOptions: j['outboundOptions'] as Map<String, dynamic>?,
    );
    c.validate();
    return c;
  }
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
      throw const FormatException('远程访问需要有效的 HTTP(S) 或 SMB 服务端点。');
    }
    return u;
  }

  void validate() {
    if (outboundOptions != null) {
      if (outboundOptions!.containsKey('uuid')) {
        throw const FormatException('实际 UUID 只能保存在安全存储。');
      }
      // Reuse the import validator with a dummy, never-persisted identity.
      RemotePairing.validateOutbound({
        ...outboundOptions!,
        'uuid': '11111111-1111-4111-8111-111111111111',
      });
    }
    if ([
          lineId,
          homeId,
          serviceId,
          credentialRef,
        ].any((v) => v.trim().isEmpty) ||
        remotePort < 1 ||
        remotePort > 65535) {
      throw const FormatException('远程访问引用或映射端口无效。');
    }
    endpoint(remoteAddress);
    if (mode != RemoteConnectionMode.remoteOnly) {
      if (localAddress == null ||
          endpoint(localAddress!).scheme != 'https' ||
          !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(localTlsSha256 ?? '')) {
        throw const FormatException('局域网自动访问需要 HTTPS 端点和配对确认的证书 SHA-256。');
      }
    }
  }
}

class RemotePairing {
  RemotePairing._(this.data, this.outbound);
  final Map<String, dynamic> data, outbound;
  static void validateOutbound(Map<String, dynamic> out) {
    final server = out['server'];
    bool validHost(Object? value) =>
        value is String &&
        value.length <= 253 &&
        (InternetAddress.tryParse(value) != null ||
            RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$').hasMatch(value) ||
            RegExp(r'^[a-zA-Z0-9]$').hasMatch(value));
    if (jsonEncode(out).length > 65536 || !validHost(server)) {
      throw const FormatException('代理主机或配置长度无效。');
    }
    final tls = out['tls'] as Map<String, dynamic>?;
    if (!validHost(tls?['server_name'])) {
      throw const FormatException('代理 TLS 服务名称无效。');
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
      throw const FormatException('配对需要开启证书校验的 VLESS TLS/REALITY 出站。');
    }
    // No external paths, ECH key logs or embedded client keys from an import.
    final certificate = tls?['certificate'];
    if (certificate is String && certificate.contains('PRIVATE KEY') ||
        certificate is List &&
            certificate.any((c) => c is! String || c.contains('PRIVATE KEY'))) {
      throw const FormatException('CA 配置不能包含私钥。');
    }
    final reality = tls?['reality'];
    if (reality != null &&
        (reality is! Map ||
            reality.keys.any(
              (k) => !['enabled', 'public_key', 'short_id'].contains(k),
            ))) {
      throw const FormatException('REALITY 客户端只保存公开参数。');
    }
    final transport = out['transport'];
    if (transport is Map) {
      final headers = transport['headers'];
      if (headers is Map &&
          headers.keys.any((k) => k.toString().toLowerCase() != 'host')) {
        throw const FormatException('传输认证头不能写入公开线路配置。');
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
      throw const FormatException('不支持的 TLS 配置字段。');
    }
  }

  factory RemotePairing.parse(String text) {
    if (text.length > 65536) throw const FormatException('配对配置过大。');
    final j = jsonDecode(text) as Map<String, dynamic>;
    if (j['version'] != 1) throw const FormatException('不支持的配对版本。');
    final out = j['outbound'] as Map<String, dynamic>;
    validateOutbound(out);
    RemoteAccessConfig(
      lineId: j['lineId'] as String,
      homeId: j['homeId'] as String,
      serviceId: j['serviceId'] as String,
      remoteAddress: j['remoteAddress'] as String,
      remotePort: j['remotePort'] as int,
      credentialRef: 'pending',
    ).validate();
    return RemotePairing._(j, out);
  }
}
