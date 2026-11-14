import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/library/library_service.dart';
import '../../services/metadata/tmdb_credentials.dart';
import '../../ui/components/forms/form_actions.dart';
import '../../ui/components/forms/secret_input.dart';
import '../../ui/components/forms/settings_text_input.dart';
import '../../ui/components/settings/settings_adaptive.dart';
import '../../ui/components/settings/settings_section.dart';

/// Settings entry for the TMDB read access token and metadata language.
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
  bool? _configured;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
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
    // Unset: blank field, the default zh-CN shown as the hint.
    final language = DefaultTextController(
      text: widget.library.metadata.setting('language'),
      defaultValue: 'zh-CN',
    );
    final configured = _configured == true;
    final tokenInput = SecretInput(
      key: const ValueKey('tmdb-token'),
      controller: token,
      // The row title already names the field; only hint at a kept token.
      placeholder: configured ? l.metadataTokenStatusSaved : null,
    );
    final languageInput = SettingsTextInput(
      key: const ValueKey('tmdb-language'),
      controller: language,
    );
    // Phones: a full-screen page with Save in the header; true saves,
    // false forgets the token, null is back.
    final saved = isCompactSettings(context)
        ? await pushSettingsPage<bool>(
            context,
            title: l.metadataConfigure,
            trailing: (c) => [
              PageSubmitButton(
                key: const ValueKey('tmdb-save'),
                label: l.save,
                onPressed: () => Navigator.pop(c, true),
              ),
            ],
            children: (c) => [
              SettingsSection(
                footer: l.metadataPrivacy,
                children: [
                  SettingsRow(
                    title: l.metadataToken,
                    stacked: true,
                    control: tokenInput,
                  ),
                  SettingsRow(
                    title: l.metadataLanguage,
                    stacked: true,
                    control: languageInput,
                  ),
                ],
              ),
              if (configured)
                SettingsSection(
                  children: [
                    SettingsRow(
                      key: const ValueKey('tmdb-forget'),
                      title: l.metadataForgetToken,
                      destructive: true,
                      onTap: () => Navigator.pop(c, false),
                    ),
                  ],
                ),
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
                    const SizedBox(height: 12),
                    languageInput,
                  ],
                ),
              ),
            ),
          );
    final trimmed = token.edited;
    final languageCode = language.resolved;
    token.dispose();
    language.dispose();
    if (!mounted || saved == null) return;
    if (!saved) return _forget();
    await _run(() async {
      if (!RegExp(r'^[a-z]{2,3}(?:-[A-Za-z]{2,4})?$').hasMatch(languageCode)) {
        throw const FormatException('language');
      }
      if (trimmed.isNotEmpty) {
        widget.library.metadata.setSetting(tmdbTokenKey, trimmed);
      }
      widget.library.metadata.setSetting('language', languageCode);
      if (trimmed.isNotEmpty) _bump();
      if (mounted && trimmed.isNotEmpty) setState(() => _configured = true);
    });
  }

  Future<void> _forget() => _run(() async {
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
    return SettingsSection(
      title: 'TMDB',
      children: [
        SettingsRow(
          key: const ValueKey('tmdb-configure'),
          title: l.metadataToken,
          description: _failed ? l.metadataFailed : null,
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
      ],
    );
  }
}
