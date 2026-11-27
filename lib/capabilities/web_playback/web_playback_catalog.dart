import 'dart:io';

import '../../core/capabilities/source_capability.dart';
import '../../data/configuration/configuration_database.dart';
import '../library/library_service.dart';
import '../sources/source_manager.dart';

class WebMedia {
  const WebMedia({
    required this.id,
    required this.title,
    required this.name,
    required this.ref,
    this.positionMs = 0,
  });
  final String id, title, name;
  final ResourceRef ref;
  final int positionMs;
  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'name': name,
    'positionMs': positionMs,
  };
}

class WebShareScope {
  const WebShareScope(this.id, this.name);
  final String id, name;
}

/// Keeps the HTTP boundary independent of persistence and source credentials.
abstract interface class WebPlaybackCatalog {
  List<WebShareScope> get scopes;
  Set<String> loadSharedScopes();
  void saveSharedScopes(Set<String> ids);
  List<WebMedia> list(Set<String> shared, {String search = '', int offset = 0});
  WebMedia? find(Set<String> shared, String id);
  Future<PlayableStream> open(WebMedia media);
  String beginProgress(WebMedia media);
  void saveProgress(
    WebMedia media,
    String session,
    int positionMs,
    int durationMs,
    bool completed,
  );
}

class LibraryWebPlaybackCatalog implements WebPlaybackCatalog {
  LibraryWebPlaybackCatalog(this.library, this.sources);
  final LibraryService library;
  final SourceManager sources;

  @override
  List<WebShareScope> get scopes => [
    for (final f in library.fileSourceList())
      if (f.enabled && library.repository.enabledFileSourceIds().contains(f.id))
        WebShareScope(
          f.id,
          f.name ??
              sources.configs
                  .where((c) => c.id == f.connectionId)
                  .firstOrNull
                  ?.name ??
              f.id,
        ),
  ];

  @override
  Set<String> loadSharedScopes() {
    final saved = ConfigurationDatabase.readSetting(
      library.configuration,
      'web_playback',
      'shared_scopes',
    );
    return saved is List ? saved.whereType<String>().toSet() : {};
  }

  @override
  void saveSharedScopes(Set<String> ids) => ConfigurationDatabase.writeSetting(
    library.configuration,
    'web_playback',
    'shared_scopes',
    ids.toList(),
  );

  WebMedia _media(dynamic row) => WebMedia(
    id: row['id'] as String,
    title: row['title'] as String,
    name: row['name'] as String,
    ref: ResourceRef(row['source'] as String, row['item'] as String),
    positionMs:
        library.progressOf(row['id'] as String)?.position.inMilliseconds ?? 0,
  );

  @override
  List<WebMedia> list(
    Set<String> shared, {
    String search = '',
    int offset = 0,
  }) => [
    for (final r in library.repository.webResources(
      shared,
      search: search,
      offset: offset,
    ))
      _media(r),
  ];

  @override
  WebMedia? find(Set<String> shared, String id) {
    final row = library.repository
        .webResources(shared, resource: id, limit: 1)
        .firstOrNull;
    return row == null ? null : _media(row);
  }

  @override
  Future<PlayableStream> open(WebMedia media) async {
    final stream = await sources.resolve(media.ref);
    final uri = stream.uri;
    // The browser never sees source URLs or credentials. Only host-owned
    // loopback gateways or local files cross this boundary.
    if (uri.scheme == 'file' ||
        (uri.scheme == 'http' &&
            uri.host == '127.0.0.1' &&
            !uri.hasQuery &&
            uri.userInfo.isEmpty)) {
      return stream;
    }
    await stream.release();
    throw const FileSystemException('source_requires_gateway');
  }

  @override
  String beginProgress(WebMedia media) => library.beginSession(media.id);

  @override
  void saveProgress(
    WebMedia media,
    String session,
    int positionMs,
    int durationMs,
    bool completed,
  ) {
    library.saveProgress(
      media.id,
      session,
      Duration(milliseconds: positionMs),
      Duration(milliseconds: durationMs),
      completed: completed,
    );
    library.notifyChanged();
  }
}
