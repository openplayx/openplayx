import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../capabilities/sources/source_manager.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../ui/components/media/content_row.dart';

/// Connector sources hidden on this device, each with a restore action.
Future<void> showHiddenConnectorSources(
  BuildContext context,
  SourceManager manager,
) {
  final l = AppLocalizations.of(context);
  return showShadDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) {
        final hidden = manager.discoveredSources
            .where(manager.sourceHidden)
            .toList();
        return ShadDialog(
          title: Text(l.connectorSourcesHidden),
          child: SizedBox(
            width: 360,
            height: ((hidden.length + 1) * 80).clamp(80, 400).toDouble(),
            child: ListView(
              shrinkWrap: true,
              children: [
                if (hidden.isEmpty) Text(l.connectorSourceNoneHidden),
                for (final entry in hidden)
                  ContentRow(
                    title: Text(entry.name),
                    subtitle: Text(entry.connectorName),
                    trailing: ShadButton.ghost(
                      child: Text(l.connectorSourceRestore),
                      onPressed: () async {
                        await manager.hideDiscoveredSource(entry, false);
                        if (context.mounted) update(() {});
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
