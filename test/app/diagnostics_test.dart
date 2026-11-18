import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:openplayx/data/diagnostics/diagnostics_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Sentry.close);

  test('missing DSN starts normally without initializing Sentry', () async {
    var starts = 0;
    await runWithDiagnostics(DiagnosticRole.main, () async {
      starts++;
    }, dsn: '');
    expect(starts, 1);
    expect(Sentry.isEnabled, false);
  });

  test('application failures propagate without a second startup', () async {
    var starts = 0;
    await expectLater(
      runWithDiagnostics(DiagnosticRole.player, () async {
        starts++;
        throw StateError('startup');
      }, dsn: ''),
      throwsStateError,
    );
    expect(starts, 1);
  });

  test('reports the original exception, message and stack to Sentry', () async {
    SentryEvent? reported;
    await Sentry.init((options) {
      options
        ..dsn = 'https://public@example.invalid/1'
        ..transport = _NoOpTransport()
        ..beforeSend = (event, hint) {
          reported = event;
          return null;
        };
    });
    final error = StateError('Actual playback failure: fixture.mkv');
    final stack = StackTrace.fromString(
      '#0      play (package:openplayx/main.dart:42:7)',
    );

    await reportDiagnostic(error, DiagnosticRole.player, stack);

    expect(reported, isNotNull);
    expect(reported!.throwable, same(error));
    expect(reported!.exceptions!.single.type, 'StateError');
    expect(reported!.exceptions!.single.value, contains(error.message));
    expect(reported!.exceptions!.single.stackTrace!.frames.last.lineNo, 42);
    expect(reported!.tags!['engine_role'], 'player');
  });

  test(
    'an existing client starts the app once without reinitialization',
    () async {
      await Sentry.init((options) {
        options
          ..dsn = 'https://public@example.invalid/1'
          ..transport = _NoOpTransport();
      });
      var starts = 0;
      await runWithDiagnostics(DiagnosticRole.background, () async {
        starts++;
      });
      expect(starts, 1);
      expect(Sentry.isEnabled, isTrue);
    },
  );
}

class _NoOpTransport implements Transport {
  @override
  Future<SentryId?> send(SentryEnvelope envelope) async => null;
}
