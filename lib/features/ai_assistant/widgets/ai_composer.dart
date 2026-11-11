import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../ui/icons/app_icons.dart';
import '../../../ui/tokens/app_spacing.dart';
import '../ai_chat_controller.dart';

class AiComposer extends StatelessWidget {
  const AiComposer({
    super.key,
    required this.controller,
    required this.toolsEnabled,
    required this.onSettings,
  });
  final AiChatController controller;
  final bool Function() toolsEnabled;
  final VoidCallback onSettings;
  Future<void> _send() => controller.send(toolsEnabled: toolsEnabled());
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), c = controller.coordinator;
    final desktop =
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.draft]),
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!c.store.loadConfig().cloudAllowed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l.aiConfigureFirst,
                      style: ShadTheme.of(context).textTheme.muted,
                    ),
                    ShadButton.ghost(
                      height: 0,
                      onPressed: onSettings,
                      child: Flexible(child: Text(l.aiModelSettings)),
                    ),
                  ],
                ),
              ),
            if (controller.sendError != null)
              ShadAlert.destructive(title: Text(l.aiSendFailed)),
            Focus(
              onKeyEvent: (_, event) {
                if (!desktop ||
                    event is! KeyDownEvent ||
                    event.logicalKey != LogicalKeyboardKey.enter ||
                    HardwareKeyboard.instance.isShiftPressed) {
                  return KeyEventResult.ignored;
                }
                final composing = controller.draft.value.composing;
                if (composing.isValid && !composing.isCollapsed) {
                  return KeyEventResult.ignored;
                }
                if (!c.busy) _send();
                return KeyEventResult.handled;
              },
              child: ShadInput(
                key: const ValueKey('ai-composer-input'),
                controller: controller.draft,
                minLines: 1,
                maxLines: 4,
                maxLength: 8000,
                textInputAction: TextInputAction.newline,
                placeholder: Text(l.aiInputHint),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.busy ? l.aiDraftNext : l.aiPrivacyNotice,
                    style: ShadTheme.of(context).textTheme.muted,
                  ),
                ),
                const SizedBox(width: 8),
                if (c.busy)
                  Tooltip(
                    message: l.aiStop,
                    child: Semantics(
                      label: l.aiStop,
                      button: true,
                      child: ShadIconButton.outline(
                        icon: const Icon(AppIcons.stop),
                        onPressed: c.stop,
                      ),
                    ),
                  )
                else
                  Tooltip(
                    message: l.aiSend,
                    child: Semantics(
                      label: l.aiSend,
                      button: true,
                      child: ShadIconButton(
                        icon: const Icon(AppIcons.send),
                        enabled: controller.draft.text.trim().isNotEmpty,
                        onPressed: controller.draft.text.trim().isEmpty
                            ? null
                            : _send,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
