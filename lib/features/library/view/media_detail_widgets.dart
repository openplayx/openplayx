part of 'media_detail_page.dart';

// Palette, measurements and the private building blocks of the detail
// page; the page itself lays them out.

/// Fixed palette of the detail page (drawn over artwork in both themes).
abstract final class _C {
  static const base = Color(0xFF121214);
  static const text = Color(0xFFFFFFFF);
  static const body = Color(0xEBFFFFFF);
  static const secondary = Color(0xD9FFFFFF);
  static const muted = Color(0x8CFFFFFF);
  static const divider = Color(0x80FFFFFF);
  static const glass = Color(0x38FFFFFF);
  static const glassHover = Color(0x4DFFFFFF);
  static const chip = Color(0x1FFFFFFF);
  static const chipHover = Color(0x33FFFFFF);
  static const star = Color(0xFFFFB800);
}

/// Measurements taken from the reference design (logical pixels).
abstract final class _M {
  static const gutter = 24.0;
  static const columnInset = 6.0;
  static const columnWidth = 200.0;
  static const columnGap = 30.0;
  static const rightPadding = 40.0;
  static const buttonHeight = 35.0;
  static const sectionGap = 36.0;
  static const headerGap = 16.0;
  static const posterWidth = 110.0;
  static const posterGap = 16.0;
  static const avatar = 80.0;
  static const avatarGap = 12.0;
  static const stillWidth = 210.0;
  static const stillGap = 23.0;
  static const cardRadius = 10.0;
  static const episodeChunk = 10;
}

const _sectionTitle = TextStyle(
  color: _C.text,
  fontSize: 15,
  fontWeight: FontWeight.w600,
  height: 1.3,
);

/// The page background: the artwork scaled up and blurred into a colour wash,
/// darkened enough for white text.
class _Wash extends StatelessWidget {
  const _Wash({required this.service, required this.art});
  final ArtworkService service;
  final ArtworkDescriptor? art;

  @override
  Widget build(BuildContext context) {
    if (art == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A2C33), _C.base],
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: 70,
              sigmaY: 70,
              tileMode: TileMode.mirror,
            ),
            child: MetadataArtwork(
              service: service,
              artwork: art!,
              cacheWidth: 96,
              fadeIn: true,
              placeholder: const ColoredBox(color: _C.base),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x8C000000)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The full-width backdrop, fading out at the bottom into the wash and
/// darkened bottom-left where the title and buttons sit.
class _Hero extends StatelessWidget {
  const _Hero({required this.service, required this.art});
  final ArtworkService service;
  final ArtworkDescriptor art;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        stops: [0, 0.6, 1],
      ).createShader(rect),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MetadataArtwork(
            service: service,
            artwork: art,
            alignment: const Alignment(0, -0.35),
            cacheWidth: null,
            fadeIn: true,
            placeholder: const SizedBox.shrink(),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33000000),
                  Color(0x00000000),
                  Color(0x59000000),
                ],
                stops: [0, 0.3, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.85, 0.75),
                radius: 1.0,
                colors: [Color(0x59000000), Color(0x00000000)],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------- controls

/// Hover/focus/press handling shared by the page's custom controls.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.onPressed,
    required this.builder,
    this.semanticLabel,
  });
  final VoidCallback? onPressed;
  final Widget Function(bool highlighted) builder;
  final String? semanticLabel;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onPressed?.call(),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: widget.builder(enabled && (_hover || _focus)),
        ),
      ),
    );
  }
}

/// Frosted translucent pill used for play and the icon actions.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.onPressed,
    required this.child,
    this.height = _M.buttonHeight,
    this.width,
    this.tooltip,
    this.semanticLabel,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double? width;
  final String? tooltip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final button = _Pressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel ?? tooltip,
      builder: (hover) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: width,
            constraints: BoxConstraints(minHeight: height),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hover ? _C.glassHover : _C.glass,
              borderRadius: BorderRadius.circular(height),
              border: Border.all(color: const Color(0x14FFFFFF)),
            ),
            child: Opacity(opacity: onPressed == null ? 0.45 : 1, child: child),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// Round dark button floating over the artwork (back, more).
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    super.key,
    required this.icon,
    this.tooltip,
    required this.onPressed,
    this.iconSize = 22,
  });
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final button = _Pressable(
      onPressed: onPressed,
      semanticLabel: tooltip,
      builder: (hover) => ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hover ? const Color(0x80000000) : const Color(0x52000000),
            ),
            child: Icon(icon, size: iconSize, color: _C.text),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.onPressed,
    this.selected = false,
    this.bold = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final bool bold;

  @override
  Widget build(BuildContext context) => _Pressable(
    onPressed: onPressed,
    semanticLabel: label,
    builder: (hover) => AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      constraints: const BoxConstraints(minHeight: 30, minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: selected || hover ? _C.chipHover : _C.chip,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? _C.text : _C.secondary,
          fontSize: 13.5,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    ),
  );
}

/// Rounded artwork frame that gains a white outline on hover or focus.
class _Card extends StatelessWidget {
  const _Card({
    required this.width,
    required this.aspectRatio,
    required this.child,
    this.highlighted = false,
  });
  final double width;
  final double aspectRatio;
  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: width,
    height: width / aspectRatio,
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(_M.cardRadius),
      border: Border.all(
        color: highlighted ? _C.text : const Color(0x1AFFFFFF),
        width: highlighted ? 2.5 : 1,
      ),
    ),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(_M.cardRadius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(_M.cardRadius),
      child: ColoredBox(color: const Color(0xFF26272B), child: child),
    ),
  );
}

class _ArtPlaceholder extends StatelessWidget {
  const _ArtPlaceholder();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF2A2B30),
    child: Center(
      child: Icon(LucideIcons.clapperboard, size: 28, color: _C.muted),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: const BoxDecoration(
      color: Color(0xCC000000),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: 15, color: _C.text),
  );
}

class _Certification extends StatelessWidget {
  const _Certification(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: _C.text, width: 1.3),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      value,
      style: const TextStyle(
        color: _C.text,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
    ),
  );
}

/// A score with its source mark: IMDb's yellow tag, TMDB's teal one, or the
/// source name in small caps for anything else.
class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.source, required this.value});
  final String source;
  final String value;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (source.toLowerCase()) {
      'imdb' => ('IMDb', const Color(0xFFF5C518), const Color(0xFF000000)),
      'tmdb' || 'themoviedb' => (
        'TMDB',
        const Color(0xFF01B4E4),
        const Color(0xFF0D253F),
      ),
      'douban' => ('豆瓣', const Color(0xFF00B51D), _C.text),
      'trakt' => ('trakt', const Color(0xFFED1C24), _C.text),
      'rottentomatoes' ||
      'tomatometer' => ('RT', const Color(0xFFFA320A), _C.text),
      _ => (source.toUpperCase(), _C.chip, _C.text),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: _C.body,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

/// Three lines of overview led by 「title」; tapping opens the full text.
class _Overview extends StatelessWidget {
  const _Overview({
    required this.title,
    required this.overview,
    required this.onMore,
  });
  final String title;
  final String overview;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => _Pressable(
    onPressed: onMore,
    builder: (hover) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '「$title」',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: overview),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: hover ? _C.text : _C.body,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
    ),
  );
}
