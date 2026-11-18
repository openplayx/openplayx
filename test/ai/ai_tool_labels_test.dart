import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/features/assistant/model/ai_tool_labels.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('Torrent labels preserve the full name in cards and activity', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final entry in {
      'mcp_orrent_list_destinations': 'Mcp Torrent list destinations',
      'mcp_orrent_create_plan': 'Mcp Torrent create plan',
      'mcp_orrent_start_download': 'Mcp Torrent start download',
    }.entries) {
      expect(AiToolLabels.tool(context, entry.key), entry.value);
      expect(
        AiToolLabels.activity(context, 'tool', entry.key),
        'Running: ${entry.value}',
      );
      expect(
        AiToolLabels.activity(context, 'confirm', entry.key),
        'Waiting for you: ${entry.value}',
      );
    }

    // The repair is limited to the MCP service prefix.
    expect(
      AiToolLabels.tool(context, 'mcp_abc123_create_plan'),
      'Mcp abc123 create plan',
    );
    expect(
      AiToolLabels.tool(context, 'mcp_abc123_orrent'),
      'Mcp abc123 orrent',
    );
    expect(
      AiToolLabels.tool(context, 'orrent_create_plan'),
      'Orrent create plan',
    );
    expect(AiToolLabels.tool(context, 'playback_pause'), 'Pause');
    expect(AiToolLabels.tool(context, null), '');
  });
}
