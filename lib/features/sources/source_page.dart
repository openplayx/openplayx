import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

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
import 'source_defaults_page.dart';
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
  StreamIterator<SourceEntry>? _scanIterator;
  @override
  void dispose() {
    unawaited(_scanIterator?.cancel());
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
      impact.defaultCapabilities.length,
      impact.playing,
      impact.running,
    );
  }

  Future<void> _scan(SourceConfig config) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final entries = <SourceEntry>[];
      final iterator = StreamIterator(widget.manager.scan(config.id));
      _scanIterator = iterator;
      try {
        while (await iterator.moveNext()) {
          entries.add(iterator.current);
        }
      } finally {
        await iterator.cancel();
        _scanIterator = null;
      }
      if (!mounted) return;
      await showShadDialog<void>(
        context: context,
        builder: (context) => ShadDialog(
          title: Text(l.previewTitle(config.titleName)),
          actions: [
            ShadButton.ghost(
              onPressed: () => Navigator.pop(context),
              child: Text(l.close),
            ),
          ],
          child: SizedBox(
            width: 480,
            height: 320,
            child: ListView(
              children: [
                Text(
                  entries.length >= 500
                      ? l.previewLimit
                      : l.filesFound(entries.length),
                ),
                Text(l.previewDescription),
                for (final entry in entries)
                  ContentRow(title: Text(entry.name)),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _error = error is PluginException ? error.message : l.scanFailed;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(SourceConfig source, bool enabled) async {
    final impact = widget.manager.impact(source.id);
    if (!enabled &&
        (impact.playing > 0 ||
            impact.running > 0 ||
            impact.defaultCapabilities.isNotEmpty)) {
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
            l.disableSourceDescription(
              impact.playing,
              impact.running,
              impact.defaultCapabilities.length,
            ),
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

  Future<void> _verify(SourceConfig source) async {
    setState(() => _busy = true);
    try {
      await widget.manager.testConnection(source.id);
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is PluginException
              ? error.message
              : l.connectionFailed;
        });
      }
    }
  }

  Future<void> _edit(SourceConfig source) async {
    await showShadDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          SourceInstanceForm(manager: widget.manager, initial: source),
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

  /// Connection-tab actions, kept inside the tab body next to the list they act
  /// on (like the file sources tab) instead of in the page header.
  Widget _connectionToolbar() {
    final browseDefault = widget.manager.bindings.defaults['source.browse'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ShadButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await showShadDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) =>
                                SourceInstanceForm(manager: widget.manager),
                          );
                          if (mounted) await _load();
                        },
                  leading: Icon(AppIcons.add),
                  enabled: !_busy,
                  child: Text(l.addSourceShort),
                ),
              ),
              if (_files != null)
                Tooltip(
                  message: l.rescanAll,
                  child: Semantics(
                    button: true,
                    label: l.rescanAll,
                    child: Builder(
                      builder: (context) {
                        final files = _files!;
                        final enabled = [
                          for (final b in files.service.fileSources())
                            if (b['enabled'] == 1) b['id'] as String,
                        ];
                        final disabled = files.scanning || enabled.isEmpty;
                        return ShadIconButton.ghost(
                          icon: Icon(AppIcons.refresh),
                          onPressed: disabled
                              ? null
                              : () => files.scan(enabled, l.scanFailedRetained),
                          enabled: !disabled,
                          width: 48,
                          height: 48,
                        );
                      },
                    ),
                  ),
                ),
              Tooltip(
                message: l.reloadConfiguration,
                child: Semantics(
                  button: true,
                  label: l.reloadConfiguration,
                  child: ShadIconButton.ghost(
                    icon: Icon(AppIcons.refresh),
                    onPressed: _busy ? null : () => _load(),
                    enabled: !_busy,
                    width: 48,
                    height: 48,
                  ),
                ),
              ),
              Tooltip(
                message: l.capabilityDefaults,
                child: Semantics(
                  button: true,
                  label: l.capabilityDefaults,
                  child: ShadIconButton.ghost(
                    icon: Icon(AppIcons.preferences),
                    onPressed: _busy
                        ? null
                        : () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    SourceDefaultsPage(manager: widget.manager),
                              ),
                            );
                            if (mounted) await _load();
                          },
                    enabled: !_busy,
                    width: 48,
                    height: 48,
                  ),
                ),
              ),
            ],
          ),
          if (browseDefault != null)
            ShadButton.ghost(
              onPressed: _busy
                  ? null
                  : () {
                      final config = widget.manager.configs
                          .where((c) => c.id == browseDefault && c.enabled)
                          .firstOrNull;
                      if (config == null) {
                        setState(() => _error = l.defaultBrowseUnavailable);
                        return;
                      }
                      _source = config;
                      _load();
                    },
              enabled: !_busy,
              child: Text(l.browseDefault),
            ),
        ],
      ),
    );
  }

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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ShadCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContentRow(
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
                      widget.manager.credentialStatus(source.id).authorization,
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: source.titleName,
                    child: ShadSwitch(
                      value: source.enabled,
                      onChanged: _busy
                          ? null
                          : (enabled) => _toggle(source, enabled),
                      enabled: !_busy,
                    ),
                  ),
                  _SourceMenu(
                    busy: _busy,
                    canVerify: source.enabled,
                    canPreview:
                        source.isFileSource &&
                        source.enabled &&
                        source.scanMode != ScanMode.disabled,
                    onVerify: () => _verify(source),
                    onPreview: () => _scan(source),
                    onEdit: () => _edit(source),
                    onDelete: () => _delete(source),
                  ),
                ],
              ),
              onTap: _busy || !source.enabled
                  ? null
                  : () {
                      _source = source;
                      _load();
                    },
            ),
            if (files != null)
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
                  children: [
                    ...children,
                    if (source.enabled)
                      ContentRow(
                        dense: true,
                        leading: Icon(AppIcons.addFolder),
                        title: Text(l.addFileSource),
                        onTap: files.scanning
                            ? null
                            : () => files.add(context, source.id),
                      ),
                  ],
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
      body: Column(
        children: [
          ...[
            if (_source == null) _connectionToolbar(),
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
class _SourceMenu extends StatefulWidget {
  const _SourceMenu({
    required this.busy,
    required this.canVerify,
    required this.canPreview,
    required this.onVerify,
    required this.onPreview,
    required this.onEdit,
    required this.onDelete,
  });
  final bool busy, canVerify, canPreview;
  final VoidCallback onVerify, onPreview, onEdit, onDelete;
  @override
  State<_SourceMenu> createState() => _SourceMenuState();
}

class _SourceMenuState extends State<_SourceMenu> {
  final _controller = ShadContextMenuController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ShadContextMenu(
      controller: _controller,
      items: [
        ShadContextMenuItem(
          leading: Icon(AppIcons.connection, size: 16),
          enabled: widget.canVerify,
          onPressed: widget.onVerify,
          child: Text(l.verifyConnection),
        ),
        ShadContextMenuItem(
          leading: Icon(AppIcons.scan, size: 16),
          enabled: widget.canPreview,
          onPressed: widget.onPreview,
          child: Text(l.previewScan),
        ),
        ShadContextMenuItem(
          leading: Icon(AppIcons.edit, size: 16),
          onPressed: widget.onEdit,
          child: Text(l.editSource),
        ),
        ShadContextMenuItem(
          leading: Icon(AppIcons.delete, size: 16),
          onPressed: widget.onDelete,
          child: Text(l.deleteSource),
        ),
      ],
      child: Tooltip(
        message: l.moreActions,
        child: Semantics(
          button: true,
          label: l.moreActions,
          child: ShadIconButton.ghost(
            icon: Icon(AppIcons.more),
            onPressed: widget.busy ? null : _controller.toggle,
            enabled: !widget.busy,
            width: 48,
            height: 48,
          ),
        ),
      ),
    );
  }
}
