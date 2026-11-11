import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/plugins/source_capability.dart';
import '../sources/source_config.dart';
import 'remote_config.dart';
import 'remote_native.dart';

class RemoteCredentialStore {
  static const _storage = FlutterSecureStorage();
  static Future<String> stage(
    String sourceId,
    Map<String, dynamic> outbound,
  ) async {
    final suffix = List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final ref = 'remote.$sourceId.$suffix';
    await _storage.write(key: ref, value: jsonEncode(outbound));
    return ref;
  }

  static Future<Map<String, dynamic>> read(String sourceId, String ref) async {
    if (!ref.startsWith('remote.$sourceId.')) {
      throw const PluginException('permissionDenied', '远程凭据不属于此来源。');
    }
    final value = await _storage.read(key: ref);
    if (value == null) {
      throw const PluginException('authRequired', '远程线路凭据不可用，请重新导入配对。');
    }
    return jsonDecode(value) as Map<String, dynamic>;
  }

  static Future<void> delete(String sourceId, String ref) async {
    if (ref.startsWith('remote.$sourceId.')) await _storage.delete(key: ref);
  }
}

/// Each client owns a path lease. Existing playback holds it through the source
/// runtime; expiry or a network change affects only newly created clients.
class RemotePathLease {
  RemotePathLease(
    this.address, {
    this.loopbackPort,
    this.localTlsSha256,
    this.onClose,
  });
  final Uri address;
  final int? loopbackPort;
  final String? localTlsSha256;
  final void Function()? onClose;
  bool _closed = false;
  void configure(HttpClient client, {SecurityContext? securityContext}) {
    client.findProxy = (_) => 'DIRECT';
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      if (uri.host != address.host ||
          uri.port != address.port ||
          uri.scheme != address.scheme ||
          proxyHost != null) {
        throw const PluginException('permissionDenied', '请求超出已授权的服务端点。');
      }
      // HttpClient still handles TLS with uri.host: SNI and certificate checks
      // are unchanged even though this raw socket uses a local forwarding port.
      final task = await Socket.startConnect(
        loopbackPort == null ? uri.host : '127.0.0.1',
        loopbackPort ?? uri.port,
      );
      Socket? connected;
      var cancelled = false;
      final socket = (() async {
        final raw = await task.socket;
        if (cancelled) {
          raw.destroy();
          throw const SocketException('cancelled');
        }
        connected = raw;
        if (uri.scheme != 'https') return raw;
        try {
          final secure = await SecureSocket.secure(
            raw,
            host: uri.host,
            context: securityContext,
          );
          connected = secure;
          if (cancelled ||
              (localTlsSha256 != null &&
                  (secure.peerCertificate == null ||
                      sha256.convert(secure.peerCertificate!.der).toString() !=
                          localTlsSha256!.toLowerCase()))) {
            secure.destroy();
            throw const PluginException(
              'serviceIdentityMismatch',
              '服务证书与已配对身份不匹配。',
            );
          }
          return secure;
        } catch (_) {
          raw.destroy();
          rethrow;
        }
      })();
      return ConnectionTask.fromSocket(socket, () {
        cancelled = true;
        task.cancel();
        connected?.destroy();
      });
    };
  }

  /// Limits a client's Socket.connect calls to one logical TCP service. Used
  /// for SMB's fixed port API without modifying the dependency or global IO.
  Future<T> runWithTcp<T>(
    Future<T> Function() action, {
    required String logicalHost,
    required int logicalPort,
  }) {
    return IOOverrides.runZoned(
      action,
      socketConnect:
          (
            target,
            port, {
            sourceAddress,
            int sourcePort = 0,
            Duration? timeout,
          }) async {
            if (_closed ||
                target != logicalHost ||
                port != logicalPort ||
                loopbackPort == null) {
              throw const PluginException('permissionDenied', '连接超出已配对服务。');
            }
            final task = await Socket.startConnect('127.0.0.1', loopbackPort!);
            return task.socket.timeout(
              timeout ?? const Duration(seconds: 15),
              onTimeout: () {
                task.cancel();
                throw const SocketException('Remote transport timed out');
              },
            );
          },
    );
  }

  void close() {
    if (!_closed) {
      _closed = true;
      onClose?.call();
    }
  }
}

typedef LocalIdentityProbe = Future<bool> Function(Uri, String);

class RemotePathSelector {
  RemotePathSelector({LocalIdentityProbe? probe, DateTime Function()? now})
    : _probe = probe ?? verifyLocalTls,
      _now = now ?? DateTime.now;
  final LocalIdentityProbe _probe;
  final DateTime Function() _now;
  final _checks = <String, Future<bool>>{};
  final _until = <String, DateTime>{};
  int _generation = 0;
  void networkChanged() {
    _generation++;
    _checks.clear();
    _until.clear();
  }

  Future<bool> localAvailable(String sourceId, RemoteAccessConfig c) {
    final key = '$sourceId:$_generation:${jsonEncode(c.toJson())}';
    if ((_until[key] ?? DateTime.fromMillisecondsSinceEpoch(0)).isBefore(
      _now(),
    )) {
      _until[key] = _now().add(const Duration(seconds: 30));
      _checks[key] = _probe(Uri.parse(c.localAddress!), c.localTlsSha256!)
          .timeout(const Duration(seconds: 2), onTimeout: () => false)
          .catchError((_) => false);
    }
    return _checks[key]!;
  }

  Future<bool> useLocal(String sourceId, RemoteAccessConfig c) async {
    c.validate();
    if (c.mode == RemoteConnectionMode.remoteOnly) return false;
    final available = await localAvailable(sourceId, c);
    if (!available && c.mode == RemoteConnectionMode.localOnly) {
      throw const PluginException(
        'localIdentityUnavailable',
        '局域网服务不可达或身份验证失败。',
      );
    }
    return available;
  }

  static Future<bool> verifyLocalTls(Uri endpoint, String expected) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2)
      ..findProxy = (_) => 'DIRECT';
    try {
      final request = await client.openUrl('HEAD', endpoint);
      request.followRedirects =
          false; // no credentials, even on the configured host
      final response = await request.close();
      final cert = response.certificate;
      return cert != null &&
          sha256.convert(cert.der).toString() == expected.toLowerCase();
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}

class _RemoteCoreEntry {
  _RemoteCoreEntry(this.ready);
  final Future<(RemoteNative, int)> ready;
  int users = 0;
}

class RemoteTransport {
  static final selector = RemotePathSelector();
  static final _cores = <String, _RemoteCoreEntry>{};
  static Future<RemotePathLease> acquire(SourceConfig source) async {
    final c = source.remoteAccess!;
    if (await selector.useLocal(source.id, c)) {
      return RemotePathLease(
        Uri.parse(c.localAddress!),
        localTlsSha256: c.localTlsSha256,
      );
    }
    final key = '${source.id}:${c.credentialRef}:${c.remotePort}';
    final entry = _cores.putIfAbsent(
      key,
      () => _RemoteCoreEntry(
        (() async {
          final out = await RemoteCredentialStore.read(
            source.id,
            c.credentialRef,
          );
          final core = RemoteNative.instance;
          return (core, core.start(out, c.remotePort));
        })(),
      ),
    );
    entry.users++;
    void release() {
      if (--entry.users == 0) {
        _cores.remove(key);
        entry.ready.then(
          (value) => value.$1.stop(value.$2),
          onError: (Object _) {},
        );
      }
    }

    try {
      final (_, port) = await entry.ready;
      return RemotePathLease(
        Uri.parse(c.remoteAddress),
        loopbackPort: port,
        onClose: release,
      );
    } catch (_) {
      release();
      rethrow;
    }
  }
}
