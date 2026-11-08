import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/plugins/source_capability.dart';
import 'file_sources.dart';
import 'media_server_sources.dart';
import 'source_config.dart';

class SourceSelection {
  const SourceSelection(this.name, this.stream);
  final String name;
  final PlayableStream stream;
}

/// Host owns persistence, credentials, instance routing and standardized errors.
/// UI never receives provider objects. Disposing the manager follows playback.
class SourceManager {
  SourceManager({FlutterSecureStorage? credentials})
    : _credentials =
          credentials ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );
  final FlutterSecureStorage _credentials;
  bool _hasBookmarks = false;
  final _retired = <Plugin>[];
  final _configs = <SourceConfig>[];
  final _providers = <String, SourceCapability>{};
  List<SourceConfig> get configs => List.unmodifiable(_configs);
  static const _key = 'source.instances.v1';
  static const _bookmarks = MethodChannel('openplayx/source_access');
  Future<void>? _loading;
  Future<void> load() => _loading ??= _load().catchError((Object error) {
    _loading = null;
    throw error;
  });
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final configs = (jsonDecode(raw) as List)
        .map((j) => SourceConfig.fromJson(j as Map<String, dynamic>))
        .toList();
    for (final config in configs) {
      config.validate();
    }
    _configs.addAll(configs);
  }

  Future<void> _persist() async {
    final ok = await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(_configs.map((c) => c.toJson()).toList()),
    );
    if (!ok) throw const PluginException('internalError', '媒体源保存失败。');
  }

  Future<void> save(SourceConfig config, String secret) async {
    config.validate();
    await load();
    final index = _configs.indexWhere((c) => c.id == config.id);
    final previous = index < 0 ? null : _configs[index];
    if (previous != null && previous.kind != config.kind) {
      throw const PluginException('invalidInput', '编辑时不能更改源类型。');
    }
    final oldSecret = previous == null || config.kind == SourceKind.local
        ? null
        : await _credentials.read(key: 'source.${config.id}');
    final effectiveSecret = previous != null && secret.isEmpty
        ? oldSecret ?? ''
        : secret;
    if (config.kind != SourceKind.local &&
        config.kind != SourceKind.smb &&
        effectiveSecret.isEmpty) {
      throw const PluginException('authRequired', '请填写访问令牌。');
    }
    var saved = config;
    if (Platform.isMacOS && config.kind == SourceKind.local) {
      final bookmark =
          previous?.address == config.address && config.bookmark != null
          ? config.bookmark
          : await _bookmarks.invokeMethod<String>('create', config.address);
      saved = SourceConfig(
        id: config.id,
        kind: config.kind,
        name: config.name,
        address: config.address,
        bookmark: bookmark,
      );
    }
    if (config.kind != SourceKind.local) {
      await _credentials.write(
        key: 'source.${config.id}',
        value: effectiveSecret,
      );
    }
    if (index < 0) {
      _configs.add(saved);
    } else {
      _configs[index] = saved;
    }
    try {
      await _persist();
    } catch (_) {
      _configs.remove(saved);
      if (previous != null) _configs.insert(index, previous);
      if (oldSecret == null) {
        await _credentials.delete(key: 'source.${config.id}');
      } else {
        await _credentials.write(key: 'source.${config.id}', value: oldSecret);
      }
      rethrow;
    }
    final provider = _providers.remove(config.id);
    if (provider is Plugin) _retired.add(provider as Plugin);
  }

  Future<void> remove(String id) async {
    final index = _configs.indexWhere((c) => c.id == id);
    if (index < 0) return;
    final config = _configs.removeAt(index);
    try {
      await _persist();
    } catch (_) {
      _configs.insert(index, config);
      rethrow;
    }
    final provider = _providers.remove(id);
    if (provider is Plugin) _retired.add(provider as Plugin);
    await _credentials.delete(key: 'source.$id');
  }

  Future<SourceCapability> _provider(String id) async {
    final existing = _providers[id];
    if (existing != null) return existing;
    final matches = _configs.where((c) => c.id == id);
    if (matches.isEmpty) throw const PluginException('notFound', '媒体源已删除。');
    var config = matches.single;
    if (Platform.isMacOS &&
        config.kind == SourceKind.local &&
        config.bookmark != null) {
      final path = await _bookmarks.invokeMethod<String>(
        'restore',
        config.bookmark,
      );
      if (path == null) {
        throw const PluginException('permissionDenied', '请重新选择本地文件夹以恢复授权。');
      }
      _hasBookmarks = true;
      config = SourceConfig(
        id: config.id,
        kind: config.kind,
        name: config.name,
        address: path,
      );
    }
    final secret = config.kind == SourceKind.local
        ? ''
        : await _credentials.read(key: 'source.$id') ?? '';
    final provider = switch (config.kind) {
      SourceKind.local => LocalFolderPlugin(config),
      SourceKind.smb => SmbPlugin(config, secret),
      SourceKind.plex => PlexPlugin(config, SourceHttp(config, secret)),
      SourceKind.jellyfin => JellyfinPlugin(config, SourceHttp(config, secret)),
    };
    _providers[id] = provider as SourceCapability;
    return provider;
  }

  Future<T> _call<T>(
    Future<T> Function() call, {
    Future<void> Function(T)? releaseLate,
  }) async {
    try {
      var expired = false;
      final pending = call().then((value) async {
        if (expired) await releaseLate?.call(value);
        return value;
      });
      return await pending.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          expired = true;
          throw TimeoutException('Source call timed out');
        },
      );
    } on PluginException {
      rethrow;
    } on TimeoutException {
      throw const PluginException(
        'timeout',
        '连接超时，请检查媒体源后重试。',
        retryable: true,
      );
    } catch (_) {
      throw const PluginException(
        'networkUnavailable',
        '无法访问媒体源，请检查地址、权限和凭据。',
        retryable: true,
      );
    }
  }

  Future<BrowseResult> browse(String id, BrowseRequest request) =>
      _call(() async {
        if (request.offset < 0 || request.limit < 1 || request.limit > 200) {
          throw const PluginException('invalidInput', '无效的分页参数。');
        }
        return (await _provider(id))
            .browse(request, CallContext.forInstance(id));
      });
  Future<PlayableStream> resolve(ResourceRef resource) => _call(
    () async => (await _provider(resource.instanceId)).resolve(
      ResolveRequest(resource),
      CallContext.forInstance(resource.instanceId),
    ),
    releaseLate: (stream) => stream.release(),
  );
  Future<void> dispose() async {
    for (final provider in _providers.values) {
      await (provider as Plugin).dispose();
    }
    _providers.clear();
    for (final provider in _retired) {
      await provider.dispose();
    }
    _retired.clear();
    if (_hasBookmarks) {
      await _bookmarks.invokeMethod<void>('releaseAll');
      _hasBookmarks = false;
    }
  }
}
