import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../ui/tokens/app_semantic_colors.dart';

/// Player-only visual constants (design §2.2). The player is always dark.
abstract final class PlayerStyle {
  static const glass = Color(0xEB18181B);
  static const glassStroke = Color(0x17FFFFFF);
  static const hover = Color(0x14FFFFFF);
  static const track = Color(0x33FFFFFF);
  static const recording = Color(0xFFEF4444);

  /// Remote access badge: playback is using relay (server) traffic.
  static const remote = Color(0xFFF2B84B);
  static const fg = AppSemanticColors.playerForeground;
  static const muted = AppSemanticColors.playerMuted;
  static const radius = BorderRadius.all(Radius.circular(12));
  static const tabular = [FontFeature.tabularFigures()];
  static const shadow = [
    Shadow(color: Color(0x99000000), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static Color accent(BuildContext context) =>
      ShadTheme.of(context).colorScheme.primary;
}

/// Semi-opaque dark surface for menus, panels and sheets.
class PlayerGlass extends StatelessWidget {
  const PlayerGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(8),
    this.radius = PlayerStyle.radius,
    this.width,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final double? width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: padding,
    decoration: BoxDecoration(
      color: PlayerStyle.glass,
      borderRadius: radius,
      border: Border.all(color: PlayerStyle.glassStroke),
      boxShadow: const [
        BoxShadow(
          color: Color(0x73000000),
          blurRadius: 40,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: PlayerStyle.fg, fontSize: 13),
      child: IconTheme.merge(
        data: const IconThemeData(color: PlayerStyle.fg, size: 18),
        child: child,
      ),
    ),
  );
}

/// Status pill for a setting that differs from its default (design L3).
class PlayerChip extends StatelessWidget {
  const PlayerChip({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.onReset,
    this.tooltip,
    this.iconColor,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap, onReset;
  final String? tooltip;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final chip = Semantics(
      button: true,
      label: tooltip ?? label,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onReset,
        onSecondaryTap: onReset,
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: PlayerStyle.glass,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: PlayerStyle.glassStroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: iconColor ?? PlayerStyle.accent(context),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: PlayerStyle.fg,
                  fontSize: 12,
                  fontFeatures: PlayerStyle.tabular,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
  }
}

/// One-shot feedback card (jump, speed, track switch...), fades by itself
/// when the parent removes it.
class PlayerOsd extends StatelessWidget {
  const PlayerOsd({super.key, this.icon, required this.text, this.detail});
  final IconData? icon;
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: PlayerGlass(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFeatures: PlayerStyle.tabular,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(width: 8),
            Text(
              detail!,
              style: const TextStyle(
                color: PlayerStyle.muted,
                fontFeatures: PlayerStyle.tabular,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Vertical level bar for brightness/volume gestures.
class PlayerLevelBar extends StatelessWidget {
  const PlayerLevelBar({super.key, required this.icon, required this.level});
  final IconData icon;

  /// 0–1.
  final double level;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: PlayerGlass(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      radius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 8),
          Container(
            width: 6,
            height: 120,
            decoration: BoxDecoration(
              color: PlayerStyle.track,
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: level.clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(
                  color: PlayerStyle.fg,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(level * 100).round()}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: PlayerStyle.tabular,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Markers drawn on the seek bar, as fractions of the duration.
class SeekMarks {
  const SeekMarks({this.a, this.b});
  final double? a, b;
}

/// Thin seek bar over the video: previews while dragging and commits once
/// on release; hover shows the target time above the pointer (design D05/D06).
class PlayerSeekBar extends StatefulWidget {
  const PlayerSeekBar({
    super.key,
    required this.value,
    required this.max,
    required this.enabled,
    required this.label,
    required this.onPreview,
    required this.onCommit,
    this.marks = const SeekMarks(),
    this.hoverLabel,
    this.lane = 20,
    this.alwaysShowThumb = false,
  });
  final double value, max;
  final bool enabled;
  final String label;
  final ValueChanged<double> onPreview, onCommit;
  final SeekMarks marks;

  /// Text shown above the pointer while hovering, for a position in ms.
  final String Function(double value)? hoverLabel;

  /// Height of the interactive lane.
  final double lane;

  /// Touch layouts show the full thumb even without hover (design M-1).
  final bool alwaysShowThumb;

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  double? _preview;
  double? _hoverX;
  bool _focused = false;
  double get _max => widget.max > 0 ? widget.max : 1;

  void _change(double value) {
    setState(() => _preview = value.clamp(0, _max));
    widget.onPreview(_preview!);
  }

  void _commit() {
    final value = _preview;
    if (value == null) return;
    setState(() => _preview = null);
    widget.onCommit(value);
  }

  void _step(double delta) {
    _change(widget.value + delta);
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final accent = PlayerStyle.accent(context);
    final current = (_preview ?? widget.value).clamp(0, _max) / _max;
    final hot = widget.enabled && (_hoverX != null || _preview != null);
    return Semantics(
      label: widget.label,
      slider: true,
      enabled: widget.enabled,
      value: '${(widget.value / _max * 100).round()}%',
      increasedValue:
          '${((widget.value + 5000).clamp(0, _max) / _max * 100).round()}%',
      decreasedValue:
          '${((widget.value - 5000).clamp(0, _max) / _max * 100).round()}%',
      onIncrease: widget.enabled ? () => _step(5000) : null,
      onDecrease: widget.enabled ? () => _step(-5000) : null,
      child: Focus(
        canRequestFocus: widget.enabled,
        skipTraversal: true,
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: (_, event) {
          if (!widget.enabled || event is KeyUpEvent || !_focused) {
            return KeyEventResult.ignored;
          }
          return KeyEventResult.ignored;
        },
        child: LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            double at(Offset local) => local.dx.clamp(0, width) / width * _max;
            return MouseRegion(
              cursor: widget.enabled
                  ? SystemMouseCursors.click
                  : MouseCursor.defer,
              onHover: widget.enabled
                  ? (event) => setState(() => _hoverX = event.localPosition.dx)
                  : null,
              onExit: (_) => setState(() => _hoverX = null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: widget.enabled
                    ? (event) {
                        _change(at(event.localPosition));
                        _commit();
                      }
                    : null,
                onHorizontalDragStart: widget.enabled
                    ? (event) => _change(at(event.localPosition))
                    : null,
                onHorizontalDragUpdate: widget.enabled
                    ? (event) {
                        _hoverX = event.localPosition.dx.clamp(0, width);
                        _change(at(event.localPosition));
                      }
                    : null,
                onHorizontalDragEnd: widget.enabled ? (_) => _commit() : null,
                onHorizontalDragCancel: () => setState(() => _preview = null),
                child: SizedBox(
                  height: widget.lane,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        height: hot ? 6 : 3,
                        decoration: BoxDecoration(
                          color: PlayerStyle.track,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      if (widget.marks.a != null)
                        Positioned(
                          left: widget.marks.a! * width,
                          width:
                              ((widget.marks.b ?? widget.marks.a!) -
                                      widget.marks.a!) *
                                  width +
                              2,
                          height: hot ? 12 : 9,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.25),
                              border: Border.symmetric(
                                vertical: BorderSide(color: accent, width: 2),
                              ),
                            ),
                          ),
                        ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: current * width,
                        height: hot ? 6 : 3,
                        decoration: BoxDecoration(
                          color: widget.enabled ? accent : PlayerStyle.muted,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      if (widget.enabled)
                        Positioned(
                          left: current * width - 7,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 120),
                            scale: hot || widget.alwaysShowThumb ? 1 : 0.6,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                color: PlayerStyle.fg,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x80000000),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (hot && widget.hoverLabel != null && _hoverX != null)
                        Positioned(
                          left: (_hoverX! - 60).clamp(0, width - 120),
                          bottom: widget.lane / 2 + 12,
                          width: 120,
                          child: Center(
                            child: PlayerGlass(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              radius: BorderRadius.circular(6),
                              child: Text(
                                widget.hoverLabel!(
                                  _hoverX!.clamp(0, width) / width * _max,
                                ),
                                key: const Key('seek-hover-label'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFeatures: PlayerStyle.tabular,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Small icon button on the video with a tooltip and semantic label.
class PlayerIconButton extends StatelessWidget {
  const PlayerIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = 40,
    this.iconSize = 20,
    this.active = false,
    this.color,
    this.onLongPress,
    this.badge,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed, onLongPress;
  final double size, iconSize;
  final bool active;
  final Color? color;

  /// Small text drawn over the icon, e.g. the "10" of a jump button.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final foreground =
        color ?? (active ? PlayerStyle.accent(context) : PlayerStyle.fg);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: ShadIconButton.ghost(
          onPressed: onPressed,
          onLongPress: onPressed == null ? null : onLongPress,
          enabled: onPressed != null,
          width: size,
          height: size,
          foregroundColor: foreground,
          icon: badge == null
              ? Icon(icon, size: iconSize)
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, size: iconSize),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          color: foreground,
                          fontSize: iconSize * 0.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A row in a player menu/panel: icon, label, value and optional check.
class PlayerMenuRow extends StatelessWidget {
  const PlayerMenuRow({
    super.key,
    required this.label,
    this.icon,
    this.value,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    this.chevron = false,
    this.height = 36,
    this.subtitle,
  });
  final String label;
  final IconData? icon;
  final String? value, subtitle;
  final bool selected, enabled, chevron;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final accent = PlayerStyle.accent(context);
    final color = enabled ? PlayerStyle.fg : PlayerStyle.muted;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        hoverColor: PlayerStyle.hover,
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: BoxConstraints(minHeight: height),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: selected
              ? BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 17,
                  color: enabled ? PlayerStyle.muted : color,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color, fontSize: 13.5),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PlayerStyle.muted,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    value!,
                    style: const TextStyle(
                      color: PlayerStyle.muted,
                      fontSize: 12,
                      fontFeatures: PlayerStyle.tabular,
                    ),
                  ),
                ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.check, size: 16, color: accent),
                ),
              if (chevron)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: PlayerStyle.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section caption inside player panels.
class PlayerSectionLabel extends StatelessWidget {
  const PlayerSectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: PlayerStyle.muted, fontSize: 11.5),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Segmented choice used for aspect ratio, zoom, fit and similar sets.
class PlayerChoiceWrap<T> extends StatelessWidget {
  const PlayerChoiceWrap({
    super.key,
    required this.options,
    required this.selected,
    required this.label,
    required this.onSelected,
  });
  final List<T> options;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final accent = PlayerStyle.accent(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final option in options)
            Semantics(
              button: true,
              selected: option == selected,
              child: InkWell(
                borderRadius: BorderRadius.circular(7),
                onTap: () => onSelected(option),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: option == selected
                        ? accent
                        : const Color(0x12FFFFFF),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    label(option),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontFeatures: PlayerStyle.tabular,
                      fontWeight: option == selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: option == selected
                          ? ShadTheme.of(context).colorScheme.primaryForeground
                          : PlayerStyle.fg,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
