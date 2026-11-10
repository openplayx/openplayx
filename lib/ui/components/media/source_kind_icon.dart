import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../data/sources/source_config.dart';
import '../../icons/app_icons.dart';

/// A recognisable mark for each kind of source, so connections can be told
/// apart at a glance: the Plex and Jellyfin marks, a network drive for SMB and
/// a folder for local folders.
class SourceKindIcon extends StatelessWidget {
  const SourceKindIcon(this.kind, {super.key, this.size = 36});
  final SourceKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final inner = size * 0.58;
    final Widget mark = switch (kind) {
      SourceKind.plex => SvgPicture.asset(
        'assets/branding/plex.svg',
        width: inner,
        height: inner,
      ),
      SourceKind.jellyfin => SvgPicture.asset(
        'assets/branding/jellyfin.svg',
        width: inner,
        height: inner,
      ),
      SourceKind.smb => Icon(
        AppIcons.server,
        size: inner,
        color: const Color(0xFF2F80ED),
      ),
      SourceKind.local => Icon(
        AppIcons.folder,
        size: inner,
        color: const Color(0xFFF59E0B),
      ),
    };
    return Semantics(
      label: kind.label,
      image: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.muted,
          borderRadius: BorderRadius.circular(size * 0.25),
        ),
        child: mark,
      ),
    );
  }
}
