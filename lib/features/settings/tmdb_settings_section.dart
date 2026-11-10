import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/library/library_service.dart';
import '../../services/metadata/tmdb_credentials.dart';
import '../../ui/components/settings/settings_section.dart';

/// Settings entry for the TMDB read access token and metadata language.
///
/// The token lives only in secure storage. Bumping `tmdbRevision` makes the
/// background metadata runtime rebuild its TMDB plugin and retry blocked items.
class TmdbSettingsSection extends StatefulWidget {
  const TmdbSettingsSection({
    super.key,
    required this.library,
    this.credentials = tmdbCredentialStorage,
  });
  final LibraryService library;
  final FlutterSecureStorage credentials;
  @override
  State<TmdbSettingsSection> createState() => _TmdbSettingsSectionState();
}

class _TmdbSettingsSectionState extends State<TmdbSettingsSection> {
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
      configured =
          (await widget.credentials.read(key: tmdbTokenKey))
              ?.trim()
              .isNotEmpty ==
          true;
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
    var token = '';
    var language = widget.library.metadata.setting(
      'language',
      fallback: 'zh-CN',
    );
    final saved = await showShadDialog<bool>(
      context: context,
      builder: (c) => ShadDialog(
        title: Text(l.metadataConfigure),
        actions: [
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
              ShadInput(
                obscureText: true,
                placeholder: Text(l.metadataToken),
                onChanged: (v) => token = v,
              ),
              const SizedBox(height: 12),
              ShadInput(
                initialValue: language,
                placeholder: Text(l.metadataLanguage),
                onChanged: (v) => language = v,
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;
    await _run(() async {
      if (!RegExp(r'^[a-z]{2,3}(?:-[A-Za-z]{2,4})?$').hasMatch(language)) {
        throw const FormatException('language');
      }
      final trimmed = token.trim();
      if (trimmed.isNotEmpty) {
        await widget.credentials.write(key: tmdbTokenKey, value: trimmed);
      }
      widget.library.metadata.setSetting('language', language);
      if (trimmed.isNotEmpty) _bump();
      if (mounted && trimmed.isNotEmpty) setState(() => _configured = true);
    });
  }

  Future<void> _forget() => _run(() async {
    await widget.credentials.delete(key: tmdbTokenKey);
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
          title: l.metadataToken,
          description: l.metadataPrivacy,
          control: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ShadButton.outline(
                enabled: !_busy && _configured != null,
                onPressed: _configure,
                child: Text(l.metadataConfigure),
              ),
              if (configured)
                ShadButton.ghost(
                  enabled: !_busy,
                  onPressed: _forget,
                  child: Text(l.metadataForgetToken),
                ),
            ],
          ),
        ),
        if (_failed)
          ShadAlert.destructive(title: Text(l.metadataFailed))
        else if (_configured != null)
          Text(
            configured ? l.metadataTokenSaved : l.metadataTokenMissing,
            style: ShadTheme.of(context).textTheme.muted,
          ),
      ],
    );
  }
}
