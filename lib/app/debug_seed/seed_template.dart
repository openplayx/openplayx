// Pure Dart (no Flutter imports): shared by the App and by
// tool/debug_seed.dart, which runs with plain `dart run`.

/// Parses a `.env` file: `KEY=VALUE` lines, `#` comments, optional
/// `export ` prefix and optional single or double quotes around the value.
Map<String, String> parseEnv(String text) {
  final result = <String, String>{};
  for (var line in text.split(RegExp(r'\r?\n'))) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring(7).trimLeft();
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final key = line.substring(0, eq).trim();
    var value = line.substring(eq + 1).trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      // Double quotes understand \" \\ and \n, as in common .env loaders.
      value = value
          .substring(1, value.length - 1)
          .replaceAllMapped(
            RegExp(r'\\(["\\n])'),
            (m) => m[1] == 'n' ? '\n' : m[1]!,
          );
    } else if (value.length >= 2 &&
        value.startsWith("'") &&
        value.endsWith("'")) {
      value = value.substring(1, value.length - 1);
    }
    result[key] = value;
  }
  return result;
}

class MissingSeedVariables implements Exception {
  const MissingSeedVariables(this.names);
  final List<String> names;
  @override
  String toString() => '.env is missing: ${names.join(', ')}';
}

final _variable = RegExp(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}');

/// Replaces `${NAME}` inside every string of the decoded seed [template]
/// with [env]`[NAME]`. Throws [MissingSeedVariables] naming every variable
/// [env] lacks. Values are substituted after JSON decoding, so they need no
/// escaping.
Object? resolveSeed(Object? template, Map<String, String> env) {
  final missing = <String>{};
  Object? walk(Object? node) => switch (node) {
    String s => s.replaceAllMapped(_variable, (m) {
      final value = env[m[1]!];
      if (value == null) missing.add(m[1]!);
      return value ?? '';
    }),
    List l => [for (final item in l) walk(item)],
    Map m => {for (final e in m.entries) e.key: walk(e.value)},
    _ => node,
  };
  final resolved = walk(template);
  if (missing.isNotEmpty) {
    throw MissingSeedVariables(missing.toList()..sort());
  }
  return resolved;
}
