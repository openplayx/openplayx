import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../ui/icons/app_icons.dart';
import '../../controller/ai_chat_controller.dart';
import '../../controller/voice_input_controller.dart';
import 'voice_recording_bar.dart';

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

  /// Transcribe the recording, then send it without a review step.
  Future<void> _sendVoice() async {
    if (await controller.voice.stop() && !controller.coordinator.busy) {
      await _send();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), c = controller.coordinator;
    final desktop =
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS;
    final theme = ShadTheme.of(context), colors = theme.colorScheme;
    final pill = BorderRadius.circular(26);
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.draft]),
      builder: (context, _) {
        final voice = controller.voice;
        final canSend = controller.draft.text.trim().isNotEmpty && !voice.busy;
        final voiceMessage = voice.error == null
            ? null
            : switch (voice.error) {
                'unsupported' => l.voiceUnsupported,
                'permission' => l.voicePermission,
                'authentication' => l.aiAuthenticationFailed,
                'rateLimited' => l.aiRateLimited,
                'timeout' => l.aiTimeout,
                'settings' => l.voiceSettingsError,
                'empty' => l.voiceEmpty,
                'tooLarge' => l.voiceTooLarge,
                'recording' => l.voiceRecordingError,
                _ => l.voiceTranscriptionError,
              };
        // Round filled button inside the pill: arrow to send, square to stop.
        Widget round(String label, IconData icon, VoidCallback? onPressed) =>
            Tooltip(
              message: label,
              child: Semantics(
                label: label,
                button: true,
                child: ShadIconButton(
                  width: 36,
                  height: 36,
                  enabled: onPressed != null,
                  decoration: const ShadDecoration(shape: BoxShape.circle),
                  backgroundColor: onPressed == null
                      ? colors.muted
                      : colors.foreground,
                  hoverBackgroundColor: colors.foreground.withValues(
                    alpha: 0.85,
                  ),
                  foregroundColor: onPressed == null
                      ? colors.mutedForeground
                      : colors.background,
                  icon: Icon(icon, size: 18),
                  onPressed: onPressed,
                ),
              ),
            );
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!c.configured)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            l.aiConfigureFirst,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.muted.copyWith(fontSize: 12),
                          ),
                          ShadButton.link(
                            height: 0,
                            size: ShadButtonSize.sm,
                            onPressed: onSettings,
                            child: Flexible(child: Text(l.aiModelSettings)),
                          ),
                        ],
                      ),
                    ),
                  if (controller.sendError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l.aiSendFailed,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.small.copyWith(
                          color: colors.destructive,
                        ),
                      ),
                    ),
                  if (!voice.busy && voiceMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        voiceMessage,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.small.copyWith(
                          color: colors.destructive,
                        ),
                      ),
                    ),
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
                      if (!c.busy) unawaited(_send());
                      return KeyEventResult.handled;
                    },
                    // Mobile keyboards have no dismiss key, so a tap anywhere
                    // outside the pill (input + its buttons) closes it.
                    child: TapRegion(
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: pill,
                          border: Border.all(color: colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: colors.foreground.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: voice.busy
                            ? VoiceRecordingBar(
                                voice: voice,
                                cancelLabel: l.cancel,
                                stopLabel: l.voiceStop,
                                sendLabel: l.voiceSend,
                                statusLabel: switch (voice.state) {
                                  VoiceInputState.recording => null,
                                  VoiceInputState.transcribing =>
                                    l.voiceTranscribing,
                                  _ => l.voicePreparing,
                                },
                                onStop: voice.stop,
                                onSend: _sendVoice,
                              )
                            : ShadInput(
                                key: const ValueKey('ai-composer-input'),
                                controller: controller.draft,
                                minLines: 1,
                                maxLines: 6,
                                maxLength: 8000,
                                textInputAction: TextInputAction.newline,
                                placeholder: Text(l.aiInputHint),
                                // Text line padded to the send button's height so a
                                // single line sits centered beside it.
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                  18,
                                  6,
                                  6,
                                  6,
                                ),
                                inputPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                crossAxisAlignment: CrossAxisAlignment.end,
                                // The pill is drawn by the container around it, so
                                // focus does not swap in the theme's input border.
                                decoration: const ShadDecoration(
                                  color: Colors.transparent,
                                  disableSecondaryBorder: true,
                                  border: ShadBorder.none,
                                  focusedBorder: ShadBorder.none,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tooltip(
                                      message: l.voiceStart,
                                      child: Semantics(
                                        label: l.voiceStart,
                                        button: true,
                                        child: ShadIconButton.ghost(
                                          width: 36,
                                          height: 36,
                                          decoration: const ShadDecoration(
                                            shape: BoxShape.circle,
                                          ),
                                          icon: const Icon(
                                            AppIcons.mic,
                                            size: 20,
                                          ),
                                          onPressed: voice.toggle,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    c.busy
                                        ? round(l.aiStop, AppIcons.stop, c.stop)
                                        : round(
                                            l.aiSend,
                                            AppIcons.sendUp,
                                            canSend ? _send : null,
                                          ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (c.busy) ...[
                    const SizedBox(height: 6),
                    Text(
                      l.aiDraftNext,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.muted.copyWith(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
