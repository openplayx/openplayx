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
/// Each instance's secret is kept on its own configuration row.
class SourceCredentialBroker {
  SourceCredentialBroker(this._service);
  final SourceConfigurationService Function() _service;
  Future<String?> readForHost(SourceConfig config) async =>
      config.hasSecret ? _service().readSecret(config.id) : null;

  /// Display saved metadata without reading the secret. The secret is
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
            !config.hasSecret)) {
      return const SourceCredentialStatus(SourceAuthorization.notRequired);
    }
    if (!config.hasSecret) {
      return const SourceCredentialStatus(SourceAuthorization.missing);
    }
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
