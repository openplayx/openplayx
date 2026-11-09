import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/shad_localizations_delegate.dart';
import 'app_shell.dart';
import '../features/design_system/component_gallery_page.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_controller.dart';
import 'theme/material_theme_adapter.dart';

class OpenPlayXApp extends StatefulWidget {
  const OpenPlayXApp({super.key, this.appearance, this.home});
  final AppThemeController? appearance;
  final Widget? home;
  @override
  State<OpenPlayXApp> createState() => _OpenPlayXAppState();
}

class _OpenPlayXAppState extends State<OpenPlayXApp> {
  late final _appearance = widget.appearance ?? AppThemeController();
  @override
  void dispose() {
    if (widget.appearance == null) _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppAppearance(
    controller: _appearance,
    child: ListenableBuilder(
      listenable: _appearance,
      builder: (context, _) => ShadApp.custom(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _appearance.mode,
        appBuilder: (context) => MaterialApp(
          title: 'OpenPlayX',
          debugShowCheckedModeBanner: false,
          theme: MaterialThemeAdapter.adapt(context),
          locale: _appearance.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: (preferred, supported) {
            for (final locale in preferred ?? <Locale>[]) {
              if (locale.languageCode == 'zh') {
                final traditional =
                    locale.scriptCode == 'Hant' ||
                    (locale.scriptCode == null &&
                        const ['TW', 'HK', 'MO'].contains(locale.countryCode));
                return Locale.fromSubtags(
                  languageCode: 'zh',
                  scriptCode: traditional ? 'Hant' : 'Hans',
                );
              }
              if (locale.languageCode == 'en') return const Locale('en');
            }
            return const Locale('en');
          },
          localizationsDelegates: const [
            AppShadLocalizationsDelegate(),
            ...AppLocalizations.localizationsDelegates,
          ],
          builder: (context, child) => ShadAppBuilder(child: child!),
          routes: {'/design-system': (_) => const ComponentGalleryPage()},
          home: widget.home ?? const AppShell(),
        ),
      ),
    ),
  );
}
