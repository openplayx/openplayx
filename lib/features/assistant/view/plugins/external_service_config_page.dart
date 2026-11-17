import 'package:flutter/material.dart';

import '../../../../assistant/plugins/external/external_service_setup.dart';
import '../../../../ui/adaptive/app_page.dart';
import '../../../../ui/components/feedback/app_feedback.dart';
import '../../../../ui/components/forms/form_actions.dart';
import '../../../../ui/components/forms/secret_input.dart';
import '../../../../ui/components/forms/settings_text_input.dart';
import '../../../../ui/components/settings/settings_section.dart';
import '../../../../l10n/l10n.dart';

/// 外部能力 → 配置: one address and token. The App connects over MCP, reads
/// what the service is and which tools it offers, and saves it as a custom
/// external capability.
class ExternalServiceConfigPage extends StatefulWidget {
  const ExternalServiceConfigPage({super.key, required this.setup});
  final ExternalServiceSetup setup;

  @override
  State<ExternalServiceConfigPage> createState() =>
      _ExternalServiceConfigPageState();
}

class _ExternalServiceConfigPageState extends State<ExternalServiceConfigPage> {
  final _url = TextEditingController();
  final _token = SecretController();
  final _name = TextEditingController();
  ExternalServiceProbe? _probe;
  String? _error;

  /// What is running (shown in the action bar), or null when idle.
  String? _busyLabel;
  bool get _busy => _busyLabel != null;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    _name.dispose();
    super.dispose();
  }

  void _edited() {
    if (_probe != null || _error != null) {
      setState(() {
        _probe = null;
        _error = null;
      });
    }
  }

  Future<void> _run(String busyLabel, Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busyLabel = busyLabel;
      _error = null;
    });
    try {
      await task();
    } on ExternalServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = appStrings.actionFailedRetry);
    } finally {
      if (mounted) setState(() => _busyLabel = null);
    }
  }

  Future<void> _connect() => _run(appStrings.extConnecting, () async {
    final probe = await widget.setup.probe(_url.text, _token.text);
    if (mounted) setState(() => _probe = probe);
  });

  Future<void> _save() => _run(appStrings.saving, () async {
    final probe = _probe;
    if (probe == null) return;
    final saved = await widget.setup.save(probe, _token.text, name: _name.text);
    if (!mounted) return;
    showAppToast(
      context,
      appStrings.extAdded(saved.displayName),
      kind: FeedbackKind.success,
    );
    Navigator.of(context).pop(true);
  });

  Widget _field(
    String key,
    String label,
    TextEditingController controller, {
    String? placeholder,
    TextInputType? keyboard,
  }) => SettingsRow(
    title: label,
    stacked: true,
    control: controller is SecretController
        ? SecretInput(
            key: ValueKey(key),
            controller: controller,
            enabled: !_busy,
            placeholder: placeholder,
            onChanged: (_) => _edited(),
          )
        : SettingsTextInput(
            key: ValueKey(key),
            controller: controller,
            enabled: !_busy,
            keyboardType: keyboard,
            example: placeholder,
            onChanged: (_) => _edited(),
          ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final probe = _probe;
    return AppPage(
      pageContext: const PageContextData(
        pageType: 'external_service_configuration',
      ),
      title: Text(l.extConfigureTitle),
      body: SettingsListView(
        children: [
          SettingsSection(
            footer: l.extConfigureFooter,
            children: [
              _field(
                'external-url',
                l.extServiceAddress,
                _url,
                placeholder: 'https://bt.example.com',
                keyboard: TextInputType.url,
              ),
              _field('external-token', l.extAccessToken, _token),
              _field('external-name', l.extNameOptional, _name),
            ],
          ),
          if (probe != null)
            SettingsSection(
              key: const ValueKey('external-detected'),
              title: l.extDetected,
              children: [
                SettingsRow(
                  title: probe.title.isNotEmpty ? probe.title : probe.baseUrl,
                  description: [
                    if (probe.version.isNotEmpty) l.extVersion(probe.version),
                    l.extToolCount(probe.tools.length),
                  ].join(' · '),
                ),
                if (probe.tools.isNotEmpty)
                  SettingsRow(
                    title: l.extTools,
                    description: probe.tools.join(l.listSeparator),
                  ),
              ],
            ),
          // Connecting is the commit until the service is identified; then
          // saving is.
          FormActions(
            status: _busy
                ? FormStatus.busy(_busyLabel!)
                : _error == null
                ? FormStatus.idle
                : FormStatus.error(_error!),
            [
              if (probe == null)
                FormAction.primary(
                  l.extConnect,
                  _busy ? null : _connect,
                  key: const ValueKey('external-connect'),
                )
              else
                FormAction.primary(
                  l.save,
                  _busy ? null : _save,
                  key: const ValueKey('external-save'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
