import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:openplayx/app/diagnostics/diagnostics_bootstrap.dart';
import 'package:openplayx/app/diagnostics/diagnostics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('missing DSN starts normally without initializing Sentry', () async {
    var starts = 0;
    await runWithDiagnostics(DiagnosticRole.main, () async {
      starts++;
    });
    expect(starts, 1);
    expect(Sentry.isEnabled, false);
  });
  test('application failures propagate without a second startup', () async {
    var starts = 0;
    await expectLater(
      runWithDiagnostics(DiagnosticRole.player, () async {
        starts++;
        throw StateError('startup');
      }),
      throwsStateError,
    );
    expect(starts, 1);
  });
  test(
    'allowlist removes private data while retaining package frame locations',
    () {
      const secret = 'https://nas:password@192.168.1.10/private/movie.mkv';
      final event = SentryEvent(
        message: SentryMessage(secret),
        tags: {'url': secret, 'failure': 'metadataBatch'},
        user: SentryUser(email: secret),
        breadcrumbs: [Breadcrumb(message: secret)],
        exceptions: [
          SentryException(
            type: 'StateError',
            value: secret,
            stackTrace: SentryStackTrace(
              frames: [
                SentryStackFrame(absPath: secret, vars: {'key': secret}),
                SentryStackFrame(
                  absPath: 'package:openplayx/main.dart',
                  function: secret,
                  lineNo: 42,
                  vars: {'token': secret},
                ),
              ],
            ),
          ),
        ],
      );
      final safe = sanitizeDiagnosticEvent(event, DiagnosticRole.player);
      final json = jsonEncode(safe.toJson());
      expect(json, isNot(contains(secret)));
      expect(json, isNot(contains('password')));
      expect(safe.exceptions!.single.stackTrace!.frames.single.lineNo, 42);
      expect(safe.tags, {'engine_role': 'player', 'failure': 'metadataBatch'});
    },
  );

  test('arbitrary exception types and tags cannot carry user content', () {
    final safe = sanitizeDiagnosticEvent(
      SentryEvent(
        tags: {'failure': '/private/user'},
        exceptions: [SentryException(type: '/private/user', value: 'chat')],
      ),
      DiagnosticRole.background,
    );
    expect(safe.exceptions!.single.type, 'UnexpectedError');
    expect(safe.tags!.containsKey('failure'), false);
  });
}
