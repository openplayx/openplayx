import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const tmdbTokenKey = 'openplayx.metadata.tmdb.token';

/// Same macOS keychain mode as the other credential stores: the data-protection
/// keychain needs a signing team, which local/ad-hoc builds do not have.
const tmdbCredentialStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);
