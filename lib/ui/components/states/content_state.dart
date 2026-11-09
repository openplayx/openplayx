import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../icons/app_icons.dart';
import '../../tokens/app_spacing.dart';

class ContentState extends StatelessWidget {
  const ContentState({
    super.key,
    required this.message,
    this.error = false,
    this.loading = false,
    this.onRetry,
    this.retryLabel,
  });
  final String message;
  final bool error, loading;
  final VoidCallback? onRetry;
  final String? retryLabel;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                loading
                    ? AppIcons.loading
                    : error
                    ? AppIcons.error
                    : AppIcons.library,
                size: 32,
                color: ShadTheme.of(context).colorScheme.mutedForeground,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                message,
                textAlign: TextAlign.center,
                style: ShadTheme.of(context).textTheme.muted,
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: ShadProgress(),
                ),
              if (onRetry != null)
                ShadButton.outline(
                  onPressed: onRetry,
                  child: Text(
                    retryLabel ??
                        MaterialLocalizations.of(context).okButtonLabel,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
