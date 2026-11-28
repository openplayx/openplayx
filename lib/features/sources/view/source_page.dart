import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/tokens/app_spacing.dart';

import '../../../ui/adaptive/app_page.dart';
import '../../../ui/components/media/content_row.dart';
import '../../../ui/icons/app_icons.dart';

import '../../../core/capabilities/source_capability.dart';
import '../../../data/sources/source_config.dart';
import '../../../capabilities/library/file_source.dart';
import '../controller/file_source_controller.dart';
import '../controller/sources_controller.dart';
import '../model/sources_state.dart';
import '../../../capabilities/sources/source_manager.dart';
import '../../../capabilities/library/library_service.dart';
import 'widgets/source_kind_icon.dart';
import 'file_source_row.dart';
import 'source_instance_form.dart';
import 'source_presentation.dart';
import 'connector_source_setup.dart';
import 'hidden_connector_sources.dart';
import '../../../data/remote_access/discovered_source.dart';
import '../../../data/remote_access/remote_config.dart';
import '../../settings/remote_access_settings_page.dart';
import 'widgets/source_list_widgets.dart';
import '../../../ui/components/feedback/app_feedback.dart';

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
  late final SourcesController _controller = SourcesController(
    sources: widget.manager,
    library: widget.library,
  );
  FileSourceController? _files;
  SourcesState get _state => _controller.state;
  bool get _busy => _state.busy;
  SourceConfig? get _source => _state.browsing;

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    final library = widget.library;
    if (library != null) {
      // File sources are the children of their connection in the tree.
      _files = FileSourceController(library, widget.manager)
        ..addListener(_refresh);
    }
    // Opening the page picks up connector changes without a manual refresh.
    unawaited(
      _load().then((_) {
        if (mounted && widget.manager.syncsDiscoveredSources) {
          unawaited(_syncDirectory());
        }
      }),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _files?.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) => _controller.load(more: more);

  String? get _error => switch (_state.failure) {
    null => null,
    SourcesFailure(:final message?) => message,
    SourcesFailure(:final kind) => switch (kind) {
      SourcesFailureKind.load => l.loadSourcesFailed,
      SourcesFailureKind.play => l.filePlayFailed,
      SourcesFailureKind.toggle => l.toggleSourceFailed,
      SourcesFailureKind.delete => l.deleteSourceFailed,
    },
  };

  Future<void> _select(SourceEntry entry) async {
    final selection = await _controller.open(entry, wanted: () => mounted);
    if (selection == null) return;
    if (!mounted) {
      await selection.stream.release();
      return;
    }
    if (widget.onPlay != null) {
      widget.onPlay!(selection);
    } else {
      Navigator.of(context).pop(selection);
    }
  }

  void _back() => _controller.back();

  Future<void> _toggle(SourceConfig source, bool enabled) async {
    final impact = _controller.impact(source.id);
    if (!enabled && impact.interruptsWork) {
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
    await _controller.setEnabled(source.id, enabled);
  }

  Future<void> _edit(SourceConfig source) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'SourceInstanceForm'),
        builder: (_) =>
            SourceInstanceForm(manager: widget.manager, initial: source),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _delete(SourceConfig source) async {
    final impact = _controller.impact(source.id);
    final discovered = widget.manager.discoveredFor(source);
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog(
        title: Text(
          discovered == null
              ? l.deleteNamedSource(source.titleName)
              : l.connectorSourceClearLocal,
        ),
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
        child: Text(
          '${l.deleteSourceDescription(impact.fileSources, impact.playing, impact.running)}'
          '${discovered == null ? '' : '\n\n${l.connectorSourceClearLocalHelp}'}',
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _controller.remove(source.id);
    if (discovered != null &&
        !widget.manager.configs.any((c) => c.id == source.id)) {
      await widget.manager.hideDiscoveredSource(discovered, true);
    }
  }

  /// Header button (top right, next to the assistant) that adds a connection.
  Future<void> _openAddSource() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'SourceInstanceForm'),
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
          Text(
            l.sourcesDescription,
            style: ShadTheme.of(context).textTheme.muted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
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

  bool _syncing = false;
  bool _connectorCollapsed = false;
  List<SourceConfig> get _visible => widget.manager.visibleConfigs;

  /// Remote access is optional: connector UI appears only while platform
  /// sync is on, and then only when there is something to set up or report.
  bool get _showConnectorSection =>
      widget.manager.pendingDiscoveredSources.isNotEmpty ||
      (widget.manager.syncsDiscoveredSources &&
          widget.manager.sourceSyncError != null);

  /// Reloads the list, and syncs connector sources when remote access is on.
  /// A failed sync keeps the last list; the connector section shows the error.
  Future<void> _syncDirectory() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await widget.manager.syncDiscoveredSources();
    } catch (_) {
      // Reported inline through sourceSyncError.
    } finally {
      if (mounted) {
        await _load();
        if (mounted) setState(() => _syncing = false);
      }
    }
  }

  Future<void> _accountSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RemoteAccessSettingsPage(sources: widget.manager),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _setupDiscovered(DiscoveredSource entry) async {
    await setupConnectorSource(
      context,
      widget.manager,
      entry,
      library: widget.library,
    );
    if (mounted) await _load();
  }

  Future<void> _hide(DiscoveredSource entry) async {
    final accepted = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog(
        title: Text(l.connectorSourceHide),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          ShadButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.connectorSourceHide),
          ),
        ],
        child: Text(l.connectorSourceHideHelp),
      ),
    );
    if (accepted == true) {
      await widget.manager.hideDiscoveredSource(entry, true);
    }
  }

  Future<void> _showHidden() async {
    await showHiddenConnectorSources(context, widget.manager);
    if (mounted) setState(() {});
  }

  /// Bottom-of-list section for connector sources that are not set up yet,
  /// with the sync status and the connector actions in its header.
  List<Widget> _connectorSection() {
    if (!_showConnectorSection) return const [];
    final theme = ShadTheme.of(context);
    final pending = widget.manager.pendingDiscoveredSources;
    final failed = widget.manager.sourceSyncError != null;
    final collapsed = _connectorCollapsed && pending.isNotEmpty;
    return [
      const Divider(height: AppSpacing.lg),
      Row(
        key: const ValueKey('connector-section'),
        children: [
          Expanded(
            child: InkWell(
              onTap: pending.isEmpty
                  ? null
                  : () => setState(
                      () => _connectorCollapsed = !_connectorCollapsed,
                    ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    if (pending.isNotEmpty) ...[
                      Icon(
                        collapsed ? AppIcons.next : AppIcons.expand,
                        size: 14,
                        color: theme.colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Flexible(
                      child: Text(
                        pending.isEmpty
                            ? l.connectorSources
                            : '${l.connectorSources} (${pending.length})',
                        style: theme.textTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Tooltip(
            message: l.connectorSourceSync,
            child: ShadIconButton.ghost(
              key: const ValueKey('sync-connector-sources'),
              width: 32,
              height: 32,
              icon: _syncing
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.refresh, size: 16),
              onPressed: _syncing ? null : _syncDirectory,
            ),
          ),
          SourceActionsMenu(
            key: const ValueKey('connector-section-menu'),
            label: l.connectorSources,
            actions: [
              SourceRowAction(
                label: l.connectorSourcesHidden,
                icon: AppIcons.showPassword,
                onPressed: _showHidden,
              ),
              SourceRowAction(
                label: l.remoteAccess,
                icon: AppIcons.connection,
                onPressed: _accountSettings,
              ),
            ],
          ),
        ],
      ),
      if (failed)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            l.connectorSourceSyncFailed,
            key: const ValueKey('connector-sync-failed'),
            style: theme.textTheme.muted,
          ),
        ),
      if (!collapsed)
        for (final entry in pending) _discoveredRow(entry),
    ];
  }

  Future<void> _connectionSettings(SourceConfig source) async {
    final link = source.remote!;
    var mode = link.mode;
    final local =
        source.kind != SourceKind.smb &&
        (link.managedLocal
            ? widget.manager.discoveredFor(source)?.supportsLocal == true
            : link.localAddress?.isNotEmpty == true);
    final accepted = await showShadDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => ShadDialog(
          title: Text(l.connectorSourceConnectionSettings),
          actions: [
            ShadButton.ghost(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            ShadButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.save),
            ),
          ],
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in RemoteConnectionMode.values)
                  if (local || option == RemoteConnectionMode.remoteOnly)
                    ContentRow(
                      title: Text(switch (option) {
                        RemoteConnectionMode.automatic => l.remoteAutomatic,
                        RemoteConnectionMode.localOnly => l.remoteLocalOnly,
                        RemoteConnectionMode.remoteOnly => l.remoteRemoteOnly,
                      }),
                      trailing: Icon(
                        mode == option ? AppIcons.check : AppIcons.next,
                      ),
                      onTap: () => update(() => mode = option),
                    ),
                if (source.kind == SourceKind.smb)
                  Text(l.connectorSourceRemoteOnlyHelp),
              ],
            ),
          ),
        ),
      ),
    );
    if (accepted != true) return;
    await widget.manager.save(
      source.copyWith(
        remote: SourceRemote(
          proxy: link.proxy,
          accountId: link.accountId,
          connectorId: link.connectorId,
          serviceName: link.serviceName,
          managedLocal: link.managedLocal,
          mode: mode,
          localAddress: link.localAddress,
          localTlsSha256: link.localTlsSha256,
        ),
      ),
      '',
    );
    if (mounted) await _load();
  }

  Widget _discoveredRow(DiscoveredSource entry) => SourceListRow(
    key: ValueKey('discovered-${entry.serviceId}'),
    title: entry.name,
    leading: SourceKindIcon(entry.kind!),
    subtitle: Text('${entry.kind!.label} · ${entry.connectorName}'),
    status: Text(
      entry.enabled ? l.connectorSourceDiscovered : l.connectorSourceDisabled,
    ),
    onTap: entry.enabled && !_busy ? () => _setupDiscovered(entry) : null,
    actions: SourceActionsMenu(
      label: entry.name,
      enabled: !_busy,
      actions: [
        if (entry.enabled)
          SourceRowAction(
            label: l.connectorSourceLogin,
            icon: AppIcons.signIn,
            onPressed: () => _setupDiscovered(entry),
          ),
        SourceRowAction(
          label: l.connectorSourceHide,
          icon: AppIcons.hidePassword,
          onPressed: () => _hide(entry),
        ),
      ],
    ),
  );

  void _browseConnection(SourceConfig source) => _controller.browse(source);

  /// A lightweight expandable group, with independent parent/child actions.
  Widget _connectionGroup(SourceConfig source) {
    final theme = ShadTheme.of(context);
    final files = _files;
    final bindings = files == null
        ? const <FileSource>[]
        : _controller.fileSourcesOf(source.id);
    final expanded = _controller.isExpanded(source);
    // Rescan of the connection: every enabled folder under it.
    final scannable = [
      for (final b in bindings)
        if (b.enabled) b.id,
    ];
    final canScan =
        files != null &&
        !_busy &&
        source.enabled &&
        !files.scanning &&
        scannable.isNotEmpty;
    final discovered = widget.manager.discoveredFor(source);
    final localPath = widget.manager.connectionUsesLocal(source.id);
    final status = discovered?.status == 'removed'
        ? l.connectorSourceRemoved
        : discovered?.status == 'disabled'
        ? l.connectorSourceDisabled
        : localPath != null
        ? (localPath ? l.connectorSourceLan : l.connectorSourceRemote)
        : SourcePresentation.summary(
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
              '${source.kind == SourceKind.local ? l.localSource : source.typeLabel}'
              '${discovered == null ? '' : ' · ${discovered.connectorName}'}'
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
            onTap: () => _controller.setExpanded(source.id, !expanded),
            actions: SourceActionsMenu(
              key: ValueKey('source-menu-${source.id}'),
              label: source.titleName,
              enabled: !_busy,
              actions: [
                if (files != null)
                  SourceRowAction(
                    key: ValueKey('source-scan-${source.id}'),
                    label: l.rescan,
                    icon: AppIcons.refresh,
                    onPressed: canScan ? () => files.scan(scannable) : null,
                  ),
                if (files != null)
                  SourceRowAction(
                    key: ValueKey('source-add-file-${source.id}'),
                    label: l.addFileSourceShort,
                    icon: AppIcons.addFolder,
                    onPressed: source.enabled && !files.scanning
                        ? () => addFileSource(context, files, source.id)
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
                if (discovered != null)
                  SourceRowAction(
                    label: l.connectorSourceConnectionSettings,
                    icon: AppIcons.settings,
                    onPressed: () => _connectionSettings(source),
                  ),
                SourceRowAction(
                  key: ValueKey('source-edit-${source.id}'),
                  label: discovered == null ? l.edit : l.connectorSourceLogin,
                  icon: AppIcons.edit,
                  onPressed: discovered == null || discovered.enabled
                      ? () => _edit(source)
                      : null,
                ),
                SourceRowAction(
                  key: ValueKey('source-toggle-${source.id}'),
                  label: source.enabled ? l.disable : l.fileSourceEnable,
                  icon: source.enabled ? AppIcons.pause : AppIcons.play,
                  onPressed: () => _toggle(source, !source.enabled),
                ),
                if (discovered != null)
                  SourceRowAction(
                    label: l.connectorSourceHide,
                    icon: AppIcons.hidePassword,
                    onPressed: () => _hide(discovered),
                  ),
                SourceRowAction(
                  key: ValueKey('source-delete-${source.id}'),
                  label: discovered == null
                      ? l.delete
                      : l.connectorSourceClearLocal,
                  icon: AppIcons.delete,
                  destructive: true,
                  onPressed: () => _delete(source),
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
                      fileSource: binding,
                      controller: files,
                      connection: source,
                      onPlay: widget.onPlay,
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
    final orphans = _controller.orphanFileSources;
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
                FileSourceRow(
                  fileSource: binding,
                  controller: files,
                  onPlay: widget.onPlay,
                ),
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
            if (_files?.failure case final failure?)
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppAlert.error(
                  title: switch (failure) {
                    FileSourceFailure.scan => l.scanFailedRetained,
                    FileSourceFailure.bind => l.bindFailed,
                  },
                ),
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
                            _visible.isEmpty &&
                            !_showConnectorSection &&
                            _orphanFileSources().isEmpty)
                        ? _emptySources()
                        // Your own sources first; connector sources waiting
                        // to be set up are an optional section at the end.
                        : RefreshIndicator(
                            onRefresh: _syncDirectory,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: AppSpacing.page(context),
                              children: [
                                for (var i = 0; i < _visible.length; i++) ...[
                                  if (i > 0) const Divider(height: 1),
                                  _connectionGroup(_visible[i]),
                                ],
                                ..._orphanFileSources(),
                                ..._connectorSection(),
                              ],
                            ),
                          )
                  : ListView(
                      padding: AppSpacing.page(context),
                      children: [
                        if (!_busy && _error == null && _state.entries.isEmpty)
                          ContentRow(title: Text(l.folderEmpty)),
                        for (final entry in _state.entries)
                          ContentRow(
                            leading: Icon(
                              entry.isFolder
                                  ? AppIcons.folder
                                  : AppIcons.playMedia,
                            ),
                            title: Text(entry.name),
                            onTap: _busy ? null : () => _select(entry),
                          ),
                        if (_state.nextOffset != null)
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
        _state.path.isNotEmpty
            ? _state.path.last.name
            : _source?.name ?? l.sources,
      ),
    ),
  );
}
