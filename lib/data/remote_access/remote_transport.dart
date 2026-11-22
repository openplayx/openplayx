import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../../core/capabilities/source_capability.dart';
import '../sources/source_config.dart';
import 'remote_config.dart';
import 'remote_native.dart';
import '../../l10n/l10n.dart';

/// Each client owns a path lease. Existing playback holds it through the source
/// runtime; expiry or a network change affects only newly created clients.
class RemotePathLease {
  RemotePathLease(
    this.address, {
    this.loopbackPort,
    this.localTlsSha256,
    this.onClose,
    this.retryAttempts = 0,
    this.retryDelayMs = 1000,
    this.beforeConnect,
  });
  final Uri address;
  final int? loopbackPort;
  final int retryAttempts, retryDelayMs;
  final Future<void> Function()? beforeConnect;
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
        throw PluginException(
          'permissionDenied',
          appStrings.errRemoteOutsideEndpoint,
        );
      }
      // HttpClient still handles TLS with uri.host: SNI and certificate checks
      // are unchanged even though this raw socket uses a local forwarding port.
      final task = _connectRaw(
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
            throw PluginException(
              'serviceIdentityMismatch',
              appStrings.errRemoteCertMismatch,
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

  ConnectionTask<Socket> _connectRaw(String host, int port) {
    ConnectionTask<Socket>? pending;
    var cancelled = false;
    final socket = (() async {
      for (var attempt = 0; ; attempt++) {
        if (cancelled || _closed) throw const SocketException('cancelled');
        try {
          await beforeConnect?.call();
          if (cancelled || _closed) throw const SocketException('cancelled');
          pending = await Socket.startConnect(host, port);
          final result = await pending!.socket;
          if (cancelled || _closed) {
            result.destroy();
            throw const SocketException('cancelled');
          }
          return result;
        } on SocketException {
          if (attempt >= retryAttempts || cancelled || _closed) rethrow;
          await Future<void>.delayed(Duration(milliseconds: retryDelayMs));
        }
      }
    })();
    return ConnectionTask.fromSocket(socket, () {
      cancelled = true;
      pending?.cancel();
    });
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
              throw PluginException(
                'permissionDenied',
                appStrings.errRemoteOutsidePaired,
              );
            }
            final task = _connectRaw('127.0.0.1', loopbackPort!);
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
  RemotePathSelector({this._probe, DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final LocalIdentityProbe? _probe;
  Duration probeTimeout = const Duration(seconds: 2);
  Duration stabilityWindow = const Duration(seconds: 30);
  final DateTime Function() _now;
  final _checks = <String, Future<bool>>{};
  final _until = <String, DateTime>{};
  int _generation = 0;
  void networkChanged() {
    _generation++;
    _checks.clear();
    _until.clear();
  }

  Future<bool> localAvailable(
    String sourceId,
    RemoteAccessConfig c, {
    RemoteRuntimePolicy? policy,
  }) {
    final timeout = policy == null
        ? probeTimeout
        : Duration(milliseconds: policy.probeTimeoutMs);
    final window = policy == null
        ? stabilityWindow
        : Duration(seconds: policy.stabilitySeconds);
    final key =
        '$sourceId:$_generation:${timeout.inMilliseconds}:${window.inSeconds}:${jsonEncode(c.toJson())}';
    if ((_until[key] ?? DateTime.fromMillisecondsSinceEpoch(0)).isBefore(
      _now(),
    )) {
      _until[key] = _now().add(window);
      _checks[key] =
          (_probe ??
                  ((uri, expected) => verifyLocalTls(
                    uri,
                    expected,
                    timeout: timeout,
                  )))(Uri.parse(c.localAddress!), c.localTlsSha256!)
              .timeout(timeout, onTimeout: () => false)
              .catchError((_) => false);
    }
    return _checks[key]!;
  }

  Future<bool> useLocal(
    String sourceId,
    RemoteAccessConfig c, {
    RemoteRuntimePolicy? policy,
  }) async {
    c.validate();
    if (c.mode == RemoteConnectionMode.remoteOnly) return false;
    final available = await localAvailable(sourceId, c, policy: policy);
    if (!available && c.mode == RemoteConnectionMode.localOnly) {
      throw PluginException(
        'localIdentityUnavailable',
        appStrings.errRemoteLanUnreachable,
      );
    }
    return available;
  }

  static Future<bool> verifyLocalTls(
    Uri endpoint,
    String expected, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..findProxy = (_) => 'DIRECT';
    try {
      final request = await client.openUrl('HEAD', endpoint);
      request.followRedirects =
          false; // no credentials, even on the configured host
      final response = await request.close().timeout(timeout);
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
  static int _retryAttempts = 0, _retryDelayMs = 1000;
  static bool _allowCellular = true;
  static const _network = MethodChannel('openplayx/network_policy');
  static final _networkChanges = StreamController<void>.broadcast();
  static bool _listening = false;
  static Stream<void> get networkChanges {
    if (!_listening) {
      _listening = true;
      _network.setMethodCallHandler((call) async {
        if (call.method == 'networkChanged') _networkChanges.add(null);
      });
    }
    return _networkChanges.stream;
  }

  static void configurePolicy({
    required int probeTimeoutMs,
    required int stabilitySeconds,
    required bool allowCellular,
    required int reconnectAttempts,
    required int reconnectDelayMs,
  }) {
    selector.probeTimeout = Duration(milliseconds: probeTimeoutMs);
    selector.stabilityWindow = Duration(seconds: stabilitySeconds);
    networkChanged();
    _allowCellular = allowCellular;
    _retryAttempts = reconnectAttempts;
    _retryDelayMs = reconnectDelayMs;
  }

  static Future<void> checkNetworkPolicy({bool? allowCellular}) async {
    if ((allowCellular ?? _allowCellular) ||
        (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    try {
      final cellular = await _network
          .invokeMethod<bool>('usingCellular')
          .timeout(const Duration(seconds: 3));
      if (cellular != false) {
        throw PluginException(
          'cellularDenied',
          appStrings.errRemoteCellularBlocked,
        );
      }
    } on PluginException {
      rethrow;
    } catch (_) {
      throw PluginException(
        'networkPolicyUnavailable',
        appStrings.errRemoteCellularUnknown,
      );
    }
  }

  static final selector = RemotePathSelector();
  static final selectedPaths = <String, (bool local, DateTime observedAt)>{};
  static void networkChanged() {
    selector.networkChanged();
    selectedPaths.clear();
  }

  static final _cores = <String, _RemoteCoreEntry>{};
  static Future<RemotePathLease> acquire(SourceConfig source) async {
    final c = source.remoteAccess!;
    if (await selector.useLocal(
      source.id,
      c,
      policy: source.remoteRuntimePolicy,
    )) {
      selectedPaths[source.id] = (true, DateTime.now());
      return RemotePathLease(
        Uri.parse(c.localAddress!),
        localTlsSha256: c.localTlsSha256,
      );
    }
    if (!c.remoteReady) {
      throw PluginException(
        'remoteUnavailable',
        appStrings.connectorSourceNotReady,
      );
    }
    await checkNetworkPolicy(
      allowCellular: source.remoteRuntimePolicy?.allowCellular,
    );
    final key = '${source.id}:${jsonEncode(c.toJson())}';
    final entry = _cores.putIfAbsent(
      key,
      () => _RemoteCoreEntry(
        (() async {
          final core = RemoteNative.instance;
          return (
            core,
            core.start({...c.credential, ...c.outbound}, c.remotePort),
          );
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
      selectedPaths[source.id] = (false, DateTime.now());
      return RemotePathLease(
        Uri.parse(source.address),
        loopbackPort: port,
        onClose: release,
        beforeConnect: () => checkNetworkPolicy(
          allowCellular:
              (source.remoteRuntimePolicy?.allowCellular ?? _allowCellular) &&
              _allowCellular,
        ),
        retryAttempts:
            source.remoteRuntimePolicy?.reconnectAttempts ?? _retryAttempts,
        retryDelayMs:
            source.remoteRuntimePolicy?.reconnectDelayMs ?? _retryDelayMs,
      );
    } catch (_) {
      release();
      rethrow;
    }
  }
}
