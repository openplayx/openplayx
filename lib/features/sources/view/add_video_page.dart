import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../capabilities/library/library_service.dart';
import '../../../capabilities/sources/source_manager.dart';
import '../../../core/capabilities/source_capability.dart';
import '../../../data/sources/source_config.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../ui/adaptive/app_page.dart';
import '../../../ui/components/feedback/app_feedback.dart';
import '../../../ui/components/settings/settings_section.dart';
import '../../../ui/tokens/app_spacing.dart';
import 'scan_scope_page.dart';
import 'source_instance_form.dart';
import 'connector_source_setup.dart';
import 'widgets/source_kind_icon.dart';

/// One entry for new connections and confirmed scopes of saved connections.
class AddVideoPage extends StatefulWidget {
  const AddVideoPage({super.key, required this.sources, required this.library});
  final SourceManager sources;
  final LibraryService library;

  @override
  State<AddVideoPage> createState() => _AddVideoPageState();
}

class _AddVideoPageState extends State<AddVideoPage> {
  StreamSubscription<SourceChange>? _sourceChanges;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sourceChanges = widget.sources.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    unawaited(_sourceChanges?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await widget.sources.load();
    } catch (_) {
      if (mounted) _error = AppLocalizations.of(context).loadSourcesFailed;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // SMB hosts and S3 endpoints must choose a share/bucket. Media servers
  // choose a library; no implicit traversal of every library on the server.
  bool _needsFolder(SourceConfig config) =>
      !config.isFileSource ||
      (config.kind == SourceKind.smb || config.kind == SourceKind.s3) &&
          Uri.parse(config.address).path.replaceAll('/', '').isEmpty;

  Future<bool> _bind(String id, {bool existing = false}) async {
    final l = AppLocalizations.of(context);
    try {
      final config = widget.sources.configs.firstWhere((c) => c.id == id);
      SourceEntry? scope;
      if (existing || _needsFolder(config)) {
        scope = await Navigator.of(context).push<SourceEntry>(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'ScanScopePage'),
            builder: (_) => ScanScopePage(
              sources: widget.sources,
              source: id,
              forHome: true,
              requireFolder: _needsFolder(config),
            ),
          ),
        );
        if (scope == null || !mounted) return false;
      }
      final binding = widget.library.addToHome(
        id,
        root: scope?.ref.id,
        name: scope == null || scope.ref.id.isEmpty
            ? config.titleName
            : scope.name,
        entry: scope,
      );
      widget.library.startScan(binding, widget.sources);
      return true;
    } catch (_) {
      if (mounted) {
        showAppToast(context, l.homeBindingFailed, kind: FeedbackKind.error);
      }
      return false;
    }
  }

  Future<void> _add(SourceKind kind) async {
    if (_busy) return;
    setState(() => _busy = true);
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'SourceInstanceForm'),
        builder: (_) => SourceInstanceForm(
          manager: widget.sources,
          initialKind: kind,
          onAddToHome: (id) => _bind(id),
        ),
      ),
    );
    if (!mounted) return;
    if (added == true) {
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _existing(String id) async {
    if (_busy) return;
    setState(() => _busy = true);
    final added = await _bind(id, existing: true);
    if (!mounted) return;
    if (added) {
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppPage(
      title: Text(l.addVideo),
      pageContext: const PageContextData(pageType: 'add_video'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppSpacing.page(context),
              children: [
                if (_error != null) Text(_error!),
                if (widget.sources.pendingDiscoveredSources.isNotEmpty)
                  SettingsSection(
                    title: l.connectorSources,
                    children: [
                      for (final source
                          in widget.sources.pendingDiscoveredSources)
                        SettingsRow(
                          title: source.name,
                          description: source.connectorName,
                          control: SourceKindIcon(source.kind!),
                          onTap: _busy || !source.enabled
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  final added = await setupConnectorSource(
                                    context,
                                    widget.sources,
                                    source,
                                    library: widget.library,
                                  );
                                  if (!context.mounted) return;
                                  if (added) {
                                    Navigator.pop(context, true);
                                  } else {
                                    setState(() => _busy = false);
                                  }
                                },
                        ),
                    ],
                  ),
                if (widget.sources.visibleConfigs.any((c) => c.enabled))
                  SettingsSection(
                    title: l.homeSavedConnections,
                    children: [
                      for (final config in widget.sources.visibleConfigs.where(
                        (c) => c.enabled,
                      ))
                        SettingsRow(
                          title: config.titleName,
                          control: SourceKindIcon(config.kind),
                          onTap: _busy ? null : () => _existing(config.id),
                        ),
                    ],
                  ),
                SettingsSection(
                  title: l.addSource,
                  children: [
                    for (final kind in SourceKind.values)
                      SettingsRow(
                        key: ValueKey('add-video-${kind.name}'),
                        title: kind == SourceKind.local
                            ? l.localFolder
                            : kind.label,
                        control: SourceKindIcon(kind),
                        onTap: _busy ? null : () => _add(kind),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
