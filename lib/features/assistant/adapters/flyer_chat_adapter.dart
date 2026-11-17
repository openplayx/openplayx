import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as flyer;

import '../../../assistant/conversation/conversation_coordinator.dart';
import '../model/ai_chat_part.dart';
import 'stream_text_smoother.dart';

/// A per-view projection. ConversationCoordinator remains the sole authority.
class FlyerChatAdapter {
  FlyerChatAdapter(this.coordinator, {bool smooth = false}) {
    if (smooth) _smoother = StreamTextSmoother(_sync);
    _sync();
    coordinator.addListener(_schedule);
  }
  final ConversationCoordinator coordinator;
  final chat = flyer.InMemoryChatController();
  final parts = <String, AiChatPart>{};

  /// Bumped after every projection, including per-frame text reveals.
  final version = ValueNotifier<int>(0);
  StreamTextSmoother? _smoother;
  String _text(String id, String text, {required bool live}) =>
      _smoother?.view(id, text, live: live) ?? text;
  bool _revealing(String id) => _smoother?.revealing(id) ?? false;
  bool _disposed = false;
  String? _conversation;
  // The coordinator coalesces text deltas at 40ms and flushes terminal events.
  // Project each notification directly, without adding a second latency window.
  void _schedule() => _sync();

  // When each reply's reasoning was first seen streaming and when the reply
  // moved on to text or a tool call. Only measured live; history has none.
  final _thinkStart = <String, DateTime>{}, _thinkEnd = <String, DateTime>{};
  Duration? _thought(String id, {required bool live, required bool done}) {
    final now = DateTime.now();
    final start = live
        ? _thinkStart.putIfAbsent(id, () => now)
        : _thinkStart[id];
    if (start == null) return null;
    if (done) _thinkEnd.putIfAbsent(id, () => now);
    final end = _thinkEnd[id];
    return end?.difference(start);
  }

  List<AiChatPart> project() {
    final items = <AiChatPart>[];
    for (final turn in coordinator.turns) {
      for (
        var messageIndex = 0;
        messageIndex < turn.messages.length;
        messageIndex++
      ) {
        final message = turn.messages[messageIndex];
        // A model may reuse a call ID in a later round. Scope results to the
        // assistant message that issued the call, using host message identities.
        final results = {
          for (final m
              in turn.messages
                  .skip(messageIndex + 1)
                  .takeWhile((m) => m.role == 'tool'))
            m.callId: m,
        };
        if (message.role != 'user' && message.role != 'assistant') continue;
        if (message.reasoning.isNotEmpty) {
          items.add(
            AiChatPart(
              id: '${message.id}:reasoning',
              turn: turn,
              kind: AiPartKind.reasoning,
              text: _text(
                '${message.id}:reasoning',
                message.reasoning,
                live: false,
              ),
              duration: _thought(
                '${message.id}:reasoning',
                live: false,
                done: true,
              ),
            ),
          );
        }
        if (message.text.isNotEmpty) {
          final user = message.role == 'user';
          // A finished reply keeps its streaming id, so a reveal still in
          // progress carries on instead of jumping to the end.
          final text = user
              ? message.text
              : _text(message.id!, message.text, live: false);
          items.add(
            AiChatPart(
              id: message.id!,
              turn: turn,
              kind: AiPartKind.text,
              text: text,
              isUser: user,
              streaming: !user && _revealing(message.id!),
            ),
          );
        }
        for (final call in message.calls) {
          final result = results[call.id];
          Map<String, dynamic> value = const {};
          Map<String, dynamic> arguments = const {};
          try {
            arguments = Map<String, dynamic>.from(
              jsonDecode(call.arguments) as Map,
            );
          } catch (_) {}
          if (result != null) {
            try {
              value = jsonDecode(result.text) as Map<String, dynamic>;
            } catch (_) {}
          }
          final pending = coordinator.confirmation;
          final executionId = '${message.id}:execution:${call.id}';
          final waiting =
              pending?.id == executionId && pending?.turnId == turn.id;
          final active = identical(coordinator.currentTurn, turn);
          final phase = result != null
              ? switch (value['status']) {
                  'success' => AiToolPhase.success,
                  'cancelled' => AiToolPhase.cancelled,
                  _ => AiToolPhase.failed,
                }
              : waiting
              ? AiToolPhase.waiting
              : !active
              ? AiToolPhase.cancelled
              : turn.executingId == executionId
              ? AiToolPhase.running
              : AiToolPhase.preparing;
          items.add(
            AiChatPart(
              id: executionId,
              turn: turn,
              kind: AiPartKind.tool,
              tool: call.name,
              phase: phase,
              text: value['error_code'] as String? ?? '',
              data: value['data'] is Map
                  ? Map<String, dynamic>.from(value['data'] as Map)
                  : const {},
              arguments: arguments,
              rawArguments: call.arguments,
              rawResult: result?.text ?? '',
              progress: phase == AiToolPhase.running ? turn.toolProgress : null,
              confirmation: waiting ? pending : null,
            ),
          );
        }
      }
      if (turn.reasoning.isNotEmpty) {
        final id = '${turn.streamingMessageId}:reasoning';
        // Reasoning is over once the reply text or a tool call begins.
        final done = turn.streaming.isNotEmpty || turn.preparingTool != null;
        items.add(
          AiChatPart(
            id: id,
            turn: turn,
            kind: AiPartKind.reasoning,
            text: _text(id, turn.reasoning, live: !done),
            streaming: !done,
            duration: _thought(id, live: true, done: done),
          ),
        );
      }
      if (turn.streaming.isNotEmpty) {
        items.add(
          AiChatPart(
            id: turn.streamingMessageId!,
            turn: turn,
            kind: AiPartKind.text,
            text: _text(turn.streamingMessageId!, turn.streaming, live: true),
            streaming: true,
          ),
        );
      }
      // Always say the turn is still running, whatever step it is in.
      if (identical(coordinator.currentTurn, turn) && turn.activity != null) {
        items.add(
          AiChatPart(
            id: '${turn.id}:activity',
            turn: turn,
            kind: AiPartKind.activity,
            text: turn.activity!,
            tool: turn.activity == 'tool' || turn.activity == 'confirm'
                ? turn.executingTool
                : turn.preparingTool,
            data: {'step': turn.step},
          ),
        );
      }
      if (turn.error != null || turn.status == 'interrupted') {
        items.add(
          AiChatPart(
            id: '${turn.id}:error',
            turn: turn,
            kind: AiPartKind.error,
            text: turn.error ?? 'interrupted',
          ),
        );
      }
    }
    return items;
  }

  void _sync() {
    if (_disposed) return;
    if (_conversation != coordinator.conversationId) _smoother?.reset();
    final projected = project();
    parts
      ..clear()
      ..addEntries(projected.map((p) => MapEntry(p.id, p)));
    final messages = projected
        .map(
          (p) => flyer.Message.custom(
            id: p.id,
            authorId: p.isUser ? 'user' : 'assistant',
            metadata: {'revision': p.revision},
          ),
        )
        .toList();
    if (_conversation != coordinator.conversationId) {
      _conversation = coordinator.conversationId;
      unawaited(chat.setMessages(messages, animated: false));
      version.value++;
      return;
    }
    final target = messages.map((m) => m.id).toSet();
    for (final old in chat.messages.toList()) {
      if (!target.contains(old.id)) {
        unawaited(chat.removeMessage(old, animated: false));
      }
    }
    for (var index = 0; index < messages.length; index++) {
      final next = messages[index];
      final old = chat.messages.where((m) => m.id == next.id).firstOrNull;
      if (old == null) {
        unawaited(chat.insertMessage(next, index: index, animated: false));
      } else if (old != next) {
        unawaited(chat.updateMessage(old, next));
      }
    }
    version.value++;
  }

  void dispose() {
    _disposed = true;
    coordinator.removeListener(_schedule);
    _smoother?.dispose();
    version.dispose();
    chat.dispose();
  }
}
