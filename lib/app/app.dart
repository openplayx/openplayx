import 'dart:io' show Platform;

import '../ui/input/remote_select.dart';
import '../ui/adaptive/app_experience.dart';

import 'package:posthog_flutter/posthog_flutter.dart';

import '../data/analytics/analytics_service.dart';
import '../data/analytics/analytics_navigation_observer.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../l10n/l10n.dart';
import '../l10n/shad_localizations_delegate.dart';
import 'app_shell.dart';
import '../features/design_system/component_gallery_page.dart';
import '../ui/theme/app_theme.dart';
import '../features/settings/app_theme_controller.dart';
import '../ui/theme/material_theme_adapter.dart';
import '../ui/theme/system_ui.dart';

class OpenPlayXApp extends StatefulWidget {
  const OpenPlayXApp({super.key, this.appearance, this.home});
  final AppThemeController? appearance;
  final Widget? home;
  @override
  State<OpenPlayXApp> createState() => _OpenPlayXAppState();
}

class _OpenPlayXAppState extends State<OpenPlayXApp> {
  final _analyticsObserver = AnalyticsNavigationObserver(
    fallback: () => AnalyticsService.instance.tabScreen,
  );
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
        themeMode: AppExperience.isTelevision(context)
            ? ThemeMode.dark
            : _appearance.mode,
        appBuilder: (context) => MaterialApp(
          title: 'OpenPlayX',
          navigatorObservers: [_analyticsObserver],
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
          builder: (context, child) {
            // Consume tvOS overscan insets once around the whole app. Applying
            // SafeArea independently inside the narrow sidebar squeezes its
            // contents between both horizontal TV margins.
            final content = Platform.operatingSystem == 'tvos'
                ? SafeArea(child: child!)
                : child!;
            // Services format messages without a BuildContext.
            setAppStrings(AppLocalizations.of(context));
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: appSystemUiStyle(Theme.of(context).brightness),
              child: Listener(
                onPointerUp: (event) =>
                    AnalyticsService.instance.interaction(event.position),
                child: RemoteSelectAsEnter(
                  child: ShadAppBuilder(
                    child: AnalyticsService.instance.ownsSdk
                        ? PostHogWidget(child: content)
                        : content,
                  ),
                ),
              ),
            );
          },
          routes: {'/design-system': (_) => const ComponentGalleryPage()},
          home: widget.home ?? const AppShell(),
        ),
      ),
    ),
  );
}
