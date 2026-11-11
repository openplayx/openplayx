import 'package:flutter/widgets.dart';

import '../../services/conversations/conversation_coordinator.dart';

class AiChatAnchor {
  const AiChatAnchor({this.messageId, this.offset = 0, this.atBottom = true});
  final String? messageId;
  final double offset;
  final bool atBottom;
}

/// Local presentation state shared by the home view and its transient panels.
class AiChatController extends ChangeNotifier {
  AiChatController(this.coordinator) {
    _conversationId = coordinator.conversationId;
    draft.text = coordinator.store.draft;
    draft.addListener(_saveDraft);
    coordinator.addListener(_changed);
  }
  final ConversationCoordinator coordinator;
  final draft = TextEditingController();
  late String _conversationId;
  bool showConversation = false;
  String? sendError;
  final _anchors = <String, AiChatAnchor>{};
  AiChatAnchor? anchorFor(String surface) =>
      _anchors['$_conversationId:$surface'] ??
      _anchors['$_conversationId:latest'];
  void saveAnchor(String surface, AiChatAnchor anchor) {
    _anchors['$_conversationId:$surface'] = anchor;
    _anchors['$_conversationId:latest'] = anchor;
  }

  void handoffAnchor(String from, String to) {
    final anchor = anchorFor(from);
    if (anchor != null) _anchors['$_conversationId:$to'] = anchor;
  }

  bool _disposed = false;
  void _saveDraft() => coordinator.store.saveDraft(draft.text);
  void _changed() {
    if (_conversationId != coordinator.conversationId) {
      _conversationId = coordinator.conversationId;
      draft.text = coordinator.store.draft;
      sendError = null;
    }
    notifyListeners();
  }

  void showChat() {
    showConversation = true;
    notifyListeners();
  }

  void showContent() {
    showConversation = false;
    notifyListeners();
  }

  void suggest(String text) {
    draft.text = text;
    draft.selection = TextSelection.collapsed(offset: text.length);
    notifyListeners();
  }

  Future<void> send({required bool toolsEnabled}) async {
    final text = draft.text;
    if (text.trim().isEmpty || coordinator.busy) return;
    try {
      final pending = coordinator.send(text, toolsEnabled: toolsEnabled);
      // A failed local save leaves no accepted user turn: keep its draft.
      if (!coordinator.busy) {
        await pending;
        return;
      }
      draft.clear();
      sendError = null;
      showChat();
      await pending;
    } catch (_) {
      if (_disposed) return;
      if (draft.text.isEmpty) draft.text = text;
      sendError = 'sendFailed';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    coordinator.removeListener(_changed);
    draft.removeListener(_saveDraft);
    draft.dispose();
    super.dispose();
  }
}
