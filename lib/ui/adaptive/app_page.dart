import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../icons/app_icons.dart';
import '../tokens/app_spacing.dart';

/// Page structure grows with text scaling and wraps actions on narrow windows.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.trailing = const [],
  });
  final Widget title, body;
  final List<Widget> actions;

  /// Right-aligned header controls, placed just left of the assistant button.
  final List<Widget> trailing;
  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              // The top-right corner is reserved for the app-wide assistant
              // button (40pt) overlaid by the shell.
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page(context).left,
                AppSpacing.md,
                AppSpacing.page(context).right + 40 + AppSpacing.sm,
                AppSpacing.md,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.border),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => Wrap(
                        spacing: AppSpacing.lg,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (Navigator.of(context).canPop())
                                Tooltip(
                                  message: MaterialLocalizations.of(context)
                                      .backButtonTooltip,
                                  child: Semantics(
                                    label: MaterialLocalizations.of(context)
                                        .backButtonTooltip,
                                    button: true,
                                    child: ShadIconButton.ghost(
                                      icon: const Icon(AppIcons.back),
                                      onPressed: () =>
                                          Navigator.of(context).maybePop(),
                                    ),
                                  ),
                                ),
                              Flexible(
                                child: DefaultTextStyle(
                                  style: theme.textTheme.h4.copyWith(
                                    color: theme.colorScheme.foreground,
                                  ),
                                  child: title,
                                ),
                              ),
                            ],
                          ),
                          if (actions.isNotEmpty)
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: actions,
                            ),
                        ],
                      ),
                    ),
                  ),
                  for (final widget in trailing) ...[
                    const SizedBox(width: AppSpacing.xs),
                    widget,
                  ],
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
