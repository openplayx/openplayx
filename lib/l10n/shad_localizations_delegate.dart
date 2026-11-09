import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'generated/app_localizations.dart';

/// shadcn_ui 0.59 provides simplified Chinese only. Supply its eleven stock
/// strings for Hant through our bundled ARB resources, using public extension
/// points rather than allowing the two scripts to mix inside one interface.
class AppShadLocalizationsDelegate
    extends LocalizationsDelegate<ShadLocalizationsData> {
  const AppShadLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) =>
      GlobalShadLocalizations.delegate.isSupported(locale);
  @override
  Future<ShadLocalizationsData> load(Locale locale) {
    if (locale.languageCode == 'zh' && locale.scriptCode == 'Hant') {
      return SynchronousFuture(
        _TraditionalShadStrings(lookupAppLocalizations(locale)),
      );
    }
    return GlobalShadLocalizations.delegate.load(locale);
  }

  @override
  bool shouldReload(AppShadLocalizationsDelegate old) => false;
}

class _TraditionalShadStrings extends ShadLocalizationsData {
  _TraditionalShadStrings(this.strings);
  final AppLocalizations strings;
  late final _timePicker = _TimePicker(this);
  @override
  ShadLocalizationsData$timePicker$en get timePicker => _timePicker;
  late final _datePicker = _DatePicker(this);
  @override
  ShadLocalizationsData$datePicker$en get datePicker => _datePicker;
  late final _input = _Input(this);
  @override
  ShadLocalizationsData$input$en get input => _input;
  late final _keyboardToolbar = _KeyboardToolbar(this);
  @override
  ShadLocalizationsData$keyboardToolbar$en get keyboardToolbar =>
      _keyboardToolbar;
}

class _TimePicker extends ShadLocalizationsData$timePicker$en {
  _TimePicker(this.root) : super.internal(root);
  final _TraditionalShadStrings root;
  @override
  String get hours => root.strings.shadHours;
  @override
  String get minutes => root.strings.shadMinutes;
  @override
  String get seconds => root.strings.shadSeconds;
  @override
  String get period => root.strings.shadPeriod;
  @override
  String get periodPlaceholder => root.strings.shadMorning;
}

class _DatePicker extends ShadLocalizationsData$datePicker$en {
  _DatePicker(this.root) : super.internal(root);
  final _TraditionalShadStrings root;
  @override
  String get selectDate => root.strings.shadSelectDate;
}

class _Input extends ShadLocalizationsData$input$en {
  _Input(this.root) : super.internal(root);
  final _TraditionalShadStrings root;
  @override
  String get cut => root.strings.shadCut;
  @override
  String get copy => root.strings.shadCopy;
  @override
  String get paste => root.strings.shadPaste;
  @override
  String get selectAll => root.strings.shadSelectAll;
}

class _KeyboardToolbar extends ShadLocalizationsData$keyboardToolbar$en {
  _KeyboardToolbar(this.root) : super.internal(root);
  final _TraditionalShadStrings root;
  @override
  String get done => root.strings.shadDone;
}
