import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as flyer;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as flyer_ui;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/conversations/conversation_coordinator.dart';
import '../../ui/icons/app_icons.dart';
import '../../ui/tokens/app_motion.dart';
import 'adapters/flyer_chat_adapter.dart';
import 'adapters/flyer_chat_theme.dart';
import 'ai_chat_controller.dart';
import 'models/ai_chat_part.dart';
import 'widgets/ai_composer.dart';
import 'widgets/ai_failure_message.dart';
import 'widgets/ai_text_message.dart';
import 'widgets/ai_tool_execution_card.dart';

class AiChatView extends StatefulWidget {
  const AiChatView({
    super.key,
    required this.coordinator,
    required this.toolsEnabled,
    required this.onSettings,
    this.controller,
    this.onShowContent,
    this.onExpand,
    this.onOpenMedia,
    this.onFavorite,
  });
  final ConversationCoordinator coordinator;
  final AiChatController? controller;
  final bool Function() toolsEnabled;
  final VoidCallback onSettings;
  final VoidCallback? onShowContent, onExpand;
  final OpenChatMedia? onOpenMedia;
  final Future<bool> Function(String id)? onFavorite;
  @override
  State<AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends State<AiChatView> {
  late final _controller =
      widget.controller ?? AiChatController(widget.coordinator);
  late final _adapter = FlyerChatAdapter(widget.coordinator);
  final _scroll = ScrollController();
  bool _atBottom = true;
  final _viewportKey = GlobalKey();
  final _messageKeys = <String, GlobalKey>{};
  String get _surface => widget.onExpand == null ? 'home' : 'panel';
  String? _restoredConversation;
  bool _restoring = false;
  bool _anchorSaveScheduled = false;
  void _saveAnchor() {
    if (!_scroll.hasClients || _restoring) return;
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    for (final message in _adapter.chat.messages) {
      final box = _messageKeys[message.id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final y = box.localToGlobal(Offset.zero).dy - top;
      if (y + box.size.height > 0 && y < viewport.size.height) {
        _controller.saveAnchor(
          _surface,
          AiChatAnchor(messageId: message.id, offset: -y, atBottom: _atBottom),
        );
        break;
      }
    }
  }

  void _restoreAnchor() {
    if (_restoredConversation == widget.coordinator.conversationId) return;
    _restoredConversation = widget.coordinator.conversationId;
    final anchor = _controller.anchorFor(_surface);
    _atBottom = anchor?.atBottom ?? true;
    _restoring = anchor != null && !anchor.atBottom && anchor.messageId != null;
    if (!_restoring) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scroll.hasClients) return;
      await _adapter.chat.scrollToMessage(
        anchor!.messageId!,
        duration: Duration.zero,
        offset: anchor.offset,
      );
      if (!mounted) return;
      _restoring = false;
    });
  }

  String? _lastRevision;
  @override
  void initState() {
    super.initState();
    widget.coordinator.addListener(_onUpdate);
    _scroll.addListener(_scrolled);
  }

  void _scrolled() {
    if (!_scroll.hasClients || _restoring) return;
    final near = _scroll.position.extentAfter < 80;
    if (near != _atBottom) setState(() => _atBottom = near);
    if (!_anchorSaveScheduled) {
      _anchorSaveScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _anchorSaveScheduled = false;
        if (mounted) _saveAnchor();
      });
    }
  }

  void _onUpdate() {
    final turn = widget.coordinator.currentTurn;
    final revision = '${turn?.id}:${turn?.streaming}:${turn?.executingCallId}';
    if (_atBottom && _lastRevision != revision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _atBottom && _scroll.hasClients) {
          unawaited(
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: AppMotion.duration(context, AppMotion.feedback),
              curve: Curves.easeOut,
            ),
          );
        }
      });
    }
    _lastRevision = revision;
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_onUpdate);
    _adapter.dispose();
    _scroll.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _history() async {
    final c = widget.coordinator, l = AppLocalizations.of(context);
    await showShadDialog<void>(
      context: context,
      builder: (context) => ShadDialog(
        title: Text(l.aiChatHistory),
        child: SizedBox(
          width: 480,
          height: 320,
          child: ListView(
            children: [
              for (final conversation in c.store.conversations)
                ShadButton.ghost(
                  enabled: !c.busy,
                  leading: conversation['id'] == c.conversationId
                      ? const Icon(AppIcons.check)
                      : null,
                  onPressed: () {
                    c.selectConversation(conversation['id'] as String);
                    Navigator.pop(context);
                  },
                  child: Flexible(
                    child: Text(
                      (conversation['title'] as String).isEmpty
                          ? l.aiUntitledChat
                          : conversation['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon(String label, IconData icon, VoidCallback? onPressed) => Tooltip(
    message: label,
    child: Semantics(
      label: label,
      button: true,
      child: ShadIconButton.ghost(
        enabled: onPressed != null,
        icon: Icon(icon, size: 18),
        onPressed: onPressed,
      ),
    ),
  );
  Widget _part(String id) {
    final part = _adapter.parts[id];
    if (part == null) return const SizedBox.shrink();
    final c = widget.coordinator, l = AppLocalizations.of(context);
    return switch (part.kind) {
      AiPartKind.text => AiTextMessage(
        text: part.text,
        isUser: part.isUser,
        streaming: part.streaming,
      ),
      AiPartKind.tool => AiToolExecutionCard(
        part: part,
        coordinator: c,
        onOpenMedia: widget.onOpenMedia,
        onFavorite: widget.onFavorite,
      ),
      AiPartKind.error => ShadAlert.destructive(
        title: Text(aiFailureMessage(part.text, l)),
        description: c.canRetry(part.turn)
            ? Align(
                alignment: AlignmentDirectional.centerStart,
                child: ShadButton.outline(
                  enabled: !c.busy,
                  onPressed: () => c.retry(part.turn),
                  child: Text(l.retry),
                ),
              )
            : null,
      ),
    };
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final c = widget.coordinator,
          l = AppLocalizations.of(context),
          theme = ShadTheme.of(context);
      _restoreAnchor();
      final page = c.context()['page'];
      final pageName = switch (page) {
        'library' => l.library,
        'sources' => l.sources,
        'settings' => l.settings,
        'player' => l.play,
        _ => l.home,
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l.aiAssistant, style: theme.textTheme.h4),
                _icon(
                  l.aiNewChat,
                  AppIcons.add,
                  c.busy
                      ? null
                      : () {
                          c.newConversation();
                          _controller.showChat();
                        },
                ),
                _icon(
                  l.aiChatHistory,
                  AppIcons.history,
                  c.busy ? null : _history,
                ),
                _icon(
                  l.aiModelSettings,
                  AppIcons.settings,
                  c.busy ? null : widget.onSettings,
                ),
                if (widget.onShowContent != null)
                  _icon(l.aiShowMedia, AppIcons.library, widget.onShowContent),
                if (widget.onExpand != null)
                  _icon(l.aiExpandChat, AppIcons.fullscreen, () {
                    _saveAnchor();
                    _controller.handoffAnchor('panel', 'home');
                    widget.onExpand!();
                  }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ShadBadge.secondary(child: Text(pageName)),
            ),
          ),
          Expanded(
            child: SizedBox(
              key: _viewportKey,
              child: flyer_ui.Chat(
                key: ValueKey(c.conversationId),
                currentUserId: 'user',
                resolveUser: (id) async => flyer.User(id: id),
                chatController: _adapter.chat,
                theme: flyerChatTheme(theme),
                builders: flyer.Builders(
                  composerBuilder: (_) => const SizedBox.shrink(),
                  linkPreviewBuilder: (_, _, _) => null,
                  emptyChatListBuilder: (_) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l.aiWelcome, style: theme.textTheme.muted),
                    ),
                  ),
                  customMessageBuilder: (
                    context,
                    message,
                    index, {
                    required isSentByMe,
                    groupStatus,
                  }) => _part(message.id),
                  chatMessageBuilder:
                      (
                        context,
                        message,
                        index,
                        animation,
                        child, {
                        isRemoved,
                        required isSentByMe,
                        groupStatus,
                      }) => Padding(
                        key: _messageKeys.putIfAbsent(
                          message.id,
                          () => GlobalKey(),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Align(
                          alignment: isSentByMe
                              ? AlignmentDirectional.centerEnd
                              : AlignmentDirectional.centerStart,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: child,
                          ),
                        ),
                      ),
                  chatAnimatedListBuilder: (context, itemBuilder) =>
                      flyer_ui.ChatAnimatedList(
                        itemBuilder: itemBuilder,
                        scrollController: _scroll,
                        insertAnimationDuration: Duration.zero,
                        removeAnimationDuration: Duration.zero,
                        shouldScrollToEndWhenSendingMessage: false,
                        scrollToBottomAppearanceThreshold: 80,
                        initialScrollToEndMode:
                            _controller.anchorFor(_surface)?.atBottom == false
                            ? flyer_ui.InitialScrollToEndMode.none
                            : flyer_ui.InitialScrollToEndMode.jump,
                        onEndReached: c.hasEarlier
                            ? () async {
                                c.loadEarlier();
                              }
                            : null,
                      ),
                  scrollToBottomBuilder: (context, animation, onPressed) =>
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: ScaleTransition(
                            scale: animation,
                            child: ShadButton.secondary(
                              onPressed: onPressed,
                              child: Flexible(
                                child: Text(
                                  l.aiLatest,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                ),
              ),
            ),
          ),
          AiComposer(
            controller: _controller,
            toolsEnabled: widget.toolsEnabled,
            onSettings: widget.onSettings,
          ),
        ],
      );
    },
  );
}
