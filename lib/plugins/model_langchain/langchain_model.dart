import 'dart:convert';

import 'package:langchain_core/chat_models.dart';
import 'package:langchain_core/prompts.dart';
import 'package:langchain_core/tools.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:openai_dart/openai_dart.dart'
    show
        ApiException,
        ConnectionException,
        ParseException,
        RequestTimeoutException;

import '../../core/models/text_model.dart';

/// One client per request so cancellation also closes the HTTP transport.
class LangChainModel implements TextModelCapability {
  LangChainModel({
    required this.apiKey,
    required this.endpoint,
    required this.model,
    this.maxTokens = 2048,
    this.streaming = true,
  });
  final String apiKey;
  final String endpoint;
  final String model;
  final int maxTokens;
  final bool streaming;

  @override
  Stream<ModelDelta> infer(ModelInferenceRequest request) async* {
    final client = ChatOpenAI(
      apiKey: apiKey,
      baseUrl: endpoint,
      defaultOptions: ChatOpenAIOptions(model: model, maxTokens: maxTokens),
    );
    try {
      ChatResult? merged;
      var receivedCharacters = 0;
      final prompt = PromptValue.chat(request.messages.map(_message).toList());
      final options = ChatOpenAIOptions(
        tools: request.tools.isEmpty
            ? null
            : [
                for (final tool in request.tools)
                  ToolSpec(
                    name: tool.name,
                    description: tool.description,
                    inputJsonSchema: tool.schema,
                  ),
              ],
      );
      final results = streaming
          ? client.stream(prompt, options: options)
          : Stream.fromFuture(client.invoke(prompt, options: options));
      await for (final chunk in results) {
        receivedCharacters +=
            chunk.outputAsString.length +
            chunk.output.toolCalls.fold<int>(
              0,
              (sum, call) => sum + call.argumentsRaw.length,
            );
        if (receivedCharacters > 64000) throw const ModelFailure('outputLimit');
        merged = merged?.concat(chunk) ?? chunk;
        for (final call in chunk.output.toolCalls) {
          yield ModelToolFragment(
            call.index,
            call.id,
            call.name,
            call.argumentsRaw,
          );
        }
        if (chunk.outputAsString.isNotEmpty) {
          yield ModelTextDelta(chunk.outputAsString);
        }
      }
      if (merged == null) throw const ModelFailure('emptyResponse');
      // Never execute truncated calls (length, content filter, broken stream).
      final reason = merged.finishReason.name;
      if (merged.output.toolCalls.isNotEmpty && reason != 'toolCalls') {
        throw const ModelFailure('incompleteToolCall');
      }
      if (reason != 'stop' && reason != 'toolCalls') {
        throw const ModelFailure('incompleteResponse');
      }
      for (final call in merged.output.toolCalls) {
        yield ModelToolDelta(
          ModelToolCall(call.id, call.name, call.argumentsRaw),
        );
      }
      yield ModelCompleted(reason, totalTokens: merged.usage.totalTokens);
    } on ModelFailure {
      rethrow;
    } on ApiException catch (error) {
      throw ModelFailure(switch (error.statusCode) {
        401 => 'authenticationFailed',
        403 => 'permissionDenied',
        429 => 'rateLimited',
        400 || 404 || 422 => 'protocolMismatch',
        _ => 'providerUnavailable',
      });
    } on ConnectionException {
      throw const ModelFailure('networkUnavailable');
    } on RequestTimeoutException {
      throw const ModelFailure('requestTimeout');
    } on ParseException {
      throw const ModelFailure('protocolMismatch');
    } catch (_) {
      // SDK exception strings can contain request URLs/headers. Keep them out
      // of conversation history and UI, including connection tests.
      throw const ModelFailure('providerRequestFailed');
    } finally {
      client.close();
    }
  }

  ChatMessage _message(ModelMessage message) => switch (message.role) {
    'system' => ChatMessage.system(message.text),
    'user' => ChatMessage.humanText(message.text),
    'tool' => ChatMessage.tool(
      toolCallId: message.callId!,
      content: message.text,
    ),
    _ => ChatMessage.aiText(
      message.text,
      toolCalls: [
        for (final call in message.calls)
          AIChatMessageToolCall(
            id: call.id,
            name: call.name,
            argumentsRaw: call.arguments,
            arguments: _arguments(call.arguments),
          ),
      ],
    ),
  };
  Map<String, dynamic> _arguments(String raw) {
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }
}
