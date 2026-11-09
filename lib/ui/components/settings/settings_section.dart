import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../tokens/app_spacing.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: ShadTheme.of(context).textTheme.large),
        const SizedBox(height: AppSpacing.md),
        ShadCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.description,
    required this.control,
  });
  final String title;
  final String? description;
  final Widget control;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: LayoutBuilder(
      builder: (context, box) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: ShadTheme.of(context).textTheme.small),
            if (description != null)
              Text(description!, style: ShadTheme.of(context).textTheme.muted),
          ],
        );
        if (box.maxWidth < 440 ||
            MediaQuery.textScalerOf(context).scale(16) > 24) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text,
              const SizedBox(height: AppSpacing.md),
              control,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: text),
            const SizedBox(width: AppSpacing.lg),
            control,
          ],
        );
      },
    ),
  );
}
