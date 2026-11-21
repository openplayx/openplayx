import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../capabilities/library/file_source.dart';
import '../../../capabilities/sources/source_manager.dart';
import '../../../core/capabilities/source_capability.dart';
import '../../../data/library/scan_status.dart';
import '../../../data/sources/source_config.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../ui/icons/app_icons.dart';
import '../../../ui/tokens/app_spacing.dart';
import '../controller/file_source_controller.dart';
import 'file_source_browser_page.dart';
import 'scan_scope_page.dart';
import 'widgets/source_list_widgets.dart';

Future<String?> _promptText(
  BuildContext context,
  String title, {
  String initial = '',
}) {
  final l = AppLocalizations.of(context);
  var value = initial;
  return showShadDialog<String>(
    context: context,
    builder: (context) => ShadDialog(
      title: Text(title),
      actions: [
        ShadButton.ghost(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        ShadButton(
          onPressed: () {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
          child: Text(l.save),
        ),
      ],
      child: ShadInput(
        initialValue: initial,
        onChanged: (text) => value = text,
        autofocus: true,
      ),
    ),
  );
}

/// Adds a file source to [connection]: tick one folder, name it, done
/// (VidHub-style); it is scanned right away.
Future<void> addFileSource(
  BuildContext context,
  FileSourceController controller,
  String connection,
) async {
  final l = AppLocalizations.of(context);
  final scope = await Navigator.of(context).push<SourceEntry>(
    MaterialPageRoute(
      settings: const RouteSettings(name: 'ScanScopePage'),
      builder: (_) =>
          ScanScopePage(sources: controller.sources, source: connection),
    ),
  );
  if (scope == null || !context.mounted) return;
  final name = await _promptText(
    context,
    l.nameFileSource,
    initial: controller.suggestedName(connection, scope),
  );
  if (name == null || !context.mounted) return;
  await controller.add(connection, scope, name);
}

Future<void> _rename(
  BuildContext context,
  FileSourceController controller,
  String id,
  String current,
) async {
  final name = await _promptText(
    context,
    AppLocalizations.of(context).nameFileSource,
    initial: current,
  );
  if (name != null) controller.rename(id, name);
}

Future<void> _remove(
  BuildContext context,
  FileSourceController controller,
  String id,
) async {
  final l = AppLocalizations.of(context);
  final count = controller.impact(id);
  final confirmed = await showShadDialog<bool>(
    context: context,
    builder: (c) => ShadDialog(
      title: Text(l.removeFileSourceConfirm),
      actions: [
        ShadButton.ghost(
          onPressed: () => Navigator.pop(c, false),
          child: Text(l.cancel),
        ),
        ShadButton.ghost(
          onPressed: () => Navigator.pop(c, true),
          child: Text(l.remove),
        ),
      ],
      child: Text(l.removeBindingDescription(count)),
    ),
  );
  if (confirmed == true) controller.remove(id);
}

/// One file source, shown as a child of its connection.
class FileSourceRow extends StatelessWidget {
  const FileSourceRow({
    super.key,
    required this.fileSource,
    required this.controller,
    this.connection,
    this.onPlay,
  });
  final FileSource fileSource;
  final FileSourceController controller;
  final SourceConfig? connection;
  final ValueChanged<SourceSelection>? onPlay;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final library = controller.library;
    final busy = controller.scanning;
    final f = fileSource;
    final id = f.id;
    final enabled = f.enabled;
    final title = f.name ?? connection?.displayName ?? l.sourceNeedsSetup;
    final scanning = f.scanning;
    // Scraping follows the scan, so its progress is shown right after it.
    final scrape = enabled && !scanning
        ? library.metadataProgressFor(id)
        : (done: 0, total: 0);
    final scraping = scrape.total > 0 && scrape.done < scrape.total;
    final scrapeStatus = scrape.total == 0
        ? ''
        : ' · ${scraping ? l.metadataProgressLabel(scrape.done, scrape.total) : l.metadataProgressDone}';
    final status = enabled
        ? '${ScanStatus.label(f.status)}${scanning ? ' · ${l.scanFoundMedia(library.scannedMediaCount(id))}' : scrapeStatus}'
        : l.fileSourceDisabled;
    final root = f.root ?? '';
    final canBrowse = enabled && connection != null && connection!.enabled;
    final canScan = canBrowse && !busy;
    void browse() {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'FileSourceBrowserPage'),
          builder: (_) => FileSourceBrowserPage(
            manager: controller.sources,
            sourceId: connection!.id,
            title: title,
            root: root.isEmpty ? null : ResourceRef(connection!.id, root),
            onPlay: onPlay,
          ),
        ),
      );
    }

    final theme = ShadTheme.of(context);
    return SourceListRow(
      key: ValueKey('file-source-$id'),
      title: title,
      leading: Icon(
        AppIcons.folder,
        size: 20,
        color: theme.colorScheme.mutedForeground,
      ),
      onTap: canBrowse ? browse : null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            root.isEmpty ? l.sourceRootFolder : root,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$status${f.error == null ? '' : ' · ${ScanStatus.error(f.error)}'}',
            key: ValueKey('file-source-status-$id'),
            style: f.error == null
                ? null
                : TextStyle(color: theme.colorScheme.destructive),
          ),
          if (scanning || scraping)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: LinearProgressIndicator(
                value: scanning ? null : scrape.done / scrape.total,
                minHeight: 2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
      actions: SourceActionsMenu(
        key: ValueKey('file-source-menu-$id'),
        label: title,
        enabled: !busy,
        actions: [
          SourceRowAction(
            key: ValueKey('file-source-scan-$id'),
            label: l.rescanFileSource,
            icon: AppIcons.refresh,
            onPressed: canScan ? () => controller.scan([id]) : null,
          ),
          SourceRowAction(
            key: ValueKey('file-source-browse-$id'),
            label: l.browseSourceFiles,
            icon: AppIcons.openFolder,
            onPressed: canBrowse ? browse : null,
          ),
          SourceRowAction(
            key: ValueKey('file-source-edit-$id'),
            label: l.edit,
            icon: AppIcons.edit,
            onPressed: () => _rename(context, controller, id, title),
          ),
          SourceRowAction(
            key: ValueKey('file-source-toggle-$id'),
            label: enabled ? l.fileSourceDisable : l.fileSourceEnable,
            icon: enabled ? AppIcons.pause : AppIcons.play,
            onPressed: () => controller.setEnabled(id, !enabled),
          ),
          SourceRowAction(
            key: ValueKey('file-source-delete-$id'),
            label: l.remove,
            icon: AppIcons.delete,
            destructive: true,
            onPressed: () => _remove(context, controller, id),
          ),
        ],
      ),
    );
  }
}
