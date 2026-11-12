import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/plugins/metadata_capability.dart';
import '../../services/artwork/artwork_service.dart';

/// Title art: the first transparent logo among [logos], else [fallback].
///
/// A cached logo shows on the first frame. While a logo is still downloading
/// the space stays blank instead of flashing the text title; the text only
/// appears when no logo qualifies, or after [patience] so a slow network does
/// not leave a hole (a logo arriving later then cross-fades in).
class TitleLogo extends StatefulWidget {
  const TitleLogo({
    super.key,
    required this.service,
    required this.logos,
    required this.fallback,
    this.maxHeight = 80,
    this.cacheWidth = 800,
    this.patience = const Duration(seconds: 3),
  });
  final ArtworkService service;

  /// Candidates in preference order, see [ArtworkService.orderedLogos].
  final List<ArtworkDescriptor> logos;
  final Widget fallback;
  final double maxHeight;
  final int cacheWidth;
  final Duration patience;

  @override
  State<TitleLogo> createState() => _TitleLogoState();
}

class _TitleLogoState extends State<TitleLogo> {
  ArtworkDescriptor? _logo;
  File? _file;
  bool _showText = false;
  Timer? _timer;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant TitleLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.logos.map((a) => a.id).join('\n');
    final oldIds = oldWidget.logos.map((a) => a.id).join('\n');
    if (ids != oldIds || widget.service != oldWidget.service) _resolve();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resolve() {
    final generation = ++_generation;
    _timer?.cancel();
    _logo = null;
    _file = null;
    _showText = widget.logos.isEmpty;
    if (_showText) return;
    final cached = widget.service.cachedLogo(widget.logos);
    if (cached != null) {
      _logo = cached.logo;
      _file = cached.file;
      _showText = cached.logo == null;
      return;
    }
    _timer = Timer(widget.patience, () {
      if (mounted && generation == _generation) {
        setState(() => _showText = true);
      }
    });
    unawaited(() async {
      final logo = await widget.service.resolveLogo(widget.logos);
      File? file;
      if (logo != null) {
        try {
          file = await widget.service.load(logo);
        } on Object {
          file = null;
        }
      }
      if (!mounted || generation != _generation) return;
      _timer?.cancel();
      setState(() {
        _logo = file == null ? null : logo;
        _file = file;
        _showText = file == null;
      });
    }());
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_file != null) {
      child = Image.file(
        _file!,
        key: ValueKey(_logo!.id),
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        cacheWidth: widget.cacheWidth,
        errorBuilder: (_, _, _) => widget.fallback,
      );
    } else if (_showText) {
      child = KeyedSubtree(key: const ValueKey('text'), child: widget.fallback);
    } else {
      // Reserve roughly the logo's eventual height so the buttons below do
      // not jump when it lands.
      final first = widget.logos.first;
      final aspect = (first.width ?? 0) > 0 && (first.height ?? 0) > 0
          ? first.width! / first.height!
          : null;
      child = LayoutBuilder(
        key: const ValueKey('blank'),
        builder: (_, c) => SizedBox(
          height: aspect == null || !c.maxWidth.isFinite
              ? widget.maxHeight
              : math.min(widget.maxHeight, c.maxWidth / aspect),
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.bottomCenter,
          children: [...previous, ?current],
        ),
        child: child,
      ),
    );
  }
}
