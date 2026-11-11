import 'config_schema.dart';

/// The first implemented slice of the plugin SDK. Only supported capabilities
/// are registered; no string-based invocation or optional stub methods.
abstract interface class Plugin {
  PluginManifest get manifest;
  Future<void> dispose();
}

class PluginManifest {
  const PluginManifest(
    this.id,
    this.name, {
    required this.browseExperience,
    this.version = '1.0.0',
    this.configSchema,
    this.capabilities = const ['source.browse', 'source.resolve'],
  });
  final String version;
  final PluginConfigSchema? configSchema;
  final String id;
  final String name;
  final String browseExperience;
  final List<String> capabilities;
}

class CallContext {
  const CallContext._(this.instanceId);
  final String instanceId;
  static CallContext forInstance(String instanceId) =>
      CallContext._(instanceId);
}

class ResourceRef {
  const ResourceRef(this.instanceId, this.id);
  final String instanceId;
  final String id;
}

class SourceEntry {
  const SourceEntry(this.ref, this.name, {required this.isFolder, this.media});
  final SourceMediaInfo? media;
  final ResourceRef ref;
  final String name;
  final bool isFolder;
}

/// Provider-owned stable content identity; titles never serve as identity keys.
class SourceMediaInfo {
  const SourceMediaInfo({
    required this.id,
    required this.title,
    this.kind = 'video',
    this.parentId,
    this.year,
    this.season,
    this.episode,
    this.metadata = const {},
    this.externalIds = const {},
    this.artworkTypes = const [],
  });
  final String id;
  final String title;
  final String kind;
  final String? parentId;
  final int? year;
  final int? season;
  final int? episode;
  final Map<String, dynamic> metadata;
  final Map<String, String> externalIds;
  final List<String> artworkTypes;
}

class BrowseRequest {
  const BrowseRequest({
    this.node,
    this.offset = 0,
    this.limit = 100,
    this.search,
  });
  final ResourceRef? node;
  final String? search;
  final int offset;
  final int limit;
}

class BrowseResult {
  const BrowseResult(this.entries, {this.nextOffset});
  final List<SourceEntry> entries;
  final int? nextOffset;
}

class ResolveRequest {
  const ResolveRequest(this.resource);
  final ResourceRef resource;
}

/// A session-owned handle. URI contains no remote credentials and is never
/// persisted. Release only after the playback backend has stopped using it.
class PlayableStream {
  PlayableStream(this.uri, {Future<void> Function()? release})
    // Public named argument describes the resource lifecycle.
    // ignore: prefer_initializing_formals
    : _release = release;
  final Uri uri;
  final Future<void> Function()? _release;
  bool _released = false;
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _release?.call();
  }
}

abstract interface class SourceCapability {
  Future<BrowseResult> browse(BrowseRequest request, CallContext context);
  Future<PlayableStream> resolve(ResolveRequest request, CallContext context);
}

class PluginException implements Exception {
  const PluginException(this.code, this.message, {this.retryable = false});
  final String code;
  final String message;
  final bool retryable;
  @override
  String toString() => message;
}

/// Bounded attachment access, separate from playable URLs. The host verifies
/// instance ownership, configured scope and allowed file types on every call.
abstract interface class SourceAttachmentCapability {
  Future<List<int>> readAttachment(
    ResourceRef ref,
    CallContext context, {
    required int maxBytes,
  });
}

/// Newest additions on a media server, for its shelf in the library.
abstract interface class RecentCapability {
  Future<List<SourceEntry>> recent(int limit, CallContext context);
}

/// Explicit search contract; a browse-only source is never advertised as search.
abstract interface class SearchCapability {
  Future<BrowseResult> search(
    String query,
    BrowseRequest page,
    CallContext context,
  );
}
