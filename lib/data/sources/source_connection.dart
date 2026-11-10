import 'source_config.dart';

/// Connection form values are separate from persisted runtime policies. A pasted
/// complete URL is accepted, but users can enter a host and use sensible defaults.
class SourceConnection {
  const SourceConnection({
    required this.host,
    required this.port,
    required this.path,
    required this.https,
  });
  final String host;
  final int port;
  final String path;
  final bool https;
  factory SourceConnection.fromConfig(SourceConfig config) {
    final uri = Uri.parse(config.address);
    return SourceConnection(
      host: uri.host,
      port: uri.hasPort
          ? uri.port
          : config.kind.standardPort ?? (uri.port == 0 ? 80 : uri.port),
      path: uri.path.replaceFirst(RegExp(r'^/+'), ''),
      https: uri.scheme == 'https',
    );
  }
  static String address(
    SourceKind kind,
    String input, {
    String port = '',
    String path = '',
    bool https = false,
  }) {
    final text = input.trim();
    if (text.isEmpty) throw const FormatException('请填写服务器地址。');
    final pasted = text.contains('://');
    final uri = Uri.tryParse(
      pasted
          ? text
          : '${kind.isHttp
                ? https
                      ? 'https'
                      : 'http'
                : kind.scheme}://$text',
    );
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.hasQuery && kind != SourceKind.dlna) ||
        uri.hasFragment ||
        !kind.schemes.contains(uri.scheme)) {
      throw const FormatException('请输入有效的 IP、主机名或服务器地址。');
    }
    final number = port.trim().isEmpty ? null : int.tryParse(port.trim());
    if (port.trim().isNotEmpty &&
        (number == null || number < 1 || number > 65535)) {
      throw const FormatException('端口须为 1–65535。');
    }
    if (kind == SourceKind.smb &&
        (number != null && number != 445 || uri.hasPort && uri.port != 445)) {
      throw const FormatException('当前 SMB 连接使用 445 端口。');
    }
    final selectedPath = path.trim().isEmpty
        ? uri.path
        : '/${path.trim().replaceFirst(RegExp(r'^/+'), '')}';
    if (selectedPath
        .split('/')
        .any(
          (s) =>
              Uri.decodeComponent(s) == '..' || Uri.decodeComponent(s) == '.',
        )) {
      throw const FormatException('路径不能包含 . 或 ..。');
    }
    final int? selectedPort;
    if (!kind.isHttp) {
      // smb/ftp/sftp: keep the URL clean when the standard port is used.
      final value = number ?? (uri.hasPort ? uri.port : null);
      selectedPort = kind == SourceKind.smb || value == kind.standardPort
          ? null
          : value;
    } else {
      selectedPort =
          number ??
          (uri.hasPort || pasted
              ? uri.port
              : uri.scheme == 'https'
              ? 443
              : kind.defaultPort ?? 80);
    }
    // Built from parts: Uri.replace keeps an existing port when given null.
    final result = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: selectedPort,
      path: selectedPath,
      query: uri.hasQuery ? uri.query : null,
    ).toString();
    return kind == SourceKind.dlna
        ? result
        : result.replaceFirst(RegExp(r'/$'), '');
  }
}
