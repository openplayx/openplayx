import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

AppLocalizations _current = lookupAppLocalizations(const Locale('en'));

/// The App's strings in the active UI language, for code that has no
/// [BuildContext] (services, data sources, error messages). Widgets should
/// keep using `AppLocalizations.of(context)`.
///
/// The App updates this whenever its resolved locale changes (see
/// `OpenPlayXApp`); until then it is English.
AppLocalizations get appStrings => _current;

/// Called by the App with the localizations of its resolved locale.
void setAppStrings(AppLocalizations strings) => _current = strings;
