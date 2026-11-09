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
  });
  final Widget title, body;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.page(context).left,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.border),
                ),
              ),
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
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
