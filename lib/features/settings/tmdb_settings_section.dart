import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../capabilities/library/library_service.dart';
import '../../capabilities/metadata/tmdb_credentials.dart';
import '../../ui/components/forms/form_actions.dart';
import '../../ui/components/forms/secret_input.dart';
import '../../ui/components/settings/settings_adaptive.dart';
import '../../ui/components/settings/settings_section.dart';

/// Cloud or direct TMDB access. Metadata follows the App's UI language.
///
/// The token is the `metadata / tmdbToken` setting. Bumping `tmdbRevision` makes the
/// background metadata runtime rebuild its TMDB plugin and retry blocked items.
class TmdbSettingsSection extends StatefulWidget {
  const TmdbSettingsSection({super.key, required this.library});
  final LibraryService library;

  @override
  State<TmdbSettingsSection> createState() => _TmdbSettingsSectionState();
}

class _TmdbSettingsSectionState extends State<TmdbSettingsSection> {
  String get _token => widget.library.metadata.setting(tmdbTokenKey).trim();
  TmdbConfig get _config =>
      TmdbConfig.fromSettings(widget.library.metadata.setting);
  late bool _cloudTab;
  bool? _configured;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _cloudTab = _config.usePlatform;
    _load();
  }

  Future<void> _load() async {
    bool configured;
    try {
      configured = _token.isNotEmpty;
    } catch (_) {
      configured = false;
    }
    if (mounted) setState(() => _configured = configured);
  }

  void _bump() => widget.library.metadata.setSetting(
    'tmdbRevision',
    '${DateTime.now().microsecondsSinceEpoch}',
  );

  Future<void> _configure() async {
    final l = AppLocalizations.of(context);
    final token = SecretController()
      ..loadStored(() async => _token.isEmpty ? null : _token);
    final configured = _configured == true;
    final tokenInput = SecretInput(
      key: const ValueKey('tmdb-token'),
      controller: token,
      // The row title already names the field; only hint at a kept token.
      placeholder: configured ? l.metadataTokenStatusSaved : null,
    );
    // Phones: a full-screen page with Save in the bottom action bar; true
    // saves, false forgets the token, null is back.
    final saved = isCompactSettings(context)
        ? await pushSettingsPage<bool>(
            context,
            title: l.metadataConfigure,
            children: (c) => [
              SettingsSection(
                footer: l.metadataPrivacy,
                children: [
                  SettingsRow(
                    title: l.metadataToken,
                    stacked: true,
                    control: tokenInput,
                  ),
                ],
              ),
              FormActions([
                if (configured)
                  FormAction.destructive(
                    l.metadataForgetToken,
                    () => Navigator.pop(c, false),
                    key: const ValueKey('tmdb-forget'),
                  ),
                FormAction.primary(
                  l.save,
                  () => Navigator.pop(c, true),
                  key: const ValueKey('tmdb-save'),
                ),
              ]),
            ],
          )
        : await showShadDialog<bool>(
            context: context,
            builder: (c) => ShadDialog(
              title: Text(l.metadataConfigure),
              actions: [
                if (configured)
                  ShadButton.ghost(
                    key: const ValueKey('tmdb-forget'),
                    foregroundColor: ShadTheme.of(c).colorScheme.destructive,
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(l.metadataForgetToken),
                  ),
                ShadButton.ghost(
                  onPressed: () => Navigator.pop(c),
                  child: Text(l.cancel),
                ),
                ShadButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(l.save),
                ),
              ],
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.metadataPrivacy),
                    const SizedBox(height: 16),
                    tokenInput,
                  ],
                ),
              ),
            ),
          );
    final trimmed = token.edited;
    token.dispose();
    if (!mounted || saved == null) return;
    if (!saved) return _forget();
    await _run(() async {
      if (trimmed.isNotEmpty) {
        widget.library.metadata.setSetting(
          tmdbModeKey,
          _config.usePlatform ? 'cloud' : 'local',
        );
        widget.library.metadata.setSetting(tmdbTokenKey, trimmed);
      }
      if (trimmed.isNotEmpty) _bump();
      if (mounted && trimmed.isNotEmpty) setState(() => _configured = true);
    });
  }

  Future<void> _forget() => _run(() async {
    widget.library.metadata.setSetting(
      tmdbModeKey,
      _config.usePlatform ? 'cloud' : 'local',
    );
    widget.library.metadata.setSetting(tmdbTokenKey, '');
    _bump();
    if (mounted) setState(() => _configured = false);
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final configured = _configured == true;
    final active = _config.usePlatform == _cloudTab;
    final hasConfig = !_cloudTab || !active;
    final hint = _cloudTab ? l.tmdbCloudHint : l.tmdbLocalHint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadTabs<bool>(
          key: const ValueKey('tmdb-mode-tabs'),
          value: _cloudTab,
          onChanged: _busy
              ? null
              : (cloud) => setState(() => _cloudTab = cloud),
          tabs: [
            for (final cloud in [true, false])
              ShadTab(
                enabled: !_busy,
                key: ValueKey(cloud ? 'tmdb-tab-cloud' : 'tmdb-tab-local'),
                value: cloud,
                trailing: _config.usePlatform == cloud
                    ? const Icon(Icons.check, size: 14)
                    : null,
                child: Text(cloud ? l.remoteTabCloud : l.remoteTabLocal),
              ),
          ],
        ),
        SettingsSection(
          title: 'TMDB',
          footer: hasConfig ? null : hint,
          children: [
            SettingsRow(
              title: active ? l.remoteModeActive : l.remoteModeInactive,
              description: _failed ? l.metadataFailed : null,
              control: Icon(
                active ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
              ),
            ),
          ],
        ),
        if (hasConfig)
          SettingsSection(
            footer: hint,
            children: [
              if (!_cloudTab)
                SettingsRow(
                  key: const ValueKey('tmdb-configure'),
                  title: l.metadataToken,
                  chevron: true,
                  onTap: !_busy && _configured != null ? _configure : null,
                  control: _configured == null
                      ? null
                      : Text(
                          configured
                              ? l.metadataTokenStatusSaved
                              : l.metadataTokenStatusMissing,
                        ),
                ),
              if (!active)
                FormActions([
                  FormAction.primary(
                    _cloudTab ? l.remoteEnableCloud : l.remoteEnableLocal,
                    _busy || (!_cloudTab && !configured)
                        ? null
                        : () => _run(() async {
                            widget.library.metadata.setSetting(
                              tmdbModeKey,
                              _cloudTab ? 'cloud' : 'local',
                            );
                            _bump();
                          }),
                    key: const ValueKey('tmdb-enable-mode'),
                  ),
                ]),
            ],
          ),
      ],
    );
  }
}
