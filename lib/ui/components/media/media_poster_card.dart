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
    this.artwork,
    this.showFavorite = false,
    this.progress,
  });
  final bool showFavorite;

  /// Watch progress in 0..1, drawn as a thin bar under the cover when set.
  final double? progress;
  final Widget? artwork;
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
                  child:
                      artwork ??
                      Center(
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
          if (progress != null)
            SizedBox(
              height: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: theme.colorScheme.border),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress!.clamp(0.0, 1.0),
                    child: ColoredBox(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
          // Compact caption: the title only, tappable like the poster.
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Favourites are hidden for now; enable with showFavorite.
                  if (showFavorite)
                    Tooltip(
                      message: label,
                      child: Semantics(
                        button: true,
                        toggled: favorite,
                        label: label,
                        child: ShadIconButton.ghost(
                          icon: Icon(
                            favorite ? AppIcons.check : AppIcons.favorite,
                          ),
                          onPressed: onFavorite,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
