import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_config.dart';
import '../../data/sources/source_manager.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/library/library_service.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/media/content_row.dart';
import '../../ui/icons/app_icons.dart';
import 'file_source_browser_page.dart';

Future<String?> _promptText(
  BuildContext context,
  String title, {
  String initial = '',
}) {
  final l = AppLocalizations.of(context);
  var value = initial;
  return showShadDialog<String>(
    context: context,
    builder: (context) => ShadDialog(
      title: Text(title),
      actions: [
        ShadButton.ghost(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        ShadButton(
          onPressed: () {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
          child: Text(l.save),
        ),
      ],
      child: ShadInput(
        initialValue: initial,
        onChanged: (text) => value = text,
        autofocus: true,
      ),
    ),
  );
}

/// Adding, scanning, renaming and removing file sources. File sources are the
/// children of a connection (a connection plus one chosen folder); the media
/// library page only shows the combined poster wall of the enabled ones.
class FileSourceController extends ChangeNotifier {
  FileSourceController(this.service, this.sources, {this.onPlay});
  final LibraryService service;
  final SourceManager sources;
  final ValueChanged<SourceSelection>? onPlay;
  bool scanning = false;
  String? error;
  Timer? _refresh;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> scan(List<String> bindings, String failedMessage) async {
    scanning = true;
    error = null;
    _notify();
    // The found-so-far counter is read from the database, so poll for it.
    _refresh = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _notify();
    });
    try {
      for (final binding in bindings) {
        try {
          await service.scan(binding, sources);
        } catch (_) {
          // One failing source keeps its own error and must not block others.
          error = failedMessage;
        }
      }
    } finally {
      _refresh?.cancel();
      scanning = false;
      _notify();
    }
  }

  /// VidHub-style flow: tick one folder of [connection], name it, finish. The
  /// new file source is scanned right away.
  Future<void> add(BuildContext context, String connection) async {
    final l = AppLocalizations.of(context);
    try {
      final scope = await Navigator.of(context).push<SourceEntry>(
        MaterialPageRoute(
          builder: (_) => _ScopePage(sources: sources, source: connection),
        ),
      );
      if (scope == null || !context.mounted) return;
      final config = sources.configs
          .where((c) => c.id == connection)
          .firstOrNull;
      final name = await _promptText(
        context,
        l.nameFileSource,
        initial: scope.ref.id.isEmpty
            ? config?.titleName ?? scope.name
            : scope.name,
      );
      if (name == null || !context.mounted) return;
      final binding = service.bind(
        service.defaultLibrary(),
        connection,
        root: scope.ref.id.isEmpty ? null : scope.ref.id,
        name: name,
        rootEntry: scope,
      );
      await scan([binding], l.scanFailedRetained);
    } catch (_) {
      error = l.bindFailed;
      _notify();
    }
  }

  Future<void> rename(BuildContext context, String id, String current) async {
    final name = await _promptText(
      context,
      AppLocalizations.of(context).nameFileSource,
      initial: current,
    );
    if (name != null) service.renameBinding(id, name);
  }

  Future<void> remove(BuildContext context, String id) async {
    final l = AppLocalizations.of(context);
    final count = service.bindingImpact(id);
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (c) => ShadDialog(
        title: Text(l.removeFileSourceConfirm),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cancel),
          ),
          ShadButton.ghost(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.remove),
          ),
        ],
        child: Text(l.removeBindingDescription(count)),
      ),
    );
    if (confirmed == true) service.removeBinding(id);
  }
}

/// One file source, shown as a child of its connection.
class FileSourceRow extends StatelessWidget {
  const FileSourceRow({
    super.key,
    required this.binding,
    required this.controller,
    this.connection,
  });
  final sql.Row binding;
  final FileSourceController controller;
  final SourceConfig? connection;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final service = controller.service;
    final busy = controller.scanning;
    final id = binding['id'] as String;
    final enabled = binding['enabled'] == 1;
    final title =
        (binding['name'] as String?) ??
        connection?.displayName ??
        l.sourceNeedsSetup;
    final scanning = enabled && binding['status'] == '扫描中';
    final status = enabled
        ? '${binding['status']}${scanning ? ' · ${l.scanFoundMedia(service.scannedMediaCount(id))}' : ''}'
        : l.fileSourceDisabled;
    final root = binding['root'] as String? ?? '';
    Widget action(String tip, IconData icon, VoidCallback? onPressed) =>
        Tooltip(
          message: tip,
          child: Semantics(
            button: true,
            label: tip,
            child: ShadIconButton.ghost(
              onPressed: onPressed,
              icon: Icon(icon),
              enabled: onPressed != null,
              width: 48,
              height: 48,
            ),
          ),
        );
    return ContentRow(
      dense: true,
      leading: Icon(AppIcons.folder),
      title: Text(title),
      // Tapping a file source browses its folders.
      onTap: !enabled || connection == null || !connection!.enabled
          ? null
          : () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => FileSourceBrowserPage(
                  manager: controller.sources,
                  sourceId: connection!.id,
                  title: title,
                  root: root.isEmpty ? null : ResourceRef(connection!.id, root),
                  onPlay: controller.onPlay,
                ),
              ),
            ),
      subtitle: Text(
        '$status${binding['error'] == null ? '' : ' · ${binding['error']}'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: enabled ? l.fileSourceDisable : l.fileSourceEnable,
            child: ShadSwitch(
              value: enabled,
              onChanged: busy
                  ? null
                  : (value) => service.setBindingEnabled(id, value),
            ),
          ),
          action(
            l.rescan,
            AppIcons.refresh,
            busy || !enabled
                ? null
                : () => controller.scan([id], l.scanFailedRetained),
          ),
          action(
            l.renameLibrary,
            AppIcons.rename,
            busy ? null : () => controller.rename(context, id, title),
          ),
          action(
            l.removeFileSource,
            AppIcons.delete,
            busy ? null : () => controller.remove(context, id),
          ),
        ],
      ),
    );
  }
}

class _ScopePage extends StatefulWidget {
  const _ScopePage({required this.sources, required this.source});
  final SourceManager sources;
  final String source;
  @override
  State<_ScopePage> createState() => _ScopePageState();
}

class _ScopePageState extends State<_ScopePage> {
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
