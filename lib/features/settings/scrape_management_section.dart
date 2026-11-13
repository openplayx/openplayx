import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/sources/source_manager.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/artwork/artwork_service.dart';
import '../../services/library/library_service.dart';
import '../../ui/components/settings/settings_adaptive.dart';
import '../../ui/components/settings/settings_section.dart';

/// Shows how much scraped metadata is stored and clears all of it.
class ScrapeManagementSection extends StatefulWidget {
  const ScrapeManagementSection({
    super.key,
    required this.library,
    required this.sources,
    this.artwork,
  });
  final LibraryService library;
  final SourceManager sources;

  /// Overridable for tests; defaults to the shared on-disk artwork cache.
  final ArtworkService? artwork;

  /// Human-readable size, e.g. `12.3 MB`.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB'];
    var value = bytes / 1024;
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(1)} ${units[unit]}';
  }

  @override
  State<ScrapeManagementSection> createState() =>
      _ScrapeManagementSectionState();
}

class _ScrapeManagementSectionState extends State<ScrapeManagementSection> {
  late final ArtworkService _artwork =
      widget.artwork ?? ArtworkService(widget.sources);
  StreamSubscription<void>? _changes;
  Timer? _debounce;
  int? _count, _databaseBytes, _artworkBytes;
  late int _quotaMb = widget.sources.artworkCacheQuotaMb;
  bool _busy = false;
  String? _message;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Background scraping keeps adding items; refresh the numbers calmly.
    _changes = widget.library.changes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 2), _refresh);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _changes?.cancel();
    if (widget.artwork == null) _artwork.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted || _busy) return;
    final stats = widget.library.metadata.scrapedStats();
    int artwork;
    try {
      artwork = await _artwork.cacheBytes();
    } catch (_) {
      artwork = 0;
    }
    if (!mounted) return;
    setState(() {
      _count = stats.media;
      _databaseBytes = stats.bytes;
      _artworkBytes = artwork;
    });
  }

  Future<void> _setQuota(int value) async {
    final previous = _quotaMb;
    setState(() {
      _quotaMb = value;
      _message = null;
      _failed = false;
    });
    try {
      await widget.sources.setArtworkCacheQuotaMb(value);
      // A lower limit applies now, not only on the next download.
      if (value < previous) await _artwork.trim();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quotaMb = previous;
        _failed = true;
        _message = AppLocalizations.of(context).preferenceSaveFailed;
      });
      return;
    }
    await _refresh();
  }

  Future<void> _clear() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showSettingsConfirm(
      context,
      title: l.scrapeClearTitle,
      message: l.scrapeClearDescription,
      confirmLabel: l.scrapeClear,
      cancelLabel: l.cancel,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
    });
    // Let the progress indicator paint before the synchronous database work.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      widget.library.metadata.clearScraped();
      try {
        await _artwork.clear();
      } catch (_) {
        // Images still loading elsewhere are re-fetched on demand later.
      }
      _message = l.scrapeCleared;
    } catch (_) {
      _failed = true;
      _message = l.scrapeClearFailed;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ready = _count != null;
    return SettingsSection(
      title: l.scrapeManagement,
      children: [
        SettingsRow(
          title: l.scrapedCount,
          control: Text(
            ready ? l.scrapedCountValue(_count!) : l.scrapeLoading,
            key: const ValueKey('scrape-count'),
          ),
        ),
        SettingsRow(
          title: l.scrapeStorage,
          description: ready
              ? l.scrapeStorageDetail(
                  ScrapeManagementSection.formatBytes(_databaseBytes!),
                  ScrapeManagementSection.formatBytes(_artworkBytes!),
                )
              : null,
          control: Text(
            ready
                ? ScrapeManagementSection.formatBytes(
                    _databaseBytes! + _artworkBytes!,
                  )
                : l.scrapeLoading,
            key: const ValueKey('scrape-size'),
          ),
        ),
        SettingsChoiceRow<int>(
          key: const ValueKey('artwork-cache-limit'),
          title: l.artworkCacheLimit,
          description: l.artworkCacheLimitDescription,
          value: _quotaMb,
          enabled: !_busy,
          options: {
            for (final mb in SourceManager.artworkCacheQuotaChoicesMb)
              mb: mb >= 1024 ? '${mb ~/ 1024} GB' : '$mb MB',
          },
          onChanged: _setQuota,
        ),
        SettingsRow(
          key: const ValueKey('scrape-clear'),
          title: l.scrapeClear,
          destructive: true,
          onTap: !_busy && ready ? _clear : null,
        ),
        if (_busy) const ShadProgress(),
        if (_message != null)
          _failed
              ? ShadAlert.destructive(title: Text(_message!))
              : ShadAlert(title: Text(_message!)),
      ],
    );
  }
}
