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
import 'source_instance_form.dart';
import 'source_defaults_page.dart';
import 'source_presentation.dart';

class SourcePage extends StatefulWidget {
  const SourcePage({super.key, required this.manager, this.onPlay});
  final SourceManager manager;
  final ValueChanged<SourceSelection>? onPlay;
  @override
  State<SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends State<SourcePage> {
  AppLocalizations get l => AppLocalizations.of(context);
  SourceConfig? _source;
  final _nodes = <SourceEntry>[];
  final _entries = <SourceEntry>[];
  int? _next;
  String? _error;
  bool _busy = true;
  StreamIterator<SourceEntry>? _scanIterator;
  @override
  void dispose() {
    unawaited(_scanIterator?.cancel());
    super.dispose();
  }

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
          title: Text(l.previewTitle(config.name)),
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _source == null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _source != null && !_busy) _back();
    },
    child: AppPage(
      body: Column(
        children: [
          if (_source != null)
            ContentRow(
              leading: Icon(AppIcons.parent),
              title: Text(l.backToParent),
              onTap: _busy ? null : _back,
            ),
          if (_busy) ShadProgress(),
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
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: ShadCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ContentRow(
                                  leading: Icon(
                                    source.kind == SourceKind.local
                                        ? AppIcons.folder
                                        : AppIcons.server,
                                  ),
                                  title: Text(source.name),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          widget.manager.applicationStatus(
                                            source.id,
                                          ),
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
                                  onTap: _busy || !source.enabled
                                      ? null
                                      : () {
                                          _source = source;
                                          _load();
                                        },
                                ),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  children: [
                                    Semantics(
                                      label: source.name,
                                      child: ShadSwitch(
                                        value: source.enabled,
                                        onChanged: _busy
                                            ? null
                                            : (enabled) async {
                                                final impact = widget.manager
                                                    .impact(source.id);
                                                if (!enabled &&
                                                    (impact.playing > 0 ||
                                                        impact.running > 0 ||
                                                        impact
                                                            .defaultCapabilities
                                                            .isNotEmpty)) {
                                                  final accepted = await showShadDialog<bool>(
                                                    context: context,
                                                    builder: (context) => ShadDialog(
                                                      title: Text(
                                                        l.disableSourceConfirm,
                                                      ),
                                                      actions: [
                                                        ShadButton.ghost(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                false,
                                                              ),
                                                          child: Text(l.cancel),
                                                        ),
                                                        ShadButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                true,
                                                              ),
                                                          child: Text(
                                                            l.disable,
                                                          ),
                                                        ),
                                                      ],
                                                      child: Text(
                                                        l.disableSourceDescription(
                                                          impact.playing,
                                                          impact.running,
                                                          impact
                                                              .defaultCapabilities
                                                              .length,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                  if (accepted != true ||
                                                      !mounted) {
                                                    return;
                                                  }
                                                }
                                                setState(() => _busy = true);
                                                try {
                                                  await widget.manager
                                                      .setEnabled(
                                                        source.id,
                                                        enabled,
                                                      );
                                                  await _load();
                                                } catch (error) {
                                                  if (mounted) {
                                                    setState(() {
                                                      _busy = false;
                                                      _error =
                                                          error
                                                              is PluginException
                                                          ? error.message
                                                          : l.toggleSourceFailed;
                                                    });
                                                  }
                                                }
                                              },
                                        enabled: !(_busy),
                                      ),
                                    ),
                                    Tooltip(
                                      message: l.verifyConnection,
                                      child: Semantics(
                                        button: true,
                                        label: l.verifyConnection,
                                        child: ShadIconButton.ghost(
                                          icon: Icon(AppIcons.connection),
                                          onPressed: _busy || !source.enabled
                                              ? null
                                              : () async {
                                                  setState(() => _busy = true);
                                                  try {
                                                    await widget.manager
                                                        .testConnection(
                                                          source.id,
                                                        );
                                                    await _load();
                                                  } catch (error) {
                                                    if (mounted) {
                                                      setState(() {
                                                        _busy = false;
                                                        _error =
                                                            error
                                                                is PluginException
                                                            ? error.message
                                                            : l.connectionFailed;
                                                      });
                                                    }
                                                  }
                                                },
                                          enabled: !(_busy || !source.enabled),
                                          width: 48,
                                          height: 48,
                                        ),
                                      ),
                                    ),
                                    if (source.isFileSource)
                                      Tooltip(
                                        message: l.previewScan,
                                        child: Semantics(
                                          button: true,
                                          label: l.previewScan,
                                          child: ShadIconButton.ghost(
                                            icon: Icon(AppIcons.scan),
                                            onPressed:
                                                _busy ||
                                                    !source.enabled ||
                                                    source.scanMode ==
                                                        ScanMode.disabled
                                                ? null
                                                : () => _scan(source),
                                            enabled:
                                                !(_busy ||
                                                    !source.enabled ||
                                                    source.scanMode ==
                                                        ScanMode.disabled),
                                            width: 48,
                                            height: 48,
                                          ),
                                        ),
                                      ),
                                    Tooltip(
                                      message: l.editSource,
                                      child: Semantics(
                                        button: true,
                                        label: l.editSource,
                                        child: ShadIconButton.ghost(
                                          icon: Icon(AppIcons.edit),
                                          onPressed: _busy
                                              ? null
                                              : () async {
                                                  await showShadDialog<bool>(
                                                    context: context,
                                                    barrierDismissible: false,
                                                    builder: (_) =>
                                                        SourceInstanceForm(
                                                          manager:
                                                              widget.manager,
                                                          initial: source,
                                                        ),
                                                  );
                                                  if (mounted) await _load();
                                                },
                                          enabled: !(_busy),
                                          width: 48,
                                          height: 48,
                                        ),
                                      ),
                                    ),
                                    Tooltip(
                                      message: l.deleteSource,
                                      child: Semantics(
                                        button: true,
                                        label: l.deleteSource,
                                        child: ShadIconButton.ghost(
                                          icon: Icon(AppIcons.delete),
                                          onPressed: _busy
                                              ? null
                                              : () async {
                                                  final confirmed =
                                                      await showShadDialog<
                                                        bool
                                                      >(
                                                        context: context,
                                                        builder: (context) => ShadDialog(
                                                          title: Text(
                                                            l.deleteNamedSource(
                                                              source.name,
                                                            ),
                                                          ),
                                                          actions: [
                                                            ShadButton.ghost(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    false,
                                                                  ),
                                                              child: Text(
                                                                l.cancel,
                                                              ),
                                                            ),
                                                            ShadButton.ghost(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    true,
                                                                  ),
                                                              child: Text(
                                                                l.delete,
                                                              ),
                                                            ),
                                                          ],
                                                          child: Text(
                                                            _deletionMessage(
                                                              source.id,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                  if (confirmed != true ||
                                                      !mounted) {
                                                    return;
                                                  }
                                                  setState(() => _busy = true);
                                                  try {
                                                    await widget.manager.remove(
                                                      source.id,
                                                    );
                                                    await _load();
                                                  } catch (_) {
                                                    if (mounted) {
                                                      setState(() {
                                                        _error = l
                                                            .deleteSourceFailed;
                                                        _busy = false;
                                                      });
                                                    }
                                                  }
                                                },
                                          enabled: !(_busy),
                                          width: 48,
                                          height: 48,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
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
      ),
      title: Text(
        _nodes.isNotEmpty ? _nodes.last.name : _source?.name ?? l.sources,
      ),
      actions: [
        if (_source == null)
          Tooltip(
            message: l.reloadConfiguration,
            child: Semantics(
              button: true,
              label: l.reloadConfiguration,
              child: ShadIconButton.ghost(
                icon: Icon(AppIcons.refresh),
                onPressed: _busy ? null : () => _load(),
                enabled: !(_busy),
                width: 48,
                height: 48,
              ),
            ),
          ),
        if (_source == null &&
            widget.manager.bindings.defaults['source.browse'] != null)
          ShadButton.ghost(
            onPressed: _busy
                ? null
                : () {
                    final id =
                        widget.manager.bindings.defaults['source.browse'];
                    final config = widget.manager.configs
                        .where((c) => c.id == id && c.enabled)
                        .firstOrNull;
                    if (config == null) {
                      setState(() => _error = l.defaultBrowseUnavailable);
                      return;
                    }
                    _source = config;
                    _load();
                  },
            enabled: !(_busy),
            child: Text(l.browseDefault),
          ),
        if (_source == null)
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
                enabled: !(_busy),
                width: 48,
                height: 48,
              ),
            ),
          ),
        if (_source == null)
          ShadButton.ghost(
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
            enabled: !(_busy),
            child: Text(l.addSourceShort),
          ),
      ],
    ),
  );
}
