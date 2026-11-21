import 'dart:async';

import 'package:flutter/widgets.dart';

import 'analytics_service.dart';

class AnalyticsNavigationObserver extends NavigatorObserver {
  AnalyticsNavigationObserver({this.active, this.fallback, this.onScreen});
  final String Function()? fallback;
  final void Function(String)? onScreen;
  final bool Function()? active;
  String current = 'home';
  void _show(Route<dynamic>? route) {
    if (route == null) return;
    final name = route.settings.name == '/'
        ? fallback?.call()
        : route.settings.name;
    if (name == null ||
        name == '/' ||
        !RegExp(r'^[a-zA-Z0-9_.:-]{1,100}$').hasMatch(name))
      return;
    current = name;
    if (active?.call() ?? true) {
      onScreen?.call(name);
      unawaited(AnalyticsService.instance.screen(name));
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _show(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _show(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _show(newRoute);
}
