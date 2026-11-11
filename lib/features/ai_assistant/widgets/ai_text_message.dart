import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../ui/icons/app_icons.dart';
import '../../../ui/tokens/app_metrics.dart';

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
      ShadToaster.of(context)
          .show(ShadToast(description: Text(l.aiLinkBlocked)));
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: isUser
          ? BoxDecoration(
              color: theme.colorScheme.muted,
              borderRadius: AppMetrics.panelRadius,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MarkdownBody(
            data: text,
            selectable: true,
            softLineBreak: true,
            styleSheet: MarkdownStyleSheet(
              p: theme.textTheme.p,
              h1: theme.textTheme.h3,
              h2: theme.textTheme.h4,
              h3: theme.textTheme.large,
              code: theme.textTheme.small,
              blockquote: theme.textTheme.muted,
              codeblockDecoration: BoxDecoration(
                color: theme.colorScheme.muted,
                borderRadius: AppMetrics.controlRadius,
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
            Text(l.aiReplying, style: theme.textTheme.muted)
          else
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Tooltip(
                message: l.shadCopy,
                child: Semantics(
                  button: true,
                  label: l.shadCopy,
                  child: ShadIconButton.ghost(
                    icon: const Icon(AppIcons.copy, size: 16),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: text)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
