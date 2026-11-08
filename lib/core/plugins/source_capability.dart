/// The first implemented slice of the plugin SDK. Only supported capabilities
/// are registered; no string-based invocation or optional stub methods.
abstract interface class Plugin {
  PluginManifest get manifest;
  Future<void> dispose();
}

class PluginManifest {
  const PluginManifest(this.id, this.name, {required this.browseExperience});
  final String id;
  final String name;
  final String browseExperience;
  final List<String> capabilities = const ['source.browse', 'source.resolve'];
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
  const SourceEntry(this.ref, this.name, {required this.isFolder});
  final ResourceRef ref;
  final String name;
  final bool isFolder;
}

class BrowseRequest {
  const BrowseRequest({this.node, this.offset = 0, this.limit = 100});
  final ResourceRef? node;
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
