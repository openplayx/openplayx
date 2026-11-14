import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:openplayx/ui/adaptive/app_page.dart';
import 'package:openplayx/ui/adaptive/assistant_action.dart';

Widget host(Widget child) => ShadApp(home: MaterialApp(home: child));

void main() {
  test('context exports only JSON, bounds content and hides locators', () {
    final json = PageContextData(
      pageType: 'media_detail',
      title: '/private/videos/movie.mkv',
      entity: const {'media_id': 'm1'},
      state: {
        'text': 'watch https://private.test/?token=secret',
        'items': List.generate(100, (i) => '$i'),
        'long': 'x' * 1000,
        'invalidNumber': double.infinity,
      },
    ).toJson();
    expect(json['schemaVersion'], 1);
    expect(json['title'], 'movie.mkv');
    expect(json['state']['items'], hasLength(20));
    expect(json['state']['long'], hasLength(200));
    expect(json['state']['invalidNumber'], isNull);
    expect(jsonEncode(json), isNot(contains('secret')));
    expect(jsonEncode(json), isNot(contains('/private')));
    expect(
      () => PageContextData(
        pageType: 'invalid',
        state: {'object': Object()},
      ).toJson(),
      throwsArgumentError,
    );
  });

  test('nested page content has a shared budget', () {
    final json = PageContextData(
      pageType: 'large_list',
      state: {
        'items': List.generate(20, (_) => List.generate(20, (_) => 'x' * 200)),
      },
    ).toJson();
    expect(jsonEncode(json).length, lessThan(6000));
  });

  test('consumers cannot mutate the retained source', () {
    final source = PageContextSource(
      const PageContextData(
        pageType: 'media_detail',
        entity: {'media_id': 'm1'},
        state: {
          'selected': ['a'],
        },
      ),
    );
    final json = source.read();
    json['entity']['media_id'] = 'changed';
    json['state']['selected'].clear();
    expect(source.read()['entity']['media_id'], 'm1');
    expect(source.read()['state']['selected'], ['a']);
  });

  testWidgets('standard header captures the nearest route and keeps it fresh', (
    tester,
  ) async {
    PageContextSource? origin;
    late StateSetter update;
    var favorite = false;
    await tester.pumpWidget(
      host(
        AssistantAction(
          label: 'Assistant',
          onPressed: () {},
          onContext: (source) => origin = source,
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return AppPage(
                    pageContext: PageContextData(
                      pageType: 'media_detail',
                      entity: const {'media_id': 'm1'},
                      state: {'favorite': favorite},
                    ),
                    title: const Text('Movie'),
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AppPage(
                              pageContext: PageContextData(
                                pageType: 'metadata_editor',
                              ),
                              title: Text('Metadata'),
                              body: SizedBox(),
                            ),
                          ),
                        ),
                        child: const Text('Edit'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Assistant'));
    expect(origin!.read()['title'], 'Movie');
    expect(origin!.read()['entity']['media_id'], 'm1');
    final originalSource = origin!;
    update(() => favorite = true);
    await tester.pump();
    expect(originalSource.read()['state']['favorite'], true);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Assistant').last);
    expect(origin!.read()['pageType'], 'metadata_editor');
    expect(originalSource.read()['pageType'], 'media_detail');
    // Disposal leaves a safe snapshot and does not retain a BuildContext reader.
    await tester.pumpWidget(const SizedBox());
    expect(origin!.read()['pageType'], 'metadata_editor');
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom layout uses the same source without AppPage', (
    tester,
  ) async {
    PageContextSource? origin;
    await tester.pumpWidget(
      host(
        AssistantAction(
          label: 'Assistant',
          onPressed: () {},
          onContext: (source) => origin = source,
          child: const PageContextScope(
            data: PageContextData(
              pageType: 'custom',
              entity: {'media_id': 'm2'},
            ),
            child: Scaffold(body: AssistantButton()),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Assistant'));
    expect(origin!.read()['pageType'], 'custom');
    expect(origin!.read()['entity']['media_id'], 'm2');
  });
}
