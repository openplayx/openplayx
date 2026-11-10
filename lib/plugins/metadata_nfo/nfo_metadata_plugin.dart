import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

import '../../core/plugins/metadata_capability.dart';
import '../../core/plugins/source_capability.dart';

typedef AttachmentReader = Future<List<int>> Function(
  ResourceRef ref, {
  int maxBytes,
});

/// Parses bounded, entity-free XML. No NFO URL is fetched by this provider.
class NfoMetadataPlugin implements Plugin, MetadataCapability {
  NfoMetadataPlugin(this.read);
  final AttachmentReader read;
  @override
  PluginManifest get manifest => const PluginManifest(
    'metadata.nfo',
    'NFO',
    browseExperience: 'none',
    capabilities: ['metadata.lookup'],
  );
  @override
  Set<MetadataAction> get actions => {MetadataAction.details};
  @override
  Future<MetadataResult> lookup(
    MetadataRequest request,
    CallContext context,
  ) async {
    if (request.action != MetadataAction.details ||
        request.attachment == null) {
      throw const PluginException('invalidInput', 'NFO 详情需要附件引用');
    }
    final ref = request.attachment!;
    final bytes = await read(ref, maxBytes: 1024 * 1024);
    try {
      return MetadataResult([parse(bytes, ref)]);
    } on PluginException {
      rethrow;
    } catch (_) {
      throw const PluginException('invalidMetadata', 'NFO 解析失败');
    }
  }

  MetadataRecord parse(List<int> bytes, ResourceRef source) {
    if (bytes.length > 1024 * 1024) {
      throw const PluginException('quotaExceeded', 'NFO 超过 1 MiB');
    }
    final text = utf8.decode(bytes);
    if (RegExp(r'<!\s*(DOCTYPE|ENTITY)', caseSensitive: false).hasMatch(text)) {
      throw const PluginException('invalidMetadata', 'NFO 不允许 DTD 或实体声明');
    }
    // Bound nesting before building the XML tree.
    var depth = 0, nodes = 0;
    for (final tag in RegExp(r'<[^>]*>').allMatches(text)) {
      final t = tag[0]!;
      if (++nodes > 20000) {
        throw const PluginException('quotaExceeded', 'NFO 节点过多');
      }
      if (t.startsWith('</')) {
        depth--;
      } else if (!t.startsWith('<?') &&
          !t.startsWith('<!') &&
          !t.endsWith('/>')) {
        depth++;
      }
      if (depth > 32) throw const PluginException('quotaExceeded', 'NFO 嵌套过深');
    }
    final doc = XmlDocument.parse(text);
    final root = doc.rootElement;
    final kind = switch (root.name.local) {
      'movie' => MediaKind.movie,
      'tvshow' => MediaKind.series,
      'season' => MediaKind.season,
      'episodedetails' => MediaKind.episode,
      _ => throw const PluginException('invalidMetadata', '不支持的 NFO 对象类型'),
    };
    String? value(String tag) {
      final result = root.getElement(tag)?.innerText.trim();
      if (result == null || result.isEmpty) return null;
      if (result.length > 32768) {
        throw const PluginException('quotaExceeded', 'NFO 字段过长');
      }
      return result;
    }

    final season = int.tryParse(value('season') ?? '');
    final episode = int.tryParse(value('episode') ?? '');
    final fields = <String, dynamic>{};
    for (final entry in {
      'title': 'title',
      'originaltitle': 'originalTitle',
      'plot': 'overview',
      'showtitle': 'showTitle',
      'premiered': 'airDate',
    }.entries) {
      final v = value(entry.key);
      if (v != null) fields[entry.value] = v;
    }
    final year = int.tryParse(value('year') ?? '');
    if (year != null) fields['year'] = year;
    if (season != null) fields['season'] = season;
    if (episode != null) fields['episode'] = episode;
    fields['kind'] = kind.name;
    for (final entry in {'genre': 'genres', 'director': 'directors'}.entries) {
      final items = root
          .findElements(entry.key)
          .take(200)
          .map((e) => e.innerText.trim())
          .where((e) => e.isNotEmpty && e.length <= 1024)
          .toList();
      if (items.isNotEmpty) fields[entry.value] = items;
    }
    final actors = root
        .findElements('actor')
        .take(200)
        .map(
          (e) => {
            'name': (e.getElement('name')?.innerText ?? '').substring(
              0,
              (e.getElement('name')?.innerText.length ?? 0).clamp(0, 1024),
            ),
            'role': (e.getElement('role')?.innerText ?? '').substring(
              0,
              (e.getElement('role')?.innerText.length ?? 0).clamp(0, 1024),
            ),
          },
        )
        .toList();
    if (actors.isNotEmpty) fields['cast'] = actors;
    final ratings = <String, dynamic>{};
    for (final r
        in root.getElement('ratings')?.findElements('rating') ??
            <XmlElement>[]) {
      final rating = double.tryParse(r.getElement('value')?.innerText ?? '');
      if (rating != null) {
        ratings[r.getAttribute('name') ?? 'nfo'] = {
          'value': rating,
          'max': double.tryParse(r.getAttribute('max') ?? '') ?? 10,
        };
      }
    }
    if (ratings.isEmpty && value('rating') != null) {
      final rating = double.tryParse(value('rating')!);
      if (rating != null) ratings['nfo'] = {'value': rating, 'max': 10};
    }
    if (ratings.isNotEmpty) fields['ratings'] = ratings;
    final ids = <MetadataRef>[];
    for (final id in root.findElements('uniqueid')) {
      final provider = id.getAttribute('type')?.toLowerCase();
      final v = id.innerText.trim();
      if (['tmdb', 'imdb', 'tvdb'].contains(provider) &&
          RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(v)) {
        // Episode/season NFO IDs refer to those objects, never blindly to a show.
        ids.add(
          MetadataRef(provider!, kind, v, season: season, episode: episode),
        );
      }
    }
    if (value('id')?.startsWith('tt') == true &&
        !ids.any((i) => i.provider == 'imdb')) {
      ids.add(MetadataRef('imdb', kind, value('id')!));
    }
    final artwork = <ArtworkDescriptor>[];
    for (final thumb in root.findElements('thumb')) {
      final ref = relativeAttachment(source, thumb.innerText.trim());
      if (ref != null) {
        artwork.add(
          ArtworkDescriptor(
            id: '${source.instanceId}:${ref.id}',
            type: thumb.getAttribute('aspect') == 'banner'
                ? 'backdrop'
                : 'poster',
            source: ref,
          ),
        );
      }
    }
    for (final thumb
        in root.getElement('fanart')?.findElements('thumb') ?? <XmlElement>[]) {
      final ref = relativeAttachment(source, thumb.innerText.trim());
      if (ref != null) {
        artwork.add(
          ArtworkDescriptor(
            id: '${source.instanceId}:${ref.id}',
            type: 'backdrop',
            source: ref,
          ),
        );
      }
    }
    const known = {
      'title',
      'originaltitle',
      'plot',
      'showtitle',
      'premiered',
      'year',
      'season',
      'episode',
      'genre',
      'director',
      'actor',
      'ratings',
      'rating',
      'uniqueid',
      'id',
      'thumb',
      'fanart',
    };
    final unknown = root.childElements
        .map((e) => e.name.local)
        .where((e) => !known.contains(e))
        .toSet();
    return MetadataRecord(
      ref: MetadataRef('nfo:${source.instanceId}', kind, source.id),
      contentRevision: sha256.convert(bytes).toString(),
      fields: fields,
      externalIds: ids,
      artwork: artwork,
      warnings: unknown.map((e) => 'unsupported:$e').toList(),
    );
  }

  @override
  Future<void> dispose() async {}
}

/// Only relative, forward-slash attachment paths below this NFO directory.
ResourceRef? relativeAttachment(ResourceRef nfo, String path) {
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.contains('\\') ||
      path.contains(':') ||
      path.split('/').any((p) => p.isEmpty || p == '..' || p == '.') ||
      !RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false).hasMatch(path)) {
    return null;
  }
  final slash = nfo.id.lastIndexOf('/');
  if (slash < 0) return null;
  return ResourceRef(nfo.instanceId, '${nfo.id.substring(0, slash + 1)}$path');
}
