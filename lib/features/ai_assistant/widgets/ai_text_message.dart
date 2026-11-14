import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../ui/icons/app_icons.dart';
import '../../../ui/tokens/app_metrics.dart';
import '../../../ui/components/feedback/app_feedback.dart';

class AiTextMessage extends StatelessWidget {
  const AiTextMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.streaming = false,
  });
  final String text;
  final bool isUser, streaming;
  Future<void> _link(BuildContext context, String? href) async {
    final uri = Uri.tryParse(href ?? ''), l = AppLocalizations.of(context);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      showAppToast(context, l.aiLinkBlocked, kind: FeedbackKind.warning);
      return;
    }
    final accepted = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog(
        title: Text(l.aiOpenLink),
        description: Text(uri.host),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          ShadButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.aiOpenExternal),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context), l = AppLocalizations.of(context);
    final colors = theme.colorScheme;
    final body = theme.textTheme.p.copyWith(height: 1.55);
    // The user's turn: a soft rounded bubble on the right, like mainstream
    // chat apps. The reply: plain text across the page, no bubble.
    if (isUser) {
      return LayoutBuilder(
        builder: (context, box) => Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Container(
            constraints: BoxConstraints(maxWidth: box.maxWidth * 0.8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colors.muted,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SelectableText(text, style: body),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarkdownBody(
          data: text,
          selectable: true,
          softLineBreak: true,
          styleSheet: MarkdownStyleSheet(
            p: body,
            listBullet: body,
            h1: theme.textTheme.h3,
            h2: theme.textTheme.h4,
            h3: theme.textTheme.large,
            code: theme.textTheme.small.copyWith(
              fontFamily: 'monospace',
              backgroundColor: colors.muted,
            ),
            blockquote: theme.textTheme.muted,
            blockquoteDecoration: BoxDecoration(
              border: Border(left: BorderSide(color: colors.border, width: 3)),
            ),
            codeblockPadding: const EdgeInsets.all(12),
            codeblockDecoration: BoxDecoration(
              color: colors.muted,
              borderRadius: AppMetrics.panelRadius,
            ),
          ),
          imageBuilder: (uri, title, alt) => Text(
            alt?.isNotEmpty == true
                ? '${l.aiRemoteImageBlocked} · $alt'
                : l.aiRemoteImageBlocked,
            style: theme.textTheme.muted,
          ),
          onTapLink: (_, href, _) => _link(context, href),
        ),
        if (streaming)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l.aiReplying, style: theme.textTheme.muted),
          )
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Tooltip(
              message: l.shadCopy,
              child: Semantics(
                button: true,
                label: l.shadCopy,
                child: ShadIconButton.ghost(
                  width: 32,
                  height: 32,
                  foregroundColor: colors.mutedForeground,
                  icon: const Icon(AppIcons.copy, size: 15),
                  onPressed: () => Clipboard.setData(ClipboardData(text: text)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
