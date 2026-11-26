import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../capabilities/speech/asr_backend_config.dart';
import '../../capabilities/speech/asr_model_store.dart';
import 'asr_http_service_settings_page.dart';
import '../../ui/components/settings/settings_section.dart';

/// Settings → Subtitles → Speech recognition: the on-device model and
/// the user's HTTP recognition services. Downloads happen only from an
/// explicit action here; tokens live in secure storage.
class AsrSettingsSection extends StatefulWidget {
  const AsrSettingsSection({super.key, required this.registry});
  final AsrBackendRegistry registry;

  @override
  State<AsrSettingsSection> createState() => _AsrSettingsSectionState();
}

class _AsrSettingsSectionState extends State<AsrSettingsSection> {
  AppLocalizations get l => AppLocalizations.of(context);
  AsrBackendRegistry get registry => widget.registry;
  AsrModelStore get models => registry.models;
  Set<String> _installed = const {};
  final _progress = <String, int>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final installed = await models.installed();
    if (mounted) setState(() => _installed = installed);
  }

  static String _mb(int bytes) => '${(bytes / 1024 / 1024).round()} MB';

  Future<void> _download(AsrModelSpec spec) async {
    final d = models.download(spec.id);
    setState(() {
      _progress[spec.id] = 0;
      _error = null;
    });
    final sub = d.progress.listen((n) {
      if (mounted) setState(() => _progress[spec.id] = n);
    });
    try {
      await d.done;
    } on AsrModelCancelled {
      // user action
    } catch (_) {
      if (mounted) setState(() => _error = l.asrModelDownloadFailed);
    } finally {
      await sub.cancel();
      if (mounted) setState(() => _progress.remove(spec.id));
      await _reload();
    }
  }

  Future<void> _import() async {
    final file = await openFile();
    if (file == null) return;
    try {
      await models.import(File(file.path));
    } on FormatException {
      if (mounted) setState(() => _error = l.asrModelImportRejected);
    }
    await _reload();
  }

  Future<void> _remove(AsrModelSpec spec) async {
    await models.remove(spec.id);
    await _reload();
  }

  void _select(AsrModelSpec spec) {
    final c = registry.get('embedded')!;
    registry.save(c.copyWith(modelId: spec.id));
    registry.selectDefault(c.id);
    setState(() {});
  }

  Future<void> _editHttp([AsrBackendConfig? existing]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'AsrHttpServiceSettingsPage'),
        builder: (_) =>
            AsrHttpServiceSettingsPage(registry: registry, existing: existing),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final embedded = registry.get('embedded')!;
    final services = registry.list().where((c) => c.kind == 'http').toList();
    final theme = ShadTheme.of(context);
    final selected = registry.get(registry.defaultBackendId)!;
    Widget option(
      String id,
      String title,
      String description,
      VoidCallback choose,
    ) => SettingsRow(
      key: ValueKey('asr-mode-$id'),
      title: title,
      description: description,
      control: Icon(
        selected.kind == id
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked,
      ),
      onTap: choose,
    );
    return Column(
      children: [
        SettingsSection(
          title: l.asrSectionBackend,
          children: [
            option('platform', l.asrPlatform, l.asrPlatformHint, () {
              registry.selectDefault('platform');
              setState(() {});
            }),
            option('embedded', l.asrLocal, l.asrModelFooter, () {
              registry.selectDefault('embedded');
              setState(() {});
            }),
            option('http', l.asrCustom, l.asrCustomHint, () {
              if (services.isEmpty) {
                _editHttp();
              } else {
                registry.selectDefault(services.first.id);
                setState(() {});
              }
            }),
          ],
        ),
        if (selected.kind == 'embedded')
          SettingsSection(
            key: const ValueKey('asr-models'),
            title: l.asrSettingsTitle,
            footer: _error ?? l.asrModelFooter,
            children: [
              for (final spec in asrModelCatalog)
                SettingsRow(
                  key: ValueKey('asr-model-${spec.id}'),
                  title: '${spec.label} · ${_mb(spec.bytes)}',
                  description: _progress.containsKey(spec.id)
                      ? l.asrModelDownloading(
                          _mb(_progress[spec.id]!),
                          _mb(spec.bytes),
                        )
                      : _installed.contains(spec.id)
                      ? (embedded.modelId == spec.id
                            ? l.asrModelInUse
                            : l.asrModelInstalled)
                      : l.asrModelNotInstalled,
                  control: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_progress.containsKey(spec.id))
                        ShadButton.ghost(
                          size: ShadButtonSize.sm,
                          onPressed: () =>
                              models.activeDownload(spec.id)?.cancel(),
                          child: Text(l.cancel),
                        )
                      else if (!_installed.contains(spec.id))
                        ShadButton.outline(
                          size: ShadButtonSize.sm,
                          onPressed: () => _download(spec),
                          child: Text(l.asrModelDownload),
                        )
                      else ...[
                        if (embedded.modelId != spec.id)
                          ShadButton.outline(
                            size: ShadButtonSize.sm,
                            onPressed: () => _select(spec),
                            child: Text(l.asrModelUse),
                          ),
                        ShadButton.ghost(
                          size: ShadButtonSize.sm,
                          foregroundColor: theme.colorScheme.destructive,
                          onPressed: () => _remove(spec),
                          child: Text(l.asrModelRemove),
                        ),
                      ],
                    ],
                  ),
                ),
              SettingsRow(
                title: l.asrModelImport,
                chevron: true,
                onTap: _import,
              ),
            ],
          ),
        SettingsSection(
          key: const ValueKey('asr-services'),
          title: l.asrCustom,
          children: [
            for (final c in services)
              SettingsRow(
                title: c.name,
                description:
                    '${c.host} · ${c.modelId}${selected.id == c.id ? ' · ${l.asrModelInUse}' : ''}',
                chevron: true,
                onTap: () => _editHttp(c),
              ),
            SettingsRow(
              key: const ValueKey('asr-add-service'),
              title: l.asrAddService,
              chevron: true,
              onTap: _editHttp,
            ),
          ],
        ),
      ],
    );
  }
}
