import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// An [AutofillGroup] that reports its fields to the platform in the order
/// they appeared (top to bottom), not in an arbitrary order.
///
/// Android's engine lists autofill fields sorted by the Java hash of each
/// field's id, and Flutter's ids are random (`EditableText-<hashCode>`). A
/// username field can then land after the password field, and password
/// managers, which take the text field before a password as its account,
/// miss it: Google's "Use strong password?" dialog asks for a username.
/// Each field gets a stable alias instead, `opx-autofill-000`, `-001`, …,
/// whose Java hashes increase with the number.
class OrderedAutofillGroup extends AutofillGroup {
  const OrderedAutofillGroup({
    super.key,
    required super.child,
    super.onDisposeAction,
  });

  @override
  AutofillGroupState createState() => _OrderedAutofillGroupState();
}

class _OrderedAutofillGroupState extends AutofillGroupState {
  final _aliases = <String, String>{};
  int _next = 0;

  String _alias(String id) => _aliases.putIfAbsent(
    id,
    () => 'opx-autofill-${(_next++ % 1000).toString().padLeft(3, '0')}',
  );

  TextInputConfiguration _aliased(TextInputConfiguration configuration) {
    final autofill = configuration.autofillConfiguration;
    if (!autofill.enabled) return configuration;
    return configuration.copyWith(
      autofillConfiguration: AutofillConfiguration(
        uniqueIdentifier: _alias(autofill.uniqueIdentifier),
        autofillHints: autofill.autofillHints,
        currentEditingValue: autofill.currentEditingValue,
        hintText: autofill.hintText,
      ),
    );
  }

  @override
  Iterable<AutofillClient> get autofillClients =>
      super.autofillClients.map((client) => _AliasedClient(client, this));

  @override
  AutofillClient? getAutofillClient(String autofillId) {
    for (final entry in _aliases.entries) {
      if (entry.value == autofillId) return super.getAutofillClient(entry.key);
    }
    return super.getAutofillClient(autofillId);
  }

  @override
  TextInputConnection attach(
    TextInputClient trigger,
    TextInputConfiguration configuration,
  ) {
    // Number every field in order before the focused one takes a number.
    for (final client in super.autofillClients) {
      _alias(client.autofillId);
    }
    return super.attach(trigger, _aliased(configuration));
  }
}

class _AliasedClient implements AutofillClient {
  _AliasedClient(this._client, this._group);

  final AutofillClient _client;
  final _OrderedAutofillGroupState _group;

  @override
  String get autofillId => _group._alias(_client.autofillId);

  @override
  TextInputConfiguration get textInputConfiguration =>
      _group._aliased(_client.textInputConfiguration);

  @override
  void autofill(TextEditingValue newEditingValue) =>
      _client.autofill(newEditingValue);
}
