import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import '../../core/plugins/source_capability.dart';

/// Small, versioned C ABI around the pinned Go core. The library is linked into
/// Apple apps, and bundled as an application library on Android/Linux/Windows.
class RemoteNative {
  RemoteNative._(DynamicLibrary lib) {
    _start = lib
        .lookupFunction<
          Int32 Function(Pointer<Uint8>),
          int Function(Pointer<Uint8>)
        >('opx_remote_start');
    _stop = lib.lookupFunction<Void Function(Int32), void Function(int)>(
      'opx_remote_stop',
    );
    _alloc = lib
        .lookupFunction<
          Pointer<Uint8> Function(Int32),
          Pointer<Uint8> Function(int)
        >('opx_remote_alloc');
    _free = lib
        .lookupFunction<
          Void Function(Pointer<Uint8>),
          void Function(Pointer<Uint8>)
        >('opx_remote_free');
  }
  late final int Function(Pointer<Uint8>) _start;
  late final void Function(int) _stop;
  late final Pointer<Uint8> Function(int) _alloc;
  late final void Function(Pointer<Uint8>) _free;
  static RemoteNative? _instance;
  static RemoteNative get instance {
    try {
      return _instance ??= RemoteNative._(
        Platform.isIOS || Platform.isMacOS
            ? DynamicLibrary.process()
            : DynamicLibrary.open(
                Platform.isWindows
                    ? 'openplayx_remote.dll'
                    : 'libopenplayx_remote.so',
              ),
      );
    } catch (_) {
      throw const PluginException(
        'remoteCoreUnavailable',
        '此构建缺少远程连接内核，请安装包含 sing-box 的构建。',
      );
    }
  }

  int start(Map<String, dynamic> outbound, int targetPort) {
    final bytes = utf8.encode(
      jsonEncode({'outbound': outbound, 'targetPort': targetPort}),
    );
    final ptr = _alloc(bytes.length + 1);
    if (ptr == nullptr) {
      throw const PluginException('quotaExceeded', '远程连接配置过大。');
    }
    try {
      ptr.asTypedList(bytes.length + 1)
        ..setAll(0, bytes)
        ..[bytes.length] = 0;
      final handle = _start(ptr);
      if (handle <= 0) {
        throw const PluginException(
          'remoteConnectionFailed',
          '远程内核启动失败，请检查线路配置。',
        );
      }
      return handle;
    } finally {
      ptr.asTypedList(bytes.length + 1).fillRange(0, bytes.length + 1, 0);
      _free(ptr);
    }
  }

  void stop(int port) => _stop(port);
}
