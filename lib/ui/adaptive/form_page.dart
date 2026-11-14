import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../tokens/app_spacing.dart';
import 'app_page.dart';

/// Full-screen page for long forms that outgrow a dialog: a scrolling,
/// width-limited body and a footer action bar that stays above the keyboard.
class FormPage extends StatelessWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.children,
    required this.actions,
    this.canPop = true,
    required this.pageContext,
    this.maxWidth = 560,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });
  final CrossAxisAlignment crossAxisAlignment;
  final Widget title;
  final PageContextData pageContext;
  final List<Widget> children;

  /// Footer buttons, primary action last.
  final List<Widget> actions;

  /// When false, back gestures and the header back button are ignored (e.g.
  /// while a save is in flight).
  final bool canPop;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final padding = AppSpacing.page(context);
    Widget limit(Widget child) => Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        // Fill the limited width so start/end alignment is relative to it.
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
    return PopScope(
      canPop: canPop,
      child: AppPage(
        pageContext: pageContext,
        title: title,
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: padding,
                child: limit(
                  Column(
                    crossAxisAlignment: crossAxisAlignment,
                    children: children,
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: padding.left,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.colorScheme.border),
                ),
              ),
              child: limit(
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: actions,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
