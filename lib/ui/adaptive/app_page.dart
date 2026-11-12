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

  /// Height of the header row (title, back button and header controls).
  static const headerHeight = 40.0;

  static ShadThemeData _compactHeaderTheme(ShadThemeData theme) {
    ShadButtonTheme compact(ShadButtonTheme t) =>
        t.copyWith(height: headerHeight);
    return theme.copyWith(
      primaryButtonTheme: compact(theme.primaryButtonTheme),
      secondaryButtonTheme: compact(theme.secondaryButtonTheme),
      outlineButtonTheme: compact(theme.outlineButtonTheme),
      ghostButtonTheme: compact(theme.ghostButtonTheme),
      destructiveButtonTheme: compact(theme.destructiveButtonTheme),
      linkButtonTheme: compact(theme.linkButtonTheme),
    );
  }

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
              // One header height for every page: controls placed in the
              // header use a compact button size so they never grow it.
              child: ShadTheme(
                data: _compactHeaderTheme(theme),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: headerHeight),
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
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
