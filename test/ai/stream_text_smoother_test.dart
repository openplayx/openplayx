import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/features/assistant/adapters/stream_text_smoother.dart';

void main() {
  testWidgets('reveals a burst over several frames, then settles', (
    tester,
  ) async {
    var changes = 0;
    final smoother = StreamTextSmoother(() => changes++);
    const text = 'Smooth streaming reveals text a little every frame.';
    expect(smoother.view('a', text, live: true), '');
    final seen = <int>[];
    for (var i = 0; i < 120 && smoother.revealing('a'); i++) {
      await tester.pump(const Duration(milliseconds: 16));
      seen.add(smoother.view('a', text, live: true).length);
    }
    expect(seen.length, greaterThan(5), reason: 'not a single jump');
    expect(seen, orderedEquals([...seen]..sort()));
    expect(smoother.view('a', text, live: true), text);
    expect(changes, greaterThan(5));
    // Roughly the catch-up window, not seconds.
    expect(seen.length * 16, lessThan(1500));
    smoother.dispose();
  });

  testWidgets('history and text already long when first seen are not retyped', (
    tester,
  ) async {
    final smoother = StreamTextSmoother(() {});
    expect(smoother.view('h', 'old reply', live: false), 'old reply');
    final long = 'x' * (StreamTextSmoother.replayLimit + 1);
    expect(smoother.view('l', long, live: true), long);
    expect(smoother.revealing('h') || smoother.revealing('l'), false);
    smoother.dispose();
  });

  testWidgets('a finished reply keeps revealing, never splits a surrogate', (
    tester,
  ) async {
    final smoother = StreamTextSmoother(() {});
    const text = '你好😀世界😀';
    smoother.view('a', text, live: true);
    for (var i = 0; i < 100 && smoother.revealing('a'); i++) {
      await tester.pump(const Duration(milliseconds: 4));
      final shown = smoother.view('a', text, live: false);
      if (shown.isNotEmpty) {
        final last = shown.codeUnitAt(shown.length - 1);
        expect(last >= 0xD800 && last <= 0xDBFF, false);
      }
    }
    expect(smoother.view('a', text, live: false), text);
    smoother.dispose();
  });
}
