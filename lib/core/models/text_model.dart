/// Provider-neutral protocol. SDK types never cross this boundary.
class ModelTool {
  const ModelTool(this.name, this.description, this.schema);
  final String name;
  final String description;
  final Map<String, dynamic> schema;
}

class ModelToolCall {
  const ModelToolCall(this.id, this.name, this.arguments);
  final String id;
  final String name;
  final String arguments;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'arguments': arguments,
  };
  factory ModelToolCall.fromJson(Map<String, dynamic> json) => ModelToolCall(
    json['id'] as String,
    json['name'] as String,
    json['arguments'] as String,
  );
}

class ModelMessage {
  const ModelMessage(
    this.role,
    this.text, {
    this.calls = const [],
    this.callId,
    this.id,
    this.reasoning = '',
  });
  final String? id;
  final String role;
  final String text;
  final List<ModelToolCall> calls;
  final String? callId;

  /// The model's visible reasoning for this reply, kept for display only;
  /// adapters never send it back to a model.
  final String reasoning;
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'role': role,
    'text': text,
    'calls': calls.map((c) => c.toJson()).toList(),
    if (callId != null) 'callId': callId,
    if (reasoning.isNotEmpty) 'reasoning': reasoning,
  };
  factory ModelMessage.fromJson(Map<String, dynamic> json) => ModelMessage(
    json['role'] as String,
    json['text'] as String,
    calls: (json['calls'] as List? ?? [])
        .map((c) => ModelToolCall.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList(),
    callId: json['callId'] as String?,
    id: json['id'] as String?,
    reasoning: json['reasoning'] as String? ?? '',
  );
}

class ModelInferenceRequest {
  const ModelInferenceRequest(this.messages, {this.tools = const []});
  final List<ModelMessage> messages;
  final List<ModelTool> tools;
}

sealed class ModelDelta {
  const ModelDelta();
}

class ModelTextDelta extends ModelDelta {
  const ModelTextDelta(this.text);
  final String text;
}

/// Reasoning ("thinking") text a provider streams before its answer, such as
/// `reasoning_content`. Display only; never executed or sent back.
class ModelReasoningDelta extends ModelDelta {
  const ModelReasoningDelta(this.text);
  final String text;
}

/// A non-executable piece of a streaming call. IDs/names may be absent on later chunks.
class ModelToolFragment extends ModelDelta {
  const ModelToolFragment(this.index, this.id, this.name, this.arguments);
  final int? index;
  final String id;
  final String name;
  final String arguments;
}

class ModelToolDelta extends ModelDelta {
  const ModelToolDelta(this.call);

  /// Emitted only when the complete stream has assembled this call.
  final ModelToolCall call;
}

class ModelCompleted extends ModelDelta {
  const ModelCompleted(this.reason, {this.totalTokens});
  final String reason;
  final int? totalTokens;
}

abstract interface class TextModelCapability {
  Stream<ModelDelta> infer(ModelInferenceRequest request);
}

class ModelFailure implements Exception {
  const ModelFailure(this.code);
  final String code;
}
