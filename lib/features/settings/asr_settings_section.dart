import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/subtitles/asr_backend_config.dart';
import '../../services/subtitles/asr_model_store.dart';
import '../../ui/components/forms/secret_input.dart';
import '../../ui/components/forms/settings_text_input.dart';
import '../../ui/components/settings/settings_section.dart';

/// Settings → AI & models → Speech recognition: the on-device model and
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
    setState(() {});
  }

  /// A dialog field with its label above: hints only carry examples.
  Widget _labeled(BuildContext c, String label, Widget input) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 4,
    children: [
      Text(label, style: ShadTheme.of(c).textTheme.small),
      input,
    ],
  );

  Future<void> _editHttp([AsrBackendConfig? existing]) async {
    // A blank name shows the service host.
    final name = TextEditingController(text: existing?.name ?? '');
    final url = TextEditingController(text: existing?.url ?? '');
    final model = DefaultTextController(
      text: existing?.modelId,
      defaultValue: 'whisper-base-multilingual',
    );
    final language = DefaultTextController(
      text: existing?.language,
      defaultValue: 'auto',
    );
    final token = SecretController();
    if (existing != null) {
      token.loadStored(() => registry.credential(existing));
    }
    var insecure = existing?.allowInsecureHttp ?? false;
    String? error;
    final result = await showShadDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => ShadDialog(
          title: Text(existing == null ? l.asrAddService : l.asrEditService),
          description: Text(l.asrServicePrivacy),
          actions: [
            if (existing != null)
              ShadButton.ghost(
                foregroundColor: ShadTheme.of(c).colorScheme.destructive,
                onPressed: () => Navigator.pop(c, 'remove'),
                child: Text(l.asrRemoveService),
              ),
            ShadButton.ghost(
              onPressed: () => Navigator.pop(c),
              child: Text(l.cancel),
            ),
            ShadButton(
              key: const ValueKey('asr-service-save'),
              onPressed: () {
                try {
                  final saved = registry.save(
                    AsrBackendConfig(
                      id: existing?.id ?? AsrBackendRegistry.newId(),
                      kind: 'http',
                      name: name.text,
                      url: url.text.trim(),
                      modelId: model.resolved,
                      language: language.resolved,
                      allowInsecureHttp: insecure,
                      uploadConsentAt: existing?.uploadConsentAt,
                    ),
                  );
                  Navigator.pop(c, saved.id);
                } on FormatException catch (e) {
                  set(
                    () => error = e.message == 'url'
                        ? l.asrServiceUrlInvalid
                        : l.asrServiceInvalid,
                  );
                }
              },
              child: Text(l.save),
            ),
          ],
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                _labeled(
                  c,
                  l.asrServiceName,
                  SettingsTextInput(controller: name),
                ),
                _labeled(
                  c,
                  l.asrServiceUrl,
                  SettingsTextInput(
                    key: const ValueKey('asr-service-url'),
                    controller: url,
                    keyboardType: TextInputType.url,
                    example: 'https://asr.example.com',
                  ),
                ),
                _labeled(
                  c,
                  l.asrServiceToken,
                  SecretInput(
                    controller: token,
                    placeholder: existing == null
                        ? null
                        : l.metadataTokenStatusSaved,
                  ),
                ),
                _labeled(c, l.asrModel, SettingsTextInput(controller: model)),
                _labeled(
                  c,
                  l.asrLanguage,
                  SettingsTextInput(controller: language),
                ),
                ShadCheckbox(
                  value: insecure,
                  label: Text(l.asrAllowHttp),
                  sublabel: Text(l.asrAllowHttpHint),
                  onChanged: (v) => set(() => insecure = v),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: ShadTheme.of(c).colorScheme.destructive,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == 'remove' && existing != null) {
      await registry.remove(existing.id);
    } else if (result != null && token.edited.isNotEmpty) {
      registry.setToken(result, token.edited);
    }
    for (final c in [name, url, model, language, token]) {
      c.dispose();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final embedded = registry.get('embedded')!;
    final services = registry.list().where((c) => c.kind == 'http').toList();
    final theme = ShadTheme.of(context);
    return Column(
      children: [
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
            SettingsRow(title: l.asrModelImport, chevron: true, onTap: _import),
          ],
        ),
        SettingsSection(
          key: const ValueKey('asr-services'),
          title: l.asrServicesTitle,
          children: [
            for (final c in services)
              SettingsRow(
                title: c.name,
                description: '${c.host} · ${c.modelId}',
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
