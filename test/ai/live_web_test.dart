// Live check of page reading and the preset 联网搜索 MCP service against
// the real internet. Skipped unless WEB_LIVE=1:
//   WEB_LIVE=1 flutter test test/ai/live_web_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/assistant/plugins/external/external_presets.dart';
import 'package:openplayx/assistant/plugins/external/external_service_registry.dart';
import 'package:openplayx/assistant/plugins/external/external_service_setup.dart';
import 'package:openplayx/assistant/plugins/web/page_reader.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/assistant/plugins/web/safe_http.dart';

void main() {
  final skip = Platform.environment['WEB_LIVE'] == '1' ? false : 'WEB_LIVE!=1';

  test('reads a public HTTPS page', () async {
    final page = await PageReader().read(
      Uri.parse('https://dart.dev/overview'),
    );
    // ignore: avoid_print
    print(
      '${page.title} (${page.text.length} chars)\n'
      '${page.text.substring(0, page.text.length.clamp(0, 800))}',
    );
    expect(page.text.length, greaterThan(500));
  }, skip: skip);

  test('rejects a host that resolves to loopback', () async {
    await expectLater(
      SafeHttp().request(Uri.parse('http://localhost:80/')),
      throwsA(isA<WebException>()),
    );
  }, skip: skip);

  test('preset 联网搜索 answers the MCP handshake and lists its tool', () async {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    // MCP_TAVILY_IP pins the address when a local resolver still caches the
    // domain's old delegation; TLS is still verified against the host name.
    final pinned = Platform.environment['MCP_TAVILY_IP'];
    final setup = ExternalServiceSetup(
      registry: ExternalServiceRegistry(db: db),
      http: pinned == null
          ? null
          : () =>
                HttpClient()
                  ..connectionFactory = (uri, _, _) async =>
                      ConnectionTask.fromSocket(
                        Socket.connect(pinned, 443).then<Socket>(
                          (s) => SecureSocket.secure(s, host: uri.host),
                        ),
                        () {},
                      ),
    );
    final probe = await setup.probe(
      ExternalPresets.tavily.baseUrl,
      'live-test-install-0001',
    );
    expect(probe.endpoint, ExternalPresets.tavily.endpoint);
    expect(probe.serverName, 'mcp-tavily');
    expect(probe.tools, ['web_search']);
    // The bundled definition must match what the server lists.
    expect(probe.toolDefs.single, ExternalPresets.tavily.toolDefs.single);
  }, skip: skip);
}
