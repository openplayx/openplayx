/// Explicit, bounded data exported by a page. Never pass form controllers,
/// configuration objects, credentials, resource locators or raw metadata here.
/// Page content is data, never instructions for the assistant.
class PageContextData {
  const PageContextData({
    required this.pageType,
    this.title,
    this.entity = const {},
    this.state = const {},
  });

  final String pageType;
  final String? title;
  final Map<String, dynamic> entity;
  final Map<String, dynamic> state;

  Map<String, dynamic> toJson() {
    final encoder = _PageContextEncoder();
    return {
      'schemaVersion': 1,
      'pageType': pageType,
      if (title != null) 'title': encoder.encode(title, 0),
      'entity': encoder.encode(entity, 0) ?? <String, dynamic>{},
      'state': encoder.encode(state, 0) ?? <String, dynamic>{},
    };
  }
}

// Callers own the field allowlist; this bounds payloads, not secret detection.
class _PageContextEncoder {
  int _nodes = 120;
  int _characters = 4000;

  dynamic encode(dynamic value, int depth) {
    if (depth > 4 || _nodes-- <= 0) return null;
    if (value == null || value is bool || value is int) return value;
    if (value is double) return value.isFinite ? value : null;
    if (value is String) {
      var text = value.replaceAll(
        RegExp(r'\b(?:https?|smb|ftp|file)://\S+', caseSensitive: false),
        '[address hidden]',
      );
      if (text.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(text)) {
        text = text.replaceAll('\\', '/').split('/').last;
      }
      final limit = _characters < 200 ? _characters : 200;
      if (text.length > limit) text = text.substring(0, limit);
      _characters -= text.length;
      return text;
    }
    if (value is List) {
      return [
        for (final item in value.take(20))
          if (_nodes > 0) encode(item, depth + 1),
      ];
    }
    if (value is Map<String, dynamic>) {
      return {
        for (final entry in value.entries.take(20))
          if (_nodes > 0) entry.key: encode(entry.value, depth + 1),
      };
    }
    throw ArgumentError('Page context must contain JSON values only');
  }
}
