import 'source_configuration_service.dart';
import 'source_secure_store.dart';

import 'dart:math';

import '../sources/source_config.dart';
import '../../l10n/l10n.dart';

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
    SourceAuthorization.notRequired => appStrings.credNotRequired,
    SourceAuthorization.missing => appStrings.credMissing,
    SourceAuthorization.configured => appStrings.credConfigured,
    SourceAuthorization.expiring => appStrings.credExpiring,
    SourceAuthorization.expired => appStrings.credExpired,
    SourceAuthorization.rejected => appStrings.credRejected,
    SourceAuthorization.verified => appStrings.credVerified,
  };
}

/// Only the host receives this object. Every reference is scoped to its instance;
/// rotation writes a fresh key before committing the new reference to SQLite.
///
/// Cloud credentials and branded WebDAV passwords use OS storage; their
/// configuration row contains an opaque scoped reference. Legacy sources retain
/// their existing row storage.
class SourceCredentialBroker {
  SourceCredentialBroker(this._service, {SourceSecureStore? secureStore})
    : secureStore = secureStore ?? const SystemSourceSecureStore();
  final SourceSecureStore secureStore;
  static const securePrefix = "secure-source:";
  final SourceConfigurationService Function() _service;
  Future<String?> readForHost(SourceConfig config) async {
    if (!config.hasSecret) return null;
    final value = _service().readSecret(config.id);
    if (value == null || !value.startsWith(securePrefix)) return value;
    if (!_owns(config.id, value)) return null;
    return secureStore.read(value);
  }

  Future<String> stage(String id, String secret) async {
    final nonce = List.generate(
      24,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final key = '$securePrefix${Uri.encodeComponent(id)}:$nonce';
    await secureStore.write(key, secret);
    return key;
  }

  bool _owns(String id, String key) {
    final prefix = '$securePrefix${Uri.encodeComponent(id)}:';
    return key.startsWith(prefix) &&
        RegExp(r'^[0-9a-f]{48}$').hasMatch(key.substring(prefix.length));
  }

  Future<void> discard(String? key, {required String instanceId}) async {
    if (key != null && _owns(instanceId, key)) await secureStore.delete(key);
  }

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
    if (!config.kind.oauth &&
        expiry != null &&
        !expiry.isAfter(DateTime.now())) {
      return SourceCredentialStatus(
        SourceAuthorization.expired,
        expiresAt: expiry,
      );
    }
    if (!config.kind.oauth &&
        expiry != null &&
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
