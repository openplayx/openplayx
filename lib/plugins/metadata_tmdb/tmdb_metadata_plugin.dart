import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/plugins/metadata_capability.dart';
import '../../core/plugins/source_capability.dart';

typedef TmdbRequest = Future<Map<String, dynamic>> Function(
  String path,
  Map<String, String> query,
);

/// Scoped host transport. Credentials only enter the Authorization header.
class TmdbTransport {
  TmdbTransport(this._token, {HttpClient? client})
    : _client = client ?? (HttpClient()..maxConnectionsPerHost = 2);
  final String _token;
  final HttpClient _client;
  bool _closed = false;
  Future<Map<String, dynamic>> get(
    String path,
    Map<String, String> query,
  ) async {
    if (_token.trim().isEmpty) {
      throw const PluginException('authRequired', '请配置 TMDB 读取访问令牌');
    }
    for (var attempt = 0; attempt < 3; attempt++) {
      if (_closed) throw const PluginException('cancelled', '查询已取消');
      HttpClientRequest? activeRequest;
      try {
        final response =
            await (() async {
              final request = await _client.getUrl(
                Uri.https('api.themoviedb.org', '/3$path', query),
              );
              activeRequest = request;
              request.followRedirects = false;
              request.headers.set('Authorization', 'Bearer $_token');
              request.headers.set('Accept', 'application/json');
              final response = await request.close();
              final bytes = <int>[];
              await for (final chunk in response) {
                if (bytes.length + chunk.length > 4 * 1024 * 1024) {
                  throw const PluginException('quotaExceeded', 'TMDB 响应过大');
                }
                bytes.addAll(chunk);
              }
              return (
                response.statusCode,
                response.headers.value('retry-after'),
                bytes,
              );
            })().timeout(
              const Duration(seconds: 20),
              onTimeout: () {
                activeRequest?.abort();
                throw TimeoutException('tmdb');
              },
            );
        final (status, retryAfter, bytes) = response;
        if (status == 401 || status == 403) {
          throw const PluginException('authRequired', 'TMDB 认证失败，请更新令牌');
        }
        if (status == 404) {
          throw const PluginException('notFound', 'TMDB 对象不存在');
        }
        if (status == 429 || status >= 500) {
          final delay = int.tryParse(retryAfter ?? '') ?? (1 << attempt);
          // Never retry earlier than Retry-After; long waits are returned to UI.
          if (attempt < 2 && delay <= 10) {
            await Future<void>.delayed(Duration(seconds: delay.clamp(1, 10)));
            continue;
          }
          throw PluginException(
            status == 429 ? 'rateLimited' : 'networkUnavailable',
            status == 429 ? 'TMDB 请求受限，请稍后重试' : 'TMDB 暂时不可用',
            retryable: true,
          );
        }
        if (status != 200) {
          throw const PluginException('providerError', 'TMDB 请求失败');
        }
        return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      } on PluginException {
        rethrow;
      } on FormatException {
        throw const PluginException('invalidMetadata', 'TMDB 响应格式无效');
      } catch (_) {
        if (_closed) throw const PluginException('cancelled', '查询已取消');
        if (attempt == 2) {
          throw const PluginException(
            'networkUnavailable',
            '无法连接 TMDB，请检查网络',
            retryable: true,
          );
        }
        await Future<void>.delayed(Duration(seconds: 1 << attempt));
      }
    }
    throw StateError('unreachable');
  }

  void close() {
    _closed = true;
    _client.close(force: true);
  }
}

class TmdbMetadataPlugin implements Plugin, MetadataCapability {
  TmdbMetadataPlugin(this.get, {this.onDispose});
  final TmdbRequest get;
  final void Function()? onDispose;
  Map<String, dynamic>? _images;
  final _searchCache = <String, ({DateTime until, MetadataResult result})>{};
  Future<void> _loadImageConfig() async {
    if (_images != null) return;
    try {
      final raw = (await get('/configuration', {}))['images'];
      if (raw is Map) _images = Map<String, dynamic>.from(raw);
    } on PluginException {
      /* Text remains usable when image configuration fails. */
    }
  }

  @override
  PluginManifest get manifest => const PluginManifest(
    'metadata.tmdb',
    'TMDB',
    browseExperience: 'none',
    capabilities: ['metadata.lookup'],
  );
  @override
  Set<MetadataAction> get actions => MetadataAction.values.toSet();
  @override
  Future<MetadataResult> lookup(
    MetadataRequest request,
    CallContext context,
  ) async {
    if (request.attachment != null) {
      throw const PluginException('invalidInput', 'TMDB 不读取来源附件');
    }
    final kind = request.kind;
    final ref = request.ref;
    if (ref != null &&
        (ref.provider != 'tmdb' ||
            !RegExp(r'^\d{1,12}$').hasMatch(ref.id) ||
            ([MediaKind.season, MediaKind.episode].contains(kind) &&
                (ref.season == null ||
                    ref.season! < 0 ||
                    ref.seriesId == null ||
                    !RegExp(r'^\d{1,12}$').hasMatch(ref.seriesId!))) ||
            (kind == MediaKind.episode &&
                (ref.episode == null || ref.episode! < 0)))) {
      throw const PluginException('invalidInput', 'TMDB ID 或季集编号无效');
    }
    final isMovie = kind == MediaKind.movie;
    final base = isMovie ? 'movie' : 'tv';
    final query = <String, String>{'language': request.language};
    if (request.action == MetadataAction.search) {
      if (![MediaKind.movie, MediaKind.series].contains(kind)) {
        throw const PluginException('invalidInput', '请先识别剧集，再选择季集');
      }
      query.addAll({
        'query': request.query!,
        'page': '${request.page}',
        'include_adult': 'false',
      });
      if (request.year != null) {
        query[isMovie ? 'year' : 'first_air_date_year'] = '${request.year}';
      }
      final key = jsonEncode([base, query]);
      final cached = _searchCache[key];
      if (cached != null && cached.until.isAfter(DateTime.now())) {
        return cached.result;
      }
      final j = await get('/search/$base', query);
      await _loadImageConfig();
      final result = MetadataResult(
        [
          for (final item in j['results'] as List? ?? [])
            _record(item as Map<String, dynamic>, kind, request.language),
        ],
        nextPage: request.page < (j['total_pages'] as int? ?? 1)
            ? request.page + 1
            : null,
      );
      if (_searchCache.length >= 100) {
        _searchCache.remove(_searchCache.keys.first);
      }
      _searchCache[key] = (
        until: DateTime.now().add(
          Duration(seconds: result.records.isEmpty ? 15 : 120),
        ),
        result: result,
      );
      return result;
    }
    if (ref == null) {
      throw const PluginException('invalidInput', '详情需要 TMDB 引用');
    }
    var path = '/$base/${ref.seriesId ?? ref.id}';
    if ([MediaKind.season, MediaKind.episode].contains(kind)) {
      path += '/season/${ref.season}';
    }
    if (kind == MediaKind.episode) path += '/episode/${ref.episode}';
    query['append_to_response'] = 'credits,images,external_ids';
    query['include_image_language'] =
        '${request.language.split('-').first},en,null';
    final j = await get(path, query);
    // Image CDN and sizes come from Provider configuration, never page constants.
    await _loadImageConfig();
    final record = _record(j, kind, request.language, ref: ref, details: true);
    if (request.action == MetadataAction.children) {
      return MetadataResult(record.children);
    }
    return MetadataResult([record]);
  }

  MetadataRecord _record(
    Map<String, dynamic> j,
    MediaKind kind,
    String language, {
    MetadataRef? ref,
    bool details = false,
  }) {
    if (j['id'] == null ||
        (j['title'] ?? j['name']) is! String ||
        (j['title'] ?? j['name']).toString().isEmpty ||
        (ref != null && '${j['id']}' != ref.id)) {
      throw const PluginException('invalidMetadata', 'TMDB 对象身份或标题无效');
    }
    ref ??= MetadataRef('tmdb', kind, '${j['id']}');
    final date =
        j[kind == MediaKind.movie
                ? 'release_date'
                : kind == MediaKind.series
                ? 'first_air_date'
                : 'air_date']
            as String?;
    final fields = <String, dynamic>{'kind': kind.name};
    void set(String k, dynamic v) {
      if (v != null && v != '' && v != const []) fields[k] = v;
    }

    set('title', j['title'] ?? j['name']);
    set('originalTitle', j['original_title'] ?? j['original_name']);
    set('overview', j['overview']);
    set(
      'year',
      date != null && date.length >= 4
          ? int.tryParse(date.substring(0, 4))
          : null,
    );
    set('airDate', date);
    set('season', j['season_number'] ?? ref.season);
    set('episode', j['episode_number'] ?? ref.episode);
    if ((j['genres'] as List?)?.isNotEmpty == true) {
      fields['genres'] = (j['genres'] as List).map((g) => g['name']).toList();
    }
    final credits = j['credits'] as Map<String, dynamic>?;
    if (credits != null) {
      fields['cast'] = [
        for (final c in (credits['cast'] as List? ?? []).take(100))
          {'name': c['name'], 'role': c['character']},
      ];
      fields['directors'] = [
        for (final c in credits['crew'] as List? ?? [])
          if (c['job'] == 'Director') c['name'],
      ];
    }
    if ((j['vote_count'] as num? ?? 0) > 0) {
      fields['ratings'] = {
        'tmdb': {
          'value': j['vote_average'],
          'max': 10,
          'votes': j['vote_count'],
        },
      };
    }
    final art = <ArtworkDescriptor>[];
    void add(
      String? file,
      String type, {
      String? lang,
      int? width,
      int? height,
    }) {
      if (file == null ||
          _images == null ||
          !RegExp(r'^/[a-zA-Z0-9_.-]+$').hasMatch(file)) {
        return;
      }
      final base = _images!['secure_base_url'] as String?;
      final sizes =
          (_images![type == 'poster'
                      ? 'poster_sizes'
                      : type == 'thumbnail'
                      ? 'still_sizes'
                      : 'backdrop_sizes']
                  as List?)
              ?.cast<String>() ??
          [];
      if (base == null || sizes.isEmpty) return;
      final size = sizes.contains('w500')
          ? 'w500'
          : sizes.contains('w780')
          ? 'w780'
          : sizes.first;
      final uri = Uri.tryParse('$base$size$file');
      if (uri?.scheme != 'https' || uri!.host != 'image.tmdb.org') return;
      final id = 'tmdb:$type:$file';
      if (!art.any((a) => a.id == id)) {
        art.add(
          ArtworkDescriptor(
            id: id,
            type: type,
            remote: uri,
            language: lang,
            width: width,
            height: height,
          ),
        );
      }
    }

    add(j['poster_path'] as String?, 'poster');
    add(j['backdrop_path'] as String?, 'backdrop');
    add(j['still_path'] as String?, 'thumbnail');
    final images = j['images'] as Map<String, dynamic>? ?? {};
    for (final entry in {
      'posters': 'poster',
      'backdrops': 'backdrop',
      'stills': 'thumbnail',
    }.entries) {
      for (final a in (images[entry.key] as List? ?? []).take(50)) {
        add(
          a['file_path'] as String?,
          entry.value,
          lang: a['iso_639_1'] as String?,
          width: a['width'] as int?,
          height: a['height'] as int?,
        );
      }
    }
    final children = <MetadataRecord>[];
    if (details && kind == MediaKind.series) {
      for (final s in j['seasons'] as List? ?? []) {
        children.add(
          _record(
            s,
            MediaKind.season,
            language,
            ref: MetadataRef(
              'tmdb',
              MediaKind.season,
              '${s['id']}',
              seriesId: ref.id,
              season: s['season_number'] as int?,
            ),
          ),
        );
      }
    } else if (details && kind == MediaKind.season) {
      for (final e in j['episodes'] as List? ?? []) {
        children.add(
          _record(
            e,
            MediaKind.episode,
            language,
            ref: MetadataRef(
              'tmdb',
              MediaKind.episode,
              '${e['id']}',
              seriesId: ref.seriesId,
              season: ref.season,
              episode: e['episode_number'] as int?,
            ),
          ),
        );
      }
    }
    final external = <MetadataRef>[];
    final ids = j['external_ids'] as Map<String, dynamic>? ?? {};
    for (final entry in {'imdb_id': 'imdb', 'tvdb_id': 'tvdb'}.entries) {
      if (ids[entry.key] != null) {
        external.add(MetadataRef(entry.value, kind, '${ids[entry.key]}'));
      }
    }
    return MetadataRecord(
      ref: ref,
      fields: fields,
      language: language,
      externalIds: external,
      artwork: art,
      children: children,
    );
  }

  @override
  Future<void> dispose() async => onDispose?.call();
}
