import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_manager.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/media/content_row.dart';
import '../../ui/icons/app_icons.dart';
import '../../ui/tokens/app_spacing.dart';
import '../../ui/components/feedback/app_feedback.dart';

/// Browses the folders of one file source, starting at its root; files play.
class FileSourceBrowserPage extends StatefulWidget {
  const FileSourceBrowserPage({
    super.key,
    required this.manager,
    required this.sourceId,
    required this.title,
    this.root,
    this.onPlay,
  });
  final SourceManager manager;
  final String sourceId;
  final String title;

  /// Where the file source starts; null browses the connection's own root.
  final ResourceRef? root;
  final ValueChanged<SourceSelection>? onPlay;
  @override
  State<FileSourceBrowserPage> createState() => _FileSourceBrowserPageState();
}

class _FileSourceBrowserPageState extends State<FileSourceBrowserPage> {
  AppLocalizations get l => AppLocalizations.of(context);
  final _folders = <SourceEntry>[];
  final _entries = <SourceEntry>[];
  int? _next;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ResourceRef? get _node => _folders.isEmpty ? widget.root : _folders.last.ref;

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.manager.load();
      final result = await widget.manager.browse(
        widget.sourceId,
        BrowseRequest(node: _node, offset: more ? _next! : 0),
      );
      if (!mounted) return;
      if (!more) _entries.clear();
      _entries.addAll(result.entries);
      _next = result.nextOffset;
    } catch (error) {
      if (mounted) {
        _error = error is PluginException ? error.message : l.loadSourcesFailed;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(SourceEntry entry) async {
    if (entry.isFolder) {
      _folders.add(entry);
      _entries.clear();
      _next = null;
      await _load();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final stream = await widget.manager.resolve(entry.ref);
      if (!mounted) {
        await stream.release();
        return;
      }
      final selection = SourceSelection(
        entry.name,
        stream,
        ref: entry.ref,
        entry: entry,
      );
      if (widget.onPlay != null) {
        widget.onPlay!(selection);
        setState(() => _busy = false);
      } else {
        Navigator.of(context).pop(selection);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is PluginException ? error.message : l.filePlayFailed;
          _busy = false;
        });
      }
    }
  }

  void _up() {
    _folders.removeLast();
    _entries.clear();
    _next = null;
    _load();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // Back goes up one folder first, then leaves the browser.
    canPop: _folders.isEmpty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_busy) _up();
    },
    child: AppPage(
      pageContext: PageContextData(
        pageType: 'file_source_browser',
        entity: {'source_id': widget.sourceId},
        state: {
          'folderDepth': _folders.length,
          'loading': _busy,
          'visibleEntryCount': _entries.length,
        },
      ),
      title: Text(_folders.isEmpty ? widget.title : _folders.last.name),
      body: Column(
        children: [
          if (_busy) ShadProgress(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  AppAlert.error(title: _error!),
                  ShadButton.ghost(
                    onPressed: _busy ? null : _load,
                    child: Text(l.retry),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: AppSpacing.page(context),
              children: [
                if (_folders.isNotEmpty)
                  ContentRow(
                    leading: Icon(AppIcons.parent),
                    title: Text(l.backToParent),
                    onTap: _busy ? null : _up,
                  ),
                if (!_busy && _error == null && _entries.isEmpty)
                  ContentRow(title: Text(l.folderEmpty)),
                for (final entry in _entries)
                  ContentRow(
                    leading: Icon(
                      entry.isFolder ? AppIcons.folder : AppIcons.playMedia,
                    ),
                    title: Text(entry.name),
                    onTap: _busy ? null : () => _open(entry),
                  ),
                if (_next != null)
                  ShadButton.ghost(
                    onPressed: _busy ? null : () => _load(more: true),
                    child: Text(l.loadMore),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
