import 'dart:convert';

import 'source_capability.dart';

enum MetadataAction { search, details, children }

enum MediaKind { movie, series, season, episode }

/// Provider IDs always include object kind and (for server IDs) instance scope.
class MetadataRef {
  const MetadataRef(
    this.provider,
    this.kind,
    this.id, {
    this.season,
    this.episode,
    this.seriesId,
  });
  final String provider;
  final MediaKind kind;
  final String id;
  final int? season;
  final int? episode;
  final String? seriesId;
  String get key => jsonEncode([provider, kind.name, id]);
  Map<String, dynamic> toJson() => {
    'provider': provider,
    'kind': kind.name,
    'id': id,
    'season': season,
    'episode': episode,
    'seriesId': seriesId,
  };
  factory MetadataRef.fromJson(Map<String, dynamic> j) => MetadataRef(
    j['provider'] as String,
    MediaKind.values.byName(j['kind'] as String),
    j['id'] as String,
    season: j['season'] as int?,
    episode: j['episode'] as int?,
    seriesId: j['seriesId'] as String?,
  );
}

class ArtworkDescriptor {
  const ArtworkDescriptor({
    required this.id,
    required this.type,
    this.remote,
    this.source,
    this.language,
    this.width,
    this.height,
  });
  final String id;
  final String type;
  final Uri? remote;
  final ResourceRef? source;
  final String? language;
  final int? width;
  final int? height;
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'remote': remote?.toString(),
    'source': source == null
        ? null
        : {'instance': source!.instanceId, 'id': source!.id},
    'language': language,
    'width': width,
    'height': height,
  };
  factory ArtworkDescriptor.fromJson(Map<String, dynamic> j) =>
      ArtworkDescriptor(
        id: j['id'] as String,
        type: j['type'] as String,
        remote: j['remote'] == null ? null : Uri.parse(j['remote'] as String),
        source: j['source'] == null
            ? null
            : ResourceRef(
                j['source']['instance'] as String,
                j['source']['id'] as String,
              ),
        language: j['language'] as String?,
        width: j['width'] as int?,
        height: j['height'] as int?,
      );
}

class MetadataRecord {
  const MetadataRecord({
    required this.ref,
    required this.fields,
    this.language = 'und',
    this.externalIds = const [],
    this.artwork = const [],
    this.children = const [],
    this.warnings = const [],
    this.contentRevision,
  });
  final String? contentRevision;
  final MetadataRef ref;
  final Map<String, dynamic> fields;
  final String language;
  final List<MetadataRef> externalIds;
  final List<ArtworkDescriptor> artwork;
  final List<MetadataRecord> children;
  final List<String> warnings;
  String get title => fields['title'] as String? ?? '';
  Map<String, dynamic> toJson() => {
    'ref': ref.toJson(),
    'fields': fields,
    'contentRevision': contentRevision,
    'language': language,
    'externalIds': externalIds.map((e) => e.toJson()).toList(),
    'artwork': artwork.map((e) => e.toJson()).toList(),
    'children': children.map((e) => e.toJson()).toList(),
    'warnings': warnings,
  };
  factory MetadataRecord.fromJson(Map<String, dynamic> j) => MetadataRecord(
    ref: MetadataRef.fromJson(j['ref'] as Map<String, dynamic>),
    contentRevision: j['contentRevision'] as String?,
    fields: j['fields'] as Map<String, dynamic>,
    language: j['language'] as String,
    externalIds: (j['externalIds'] as List)
        .map((e) => MetadataRef.fromJson(e))
        .toList(),
    artwork: (j['artwork'] as List)
        .map((e) => ArtworkDescriptor.fromJson(e))
        .toList(),
    children: (j['children'] as List)
        .map((e) => MetadataRecord.fromJson(e))
        .toList(),
    warnings: (j['warnings'] as List).cast<String>(),
  );
}

class MetadataRequest {
  MetadataRequest({
    required this.action,
    required this.kind,
    this.ref,
    this.query,
    this.year,
    this.attachment,
    this.language = 'zh-CN',
    this.page = 1,
    this.revision = 0,
  }) {
    if (page < 1 ||
        page > 500 ||
        language.length > 32 ||
        (action == MetadataAction.search &&
            (query == null ||
                query!.trim().isEmpty ||
                ref != null ||
                attachment != null)) ||
        (action != MetadataAction.search &&
            (query != null || (ref == null && attachment == null))) ||
        (ref != null && attachment != null) ||
        (ref != null && ref!.kind != kind) ||
        (action == MetadataAction.children &&
            (ref == null ||
                ![MediaKind.series, MediaKind.season].contains(kind)))) {
      throw const PluginException('invalidInput', '无效的元数据查询参数');
    }
  }
  final MetadataAction action;
  final MediaKind kind;
  final MetadataRef? ref;
  final String? query;
  final int? year;
  final ResourceRef? attachment;
  final String language;
  final int page;
  final int revision;
}

class MetadataResult {
  MetadataResult(this.records, {this.nextPage, this.warnings = const []})
    : fetchedAt = DateTime.now().toUtc();
  final List<MetadataRecord> records;
  final int? nextPage;
  final List<String> warnings;
  final DateTime fetchedAt;
}

abstract interface class MetadataCapability {
  Set<MetadataAction> get actions;
  Future<MetadataResult> lookup(MetadataRequest request, CallContext context);
}

/// Registry owns provider lifecycle; UI and providers cannot write library data.
class MetadataRegistry {
  final _providers = <String, MetadataCapability>{};
  void register(String instance, MetadataCapability provider) {
    if (provider is! Plugin || _providers.containsKey(instance)) {
      throw StateError('Invalid or duplicate metadata plugin');
    }
    _providers[instance] = provider;
  }

  Future<MetadataResult> lookup(String instance, MetadataRequest request) {
    final provider = _providers[instance];
    if (provider == null || !provider.actions.contains(request.action)) {
      throw const PluginException('unsupported', '此元数据实例不支持该查询');
    }
    return provider.lookup(request, CallContext.forInstance(instance));
  }

  Future<void> dispose() async {
    for (final provider in _providers.values) {
      await (provider as Plugin).dispose();
    }
    _providers.clear();
  }
}

MetadataRecord metadataFromSource(SourceMediaInfo info, String source) {
  final kind = MediaKind.values.where((k) => k.name == info.kind).firstOrNull;
  if (kind == null) throw const PluginException('unsupported', '不支持此媒体类型的影视信息');
  return MetadataRecord(
    ref: MetadataRef('server:$source', kind, info.id),
    fields: {
      ...info.metadata,
      'title': info.title,
      'kind': kind.name,
      if (info.year != null) 'year': info.year,
      if (info.season != null) 'season': info.season,
      if (info.episode != null) 'episode': info.episode,
    },
    externalIds: [
      for (final e in info.externalIds.entries)
        MetadataRef(e.key, kind, e.value),
    ],
    artwork: [
      for (final type in info.artworkTypes)
        ArtworkDescriptor(
          id: 'server:$source:$type:${info.id}',
          type: type,
          source: ResourceRef(source, 'artwork:$type:${info.id}'),
        ),
    ],
  );
}
