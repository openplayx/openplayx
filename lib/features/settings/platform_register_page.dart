import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/remote_access/relay_subscription.dart';
import '../../l10n/l10n.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/feedback/app_feedback.dart';
import '../../ui/components/forms/form_actions.dart';
import '../../ui/components/forms/ordered_autofill_group.dart';
import '../../ui/components/forms/secret_input.dart';
import '../../ui/components/settings/settings_section.dart';

/// Registers a platform account without leaving the App: email, then the
/// emailed code and a new password. Pops with the registered email.
class PlatformRegisterPage extends StatefulWidget {
  const PlatformRegisterPage({
    super.key,
    this.email,
    required this.request,
    required this.complete,
  });

  final String? email;
  final Future<void> Function(String email) request;
  final Future<void> Function(String email, String code, String password)
  complete;

  @override
  State<PlatformRegisterPage> createState() => _PlatformRegisterPageState();
}

class _PlatformRegisterPageState extends State<PlatformRegisterPage> {
  static const _resendCooldown = 60;
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  /// The address the code went to; null while still on the email step.
  String? _sentTo;
  bool _busy = false;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _password.addListener(_mirrorGeneratedPassword);
  }

  String _lastPassword = '';

  /// A system strong-password suggestion arrives as one whole value in an
  /// empty field. iOS fills both new-password fields itself; other password
  /// managers fill only the first, so copy it into an empty confirmation.
  void _mirrorGeneratedPassword() {
    final value = _password.text;
    if (_lastPassword.isEmpty && value.length >= 12 && _confirm.text.isEmpty) {
      _confirm.text = value;
    }
    _lastPassword = value;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _resendIn = _resendCooldown;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  String _message(Object error, AppLocalizations l) {
    if (error is RelayApiException) {
      switch (error.code) {
        case 'invalid_code':
          return l.remotePlatformInvalidCode;
        case 'invalid_challenge':
          return l.remotePlatformCodeExpired;
        case 'invalid_password':
          return l.remotePlatformPasswordTooShort;
      }
    }
    return error is FormatException ? error.message : '$error';
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) _error = _message(error, AppLocalizations.of(context));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = l.remotePlatformInvalidEmail);
      return;
    }
    await _guard(() async {
      await widget.request(email);
      if (!mounted) return;
      _sentTo = email;
      _email.text = email;
      _code.clear();
      _startCooldown();
      showAppToast(
        context,
        l.remotePlatformRegistrationSent,
        kind: FeedbackKind.success,
      );
    });
  }

  Future<void> _resend() async {
    final l = AppLocalizations.of(context);
    await _guard(() async {
      await widget.request(_sentTo!);
      if (!mounted) return;
      _code.clear();
      _startCooldown();
      showAppToast(
        context,
        l.remotePlatformRegistrationSent,
        kind: FeedbackKind.success,
      );
    });
  }

  Future<void> _complete() async {
    final l = AppLocalizations.of(context);
    final code = _code.text.trim();
    final String? problem;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      problem = l.remotePlatformInvalidCode;
    } else if (_password.text.length < 12) {
      problem = l.remotePlatformPasswordTooShort;
    } else if (_password.text != _confirm.text) {
      problem = l.remotePlatformPasswordMismatch;
    } else {
      problem = null;
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    await _guard(() async {
      await widget.complete(_sentTo!, code, _password.text);
      // Ask the system password manager to save the email and new password.
      TextInput.finishAutofillContext();
      if (mounted) Navigator.of(context).pop(_sentTo);
    });
  }

  void _changeEmail() {
    _timer?.cancel();
    setState(() {
      _sentTo = null;
      _resendIn = 0;
      _password.clear();
      _confirm.clear();
      _error = null;
      _code.clear();
    });
  }

  FormStatus _status(AppLocalizations l) => _busy
      ? FormStatus.busy(l.loading)
      : _error == null
      ? FormStatus.idle
      : FormStatus.error(_error!);

  final _emailFieldKey = GlobalKey();

  /// One email field for both steps, so the system autofill session sees the
  /// user type the account name into a real, visible field. Android's strong
  /// password dialog and save prompt only pick the username from such a field.
  /// Once the code is sent it stays as a read-only account name; change it
  /// with the change-email action.
  Widget _emailField(AppLocalizations l) {
    final sent = _sentTo != null;
    return KeyedSubtree(
      key: const ValueKey('relay-registration-email'),
      child: ShadInput(
        key: _emailFieldKey,
        controller: _email,
        placeholder: Text(l.remotePlatformEmail),
        readOnly: sent,
        // iOS reads only the first hint; Android passes them all, and Google
        // Password Manager pairs a newPassword field with a newUsername one
        // on sign-up forms.
        autofillHints: const [
          AutofillHints.username,
          AutofillHints.newUsername,
          AutofillHints.email,
        ],
        keyboardType: TextInputType.emailAddress,
        textInputAction: sent ? TextInputAction.next : TextInputAction.done,
        onSubmitted: sent ? null : (_) => _send(),
        enabled: sent || !_busy,
        autocorrect: false,
        enableSuggestions: false,
      ),
    );
  }

  List<Widget> _emailStep(AppLocalizations l) => [
    SettingsSection(
      footer: l.remotePlatformRegisterHint,
      children: [_emailField(l)],
    ),
    FormActions([
      FormAction.primary(
        l.remotePlatformSendRegistration,
        _busy ? null : _send,
        key: const ValueKey('relay-registration-submit'),
      ),
    ], status: _status(l)),
  ];

  List<Widget> _codeStep(AppLocalizations l) => [
    SettingsSection(
      footer: l.remotePlatformCodeSentTo(_sentTo!),
      children: [
        _emailField(l),
        ShadInput(
          key: const ValueKey('relay-registration-code'),
          controller: _code,
          placeholder: Text(l.remotePlatformCode),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          autofillHints: const [AutofillHints.oneTimeCode],
          textInputAction: TextInputAction.next,
          enabled: !_busy,
          autocorrect: false,
          enableSuggestions: false,
        ),
        SecretInput(
          key: const ValueKey('relay-registration-password'),
          controller: _password,
          placeholder: l.remotePlatformNewPassword,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          enabled: !_busy,
          copyable: true,
        ),
        SecretInput(
          key: const ValueKey('relay-registration-confirm'),
          controller: _confirm,
          placeholder: l.remotePlatformConfirmPassword,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _complete(),
          enabled: !_busy,
          copyable: true,
        ),
      ],
    ),
    FormActions([
      FormAction(
        l.remotePlatformChangeEmail,
        _busy ? null : _changeEmail,
        key: const ValueKey('relay-registration-change-email'),
      ),
      FormAction(
        _resendIn > 0
            ? l.remotePlatformResendCodeIn(_resendIn)
            : l.remotePlatformResendCode,
        _busy || _resendIn > 0 ? null : _resend,
        key: const ValueKey('relay-registration-resend'),
      ),
      FormAction.primary(
        l.remotePlatformCompleteRegistration,
        _busy ? null : _complete,
        key: const ValueKey('relay-registration-complete'),
      ),
    ], status: _status(l)),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: !_busy,
      child: AppPage(
        pageContext: const PageContextData(pageType: 'platform_register'),
        title: Text(l.remotePlatformRegister),
        body: OrderedAutofillGroup(
          child: SettingsListView(
            children: _sentTo == null ? _emailStep(l) : _codeStep(l),
          ),
        ),
      ),
    );
  }
}
