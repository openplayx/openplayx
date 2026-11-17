import 'package:flutter/material.dart';

import '../../../capabilities/playback/playback_launcher.dart';
import '../../../capabilities/sources/source_manager.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../capabilities/artwork/artwork_service.dart';
import '../../../capabilities/library/library_service.dart';
import '../../../capabilities/library/media_models.dart';
import 'media_detail_page.dart';
import '../../../ui/components/feedback/app_feedback.dart';

/// Opening a library item's detail page and playing one of its versions,
/// shared by the home shelves and the library poster wall.
mixin MediaOpener<T extends StatefulWidget> on State<T> {
  SourceManager get openerSources;
  LibraryService? get openerService;
  ArtworkService get openerArtwork;
  ValueChanged<SourceSelection>? get openerPlay;

  bool _resolvingResource = false;

  String resourceLabel(MediaVersion version) {
    final l = AppLocalizations.of(context);
    final service = openerService!;
    final watched = service.progressOf(version.id);
    final progress = watched == null
        ? ''
        : watched.completed
        ? l.watchedSuffix
        : l.watchedMinutes(watched.position.inMinutes);
    final source = version.ref.instanceId;
    if (source == '@local') return l.localResource(progress);
    final config = openerSources.configs
        .where((c) => c.id == source && c.enabled)
        .firstOrNull;
    if (config == null) return l.setupResource(progress);
    return '${config.displayName} · ${service.observedMissing(version.id) ? l.missingOnScan : l.verifyOnPlay}$progress';
  }

  /// Movies and plain videos open the movie page, series the episode page.
  Future<void> openDetail(dynamic media, {BuildContext? from}) async {
    await Navigator.of(from ?? context).push<void>(
      MaterialPageRoute(
        builder: (_) => MediaDetailPage(
          service: openerService!,
          sources: openerSources,
          artwork: openerArtwork,
          media: media,
          play: playResource,
          resourceLabel: resourceLabel,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> playResource(BuildContext detail, MediaVersion version) async {
    if (_resolvingResource) return;
    _resolvingResource = true;
    try {
      final selection = await PlaybackLauncher(openerSources).select(
        version.ref,
        version.name,
        wanted: () => mounted && detail.mounted,
      );
      if (selection == null) return;
      if (!mounted || !detail.mounted) {
        await selection.stream.release();
        return;
      }
      if (openerPlay != null) {
        openerPlay!(selection);
      } else {
        Navigator.pop(detail);
        Navigator.pop(context, selection);
      }
    } catch (_) {
      if (detail.mounted) {
        showAppToast(
          detail,
          AppLocalizations.of(detail).versionOpenFailed,
          kind: FeedbackKind.error,
        );
      }
    } finally {
      _resolvingResource = false;
    }
  }
}
