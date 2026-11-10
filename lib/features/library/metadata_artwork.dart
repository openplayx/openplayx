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
  });
  final ArtworkService service;
  final ArtworkDescriptor artwork;
  final double? width;
  final double? height;
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

  Widget get _placeholder => SizedBox(
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
            fit: BoxFit.cover,
            cacheWidth: 600,
            errorBuilder: (_, _, _) => _placeholder,
          )
        : _placeholder,
  );
}
