import 'dart:async';
import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart' as flyer;

import '../../../services/conversations/conversation_coordinator.dart';
import '../models/ai_chat_part.dart';

/// A per-view projection. ConversationCoordinator remains the sole authority.
class FlyerChatAdapter {
  FlyerChatAdapter(this.coordinator) {
    _sync();
    coordinator.addListener(_schedule);
  }
  final ConversationCoordinator coordinator;
  final chat = flyer.InMemoryChatController();
  final parts = <String, AiChatPart>{};
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
              text: message.reasoning,
              duration: _thought(
                '${message.id}:reasoning',
                live: false,
                done: true,
              ),
            ),
          );
        }
        if (message.text.isNotEmpty) {
          items.add(
            AiChatPart(
              id: message.id!,
              turn: turn,
              kind: AiPartKind.text,
              text: message.text,
              isUser: message.role == 'user',
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
            text: turn.reasoning,
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
            text: turn.streaming,
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
  }

  void dispose() {
    _disposed = true;
    coordinator.removeListener(_schedule);
    chat.dispose();
  }
}
