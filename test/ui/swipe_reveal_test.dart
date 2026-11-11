import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/ui/components/swipe_reveal.dart';

void main() {
  testWidgets('swipe reveals the action; tap or swipe back closes it', (
    tester,
  ) async {
    var taps = 0, actions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeReveal(
            action: (close) => TextButton(
              onPressed: () {
                actions++;
                close();
              },
              child: const Text('Delete'),
            ),
            child: ListTile(title: const Text('Row'), onTap: () => taps++),
          ),
        ),
      ),
    );
    // A short swipe snaps back.
    await tester.drag(find.text('Row'), const Offset(-20, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    await tester.drag(find.text('Row'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);
    // While open, tapping the row closes it instead of activating it.
    await tester.tap(find.text('Row'));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    expect(taps, 0);
    // Swiping right closes too.
    await tester.drag(find.text('Row'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Row'), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    // The action runs and closes the row.
    await tester.drag(find.text('Row'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(find.text('Delete'), findsNothing);
    // Closed rows behave normally.
    await tester.tap(find.text('Row'));
    expect(taps, 1);
  });
}
