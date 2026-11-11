import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/plugins/source_capability.dart';
import '../configuration/source_configuration_service.dart';
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
///
/// Secrets live in the configuration SQLite database. Entries written by older
/// versions sit in the macOS keychain; they are copied over the first time they
/// are needed (one last keychain prompt per source) and then removed from it.
class SourceCredentialBroker {
  SourceCredentialBroker(this._service, [FlutterSecureStorage? legacyKeychain])
    : _legacy =
          legacyKeychain ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );
  final SourceConfigurationService Function() _service;
  final FlutterSecureStorage _legacy;
  void _check(String id, String ref) {
    if (ref != 'source.$id' && !ref.startsWith('source.$id.')) {
      throw const PluginException('permissionDenied', '凭据不属于此实例。');
    }
  }

  Future<String?> readForHost(SourceConfig config) async {
    final ref = config.credentialRef;
    if (ref == null) return null;
    _check(config.id, ref);
    final stored = _service().readSecret(ref);
    if (stored != null) return stored;
    return _migrateLegacy(ref);
  }

  Future<String?> _migrateLegacy(String ref) async {
    String? secret;
    try {
      secret = await _legacy.read(key: ref);
    } catch (_) {
      return null; // No keychain, or the user declined: treat as missing.
    }
    if (secret == null) return null;
    _service().writeSecret(ref, secret);
    try {
      await _legacy.delete(key: ref);
    } catch (_) {} // The copy is saved; a leftover keychain item is harmless.
    return secret;
  }

  Future<String> stage(String instanceId, String secret) async {
    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final ref = 'source.$instanceId.$suffix';
    _service().writeSecret(ref, secret);
    return ref;
  }

  Future<void> delete(String instanceId, String? ref) async {
    if (ref == null) return;
    _check(instanceId, ref);
    _service().deleteSecret(ref);
  }

  /// Display saved metadata without unlocking the keychain. The secret is
  /// checked only when the host actually opens a connection.
  SourceCredentialStatus status(
    SourceConfig config, {
    bool verified = false,
    bool rejected = false,
  }) {
    if (config.kind == SourceKind.local ||
        config.kind == SourceKind.dlna ||
        ((config.kind.optionalCredential || config.kind == SourceKind.sftp) &&
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
