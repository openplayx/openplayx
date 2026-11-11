import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../icons/app_icons.dart';
import '../../tokens/app_motion.dart';

/// Visual metrics shared by the home shelves and the library poster wall.
abstract final class ShelfMetrics {
  static const radius = BorderRadius.all(Radius.circular(12));
  static const posterWidth = 120.0;
  static const landscapeWidth = 220.0;
  static const gap = 20.0;
  static const gridGap = 16.0;
  static const gridMinWidth = 132.0;
  static const captionGap = 8.0;

  /// Height of the title + subtitle block under a tile, scaled with text.
  static double captionHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return captionGap + scaler.scale(15) * 1.35 + 2 + scaler.scale(12.5) * 1.35;
  }
}

/// Section header: bold title on the left, muted "All · N ›" on the right.
class ShelfHeader extends StatelessWidget {
  const ShelfHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onViewAll,
  });
  final String title;
  final String? trailing;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final muted = theme.colorScheme.mutedForeground;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.foreground,
            ),
          ),
        ),
        if (trailing != null)
          _Hoverable(
            onTap: onViewAll,
            builder: (hover) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailing!,
                  style: TextStyle(
                    fontSize: 15,
                    color: hover ? theme.colorScheme.foreground : muted,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  AppIcons.next,
                  size: 18,
                  color: hover ? theme.colorScheme.foreground : muted,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A titled horizontal row of tiles.
class MediaShelf extends StatelessWidget {
  const MediaShelf({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    required this.tileWidth,
    required this.tileHeight,
    this.trailing,
    this.onViewAll,
    this.padding = EdgeInsets.zero,
  });
  final String title;
  final String? trailing;
  final VoidCallback? onViewAll;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double tileWidth;

  /// Artwork height; the caption height is added automatically.
  final double tileHeight;

  /// Horizontal page padding, applied inside the scroll view so tiles can
  /// scroll under the edge like VidHub.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: EdgeInsets.only(left: padding.left, right: padding.right),
        child: ShelfHeader(
          title: title,
          trailing: trailing,
          onViewAll: onViewAll,
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        height: tileHeight + ShelfMetrics.captionHeight(context) + 4,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(left: padding.left, right: padding.right),
          clipBehavior: Clip.none,
          itemCount: itemCount,
          separatorBuilder: (_, _) => const SizedBox(width: ShelfMetrics.gap),
          itemBuilder: (context, index) =>
              SizedBox(width: tileWidth, child: itemBuilder(context, index)),
        ),
      ),
    ],
  );
}

/// Portrait 2:3 poster with an optional rating badge, title and subtitle.
class PosterTile extends StatelessWidget {
  const PosterTile({
    super.key,
    required this.title,
    this.subtitle,
    this.artwork,
    this.rating,
    this.onTap,
  });
  final String title;
  final String? subtitle;
  final Widget? artwork;
  final String? rating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _Hoverable(
    onTap: onTap,
    semanticLabel: title,
    builder: (hover) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: _Cover(
            hover: hover,
            artwork: artwork,
            overlay: rating == null
                ? null
                : Positioned(right: 8, bottom: 6, child: _RatingBadge(rating!)),
          ),
        ),
        _Caption(title: title, subtitle: subtitle),
      ],
    ),
  );
}

/// Landscape 16:9 still with "position / duration" and a progress bar.
class LandscapeTile extends StatelessWidget {
  const LandscapeTile({
    super.key,
    required this.title,
    this.subtitle,
    this.artwork,
    this.timeLabel,
    this.progress,
    this.onTap,
  });
  final String title;
  final String? subtitle;
  final Widget? artwork;
  final String? timeLabel;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _Hoverable(
    onTap: onTap,
    semanticLabel: title,
    builder: (hover) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _Cover(
            hover: hover,
            artwork: artwork,
            scrim: true,
            overlay: Positioned(
              left: 10,
              right: 10,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (timeLabel != null)
                    Text(
                      timeLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                    ),
                  if (progress != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Color(0x4DFFFFFF)),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress!.clamp(0.0, 1.0),
                              child: const ColoredBox(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        _Caption(title: title, subtitle: subtitle),
      ],
    ),
  );
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.hover,
    this.artwork,
    this.overlay,
    this.scrim = false,
  });
  final bool hover;
  final Widget? artwork;
  final Widget? overlay;
  final bool scrim;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.feedback),
      decoration: BoxDecoration(
        borderRadius: ShelfMetrics.radius,
        color: theme.colorScheme.muted,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: hover ? (dark ? .55 : .28) : (dark ? .35 : .14),
            ),
            blurRadius: hover ? 18 : 10,
            offset: Offset(0, hover ? 8 : 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: ShelfMetrics.radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale: hover ? 1.04 : 1,
              duration: AppMotion.duration(context, AppMotion.panel),
              curve: Curves.easeOut,
              child:
                  artwork ??
                  Center(
                    child: Icon(
                      AppIcons.movie,
                      size: 36,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
            ),
            if (scrim)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [.45, 1],
                    colors: [Color(0x00000000), Color(0x99000000)],
                  ),
                ),
              ),
            ?overlay,
          ],
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge(this.value);
  final String value;

  @override
  Widget build(BuildContext context) => Text(
    value,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 15,
      height: 1,
      fontWeight: FontWeight.w800,
      fontStyle: FontStyle.italic,
      letterSpacing: -.5,
      shadows: [
        Shadow(blurRadius: 6, color: Colors.black87),
        Shadow(blurRadius: 2, color: Colors.black54),
      ],
    ),
  );
}

class _Caption extends StatelessWidget {
  const _Caption({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, ShelfMetrics.captionGap, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.foreground,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: theme.colorScheme.mutedForeground,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hover + press feedback with a pointer cursor; no ink splash.
class _Hoverable extends StatefulWidget {
  const _Hoverable({required this.builder, this.onTap, this.semanticLabel});
  final Widget Function(bool hover) builder;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<_Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<_Hoverable> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: widget.onTap != null,
    label: widget.semanticLabel,
    child: FocusableActionDetector(
      enabled: widget.onTap != null,
      mouseCursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _hover = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.builder(_hover && widget.onTap != null),
      ),
    ),
  );
}
