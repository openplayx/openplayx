import 'dart:async';
import 'dart:convert';

import '../../core/models/text_model.dart';

/// Checks a model connection: a plain reply must work; tool calls are
/// optional (without them the assistant only chats).
abstract final class ModelProbe {
  /// Whether [model] answers a plain request. Throws [ModelFailure] or
  /// [TimeoutException] when it cannot be reached.
  static Future<bool> replies(TextModelCapability model) =>
      _probe(model, tools: false);

  /// Whether [model] calls a tool as asked; false on any failure.
  static Future<bool> callsTools(TextModelCapability model) async {
    try {
      return await _probe(model, tools: true);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _probe(
    TextModelCapability model, {
    required bool tools,
  }) async {
    final request = ModelInferenceRequest(
      [
        ModelMessage(
          'user',
          tools
              ? 'Call connection_probe with value ok. This is a protocol test.'
              : 'Reply with OK.',
        ),
      ],
      tools: tools
          ? [
              const ModelTool(
                'connection_probe',
                'Protocol test with no business effects.',
                {
                  'type': 'object',
                  'properties': {
                    'value': {
                      'type': 'string',
                      'enum': ['ok'],
                    },
                  },
                  'required': ['value'],
                  'additionalProperties': false,
                },
              ),
            ]
          : [],
    );
    var text = false, tool = false, complete = false;
    await for (final event
        in model.infer(request).timeout(const Duration(seconds: 30))) {
      if (event is ModelTextDelta && event.text.trim().isNotEmpty) text = true;
      if (event is ModelCompleted) complete = true;
      if (event is ModelToolDelta) {
        final args = jsonDecode(event.call.arguments);
        tool =
            event.call.name == 'connection_probe' &&
            args is Map &&
            args['value'] == 'ok';
      }
    }
    return complete && (tools ? tool : text);
  }
}
