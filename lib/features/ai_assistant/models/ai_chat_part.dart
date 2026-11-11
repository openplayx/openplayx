import '../../../services/conversations/conversation_coordinator.dart';

enum AiPartKind { text, tool, error }

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
  final PendingConfirmation? confirmation;
  String get revision => '$text|$streaming|$phase|$data|${confirmation?.id}';
}
