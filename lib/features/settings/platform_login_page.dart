import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/remote_access/relay_subscription.dart';
import '../../l10n/l10n.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/forms/form_actions.dart';
import '../../ui/components/settings/settings_section.dart';

/// Keep the form visible until authentication finishes, including failures.
class PlatformLoginPage extends StatefulWidget {
  const PlatformLoginPage({super.key, this.email, required this.login});

  final String? email;
  final Future<void> Function(String email, String password) login;

  @override
  State<PlatformLoginPage> createState() => _PlatformLoginPageState();
}

class _PlatformLoginPageState extends State<PlatformLoginPage> {
  late final _email = TextEditingController(text: widget.email);
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = l.remotePlatformInvalidEmail);
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = l.errSignInFailed);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.login(email, _password.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is RelayApiException && error.code == 'invalid_login'
            ? l.errSignInFailed
            : error is FormatException
            ? error.message
            : '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: !_busy,
      child: AppPage(
        pageContext: const PageContextData(pageType: 'platform_login'),
        title: Text(l.remotePlatformLogin),
        body: SettingsListView(
          children: [
            SettingsSection(
              children: [
                ShadInput(
                  key: const ValueKey('relay-account-email'),
                  controller: _email,
                  placeholder: Text(l.remotePlatformEmail),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !_busy,
                  autocorrect: false,
                  enableSuggestions: false,
                ),
                ShadInput(
                  key: const ValueKey('relay-account-password'),
                  controller: _password,
                  placeholder: Text(l.password),
                  obscureText: true,
                  enabled: !_busy,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  autocorrect: false,
                  enableSuggestions: false,
                ),
              ],
            ),
            FormActions(
              [
                FormAction.primary(
                  l.remotePlatformLogin,
                  _busy ? null : _submit,
                  key: const ValueKey('relay-login-submit'),
                ),
              ],
              status: _busy
                  ? FormStatus.busy(l.loading)
                  : _error == null
                  ? FormStatus.idle
                  : FormStatus.error(_error!),
            ),
          ],
        ),
      ),
    );
  }
}
