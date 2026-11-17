import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/ui/input/remote_select.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('remote select presses a focused shadcn button', (tester) async {
    var pressed = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      ShadApp(
        home: RemoteSelectAsEnter(
          child: Center(
            child: ShadButton(
              focusNode: focus,
              onPressed: () => pressed++,
              child: const Text('Go'),
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(pressed, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pump();
    expect(pressed, 2);
  });

  testWidgets('other keys and unfocused select pass through', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      ShadApp(
        home: RemoteSelectAsEnter(
          child: Center(
            child: ShadButton(
              onPressed: () => pressed++,
              child: const Text('Go'),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    expect(pressed, 0);
  });

  testWidgets('Material buttons keep their own select handling', (
    tester,
  ) async {
    var pressed = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RemoteSelectAsEnter(
          child: Center(
            child: TextButton(
              focusNode: focus,
              onPressed: () => pressed++,
              child: const Text('Go'),
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(pressed, 1);
  });
}
