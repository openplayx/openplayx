import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/media_server_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';

class SearchHttp extends SourceHttp {
  SearchHttp(SourceConfig config, this.response) : super(config, 'secret');
  final Map<String, dynamic> response;
  String? path;
  Map<String, String>? query;
  @override
  Future<Map<String, dynamic>> json(
    String path, [
    Map<String, String> query = const {},
  ]) async {
    this.path = path;
    this.query = query;
    return response;
  }
}

void main() {
  test(
    'Jellyfin search uses recursive SearchTerm and server pagination',
    () async {
      const config = SourceConfig(
        id: 'jelly',
        name: 'Jellyfin',
        kind: SourceKind.jellyfin,
        address: 'https://host',
        userId: 'user',
      );
      final http = SearchHttp(config, {
        'Items': [
          {
            'Id': 'movie',
            'Name': 'Film',
            'Type': 'Movie',
            'MediaType': 'Video',
            'MediaSources': [{}, {}],
          },
        ],
        'TotalRecordCount': 100,
      });
      final plugin = JellyfinPlugin(config, http);
      final page = await plugin.search(
        'Film',
        const BrowseRequest(offset: 20, limit: 10),
        CallContext.forInstance('jelly'),
      );
      expect(http.path, 'Users/user/Items');
      expect(http.query!['SearchTerm'], 'Film');
      expect(http.query!['Recursive'], 'true');
      expect(http.query!['StartIndex'], '20');
      expect(page.nextOffset, 21);
      expect(page.entries.single.isFolder, true); // User must choose a version.
      expect(page.entries.single.ref.id, 'versions:movie');
      expect(plugin.manifest.capabilities, contains('search.media'));
    },
  );
  test(
    'Plex search uses library/all title filter and preserves provider identity',
    () async {
      const config = SourceConfig(
        id: 'plex',
        name: 'Plex',
        kind: SourceKind.plex,
        address: 'https://host',
      );
      final http = SearchHttp(config, {
        'MediaContainer': {
          'Metadata': [
            {
              'ratingKey': '1',
              'key': '/library/metadata/1',
              'title': 'Film',
              'type': 'movie',
            },
          ],
          'totalSize': 100,
        },
      });
      final plugin = PlexPlugin(config, http);
      final page = await plugin.search(
        'Film',
        const BrowseRequest(offset: 30, limit: 10),
        CallContext.forInstance('plex'),
      );
      expect(http.path, '/library/all');
      expect(http.query!['title'], 'Film');
      expect(http.query!['X-Plex-Container-Start'], '30');
      expect(page.nextOffset, 31);
      expect(page.entries.single.ref.instanceId, 'plex');
      expect(page.entries.single.ref.id, '/library/metadata/1');
      expect(page.entries.single.isFolder, false);
    },
  );
}
