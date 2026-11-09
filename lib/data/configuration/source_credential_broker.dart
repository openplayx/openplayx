import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/plugins/source_capability.dart';
import '../sources/source_config.dart';

enum SourceAuthorization {
  notRequired,
  missing,
  configured,
  expiring,
  expired,
  rejected,
  verified,
}

class SourceCredentialStatus {
  const SourceCredentialStatus(this.authorization, {this.expiresAt});
  final SourceAuthorization authorization;
  final DateTime? expiresAt;
  String get label => switch (authorization) {
    SourceAuthorization.notRequired => '无需账号凭据',
    SourceAuthorization.missing => '缺少凭据',
    SourceAuthorization.configured => '凭据已保存 · 尚未验证',
    SourceAuthorization.expiring => '令牌将在 7 天内到期',
    SourceAuthorization.expired => '令牌已到期',
    SourceAuthorization.rejected => '认证失败 · 请更新凭据',
    SourceAuthorization.verified => '连接已验证',
  };
}

/// Only the host receives this object. Every reference is scoped to its instance;
/// rotation writes a fresh key before committing the new reference to SQLite.
class SourceCredentialBroker {
  SourceCredentialBroker([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );
  final FlutterSecureStorage _storage;
  void _check(String id, String ref) {
    if (ref != 'source.$id' && !ref.startsWith('source.$id.')) {
      throw const PluginException('permissionDenied', '凭据不属于此实例。');
    }
  }

  Future<String?> readForHost(SourceConfig config) async {
    final ref = config.credentialRef;
    if (ref == null) return null;
    _check(config.id, ref);
    return _storage.read(key: ref);
  }

  Future<String> stage(String instanceId, String secret) async {
    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final ref = 'source.$instanceId.$suffix';
    await _storage.write(key: ref, value: secret);
    return ref;
  }

  Future<void> delete(String instanceId, String? ref) async {
    if (ref == null) return;
    _check(instanceId, ref);
    await _storage.delete(key: ref);
  }

  /// Display saved metadata without unlocking the keychain. The secret is
  /// checked only when the host actually opens a connection.
  SourceCredentialStatus status(
    SourceConfig config, {
    bool verified = false,
    bool rejected = false,
  }) {
    if (config.kind == SourceKind.local ||
        (config.kind == SourceKind.smb &&
            config.username.isEmpty &&
            config.credentialRef == null)) {
      return const SourceCredentialStatus(SourceAuthorization.notRequired);
    }
    final ref = config.credentialRef;
    if (ref == null) {
      return const SourceCredentialStatus(SourceAuthorization.missing);
    }
    _check(config.id, ref);
    final expiry = config.credentialExpiresAt;
    if (expiry != null && !expiry.isAfter(DateTime.now())) {
      return SourceCredentialStatus(
        SourceAuthorization.expired,
        expiresAt: expiry,
      );
    }
    if (expiry != null &&
        expiry.difference(DateTime.now()) <= const Duration(days: 7)) {
      return SourceCredentialStatus(
        SourceAuthorization.expiring,
        expiresAt: expiry,
      );
    }
    return SourceCredentialStatus(
      rejected
          ? SourceAuthorization.rejected
          : verified
          ? SourceAuthorization.verified
          : SourceAuthorization.configured,
      expiresAt: expiry,
    );
  }
}
