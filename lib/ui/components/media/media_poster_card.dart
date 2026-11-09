import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../icons/app_icons.dart';
import '../../tokens/app_spacing.dart';

class MediaPosterCard extends StatelessWidget {
  const MediaPosterCard({
    super.key,
    required this.title,
    required this.favorite,
    required this.onFavorite,
    this.onOpen,
  });
  final String title;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final label = favorite
        ? AppLocalizations.of(context).unfavorite
        : AppLocalizations.of(context).favorite;
    return ShadCard(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Material(
              color: theme.colorScheme.muted,
              child: InkWell(
                onTap: onOpen,
                child: Semantics(
                  button: true,
                  label: title,
                  child: Center(
                    child: Icon(
                      AppIcons.movie,
                      size: 48,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: ShadButton.ghost(
                    expands: true,
                    height: 64,
                    onPressed: onOpen,
                    enabled: onOpen != null,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Tooltip(
                  message: label,
                  child: Semantics(
                    button: true,
                    toggled: favorite,
                    label: label,
                    child: ShadIconButton.ghost(
                      icon: Icon(favorite ? AppIcons.check : AppIcons.favorite),
                      onPressed: onFavorite,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
