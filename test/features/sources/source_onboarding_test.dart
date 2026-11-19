import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/features/sources/view/source_page.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app_test_host.dart';
import 'source_flow_test.dart' show MemorySources;

class _LoadingSources extends MemorySources {
  _LoadingSources(this.connection);

  final SourceConfig? connection;
  final finishLoading = Completer<void>();

  @override
  Future<void> load() async {
    await finishLoading.future;
    if (connection case final config?) saved.add(config);
  }
}

void main() {
  for (final connection in <SourceConfig?>[
    null,
    const SourceConfig(
      id: 'webdav',
      kind: SourceKind.webdav,
      name: 'VM WebDAV',
      address: 'https://example.com/dav',
    ),
    const SourceConfig(
      id: 'ftp',
      kind: SourceKind.ftp,
      name: 'VM FTP',
      address: 'ftp://example.com/media',
    ),
    const SourceConfig(
      id: 'sftp',
      kind: SourceKind.sftp,
      name: 'VM SFTP',
      address: 'sftp://example.com/media',
    ),
    const SourceConfig(
      id: 'disabled',
      kind: SourceKind.webdav,
      name: 'Disabled WebDAV',
      address: 'https://example.com/dav',
      enabled: false,
    ),
  ]) {
    testWidgets(
      'storage onboarding waits for loading and only appears without connections (${connection?.id ?? 'empty'})',
      (tester) async {
        final sources = _LoadingSources(connection);
        addTearDown(sources.dispose);
        final page = ValueNotifier<Widget>(const SizedBox());
        addTearDown(page.dispose);
        await tester.pumpWidget(
          TestApp(
            home: ValueListenableBuilder<Widget>(
              valueListenable: page,
              builder: (context, child, _) => child,
            ),
          ),
        );
        // Finish application localization before mounting the page. Its pending
        // source load then remains observable without settling its animation.
        await tester.pumpAndSettle();
        page.value = SourcePage(manager: sources);
        await tester.pump();
        expect(find.byType(SourcePage), findsOneWidget);
        final description = AppLocalizations.of(
          tester.element(find.byType(SourcePage)),
        ).sourcesDescription;

        expect(find.byType(ShadProgress), findsOneWidget);
        expect(find.text(description), findsNothing);
        expect(find.byKey(const ValueKey('add-source-empty')), findsNothing);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(description), findsNothing);

        sources.finishLoading.complete();
        await tester.pumpAndSettle();

        expect(find.byType(ShadProgress), findsNothing);
        expect(
          find.text(description),
          connection == null ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('add-source-empty')),
          connection == null ? findsOneWidget : findsNothing,
        );
        if (connection != null) {
          expect(find.text(connection.name), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
