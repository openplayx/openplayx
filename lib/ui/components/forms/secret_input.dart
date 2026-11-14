import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../icons/app_icons.dart';

/// Holds one secret (API key, token, password) for a [SecretInput].
///
/// [loadStored] fills the field with the saved value so the user sees it
/// masked and can reveal it; [edited] tells the caller whether anything
/// needs to be written back.
class SecretController extends TextEditingController {
  SecretController({super.text});

  String? _stored;
  bool _disposed = false;

  /// Whether a saved secret exists (as last loaded or saved).
  bool get hasStored => _stored?.isNotEmpty == true;

  /// Reads the saved secret and shows it, unless the user already typed.
  /// A failed read (no keychain, user declined) counts as nothing saved.
  Future<void> loadStored(Future<String?> Function() read) async {
    String? value;
    try {
      value = (await read())?.trim();
    } catch (_) {
      value = null;
    }
    if (_disposed) return;
    _stored = value;
    if (text.isEmpty && hasStored) text = value!;
  }

  /// The trimmed new secret, or '' when the field is empty or still holds
  /// the saved value. '' means "keep what is saved".
  String get edited {
    final value = text.trim();
    return value == _stored ? '' : value;
  }

  /// Call after the current value was written to storage.
  void markSaved() {
    final value = text.trim();
    if (value.isNotEmpty) _stored = value;
  }

  /// Forgets the saved value, e.g. after the credential was deleted.
  void forgetStored() {
    _stored = null;
    clear();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The one input for secrets across the app: masked dots by default, an eye
/// button on the right to reveal or hide the content. Style changes here
/// apply to every API key, token and password field.
class SecretInput extends StatefulWidget {
  const SecretInput({
    super.key,
    required this.controller,
    this.placeholder,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
    this.inline = false,
  });

  final TextEditingController controller;
  final String? placeholder;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  /// Borderless, for a field sitting inside a grouped settings row.
  final bool inline;

  @override
  State<SecretInput> createState() => _SecretInputState();
}

class _SecretInputState extends State<SecretInput> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = _visible ? l.hidePassword : l.showPassword;
    return ShadInput(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: !_visible,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      decoration: widget.inline ? ShadDecoration.none : null,
      padding: widget.inline ? EdgeInsets.zero : null,
      placeholder: widget.placeholder == null
          ? null
          : Text(widget.placeholder!),
      onChanged: widget.onChanged,
      trailing: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          child: ShadIconButton.ghost(
            width: 32,
            height: 32,
            iconSize: 18,
            padding: EdgeInsets.zero,
            onPressed: () => setState(() => _visible = !_visible),
            // The eye shows the current state: open while the content is
            // visible, closed while it is masked.
            icon: Icon(
              _visible ? AppIcons.showPassword : AppIcons.hidePassword,
            ),
          ),
        ),
      ),
    );
  }
}
