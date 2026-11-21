import 'dart:io';

/// Checks only the Relay TCP/TLS entry. It sends no account or device secret
/// and makes no claim that a Home service is reachable through that node.
Future<Duration> probeRelayNode(Map<String, dynamic> node) async {
  final watch = Stopwatch()..start();
  Socket? raw;
  SecureSocket? tls;
  try {
    raw = await Socket.connect(
      node['host'] as String,
      node['port'] as int,
      timeout: const Duration(seconds: 4),
    );
    tls = await SecureSocket.secure(
      raw,
      host: node['tlsServerName'] as String,
    ).timeout(const Duration(seconds: 4));
    return watch.elapsed;
  } finally {
    tls?.destroy();
    raw?.destroy();
  }
}
