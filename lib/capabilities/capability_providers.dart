import '../data/sources/source_config.dart';
import '../l10n/l10n.dart';
import 'capability_switches.dart';
import 'media_processing/media_processing_service.dart';
import 'sources/source_manager.dart';

/// A capability provider the user can switch off App-wide.
class CapabilityProvider {
  const CapabilityProvider._(this.id, {this.sourceKind});

  /// Switch id (`source.smb`, `media.ffmpeg`, `asr.whisper`).
  final String id;
  final SourceKind? sourceKind;

  static const ffmpegId = MediaProcessingService.providerId;
  static const speechId = 'asr.whisper';

  /// Every switchable provider: the source kinds, FFmpeg and speech
  /// recognition.
  static final all = List<CapabilityProvider>.unmodifiable([
    for (final kind in SourceKind.values)
      CapabilityProvider._('source.${kind.name}', sourceKind: kind),
    const CapabilityProvider._(ffmpegId),
    const CapabilityProvider._(speechId),
  ]);

  static CapabilityProvider? byId(String id) =>
      all.where((p) => p.id == id).firstOrNull;

  String get name => switch (sourceKind) {
    final kind? => kind.label,
    null => id == ffmpegId ? appStrings.catFfmpegName : appStrings.catAsrName,
  };

  String get summary => switch (sourceKind) {
    SourceKind.local => appStrings.catSummaryLocal,
    SourceKind.smb => appStrings.catSummarySmb,
    SourceKind.webdav => appStrings.catSummaryWebdav,
    SourceKind.onedrive ||
    SourceKind.dropbox ||
    SourceKind.baidu => appStrings.catSummaryCloudDrive,
    SourceKind.ftp => appStrings.catSummaryFtp,
    SourceKind.sftp => appStrings.catSummarySftp,
    SourceKind.s3 => appStrings.catSummaryS3,
    SourceKind.plex => appStrings.catSummaryPlex,
    SourceKind.jellyfin => appStrings.catSummaryJellyfin,
    SourceKind.emby => appStrings.catSummaryEmby,
    SourceKind.dlna => appStrings.catSummaryDlna,
    null =>
      id == ffmpegId ? appStrings.catFfmpegSummary : appStrings.catAsrSummary,
  };

  /// Providers that must be on for this one to work.
  List<CapabilityProvider> get dependencies => [
    for (final dep in capabilityDependencies[id] ?? const <String>[])
      ?byId(dep),
  ];

  /// Playback sessions and tasks that switching this provider off would
  /// interrupt (sources only; media and speech tasks finish on their own).
  SourceInstanceImpact impact(SourceManager sources) {
    final kind = sourceKind;
    if (kind == null) return const SourceInstanceImpact();
    var playing = 0, running = 0;
    for (final c in sources.configs.where((c) => c.kind == kind)) {
      final i = sources.impact(c.id);
      playing += i.playing;
      running += i.running;
    }
    return SourceInstanceImpact(playing: playing, running: running);
  }
}
