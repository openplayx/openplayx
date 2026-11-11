import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/plugins/metadata_capability.dart';
import '../../services/artwork/artwork_service.dart';
import '../../ui/icons/app_icons.dart';

class MetadataArtwork extends StatefulWidget {
  const MetadataArtwork({
    super.key,
    required this.service,
    required this.artwork,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth = 600,
    this.placeholder,
    this.fadeIn = false,
  });
  final ArtworkService service;
  final ArtworkDescriptor artwork;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;

  /// Decode width in physical pixels; null decodes at full resolution.
  final int? cacheWidth;

  /// Shown while loading and on failure; defaults to a movie icon.
  final Widget? placeholder;

  /// Cross-fades the image in once decoded instead of popping in.
  final bool fadeIn;
  @override
  State<MetadataArtwork> createState() => _MetadataArtworkState();
}

class _MetadataArtworkState extends State<MetadataArtwork> {
  late Future<File> _file;
  late String _cacheKey;
  @override
  void initState() {
    super.initState();
    _cacheKey = widget.service.cacheKey(widget.artwork);
    _file = widget.service.load(widget.artwork);
  }

  @override
  void didUpdateWidget(covariant MetadataArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = widget.service.cacheKey(widget.artwork);
    if (nextKey != _cacheKey || oldWidget.service != widget.service) {
      _cacheKey = nextKey;
      _file = widget.service.load(widget.artwork);
    }
  }

  Widget get _placeholder =>
      widget.placeholder ??
      SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(child: Icon(AppIcons.movie, size: 40)),
      );
  @override
  Widget build(BuildContext context) => FutureBuilder<File>(
    future: _file,
    builder: (_, snapshot) => snapshot.hasData
        ? Image.file(
            snapshot.data!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            alignment: widget.alignment,
            cacheWidth: widget.cacheWidth,
            errorBuilder: (_, _, _) => _placeholder,
            frameBuilder: widget.fadeIn
                ? (_, child, frame, sync) => sync
                      ? child
                      : AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 250),
                          child: child,
                        )
                : null,
          )
        : _placeholder,
  );
}
