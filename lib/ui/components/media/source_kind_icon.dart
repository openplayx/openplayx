import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../data/sources/source_config.dart';
import '../../icons/app_icons.dart';

/// A recognisable mark for each kind of source, so connections can be told
/// apart at a glance: the Plex, Jellyfin and Emby marks, and a distinct
/// coloured symbol for each file protocol.
class SourceKindIcon extends StatelessWidget {
  const SourceKindIcon(this.kind, {super.key, this.size = 36});
  final SourceKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final inner = size * 0.58;
    Widget glyph(IconData icon, Color color) =>
        Icon(icon, size: inner, color: color);
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
      SourceKind.emby => SvgPicture.asset(
        'assets/branding/emby.svg',
        width: inner,
        height: inner,
      ),
      SourceKind.smb => glyph(AppIcons.server, const Color(0xFF2F80ED)),
      SourceKind.local => glyph(AppIcons.folder, const Color(0xFFF59E0B)),
      SourceKind.webdav => glyph(LucideIcons.globe, const Color(0xFF0EA5E9)),
      SourceKind.ftp => glyph(LucideIcons.hardDrive, const Color(0xFF8B5CF6)),
      SourceKind.sftp => glyph(LucideIcons.terminal, const Color(0xFF10B981)),
      SourceKind.s3 => glyph(LucideIcons.database, const Color(0xFFF97316)),
      SourceKind.dlna => glyph(LucideIcons.cast, const Color(0xFFEC4899)),
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
