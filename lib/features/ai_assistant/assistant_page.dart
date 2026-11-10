import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/conversations/conversation_coordinator.dart';

class AssistantView extends StatefulWidget {
  const AssistantView({
    super.key,
    required this.coordinator,
    required this.toolsEnabled,
    required this.onSettings,
  });
  final ConversationCoordinator coordinator;
  final bool Function() toolsEnabled;
  final VoidCallback onSettings;
  @override
  State<AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends State<AssistantView> {
  final _input = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty || widget.coordinator.busy) return;
    _input.clear();
    setState(() => _error = null);
    try {
      await widget.coordinator.send(text, toolsEnabled: widget.toolsEnabled());
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).aiSendFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.coordinator;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.aiAssistant,
                  style: ShadTheme.of(context).textTheme.h4,
                ),
              ),
              ShadButton.ghost(
                onPressed: c.busy ? null : widget.onSettings,
                child: Text(l.settings),
              ),
            ],
          ),
          Text(l.aiPrivacyNotice),
          if (c.turns.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(l.aiWelcome),
            ),
          for (final turn in c.turns) ...[
            for (final message in turn.messages)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ShadCard(
                  padding: const EdgeInsets.all(12),
                  title: Text(
                    message.role == 'user'
                        ? l.aiYou
                        : message.role == 'tool'
                        ? l.aiToolResult
                        : l.aiAssistant,
                  ),
                  child: SelectableText(
                    message.role == 'tool'
                        ? _toolResult(message.text, l)
                        : message.text.isNotEmpty
                        ? message.text
                        : message.calls.map((call) => call.name).join(', '),
                  ),
                ),
              ),
            if (turn.streaming.isNotEmpty) SelectableText(turn.streaming),
            if (turn.executingTool != null && c.busy)
              Text(l.aiExecuting(turn.executingTool!)),
            if (turn.error != null)
              Text(
                _failure(turn.error!, l),
                style: TextStyle(
                  color: ShadTheme.of(context).colorScheme.destructive,
                ),
              ),
            if (turn.status == 'interrupted') Text(l.aiInterrupted),
            if (turn.tokens != null) Text(l.aiTokenUsage(turn.tokens!)),
          ],
          if (c.confirmation case final pending?)
            ShadCard(
              title: Text(l.aiConfirmAction),
              description: Text(
                '${pending.tool}\n${jsonEncode(pending.arguments)}',
              ),
              child: Wrap(
                spacing: 8,
                children: [
                  ShadButton(
                    onPressed: () => c.decide(true),
                    child: Text(l.aiApprove),
                  ),
                  ShadButton.outline(
                    onPressed: () => c.decide(false),
                    child: Text(l.cancel),
                  ),
                ],
              ),
            ),
          if (_error != null) Text(_error!),
          const SizedBox(height: 8),
          ShadInput(
            controller: _input,
            maxLines: 3,
            maxLength: 8000,
            placeholder: Text(l.aiInputHint),
            enabled: !c.busy,
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: c.busy
                ? ShadButton.outline(onPressed: c.stop, child: Text(l.aiStop))
                : ShadButton(onPressed: _send, child: Text(l.aiSend)),
          ),
        ],
      ),
    );
  }

  String _toolResult(String text, AppLocalizations l) {
    try {
      final result = jsonDecode(text) as Map<String, dynamic>;
      return result['status'] == 'success'
          ? const JsonEncoder.withIndent('  ').convert(result['data'])
          : '${l.aiToolFailed}: ${result['error_code'] ?? result['status']}';
    } catch (_) {
      return l.aiToolFailed;
    }
  }

  String _failure(String code, AppLocalizations l) => switch (code) {
    'configurationRequired' => l.aiConfigureFirst,
    'cancelled' => l.aiCancelled,
    'authenticationFailed' => l.aiAuthenticationFailed,
    'rateLimited' => l.aiRateLimited,
    'protocolMismatch' => l.aiProtocolMismatch,
    'turnTimeout' || 'requestTimeout' => l.aiTimeout,
    'requestBudget' ||
    'toolBudget' ||
    'tokenBudget' ||
    'outputLimit' ||
    'contextBudget' => l.aiBudgetReached,
    _ => l.aiProviderFailed,
  };
}
