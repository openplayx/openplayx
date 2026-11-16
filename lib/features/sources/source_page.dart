import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../ui/tokens/app_metrics.dart';
import '../../ui/tokens/app_spacing.dart';

import '../../ui/adaptive/app_page.dart';
import '../../ui/components/media/content_row.dart';
import '../../ui/icons/app_icons.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_config.dart';
import '../../data/sources/source_manager.dart';
import '../../services/library/library_service.dart';
import '../../ui/components/media/source_kind_icon.dart';
import 'file_source_actions.dart';
import 'source_instance_form.dart';
import 'source_presentation.dart';
import 'source_list_widgets.dart';
import '../../ui/components/feedback/app_feedback.dart';

class SourcePage extends StatefulWidget {
  const SourcePage({
    super.key,
    required this.manager,
    this.library,
    this.onPlay,
  });
  final SourceManager manager;

  /// File sources are grouped beneath their connection when available.
  final LibraryService? library;
  final ValueChanged<SourceSelection>? onPlay;
  @override
  State<SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends State<SourcePage> {
  AppLocalizations get l => AppLocalizations.of(context);
  SourceConfig? _source;
  FileSourceController? _files;
  StreamSubscription<void>? _libraryChanges;
  void _refresh() {
    if (mounted) setState(() {});
  }

  final _expandedConnections = <String, bool>{};
  final _nodes = <SourceEntry>[];
  final _entries = <SourceEntry>[];
  int? _next;
  String? _error;
  bool _busy = true;
  @override
  void dispose() {
    unawaited(_libraryChanges?.cancel());
    _files?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final library = widget.library;
    if (library != null) {
      // File sources are the children of their connection in the tree.
      _files = FileSourceController(
        library,
        widget.manager,
        onPlay: widget.onPlay,
      )..addListener(_refresh);
      _libraryChanges = library.changes.listen((_) => _refresh());
    }
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.manager.load();
      if (_source == null && !more) await widget.manager.reload();
      if (_source != null) {
        final result = await widget.manager.browse(
          _source!.id,
          BrowseRequest(
            node: _nodes.isEmpty ? null : _nodes.last.ref,
            offset: more ? _next! : 0,
          ),
        );
        if (!mounted) return;
        if (!more) _entries.clear();
        _entries.addAll(result.entries);
        _next = result.nextOffset;
      }
    } catch (error) {
      if (mounted) {
        _error = error is PluginException ? error.message : l.loadSourcesFailed;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(SourceEntry entry) async {
    if (entry.isFolder) {
      _nodes.add(entry);
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

  void _back() {
    if (_nodes.isNotEmpty) {
      _nodes.removeLast();
    } else {
      _source = null;
    }
    _entries.clear();
    _next = null;
    _load();
  }

  String _deletionMessage(String id) {
    final impact = widget.manager.impact(id);
    return l.deleteSourceDescription(
      _files?.service.fileSourcesOf(id).length ?? 0,
      impact.playing,
      impact.running,
    );
  }

  Future<void> _toggle(SourceConfig source, bool enabled) async {
    final impact = widget.manager.impact(source.id);
    if (!enabled && (impact.playing > 0 || impact.running > 0)) {
      final accepted = await showShadDialog<bool>(
        context: context,
        builder: (context) => ShadDialog(
          title: Text(l.disableSourceConfirm),
          actions: [
            ShadButton.ghost(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            ShadButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.disable),
            ),
          ],
          child: Text(
            l.disableSourceDescription(impact.playing, impact.running),
          ),
        ),
      );
      if (accepted != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await widget.manager.setEnabled(source.id, enabled);
      // The library hides the file sources of disabled connections.
      _files?.service.notifyChanged();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is PluginException
              ? error.message
              : l.toggleSourceFailed;
        });
      }
    }
  }

  Future<void> _edit(SourceConfig source) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            SourceInstanceForm(manager: widget.manager, initial: source),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _delete(SourceConfig source) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog(
        title: Text(l.deleteNamedSource(source.titleName)),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          ShadButton.ghost(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
        child: Text(_deletionMessage(source.id)),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.manager.remove(source.id);
      // Its file sources and what they brought in go with the connection.
      _files?.service.removeFileSourcesOf(source.id);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = l.deleteSourceFailed;
          _busy = false;
        });
      }
    }
  }

  /// Header button (top right, next to the assistant) that adds a connection.
  Future<void> _openAddSource() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SourceInstanceForm(manager: widget.manager),
      ),
    );
    if (mounted) await _load();
  }

  /// Plain ghost icon, same look as the assistant button beside it.
  Widget _addSourceButton() => Tooltip(
    message: l.addSourceConnection,
    child: Semantics(
      label: l.addSourceConnection,
      button: true,
      excludeSemantics: true,
      child: ShadIconButton.ghost(
        key: const ValueKey('add-source'),
        width: 40,
        height: 40,
        icon: const Icon(AppIcons.add),
        onPressed: _busy ? null : _openAddSource,
        enabled: !_busy,
      ),
    ),
  );

  /// Shown in the middle of the page while no source exists.
  Widget _emptySources() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShadButton(
            key: const ValueKey('add-source-empty'),
            onPressed: _busy ? null : _openAddSource,
            enabled: !_busy,
            leading: const Icon(AppIcons.add),
            child: Text(l.addSource),
          ),
        ],
      ),
    ),
  );

  void _browseConnection(SourceConfig source) {
    _source = source;
    _nodes.clear();
    _load();
  }

  /// A lightweight expandable group, with independent parent/child actions.
  Widget _connectionGroup(SourceConfig source) {
    final theme = ShadTheme.of(context);
    final files = _files;
    final bindings = files == null
        ? const <Map<String, Object?>>[]
        : files.service
              .fileSources()
              .where((binding) => binding['source'] == source.id)
              .toList();
    final expanded = _expandedConnections[source.id] ?? source.enabled;
    // Rescan of the connection: every enabled folder under it.
    final scannable = [
      for (final b in bindings)
        if (b['enabled'] == 1) b['id'] as String,
    ];
    final canScan =
        files != null &&
        !_busy &&
        source.enabled &&
        !files.scanning &&
        scannable.isNotEmpty;
    final status = SourcePresentation.summary(
      l,
      widget.manager.applicationStatus(source.id),
      widget.manager.credentialStatus(source.id).authorization,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SourceListRow(
            key: ValueKey('source-${source.id}'),
            title: source.titleName,
            expanded: expanded,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  expanded ? AppIcons.expand : AppIcons.next,
                  size: 14,
                  color: theme.colorScheme.mutedForeground,
                ),
                const SizedBox(width: AppSpacing.sm),
                SourceKindIcon(source.kind),
              ],
            ),
            subtitle: Text(
              '${source.kind == SourceKind.local ? l.localSource : source.kind.label}'
              '${files == null ? '' : ' · ${l.sourceFileCount(bindings.length)}'}',
            ),
            status: Text(
              status,
              key: ValueKey('source-status-${source.id}'),
              style: theme.textTheme.muted.copyWith(
                color:
                    SourcePresentation.needsAttention(
                      widget.manager.applicationStatus(source.id),
                      widget.manager.credentialStatus(source.id).authorization,
                    )
                    ? theme.colorScheme.destructive
                    : theme.colorScheme.mutedForeground,
              ),
            ),
            onTap: () => setState(() {
              _expandedConnections[source.id] = !expanded;
            }),
            actions: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (files != null)
                  Tooltip(
                    message: l.rescan,
                    child: ShadIconButton.ghost(
                      key: ValueKey('source-scan-${source.id}'),
                      width: AppMetrics.touchTarget,
                      height: AppMetrics.touchTarget,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      icon: const Icon(AppIcons.refresh, size: 18),
                      enabled: canScan,
                      onPressed: canScan
                          ? () => files.scan(scannable, l.scanFailedRetained)
                          : null,
                    ),
                  ),
                SourceActionsMenu(
                  key: ValueKey('source-menu-${source.id}'),
                  label: source.titleName,
                  enabled: !_busy,
                  actions: [
                    if (files != null)
                      SourceRowAction(
                        key: ValueKey('source-add-file-${source.id}'),
                        label: l.addFileSourceShort,
                        icon: AppIcons.addFolder,
                        onPressed: source.enabled && !files.scanning
                            ? () => files.add(context, source.id)
                            : null,
                      ),
                    SourceRowAction(
                      key: ValueKey('source-browse-${source.id}'),
                      label: l.browseSourceFiles,
                      icon: AppIcons.openFolder,
                      onPressed: source.enabled
                          ? () => _browseConnection(source)
                          : null,
                    ),
                    SourceRowAction(
                      key: ValueKey('source-edit-${source.id}'),
                      label: l.edit,
                      icon: AppIcons.edit,
                      onPressed: () => _edit(source),
                    ),
                    SourceRowAction(
                      key: ValueKey('source-toggle-${source.id}'),
                      label: source.enabled ? l.disable : l.fileSourceEnable,
                      icon: source.enabled ? AppIcons.pause : AppIcons.play,
                      onPressed: () => _toggle(source, !source.enabled),
                    ),
                    SourceRowAction(
                      key: ValueKey('source-delete-${source.id}'),
                      label: l.delete,
                      icon: AppIcons.delete,
                      destructive: true,
                      onPressed: () => _delete(source),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (expanded && files != null)
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: MediaQuery.sizeOf(context).width < 400 ? 40 : 48,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final binding in bindings)
                    FileSourceRow(
                      binding: binding,
                      controller: files,
                      connection: source,
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ShadButton.ghost(
                      key: ValueKey('source-add-folder-${source.id}'),
                      leading: const Icon(AppIcons.add, size: 16),
                      enabled: !_busy && source.enabled && !files.scanning,
                      onPressed: _busy || !source.enabled || files.scanning
                          ? null
                          : () => files.add(context, source.id),
                      child: Text(
                        l.addFileSourceShort,
                        style: theme.textTheme.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// File sources whose connection no longer exists stay removable.
  List<Widget> _orphanFileSources() {
    final files = _files;
    if (files == null) return const [];
    final known = {for (final c in widget.manager.configs) c.id};
    final orphans = [
      for (final b in files.service.fileSources())
        if (!known.contains(b['source'])) b,
    ];
    if (orphans.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: ShadCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ContentRow(
                leading: Icon(AppIcons.warning),
                title: Text(l.sourceNeedsSetup),
              ),
              for (final binding in orphans)
                FileSourceRow(binding: binding, controller: files),
            ],
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _source == null && !(_files?.scanning ?? false),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _source != null && !_busy) _back();
    },
    child: AppPage(
      pageContext: const PageContextData(pageType: 'sources'),
      trailing: [if (_source == null) _addSourceButton()],
      body: Column(
        children: [
          ...[
            if (_source != null)
              ContentRow(
                leading: Icon(AppIcons.parent),
                title: Text(l.backToParent),
                onTap: _busy ? null : _back,
              ),
            if (_busy) ShadProgress(),
            if (_files?.error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppAlert.error(title: _files!.error!),
              ),
            for (final issue in widget.manager.configurationIssues)
              ContentRow(
                leading: Icon(AppIcons.warning),
                title: Text(issue.message),
                subtitle: Text(issue.instanceId),
              ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    AppAlert.error(title: _error!),
                    ShadButton.ghost(
                      onPressed: _busy ? null : _load,
                      enabled: !(_busy),
                      child: Text(l.retry),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _source == null
                  ? (!_busy &&
                            widget.manager.configs.isEmpty &&
                            _orphanFileSources().isEmpty)
                        ? _emptySources()
                        : ListView(
                            padding: AppSpacing.page(context),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.lg,
                                ),
                                child: Text(
                                  l.sourcesDescription,
                                  style: ShadTheme.of(context).textTheme.muted,
                                ),
                              ),
                              for (
                                var i = 0;
                                i < widget.manager.configs.length;
                                i++
                              ) ...[
                                if (i > 0) const Divider(height: 1),
                                _connectionGroup(widget.manager.configs[i]),
                              ],
                              ..._orphanFileSources(),
                            ],
                          )
                  : ListView(
                      padding: AppSpacing.page(context),
                      children: [
                        if (!_busy && _error == null && _entries.isEmpty)
                          ContentRow(title: Text(l.folderEmpty)),
                        for (final entry in _entries)
                          ContentRow(
                            leading: Icon(
                              entry.isFolder
                                  ? AppIcons.folder
                                  : AppIcons.playMedia,
                            ),
                            title: Text(entry.name),
                            onTap: _busy ? null : () => _select(entry),
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
          ],
        ],
      ),
      title: Text(
        _nodes.isNotEmpty ? _nodes.last.name : _source?.name ?? l.sources,
      ),
    ),
  );
}
