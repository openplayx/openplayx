import 'package:flutter/material.dart';

import '../../../capabilities/library/library_service.dart';
import '../../../capabilities/sources/source_manager.dart';
import '../../../core/capabilities/source_capability.dart';
import '../../../data/remote_access/discovered_source.dart';
import '../../../data/sources/source_config.dart';
import 'scan_scope_page.dart';
import 'source_instance_form.dart';

/// Shared by Sources and Add Video. Discovery never starts a scan itself.
Future<bool> setupConnectorSource(
  BuildContext context,
  SourceManager sources,
  DiscoveredSource entry, {
  LibraryService? library,
}) async {
  if (!entry.enabled || entry.kind == null) return false;
  final existing = sources.configs
      .where(
        (c) =>
            c.remote?.accountId == entry.accountId &&
            c.remote?.proxy == entry.serviceId,
      )
      .firstOrNull;
  return await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'ConnectorSourceSetup'),
          builder: (_) => SourceInstanceForm(
            manager: sources,
            initial: existing ?? entry.draft(),
            onAddToHome: library == null
                ? null
                : (id) async {
                    if (!context.mounted) return false;
                    final scope = await Navigator.of(context).push<SourceEntry>(
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'ScanScopePage'),
                        builder: (_) => ScanScopePage(
                          sources: sources,
                          source: id,
                          forHome: true,
                          requireFolder:
                              entry.kind == SourceKind.smb ||
                              !entry.kind!.files,
                        ),
                      ),
                    );
                    if (scope == null || !context.mounted) return false;
                    final binding = library.addToHome(
                      id,
                      root: scope.ref.id,
                      name: scope.name,
                      entry: scope,
                    );
                    library.startScan(binding, sources);
                    return true;
                  },
          ),
        ),
      ) ??
      false;
}
