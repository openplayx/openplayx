import 'dart:convert';

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
  });
  final String lineId, homeId, serviceId, remoteAddress, credentialRef;
  final int remotePort;
  final RemoteConnectionMode mode;
  final String? localAddress, localTlsSha256;
  Map<String, dynamic> toJson() => {
    'lineId': lineId,
    'homeId': homeId,
    'serviceId': serviceId,
    'remoteAddress': remoteAddress,
    'remotePort': remotePort,
    'credentialRef': credentialRef,
    'mode': mode.name,
    'localAddress': localAddress,
    'localTlsSha256': localTlsSha256,
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
  factory RemotePairing.parse(String text) {
    if (text.length > 65536) throw const FormatException('配对配置过大。');
    final j = jsonDecode(text) as Map<String, dynamic>;
    if (j['version'] != 1) throw const FormatException('不支持的配对版本。');
    final out = j['outbound'] as Map<String, dynamic>;
    final tls = out['tls'] as Map<String, dynamic>?;
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
