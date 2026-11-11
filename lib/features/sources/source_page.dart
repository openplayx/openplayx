import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../ui/tokens/app_spacing.dart';

import '../../ui/adaptive/app_page.dart';
import '../../ui/components/media/content_row.dart';
import '../../ui/components/swipe_reveal.dart';
import '../../ui/icons/app_icons.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_config.dart';
import '../../data/sources/source_manager.dart';
import '../../services/library/library_service.dart';
import '../../ui/components/media/source_kind_icon.dart';
import 'file_source_actions.dart';
import 'source_instance_form.dart';
import 'source_presentation.dart';

class SourcePage extends StatefulWidget {
  const SourcePage({
    super.key,
    required this.manager,
    this.library,
    this.onPlay,
  });
  final SourceManager manager;

  /// When provided, the page offers a second "file sources" tab next to the
  /// connections.
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
    return l.deleteSourceDescription(impact.playing, impact.running);
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
  Widget _addSourceButton() => ShadButton.ghost(
    key: const ValueKey('add-source'),
    onPressed: _busy
        ? null
        : () async {
            await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => SourceInstanceForm(manager: widget.manager),
              ),
            );
            if (mounted) await _load();
          },
    leading: Icon(AppIcons.add),
    enabled: !_busy,
    child: Text(l.addSourceShort),
  );

  /// A connection with its file sources nested below it: a two-level tree.
  Widget _connectionCard(SourceConfig source) {
    final files = _files;
    final children = files == null
        ? const <Widget>[]
        : [
            for (final binding in files.service.fileSources())
              if (binding['source'] == source.id)
                FileSourceRow(
                  binding: binding,
                  controller: files,
                  connection: source,
                ),
          ];
    final actions = [
      if (files != null)
        SwipeAction(
          key: ValueKey('source-add-file-${source.id}'),
          label: l.addFileSourceShort,
          onPressed: source.enabled && !files.scanning
              ? () => files.add(context, source.id)
              : null,
        ),
      SwipeAction(
        key: ValueKey('source-edit-${source.id}'),
        label: l.edit,
        onPressed: () => _edit(source),
      ),
      SwipeAction(
        key: ValueKey('source-delete-${source.id}'),
        label: l.delete,
        destructive: true,
        onPressed: () => _delete(source),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ShadCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Swiping left reveals add file source, edit and delete.
            SwipeReveal(
              key: ValueKey('source-${source.id}'),
              enabled: !_busy,
              actionWidth: SwipeActionBar.width * actions.length + 4,
              trailingInset: AppSpacing.md,
              action: (close) => SwipeActionBar(actions: actions, close: close),
              child: ContentRow(
                leading: SourceKindIcon(source.kind),
                title: Text(source.titleName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.sourceVersion(
                        source.kind == SourceKind.local
                            ? l.localSource
                            : source.kind.label,
                        source.pluginVersion,
                        source.configVersion,
                        source.revision,
                      ),
                    ),
                    Text(
                      SourcePresentation.application(
                        l,
                        widget.manager.applicationStatus(source.id),
                      ),
                    ),
                    Text(
                      SourcePresentation.credential(
                        l,
                        widget.manager
                            .credentialStatus(source.id)
                            .authorization,
                      ),
                    ),
                  ],
                ),
                trailing: Semantics(
                  label: source.titleName,
                  child: ShadSwitch(
                    value: source.enabled,
                    onChanged: _busy
                        ? null
                        : (enabled) => _toggle(source, enabled),
                    enabled: !_busy,
                  ),
                ),
                onTap: _busy || !source.enabled
                    ? null
                    : () {
                        _source = source;
                        _load();
                      },
              ),
            ),
            if (children.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 28, bottom: 4),
                padding: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: ShadTheme.of(context).colorScheme.border,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [...children],
                ),
              ),
          ],
        ),
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
            if (_busy || (_files?.scanning ?? false)) ShadProgress(),
            if (_files?.error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ShadAlert.destructive(title: Text(_files!.error!)),
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
                    ShadAlert.destructive(title: Text(_error!)),
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
                  ? ListView(
                      padding: AppSpacing.page(context),
                      children: [
                        if (!_busy && widget.manager.configs.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(l.sourcesEmpty),
                          ),
                        for (final source in widget.manager.configs)
                          _connectionCard(source),
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

/// The secondary actions of one connection, collapsed into a "more" menu so the
/// row keeps a single line of controls (enable switch + menu).
