import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_manager.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/artwork/artwork_service.dart';
import '../../services/library/library_service.dart';
import 'media_detail_page.dart';
import '../../ui/components/feedback/app_feedback.dart';

/// Opening a library item's detail page and playing one of its versions,
/// shared by the home shelves and the library poster wall.
mixin MediaOpener<T extends StatefulWidget> on State<T> {
  SourceManager get openerSources;
  LibraryService? get openerService;
  ArtworkService get openerArtwork;
  ValueChanged<SourceSelection>? get openerPlay;

  bool _resolvingResource = false;

  Future<PlayableStream> _resolveResource(ResourceRef ref) async {
    if (ref.instanceId == '@local') {
      final missing = AppLocalizations.of(context).localUnavailable;
      if (!await File(ref.id).exists()) throw StateError(missing);
      return PlayableStream(Uri.file(ref.id));
    }
    return openerSources.resolve(ref);
  }

  String resourceLabel(dynamic resource) {
    final l = AppLocalizations.of(context);
    final service = openerService!;
    final checkpoint = service.checkpoint(resource['id'] as String);
    final progress = checkpoint != null && checkpoint['completed'] == 0
        ? l.watchedMinutes((checkpoint['position'] as int) ~/ 60000)
        : checkpoint?['completed'] == 1
        ? l.watchedSuffix
        : '';
    if (resource['source'] == '@local') return l.localResource(progress);
    final source = openerSources.configs
        .where((c) => c.id == resource['source'] && c.enabled)
        .firstOrNull;
    if (source == null) return l.setupResource(progress);
    return '${source.displayName} · ${service.observedMissing(resource['id'] as String) ? l.missingOnScan : l.verifyOnPlay}$progress';
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

  Future<void> playResource(BuildContext detail, dynamic resource) async {
    if (_resolvingResource) return;
    _resolvingResource = true;
    try {
      final ref = ResourceRef(
        resource['source'] as String,
        resource['item'] as String,
      );
      final stream = await _resolveResource(ref);
      if (!mounted || !detail.mounted) {
        await stream.release();
        return;
      }
      final selection = SourceSelection(
        resource['name'] as String,
        stream,
        ref: ref,
      );
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
