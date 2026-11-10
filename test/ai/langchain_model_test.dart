import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/plugins/model_langchain/langchain_model.dart';

void main() {
  test('SDK assembles interleaved streaming arguments and preserves call/result IDs', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    Map<String, dynamic>? payload;
    server.listen((request) async {
      payload = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      void chunk(Map<String, dynamic> delta, String? reason) =>
          request.response.write(
            'data: ${jsonEncode({
              'id': 'reply',
              'object': 'chat.completion.chunk',
              'created': 1,
              'model': 'test-model',
              'choices': [
                {'index': 0, 'delta': delta, 'finish_reason': reason},
              ],
            })}\n\n',
          );
      chunk({
        'role': 'assistant',
        'content': 'Looking',
        'tool_calls': [
          {
            'index': 0,
            'id': 'first',
            'type': 'function',
            'function': {'name': 'search_media', 'arguments': '{"query":'},
          },
          {
            'index': 1,
            'id': 'second',
            'type': 'function',
            'function': {'name': 'context_get', 'arguments': '{'},
          },
        ],
      }, null);
      chunk({
        'tool_calls': [
          {
            'index': 1,
            'function': {'arguments': '}'},
          },
          {
            'index': 0,
            'function': {'arguments': '"movie"}'},
          },
        ],
      }, null);
      chunk({}, 'tool_calls');
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
    });
    final model = LangChainModel(
      apiKey: 'secret-test',
      model: 'test-model',
      endpoint: 'http://127.0.0.1:${server.port}/v1',
    );
    final events = await model
        .infer(
          const ModelInferenceRequest(
            [
              ModelMessage('user', 'Find media'),
              ModelMessage(
                'assistant',
                '',
                calls: [ModelToolCall('previous', 'context_get', '{}')],
              ),
              ModelMessage('tool', '{"page":"home"}', callId: 'previous'),
            ],
            tools: [
              ModelTool('search_media', 'Search', {'type': 'object'}),
            ],
          ),
        )
        .toList();
    expect(events.whereType<ModelTextDelta>().single.text, 'Looking');
    final calls = events
        .whereType<ModelToolDelta>()
        .map((e) => e.call)
        .toList();
    expect(calls.map((c) => c.id), ['first', 'second']);
    expect(jsonDecode(calls.first.arguments), {'query': 'movie'});
    expect(jsonDecode(calls.last.arguments), {});
    expect(events.last, isA<ModelCompleted>());
    final messages = payload!['messages'] as List;
    expect(messages.last['tool_call_id'], 'previous');
    expect(jsonEncode(payload), isNot(contains('secret-test')));
  });

  test('SDK refuses tool calls terminated by length limit', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: ${jsonEncode({
          'id': 'r',
          'object': 'chat.completion.chunk',
          'created': 1,
          'model': 'm',
          'choices': [
            {
              'index': 0,
              'delta': {
                'tool_calls': [
                  {
                    'index': 0,
                    'id': 'a',
                    'type': 'function',
                    'function': {'name': 'write', 'arguments': '{"value":'},
                  },
                ],
              },
              'finish_reason': 'length',
            },
          ],
        })}\n\ndata: [DONE]\n\n',
      );
      await request.response.close();
    });
    final model = LangChainModel(
      apiKey: 'key',
      model: 'm',
      endpoint: 'http://127.0.0.1:${server.port}/v1',
    );
    await expectLater(
      model
          .infer(const ModelInferenceRequest([ModelMessage('user', 'write')]))
          .toList(),
      throwsA(
        isA<ModelFailure>().having((e) => e.code, 'code', 'incompleteToolCall'),
      ),
    );
  });
  test(
    'authentication errors become safe typed failures without provider body',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        await request.drain<void>();
        request.response.statusCode = 401;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'error': {
              'message': 'secret-token and private-url',
              'type': 'invalid_api_key',
            },
          }),
        );
        await request.response.close();
      });
      final model = LangChainModel(
        apiKey: 'secret-token',
        model: 'm',
        endpoint: 'http://127.0.0.1:${server.port}/v1',
      );
      await expectLater(
        model
            .infer(const ModelInferenceRequest([ModelMessage('user', 'hello')]))
            .toList(),
        throwsA(
          isA<ModelFailure>().having(
            (e) => e.code,
            'code',
            'authenticationFailed',
          ),
        ),
      );
    },
  );
}
