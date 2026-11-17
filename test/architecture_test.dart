import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Layers of `lib/`, lowest first. A layer may import itself and the layers
/// listed for it; `app/` (composition) and `main.dart` may import anything.
///
///   core          interfaces and plain models
///   data          storage, repositories, source connectors, diagnostics
///   capabilities  shared abilities of the App and the AI (sources, library,
///                 metadata, media processing, speech, artwork…); they know
///                 nothing about the AI or its plugins
///   assistant     the AI: model access, conversations, plugins (AI wrappers
///                 around capabilities, their tools and AI permissions)
///   ui            design system: tokens, theme, shared widgets
///   features      screens, each split into model / controller / view
const _allowed = <String, Set<String>>{
  'l10n': {},
  'core': {'l10n'},
  'data': {'core', 'l10n'},
  'capabilities': {'core', 'data', 'l10n'},
  'assistant': {'core', 'data', 'capabilities', 'l10n'},
  'ui': {'core', 'l10n'},
  'features': {'core', 'data', 'capabilities', 'assistant', 'ui', 'l10n'},
};

/// Extra rules inside a layer: (importer prefix, forbidden target prefix,
/// reason).
const _forbidden = [
  (
    'capabilities/sources/',
    'capabilities/library/',
    'sources do not know the library; the library refers to sources',
  ),
];

/// Known violations being removed; delete an entry once it is fixed. A
/// listed import that no longer exists fails the test, so the list only
/// shrinks.
const _pending = <String>{};

final _directive = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

/// `importer -> target` for every in-package import under lib/.
Iterable<(String, String)> _imports() sync* {
  final lib = Directory('lib');
  for (final file in lib.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final from = file.path.substring('lib/'.length).replaceAll(r'\', '/');
    for (final match in _directive.allMatches(file.readAsStringSync())) {
      final uri = match.group(1)!;
      String target;
      if (uri.startsWith('package:openplayx/')) {
        target = uri.substring('package:openplayx/'.length);
      } else if (uri.startsWith('dart:') || uri.startsWith('package:')) {
        continue;
      } else {
        target = Uri.parse(from).resolve(uri).path;
      }
      yield (from, target);
    }
  }
}

void main() {
  test('every lib/ file belongs to a known layer', () {
    final unknown = {
      for (final (from, _) in _imports())
        if (!_allowed.containsKey(from.split('/').first) &&
            from.split('/').first != 'app' &&
            from != 'main.dart')
          from,
    };
    expect(unknown, isEmpty);
  });

  test('imports only point down the layers', () {
    final violations = <String>{};
    for (final (from, target) in _imports()) {
      final layer = from.split('/').first;
      final allowed = _allowed[layer];
      if (allowed == null) continue; // app/ and main.dart
      final targetLayer = target.split('/').first;
      final reasons = [
        if (targetLayer != layer && !allowed.contains(targetLayer))
          '$layer may not import $targetLayer',
        for (final (prefix, forbidden, reason) in _forbidden)
          if (from.startsWith(prefix) && target.startsWith(forbidden)) reason,
      ];
      if (reasons.isNotEmpty) violations.add('$from -> $target');
    }
    expect(
      violations.difference(_pending),
      isEmpty,
      reason: 'new imports against the layering',
    );
    expect(
      _pending.difference(violations),
      isEmpty,
      reason: 'fixed: remove these from _pending',
    );
  });
}
