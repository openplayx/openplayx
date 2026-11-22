const tmdbTokenKey = 'tmdbToken';
const tmdbModeKey = 'tmdbMode';

/// Existing credentials keep using TMDB directly; new installations use cloud.
class TmdbConfig {
  TmdbConfig.fromSettings(String Function(String) read)
    : token = read(tmdbTokenKey).trim(),
      usePlatform = switch (read(tmdbModeKey)) {
        'cloud' => true,
        'local' => false,
        _ => read(tmdbTokenKey).trim().isEmpty,
      };

  final String token;
  final bool usePlatform;
  bool get configured => usePlatform || token.isNotEmpty;
}
