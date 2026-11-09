import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../ui/components/states/content_state.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/media/content_row.dart';
import '../../ui/icons/app_icons.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_manager.dart';
import '../../services/library/library_service.dart';
import '../../ui/components/media/media_poster_card.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.sources,
    this.service,
    this.onPlay,
  });
  final SourceManager sources;
  final LibraryService? service;
  final ValueChanged<SourceSelection>? onPlay;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  AppLocalizations get l => AppLocalizations.of(context);
  LibraryService? _service;
  String? _library;
  String _search = '';
  String? _sourceFilter;
  String? _typeFilter;
  bool? _watchedFilter;
  String? _error;
  bool _favorites = false;
  bool _scanning = false;
  bool _resolving = false;
  Timer? _scanRefresh;
  int _offset = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = widget.service ?? await LibraryService.open();
      await widget.sources.load();
      if (!mounted) {
        if (widget.service == null) service.close();
        return;
      }
      setState(() {
        _service = service;
      });
    } catch (_) {
      if (mounted) setState(() => _error = l.libraryLoadFailed);
    }
  }

  @override
  void dispose() {
    _scanRefresh?.cancel();
    // Database closure waits for any active scan.
    if (widget.service == null) _service?.close();
    super.dispose();
  }

  Future<String?> _text(String title, {String initial = ''}) async {
    var value = initial;
    final result = await showShadDialog<String>(
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
              if (value.trim().isNotEmpty) {
                Navigator.pop(context, value.trim());
              }
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
    return result;
  }

  Future<void> _create() async {
    final name = await _text(l.createLibrary);
    if (name != null && mounted) {
      final type = await showShadDialog<String>(
        context: context,
        builder: (c) => ShadDialog(
          title: Text(l.contentType),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in {
                'mixed': l.mixed,
                'movie': l.movie,
                'series': l.series,
                'home': l.homeVideos,
                'audio': l.audio,
              }.entries)
                ShadButton.ghost(
                  onPressed: () => Navigator.pop(c, entry.key),
                  child: Text(entry.value),
                ),
            ],
          ),
        ),
      );
      if (type == null || !mounted) return;
      setState(() {
        _library = _service!.create(name, type: type);
        _offset = 0;
      });
    }
  }

  Future<void> _bind() async {
    try {
      await widget.sources.load();
      if (!mounted) return;
      final source = await showShadDialog<String>(
        context: context,
        builder: (context) => ShadDialog(
          title: Text(l.chooseScopeSource),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final source in widget.sources.configs.where(
                (c) => c.enabled,
              ))
                ShadButton.ghost(
                  onPressed: () => Navigator.pop(context, source.id),
                  child: Text(source.name),
                ),
              if (widget.sources.configs.where((c) => c.enabled).isEmpty)
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(l.addEnabledSource),
                ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;
      final scope = await Navigator.of(context).push<SourceEntry>(
        MaterialPageRoute(
          builder: (_) => _ScopePage(sources: widget.sources, source: source),
        ),
      );
      if (scope == null || !mounted) return;
      final binding = _service!.bind(
        _library!,
        source,
        root: scope.ref.id.isEmpty ? null : scope.ref.id,
        rootEntry: scope,
      );
      await _scan(binding);
    } catch (_) {
      if (mounted) setState(() => _error = l.bindFailed);
    }
  }

  Future<void> _scan(String binding) async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    _scanRefresh = Timer.periodic(Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
    try {
      await _service!.scan(binding, widget.sources);
    } catch (_) {
      if (mounted) setState(() => _error = l.scanFailedRetained);
    } finally {
      _scanRefresh?.cancel();
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<PlayableStream> _resolve(ResourceRef ref) async {
    if (ref.instanceId == '@local') {
      if (!await File(ref.id).exists()) throw StateError(l.localUnavailable);
      return PlayableStream(Uri.file(ref.id));
    }
    return widget.sources.resolve(ref);
  }

  String _resourceLabel(dynamic resource) {
    final checkpoint = _service!.checkpoint(resource['id'] as String);
    final progress = checkpoint != null && checkpoint['completed'] == 0
        ? l.watchedMinutes((checkpoint['position'] as int) ~/ 60000)
        : checkpoint?['completed'] == 1
        ? l.watchedSuffix
        : '';
    if (resource['source'] == '@local') return l.localResource(progress);
    final source = widget.sources.configs
        .where((c) => c.id == resource['source'] && c.enabled)
        .firstOrNull;
    if (source == null) return l.setupResource(progress);
    return '${source.name} · ${_service!.observedMissing(resource['id'] as String) ? l.missingOnScan : l.verifyOnPlay}$progress';
  }

  Future<void> _detail(dynamic media) async {
    final service = _service!;
    var childOffset = 0;
    await showShadSheet<void>(
      context: context,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, updateDetail) => ShadSheet(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * 0.8,
            child: SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ContentRow(
                    title: Text(media['title'] as String),
                    subtitle: Text(l.chooseVersion),
                  ),
                  for (final child in service.children(
                    media['id'] as String,
                    library: _library,
                    offset: childOffset,
                  ))
                    ContentRow(
                      leading: Icon(AppIcons.collection),
                      title: Text(child['title'] as String),
                      subtitle: Text(
                        '${{'series': l.series, 'season': l.season, 'episode': l.episode}[child['kind']] ?? l.media} · ${child['season'] ?? '-'} / ${child['episode'] ?? '-'}',
                      ),
                      onTap: () {
                        Navigator.pop(sheet);
                        _detail(child);
                      },
                    ),
                  if (childOffset > 0 ||
                      service
                              .children(
                                media['id'] as String,
                                library: _library,
                                offset: childOffset,
                              )
                              .length ==
                          40)
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ShadButton.ghost(
                          onPressed: childOffset == 0
                              ? null
                              : () => updateDetail(() => childOffset -= 40),
                          enabled: !(childOffset == 0),
                          child: Text(l.previousPage),
                        ),
                        ShadButton.ghost(
                          onPressed:
                              service
                                      .children(
                                        media['id'] as String,
                                        library: _library,
                                        offset: childOffset,
                                      )
                                      .length <
                                  40
                              ? null
                              : () => updateDetail(() => childOffset += 40),
                          enabled:
                              !(service
                                      .children(
                                        media['id'] as String,
                                        library: _library,
                                        offset: childOffset,
                                      )
                                      .length <
                                  40),
                          child: Text(l.nextPage),
                        ),
                      ],
                    ),
                  for (final resource in service.resources(
                    media['id'] as String,
                  ))
                    ContentRow(
                      leading: Icon(AppIcons.playMedia),
                      title: Text(resource['name'] as String),
                      subtitle: Text(_resourceLabel(resource)),
                      onTap: () async {
                        try {
                          if (_resolving) return;
                          _resolving = true;
                          final stream = await _resolve(
                            ResourceRef(
                              resource['source'] as String,
                              resource['item'] as String,
                            ),
                          );
                          if (!mounted || !sheet.mounted) {
                            await stream.release();
                            return;
                          }
                          Navigator.pop(sheet);
                          final selection = SourceSelection(
                            resource['name'] as String,
                            stream,
                            ref: ResourceRef(
                              resource['source'] as String,
                              resource['item'] as String,
                            ),
                          );
                          if (widget.onPlay != null) {
                            widget.onPlay!(selection);
                          } else {
                            Navigator.pop(context, selection);
                          }
                        } catch (_) {
                          if (sheet.mounted) {
                            ShadToaster.of(sheet).show(
                              ShadToast.destructive(
                                description: Text(l.versionOpenFailed),
                              ),
                            );
                          }
                        } finally {
                          _resolving = false;
                        }
                      },
                    ),
                  ContentRow(
                    leading: Icon(AppIcons.addToLibrary),
                    title: Text(l.addToLibrary),
                    onTap: () async {
                      final library = await showShadDialog<String>(
                        context: context,
                        builder: (c) => ShadDialog(
                          title: Text(l.chooseLibrary),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final library in service.libraries)
                                ShadButton.ghost(
                                  onPressed: () =>
                                      Navigator.pop(c, library['id'] as String),
                                  child: Text(library['name'] as String),
                                ),
                            ],
                          ),
                        ),
                      );
                      if (library != null && mounted) {
                        service.addManual(library, media['id'] as String);
                        setState(() {});
                      }
                      if (sheet.mounted) Navigator.pop(sheet);
                    },
                  ),
                  ContentRow(
                    leading: Icon(AppIcons.edit),
                    title: Text(l.correctTitle),
                    onTap: () async {
                      final title = await _text(
                        l.correctTitle,
                        initial: media['title'] as String,
                      );
                      if (title != null && mounted) {
                        service.rename(media['id'] as String, title);
                        setState(() {});
                      }
                      if (sheet.mounted) Navigator.pop(sheet);
                    },
                  ),
                  if (_library != null)
                    ContentRow(
                      leading: Icon(AppIcons.remove),
                      title: Text(l.removeFromLibrary),
                      onTap: () {
                        service.remove(_library!, media['id'] as String);
                        Navigator.pop(sheet);
                        setState(() {});
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    final rows = service == null
        ? []
        : service.query(
            _library,
            search: _search,
            favorites: _favorites,
            source: _sourceFilter,
            contentType: _typeFilter,
            watched: _watchedFilter,
            offset: _offset,
          );
    return PopScope(
      canPop: !_scanning,
      child: AppPage(
        body: service == null
            ? Center(
                child: _error == null
                    ? ContentState(message: l.loading, loading: true)
                    : Text(_error!),
              )
            : LayoutBuilder(
                builder: (context, layout) => Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: layout.maxHeight * 0.45,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            if (widget.onPlay == null &&
                                service.continueWatching().isNotEmpty) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(l.continueIncludingHistory),
                                ),
                              ),
                              SizedBox(
                                height: 100,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    for (final media
                                        in service.continueWatching())
                                      SizedBox(
                                        width: 240,
                                        child: ShadCard(
                                          padding: EdgeInsets.zero,
                                          child: ContentRow(
                                            leading: Icon(AppIcons.history),
                                            title: Text(
                                              media['title'] as String,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text(
                                              l.watchProgress(
                                                (media['position'] as int) ~/
                                                    60000,
                                                (media['duration'] as int) ~/
                                                    60000,
                                              ),
                                            ),
                                            onTap: _scanning
                                                ? null
                                                : () => _detail(media),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            if (service.libraries.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.all(12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 240,
                                      child: ShadSelect<String>(
                                        onChanged: _scanning
                                            ? null
                                            : (value) => setState(() {
                                                _library = value == '*'
                                                    ? null
                                                    : value;
                                                _offset = 0;
                                              }),
                                        initialValue: _library ?? '*',
                                        key: ValueKey(_library ?? '*'),
                                        options: [
                                          ShadOption(
                                            value: '*',
                                            child: Text(l.allLibraries),
                                          ),
                                          for (final library
                                              in service.libraries)
                                            ShadOption(
                                              value: library['id'] as String,
                                              child: Text(
                                                library['name'] as String,
                                              ),
                                            ),
                                        ],
                                        selectedOptionBuilder: (_, value) =>
                                            Text(
                                              value == '*'
                                                  ? l.allLibraries
                                                  : service.libraries
                                                            .firstWhere(
                                                              (l) =>
                                                                  l['id'] ==
                                                                  value,
                                                            )['name']
                                                        as String,
                                            ),
                                        maxWidth: 240,
                                        enabled: !(_scanning),
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 4,
                                      children: [
                                        Tooltip(
                                          message: l.renameLibrary,
                                          child: Semantics(
                                            button: true,
                                            label: l.renameLibrary,
                                            child: ShadIconButton.ghost(
                                              onPressed:
                                                  _scanning || _library == null
                                                  ? null
                                                  : () async {
                                                      final name = await _text(
                                                        l.renameLibrary,
                                                        initial:
                                                            service.libraries
                                                                    .firstWhere(
                                                                      (l) =>
                                                                          l['id'] ==
                                                                          _library,
                                                                    )['name']
                                                                as String,
                                                      );
                                                      if (name != null &&
                                                          mounted) {
                                                        setState(
                                                          () => service
                                                              .renameLibrary(
                                                                _library!,
                                                                name,
                                                              ),
                                                        );
                                                      }
                                                    },
                                              icon: Icon(AppIcons.rename),
                                              enabled:
                                                  !(_scanning ||
                                                      _library == null),
                                              width: 48,
                                              height: 48,
                                            ),
                                          ),
                                        ),
                                        Tooltip(
                                          message: l.addSourceScope,
                                          child: Semantics(
                                            button: true,
                                            label: l.addSourceScope,
                                            child: ShadIconButton.ghost(
                                              onPressed:
                                                  _scanning || _library == null
                                                  ? null
                                                  : _bind,
                                              icon: Icon(AppIcons.addFolder),
                                              enabled:
                                                  !(_scanning ||
                                                      _library == null),
                                              width: 48,
                                              height: 48,
                                            ),
                                          ),
                                        ),
                                        Tooltip(
                                          message: l.deleteLibrary,
                                          child: Semantics(
                                            button: true,
                                            label: l.deleteLibrary,
                                            child: ShadIconButton.ghost(
                                              onPressed:
                                                  _scanning || _library == null
                                                  ? null
                                                  : () async {
                                                      final confirmed = await showShadDialog<bool>(
                                                        context: context,
                                                        builder: (c) => ShadDialog(
                                                          title: Text(
                                                            l.deleteLibraryConfirm,
                                                          ),
                                                          actions: [
                                                            ShadButton.ghost(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    c,
                                                                    false,
                                                                  ),
                                                              child: Text(
                                                                l.cancel,
                                                              ),
                                                            ),
                                                            ShadButton.ghost(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    c,
                                                                    true,
                                                                  ),
                                                              child: Text(
                                                                l.delete,
                                                              ),
                                                            ),
                                                          ],
                                                          child: Text(
                                                            l.deleteLibraryDescription,
                                                          ),
                                                        ),
                                                      );
                                                      if (confirmed == true &&
                                                          mounted) {
                                                        setState(() {
                                                          service.delete(
                                                            _library!,
                                                          );
                                                          _library =
                                                              service
                                                                      .libraries
                                                                      .firstOrNull?['id']
                                                                  as String?;
                                                          _offset = 0;
                                                        });
                                                      }
                                                    },
                                              icon: Icon(AppIcons.delete),
                                              enabled:
                                                  !(_scanning ||
                                                      _library == null),
                                              width: 48,
                                              height: 48,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            if (_library != null) ...[
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: ShadInput(
                                  placeholder: Text(l.searchLibrary),
                                  leading: Icon(AppIcons.search),
                                  onChanged: (value) => setState(() {
                                    _search = value;
                                    _offset = 0;
                                  }),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ShadSelect<String>(
                                    onChanged: (value) => setState(() {
                                      _sourceFilter = value == '*'
                                          ? null
                                          : value;
                                      _offset = 0;
                                    }),
                                    initialValue: _sourceFilter ?? '*',
                                    key: ValueKey('source-$_sourceFilter'),
                                    options: [
                                      ShadOption(
                                        value: '*',
                                        child: Text(l.allSources),
                                      ),
                                      for (final source
                                          in widget.sources.configs)
                                        ShadOption(
                                          value: source.id,
                                          child: Text(source.name),
                                        ),
                                    ],
                                    selectedOptionBuilder: (_, value) => Text(
                                      value == '*'
                                          ? l.allSources
                                          : widget.sources.configs
                                                .firstWhere(
                                                  (s) => s.id == value,
                                                )
                                                .name,
                                    ),
                                    maxWidth: 240,
                                    enabled: !_scanning,
                                  ),
                                  ShadSelect<String>(
                                    onChanged: (value) => setState(() {
                                      _typeFilter = value == '*' ? null : value;
                                      _offset = 0;
                                    }),
                                    initialValue: _typeFilter ?? '*',
                                    key: ValueKey('type-$_typeFilter'),
                                    options: [
                                      for (final entry in {
                                        '*': l.allTypes,
                                        'movie': l.movie,
                                        'series': l.series,
                                        'season': l.season,
                                        'episode': l.episode,
                                        'video': l.video,
                                        'audio': l.audio,
                                      }.entries)
                                        ShadOption(
                                          value: entry.key,
                                          child: Text(entry.value),
                                        ),
                                    ],
                                    selectedOptionBuilder: (_, value) => Text(
                                      {
                                        '*': l.allTypes,
                                        'movie': l.movie,
                                        'series': l.series,
                                        'season': l.season,
                                        'episode': l.episode,
                                        'video': l.video,
                                        'audio': l.audio,
                                      }[value]!,
                                    ),
                                    maxWidth: 240,
                                    enabled: !_scanning,
                                  ),
                                  ShadSelect<String>(
                                    onChanged: (value) => setState(() {
                                      _watchedFilter = value == '*'
                                          ? null
                                          : value == 'yes';
                                      _offset = 0;
                                    }),
                                    initialValue: _watchedFilter == null
                                        ? '*'
                                        : _watchedFilter!
                                        ? 'yes'
                                        : 'no',
                                    key: ValueKey('watched-$_watchedFilter'),
                                    options: [
                                      ShadOption(
                                        value: '*',
                                        child: Text(l.allWatchStates),
                                      ),
                                      ShadOption(
                                        value: 'yes',
                                        child: Text(l.watched),
                                      ),
                                      ShadOption(
                                        value: 'no',
                                        child: Text(l.unwatched),
                                      ),
                                    ],
                                    selectedOptionBuilder: (_, value) => Text(
                                      {
                                        '*': l.allWatchStates,
                                        'yes': l.watched,
                                        'no': l.unwatched,
                                      }[value]!,
                                    ),
                                    maxWidth: 240,
                                    enabled: !_scanning,
                                  ),
                                  ShadCheckbox(
                                    label: Text(l.favorite),
                                    value: _favorites,
                                    onChanged: (value) => setState(() {
                                      _favorites = value;
                                      _offset = 0;
                                    }),
                                  ),
                                  ShadButton.ghost(
                                    onPressed: _scanning
                                        ? null
                                        : () {
                                            service.clearIgnored(_library!);
                                            setState(() {});
                                          },
                                    width: double.infinity,
                                    height: 0,
                                    expands: true,
                                    enabled: !(_scanning),
                                    child: Text(l.restoreIgnored),
                                  ),
                                ],
                              ),
                              for (final binding in service.bindings(_library!))
                                ContentRow(
                                  dense: true,
                                  title: Text(
                                    '${binding['status']} · ${widget.sources.configs.where((c) => c.id == binding['source']).firstOrNull?.name ?? l.sourceNeedsSetup}',
                                  ),
                                  subtitle: binding['error'] == null
                                      ? null
                                      : Text(binding['error'] as String),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Tooltip(
                                        message: l.rescan,
                                        child: Semantics(
                                          button: true,
                                          label: l.rescan,
                                          child: ShadIconButton.ghost(
                                            onPressed: _scanning
                                                ? null
                                                : () => _scan(
                                                    binding['id'] as String,
                                                  ),
                                            icon: Icon(AppIcons.refresh),
                                            enabled: !(_scanning),
                                            width: 48,
                                            height: 48,
                                          ),
                                        ),
                                      ),
                                      Tooltip(
                                        message: l.removeBinding,
                                        child: Semantics(
                                          button: true,
                                          label: l.removeBinding,
                                          child: ShadIconButton.ghost(
                                            onPressed: _scanning
                                                ? null
                                                : () async {
                                                    final count = service
                                                        .bindingImpact(
                                                          binding['id']
                                                              as String,
                                                        );
                                                    final confirmed =
                                                        await showShadDialog<
                                                          bool
                                                        >(
                                                          context: context,
                                                          builder: (c) => ShadDialog(
                                                            title: Text(
                                                              l.removeBindingConfirm,
                                                            ),
                                                            actions: [
                                                              ShadButton.ghost(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      c,
                                                                      false,
                                                                    ),
                                                                child: Text(
                                                                  l.cancel,
                                                                ),
                                                              ),
                                                              ShadButton.ghost(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      c,
                                                                      true,
                                                                    ),
                                                                child: Text(
                                                                  l.remove,
                                                                ),
                                                              ),
                                                            ],
                                                            child: Text(
                                                              l.removeBindingDescription(
                                                                count,
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                    if (confirmed == true &&
                                                        mounted) {
                                                      setState(
                                                        () => service
                                                            .removeBinding(
                                                              binding['id']
                                                                  as String,
                                                            ),
                                                      );
                                                    }
                                                  },
                                            icon: Icon(AppIcons.unlink),
                                            enabled: !(_scanning),
                                            width: 48,
                                            height: 48,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            if (_scanning) ShadProgress(),
                            if (_error != null)
                              ShadAlert.destructive(title: Text(_error!)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: service.libraries.isEmpty
                          ? Center(
                              child: ShadButton(
                                onPressed: _create,
                                child: Text(l.createFirstLibrary),
                              ),
                            )
                          : rows.isEmpty
                          ? Center(
                              child: Text(
                                _search.isNotEmpty ||
                                        _favorites ||
                                        _sourceFilter != null ||
                                        _typeFilter != null ||
                                        _watchedFilter != null
                                    ? l.noMatchingMedia
                                    : l.libraryEmpty,
                              ),
                            )
                          : GridView.builder(
                              padding: EdgeInsets.all(16),
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 220,
                                    mainAxisExtent:
                                        240 +
                                        MediaQuery.textScalerOf(context)
                                                .scale(20) *
                                            2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount: rows.length,
                              itemBuilder: (_, index) {
                                final media = rows[index];
                                return MediaPosterCard(
                                  title: media['title'] as String,
                                  favorite: media['favorite'] == 1,
                                  onOpen: _scanning
                                      ? null
                                      : () => _detail(media),
                                  onFavorite: () => setState(
                                    () => service.favorite(
                                      media['id'] as String,
                                      media['favorite'] != 1,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (_library != null)
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ShadButton.ghost(
                            onPressed: _offset == 0
                                ? null
                                : () => setState(() => _offset -= 40),
                            enabled: !(_offset == 0),
                            child: Text(l.previousPage),
                          ),
                          Text('${_offset ~/ 40 + 1}'),
                          ShadButton.ghost(
                            onPressed: rows.length < 40
                                ? null
                                : () => setState(() => _offset += 40),
                            enabled: !(rows.length < 40),
                            child: Text(l.nextPage),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
        title: Text(l.library),
        actions: [
          if (service != null)
            Tooltip(
              message: l.createLibrary,
              child: Semantics(
                button: true,
                label: l.createLibrary,
                child: ShadIconButton.ghost(
                  onPressed: _scanning ? null : _create,
                  icon: Icon(AppIcons.add),
                  enabled: !(_scanning),
                  width: 48,
                  height: 48,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScopePage extends StatefulWidget {
  const _ScopePage({required this.sources, required this.source});
  final SourceManager sources;
  final String source;
  @override
  State<_ScopePage> createState() => _ScopePageState();
}

class _ScopePageState extends State<_ScopePage> {
  AppLocalizations get l => AppLocalizations.of(context);
  final List<SourceEntry> _path = [];
  List<SourceEntry> _folders = [];
  int? _next;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await widget.sources.browse(
        widget.source,
        BrowseRequest(node: _path.lastOrNull?.ref, offset: more ? _next! : 0),
      );
      if (mounted) {
        setState(() {
          _folders = [
            ...(more ? _folders : <SourceEntry>[]),
            ...page.entries.where((e) => e.isFolder),
          ];
          _next = page.nextOffset;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = l.browseFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    body: Column(
      children: [
        Padding(padding: EdgeInsets.all(16), child: Text(l.scopeDescription)),
        if (_busy) ShadProgress(),
        if (_error != null)
          ShadButton.ghost(onPressed: () => _load(), child: Text(_error!)),
        if (_path.isNotEmpty)
          ContentRow(
            title: Text(l.parent),
            onTap: _busy
                ? null
                : () {
                    _path.removeLast();
                    _load();
                  },
          ),
        Expanded(
          child: ListView(
            children: [
              for (final folder in _folders)
                ContentRow(
                  leading: Icon(AppIcons.folder),
                  title: Text(folder.name),
                  onTap: _busy
                      ? null
                      : () {
                          _path.add(folder);
                          _load();
                        },
                ),
              if (_next != null)
                ShadButton.ghost(
                  onPressed: _busy ? null : () => _load(more: true),
                  enabled: !(_busy),
                  child: Text(l.loadMore),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: ShadButton(
            onPressed: _busy || _error != null
                ? null
                : () => Navigator.pop(
                    context,
                    _path.lastOrNull ??
                        SourceEntry(
                          ResourceRef(widget.source, ''),
                          l.rootFolder,
                          isFolder: true,
                        ),
                  ),
            enabled: !(_busy || _error != null),
            child: Text(l.confirmScanScope),
          ),
        ),
      ],
    ),
    title: Text(_path.lastOrNull?.name ?? l.chooseScanScope),
  );
}
