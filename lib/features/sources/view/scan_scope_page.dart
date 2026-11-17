import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../capabilities/sources/source_manager.dart';
import '../../../core/capabilities/source_capability.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../ui/adaptive/app_page.dart';
import '../../../ui/components/media/content_row.dart';
import '../../../ui/icons/app_icons.dart';

/// Picks the folder of a connection that a new file source scans.
class ScanScopePage extends StatefulWidget {
  const ScanScopePage({super.key, required this.sources, required this.source});
  final SourceManager sources;
  final String source;
  @override
  State<ScanScopePage> createState() => _ScanScopePageState();
}

class _ScanScopePageState extends State<ScanScopePage> {
  AppLocalizations get l => AppLocalizations.of(context);
  final List<SourceEntry> _path = [];
  List<SourceEntry> _folders = [];
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
          _next = page.nextOffset;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = l.browseFailed);
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
          ShadButton.ghost(onPressed: () => _load(), child: Text(_error!)),
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
            onPressed: _busy || _error != null
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
            enabled: !(_busy || _error != null),
            child: Text(l.confirmScanScope),
          ),
        ),
      ],
    ),
    title: Text(_path.lastOrNull?.name ?? l.chooseScanScope),
  );
}
