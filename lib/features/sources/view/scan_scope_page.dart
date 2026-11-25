import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../capabilities/sources/source_manager.dart';
import '../../../core/capabilities/source_capability.dart';
import '../../../data/sources/source_config.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../ui/adaptive/app_page.dart';
import '../../../ui/components/media/content_row.dart';
import '../../../ui/icons/app_icons.dart';

/// Picks the folder of a connection that a new file source scans.
class ScanScopePage extends StatefulWidget {
  const ScanScopePage({
    super.key,
    required this.sources,
    required this.source,
    this.forHome = false,
    this.requireFolder = false,
  });
  final SourceManager sources;
  final String source;
  final bool forHome;
  final bool requireFolder;
  @override
  State<ScanScopePage> createState() => _ScanScopePageState();
}

class _ScanScopePageState extends State<ScanScopePage> {
  AppLocalizations get l => AppLocalizations.of(context);
  final List<SourceEntry> _path = [];
  List<SourceEntry> _folders = [];
  List<SourceEntry> _files = [];
  int? _next;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
      if (!more) {
        _folders = [];
        _files = [];
        _next = null;
      }
    });
    try {
      final page = await widget.sources.browse(
        widget.source,
        BrowseRequest(node: _path.lastOrNull?.ref, offset: more ? _next! : 0),
      );
      if (mounted) {
        setState(() {
          _folders = [
            ...(more ? _folders : <SourceEntry>[]),
            ...page.entries.where((e) => e.isFolder),
          ];
          _files = [
            ...(more ? _files : <SourceEntry>[]),
            ...page.entries.where(
              (e) =>
                  !e.isFolder &&
                  (e.isDisc ||
                      matchesScanExtension(
                        e.name,
                        widget.sources.scanExtensions,
                      )),
            ),
          ];
          _next = page.nextOffset;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is PluginException ? error.message : l.browseFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    pageContext: const PageContextData(pageType: 'scan_scope_picker'),
    body: Column(
      children: [
        Padding(padding: EdgeInsets.all(16), child: Text(l.scopeDescription)),
        if (_busy) ShadProgress(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(_error!),
                ShadButton.ghost(
                  onPressed: _busy ? null : () => _load(),
                  child: Text(l.retry),
                ),
              ],
            ),
          ),
        if (_path.isNotEmpty)
          ContentRow(
            title: Text(l.parent),
            onTap: _busy
                ? null
                : () {
                    _path.removeLast();
                    _load();
                  },
          ),
        Expanded(
          child: ListView(
            children: [
              for (final folder in _folders)
                ContentRow(
                  leading: Icon(AppIcons.folder),
                  title: Text(folder.name),
                  onTap: _busy
                      ? null
                      : () {
                          _path.add(folder);
                          _load();
                        },
                ),
              for (final file in _files)
                ContentRow(
                  leading: Icon(AppIcons.playMedia),
                  title: Text(file.name),
                ),
              if (_next != null)
                ShadButton.ghost(
                  onPressed: _busy ? null : () => _load(more: true),
                  enabled: !(_busy),
                  child: Text(l.loadMore),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: ShadButton(
            onPressed:
                _busy ||
                    _error != null ||
                    (widget.requireFolder && _path.isEmpty)
                ? null
                : () => Navigator.pop(
                    context,
                    _path.lastOrNull ??
                        SourceEntry(
                          ResourceRef(widget.source, ''),
                          l.rootFolder,
                          isFolder: true,
                        ),
                  ),
            enabled:
                !(_busy ||
                    _error != null ||
                    (widget.requireFolder && _path.isEmpty)),
            child: Text(widget.forHome ? l.addAndShowHome : l.confirmScanScope),
          ),
        ),
      ],
    ),
    title: Text(_path.lastOrNull?.name ?? l.chooseScanScope),
  );
}
