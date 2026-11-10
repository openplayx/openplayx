import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../ui/components/media/source_kind_icon.dart';
import '../../ui/tokens/app_spacing.dart';

import '../../ui/adaptive/app_page.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_manager.dart';
import '../../data/sources/source_schema.dart';

class SourceDefaultsPage extends StatefulWidget {
  const SourceDefaultsPage({super.key, required this.manager});
  final SourceManager manager;
  @override
  State<SourceDefaultsPage> createState() => _SourceDefaultsPageState();
}

class _SourceDefaultsPageState extends State<SourceDefaultsPage> {
  AppLocalizations get l => AppLocalizations.of(context);
  String? _error;
  bool _busy = false;
  Future<void> _save(String capability, String? id) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.manager.setDefault(capability, id);
    } catch (error) {
      if (mounted) {
        _error = error is PluginException ? error.message : l.defaultSaveFailed;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _searchScope(String id, bool selected) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ids = widget.manager.bindings.searchInstances.toSet();
      selected ? ids.add(id) : ids.remove(id);
      await widget.manager.setSearchInstances(ids.toList());
    } catch (_) {
      if (mounted) _error = l.defaultSaveFailed;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _selected(String capability) {
    final id = widget.manager.bindings.defaults[capability];
    return widget.manager.configs.any(
          (c) =>
              c.id == id &&
              c.enabled &&
              SourceSchemas.forKind(c.kind).capabilities.contains(capability),
        )
        ? id!
        : '';
  }

  @override
  Widget build(BuildContext context) => AppPage(
    body: ListView(
      padding: AppSpacing.page(context),
      children: [
        Text(l.defaultDescription),
        for (final capability in ['source.browse', 'source.resolve'])
          Padding(
            padding: EdgeInsets.only(top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  capability == 'source.browse'
                      ? l.defaultBrowse
                      : l.defaultResolve,
                ),
                SizedBox(height: 8),
                // Align loosens the stretched (tight) width, so the select's own
                // maxWidth no longer conflicts with the column's minimum.
                Align(
                  alignment: Alignment.centerLeft,
                  child: ShadSelect<String>(
                    key: ValueKey(
                      '$capability-${widget.manager.bindings.defaults[capability]}',
                    ),
                    initialValue: _selected(capability),
                    onChanged: _busy
                        ? null
                        : (value) =>
                              _save(capability, value == '' ? null : value),
                    options: [
                      ShadOption(value: '', child: Text(l.chooseEachTime)),
                      for (final config in widget.manager.configs.where(
                        (c) =>
                            c.enabled &&
                            SourceSchemas.forKind(c.kind).capabilities
                                .contains(capability),
                      ))
                        ShadOption(
                          value: config.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SourceKindIcon(config.kind, size: 24),
                              const SizedBox(width: 8),
                              Text(config.displayName),
                            ],
                          ),
                        ),
                    ],
                    selectedOptionBuilder: (_, id) => Text(
                      id.isEmpty
                          ? l.chooseEachTime
                          : widget.manager.configs
                                .firstWhere((c) => c.id == id)
                                .displayName,
                    ),
                    enabled: !_busy,
                    maxWidth: 640,
                  ),
                ),
              ],
            ),
          ),
        if (widget.manager.bindings.defaults.entries.any(
          (e) => _selected(e.key).isEmpty,
        ))
          Text(l.defaultUnavailable),
        SizedBox(height: 24),
        Text(l.searchScope),
        Text(l.searchScopeDescription),
        for (final source in widget.manager.configs.where(
          (s) =>
              s.enabled &&
              SourceSchemas.forKind(s.kind).capabilities
                  .contains('search.media'),
        ))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ShadCheckbox(
              value: widget.manager.bindings.searchInstances.contains(
                source.id,
              ),
              enabled: !_busy,
              label: Text(source.displayName),
              onChanged: (value) => _searchScope(source.id, value),
            ),
          ),
        if (_error != null)
          Padding(
            padding: EdgeInsets.only(top: 12),
            child: ShadAlert.destructive(title: Text(_error!)),
          ),
      ],
    ),
    title: Text(l.sourceDefaultsTitle),
  );
}
