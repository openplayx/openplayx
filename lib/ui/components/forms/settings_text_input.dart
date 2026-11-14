import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// A text field whose blank value means [defaultValue].
///
/// App-wide rule for settings fields:
/// - editing a saved configuration shows the saved value in the field;
/// - a new configuration leaves optional fields blank, with the default shown
///   as the hint, and [resolved] returns the default for a blank field;
/// - a field the user must decide (an address, a model) has no default: it
///   stays blank with an example hint and the form rejects it when empty.
class DefaultTextController extends TextEditingController {
  DefaultTextController({super.text, required this.defaultValue});

  /// Used when the field is blank; also shown as the hint.
  final String defaultValue;

  /// The trimmed text, or [defaultValue] when blank.
  String get resolved {
    final v = text.trim();
    return v.isEmpty ? defaultValue : v;
  }
}

/// The one plain text input for settings forms. Hints are a default value
/// (from a [DefaultTextController]) or an example; explanations belong in
/// the row description or section footer, never in the hint.
class SettingsTextInput extends StatelessWidget {
  const SettingsTextInput({
    super.key,
    required this.controller,
    this.example,
    this.enabled = true,
    this.inline = false,
    this.keyboardType,
    this.maxLines = 1,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// Example value for the hint when the field has no default.
  final String? example;
  final bool enabled;

  /// Borderless, for a field sitting inside a grouped settings row.
  final bool inline;
  final TextInputType? keyboardType;
  final int maxLines;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final hint = c is DefaultTextController ? c.defaultValue : example;
    return ShadInput(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: false,
      decoration: inline ? ShadDecoration.none : null,
      padding: inline ? EdgeInsets.zero : null,
      placeholder: hint == null ? null : Text(hint),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
