import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/theme/app_theme.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:openplayx/ui/icons/app_icons.dart';
import 'package:openplayx/ui/components/media/media_shelf.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Widget host(Widget child) => ShadApp.custom(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: ThemeMode.light,
  appBuilder: (context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: Theme.of(context),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      GlobalShadLocalizations.delegate,
      ...AppLocalizations.localizationsDelegates,
    ],
    builder: (context, child) => ShadAppBuilder(child: child!),
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('hover arrows page the shelf one group at a time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      host(
        MediaShelf(
          title: 'Movies',
          itemCount: 20,
          tileWidth: ShelfMetrics.posterWidth,
          tileHeight: ShelfMetrics.posterWidth * 1.5,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          itemBuilder: (_, i) => PosterTile(title: 'Film $i'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
    double offset() => list.position.pixels;
    Finder arrow(String label) =>
        find.byIcon(label == 'Next' ? AppIcons.next : AppIcons.previous);
    double opacity(String label) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: arrow(label),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    // Hidden until the pointer is over the shelf.
    expect(opacity('Next'), 0);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('Film 1')));
    await tester.pumpAndSettle();
    expect(opacity('Next'), 1);
    expect(opacity('Previous'), 0, reason: 'already at the start');

    // 800 - 2*40 = 720 px visible; stride 140 -> 5 whole tiles per group.
    const stride = ShelfMetrics.posterWidth + ShelfMetrics.gap;
    await tester.tap(arrow('Next'));
    await tester.pumpAndSettle();
    expect(offset(), 5 * stride);
    expect(opacity('Previous'), 1);
    await tester.tap(arrow('Next'));
    await tester.pumpAndSettle();
    expect(offset(), 10 * stride);
    await tester.tap(arrow('Previous'));
    await tester.pumpAndSettle();
    expect(offset(), 5 * stride);

    // The last group stops at the end and hides the next arrow.
    for (var i = 0; i < 5; i++) {
      if (opacity('Next') == 0) break;
      await tester.tap(arrow('Next'));
      await tester.pumpAndSettle();
    }
    expect(offset(), list.position.maxScrollExtent);
    expect(opacity('Next'), 0);
  });
}
