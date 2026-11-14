/// A deliberately small JSON Schema subset for external (MCP) tool inputs.
///
/// [unsupported] names the first keyword outside the subset, so a tool whose
/// schema the host cannot fully check is reported and left unregistered
/// instead of being registered with parts of its contract dropped.
abstract final class JsonSchemaLite {
  static const _types = {
    'object',
    'string',
    'integer',
    'number',
    'boolean',
    'array',
    'null',
  };

  /// Keywords that only describe, never constrain.
  static const _annotations = {
    'title',
    'description',
    'default',
    'examples',
    r'$schema',
    r'$comment',
    'deprecated',
    'readOnly',
    'writeOnly',
  };

  static const _keywords = {
    'type',
    'properties',
    'required',
    'additionalProperties',
    'enum',
    'const',
    'minimum',
    'maximum',
    'exclusiveMinimum',
    'exclusiveMaximum',
    'minLength',
    'maxLength',
    'pattern',
    'format',
    'items',
    'minItems',
    'maxItems',
  };

  /// Null when the whole schema is within the subset; otherwise a short
  /// reason such as `unsupported keyword: oneOf`.
  static String? unsupported(Object? schema, {int depth = 0}) {
    if (depth > 8) return 'schema too deep';
    if (schema is! Map) return 'schema is not an object';
    for (final key in schema.keys) {
      if (_annotations.contains(key)) continue;
      if (!_keywords.contains(key)) return 'unsupported keyword: $key';
    }
    final type = schema['type'];
    if (type != null) {
      final types = type is List ? type : [type];
      if (types.isEmpty || types.any((t) => !_types.contains(t))) {
        return 'unsupported type: $type';
      }
    }
    final pattern = schema['pattern'];
    if (pattern != null) {
      if (pattern is! String) return 'invalid pattern';
      try {
        RegExp(pattern);
      } catch (_) {
        return 'invalid pattern';
      }
    }
    final props = schema['properties'];
    if (props != null) {
      if (props is! Map) return 'invalid properties';
      for (final p in props.values) {
        final r = unsupported(p, depth: depth + 1);
        if (r != null) return r;
      }
    }
    final additional = schema['additionalProperties'];
    if (additional != null && additional is! bool) {
      final r = unsupported(additional, depth: depth + 1);
      if (r != null) return r;
    }
    final items = schema['items'];
    if (items != null) {
      final r = unsupported(items, depth: depth + 1);
      if (r != null) return r;
    }
    final required = schema['required'];
    if (required != null &&
        (required is! List || required.any((r) => r is! String))) {
      return 'invalid required';
    }
    return null;
  }

  static bool _isType(Object? value, String type) => switch (type) {
    'object' => value is Map,
    'array' => value is List,
    'string' => value is String,
    'boolean' => value is bool,
    'null' => value == null,
    'integer' => value is int || (value is double && value == value.truncate()),
    'number' => value is num && value.isFinite,
    _ => false,
  };

  /// Validates [value] against a schema accepted by [unsupported].
  static bool valid(Map schema, Object? value) {
    final type = schema['type'];
    if (type != null) {
      final types = type is List ? type : [type];
      if (!types.any((t) => _isType(value, t as String))) return false;
    }
    if (schema.containsKey('const') && schema['const'] != value) return false;
    final values = schema['enum'];
    if (values is List && !values.contains(value)) return false;
    if (value is num) {
      final min = schema['minimum'], max = schema['maximum'];
      final xmin = schema['exclusiveMinimum'],
          xmax = schema['exclusiveMaximum'];
      if (min is num && value < min) return false;
      if (max is num && value > max) return false;
      if (xmin is num && value <= xmin) return false;
      if (xmax is num && value >= xmax) return false;
    }
    if (value is String) {
      final min = schema['minLength'], max = schema['maxLength'];
      if (min is int && value.length < min) return false;
      if (max is int && value.length > max) return false;
      final pattern = schema['pattern'];
      if (pattern is String && !RegExp(pattern).hasMatch(value)) return false;
    }
    if (value is List) {
      final min = schema['minItems'], max = schema['maxItems'];
      if (min is int && value.length < min) return false;
      if (max is int && value.length > max) return false;
      final items = schema['items'];
      if (items is Map && value.any((v) => !valid(items, v))) return false;
    }
    if (value is Map) {
      final props = schema['properties'] is Map
          ? schema['properties'] as Map
          : const {};
      final required = schema['required'] is List
          ? schema['required'] as List
          : const [];
      if (required.any((k) => !value.containsKey(k))) return false;
      final additional = schema['additionalProperties'];
      for (final entry in value.entries) {
        final sub = props[entry.key];
        if (sub is Map) {
          if (!valid(sub, entry.value)) return false;
        } else if (additional == false) {
          return false;
        } else if (additional is Map && !valid(additional, entry.value)) {
          return false;
        }
      }
    }
    return true;
  }
}
