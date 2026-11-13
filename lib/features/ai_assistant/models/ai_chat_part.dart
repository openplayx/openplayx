import '../../../services/conversations/conversation_coordinator.dart';

enum AiPartKind { text, reasoning, tool, activity, error }

enum AiToolPhase { preparing, running, waiting, success, failed, cancelled }

/// Presentation-only content produced from host records, never model JSON.
class AiChatPart {
  const AiChatPart({
    required this.id,
    required this.turn,
    required this.kind,
    this.text = '',
    this.isUser = false,
    this.streaming = false,
    this.tool,
    this.phase,
    this.data = const {},
    this.arguments = const {},
    this.progress,
    this.confirmation,
  });
  final String id;
  final ConversationTurn turn;
  final AiPartKind kind;
  final String text;
  final bool isUser, streaming;
  final String? tool;
  final AiToolPhase? phase;
  final Map<String, dynamic> data;

  /// Decoded call arguments, for a host-side summary on the tool card.
  final Map<String, dynamic> arguments;

  /// Live progress of a running tool (see `ToolExecution.report`).
  final Map<String, dynamic>? progress;
  final PendingConfirmation? confirmation;
  String get revision =>
      '$text|$streaming|$tool|$phase|$data|$progress|${confirmation?.id}';
}
