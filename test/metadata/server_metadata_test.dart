import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/media_server_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';

class FixtureHttp extends SourceHttp {
  FixtureHttp(SourceConfig config) : super(config, 'private-token');
  Map<String, dynamic> response = {};
  String? lastPath;
  @override
  Future<Map<String, dynamic>> json(
    String path, [
    Map<String, String> query = const {},
  ]) async {
    lastPath = path;
    return response;
  }

  @override
  Future<List<int>> attachment(String path, {required int maxBytes}) async {
    lastPath = path;
    return [1, 2, 3];
  }
}

void main() {
  test('Jellyfin metadata retains server identity and scoped authenticated artwork refs', () async {
    const config = SourceConfig(
      id: 'jf',
      kind: SourceKind.jellyfin,
      name: 'Jellyfin',
      address: 'http://localhost',
      userId: 'u',
    );
    final http = FixtureHttp(config)
      ..response = {
        'Id': '42',
        'Name': 'Film',
        'Type': 'Movie',
        'Overview': 'Story',
        'ProviderIds': {'Tmdb': '10'},
        'ImageTags': {'Primary': 'tag'},
      };
    final plugin = JellyfinPlugin(config, http);
    final result = await plugin.lookup(
      MetadataRequest(
        action: MetadataAction.details,
        kind: MediaKind.movie,
        ref: const MetadataRef('server:jf', MediaKind.movie, '42'),
      ),
      CallContext.forInstance('jf'),
    );
    final record = result.records.single;
    expect(record.fields['overview'], 'Story');
    expect(record.externalIds.single.id, '10');
    expect(record.artwork.single.source!.id, 'artwork:poster:42');
    expect(record.toJson().toString(), isNot(contains('private-token')));
    await plugin.readAttachment(
      record.artwork.single.source!,
      CallContext.forInstance('jf'),
      maxBytes: 1024,
    );
    expect(http.lastPath, 'Items/42/Images/Primary/0');
    await expectLater(
      plugin.lookup(
        MetadataRequest(
          action: MetadataAction.details,
          kind: MediaKind.movie,
          ref: const MetadataRef('server:other', MediaKind.movie, '42'),
        ),
        CallContext.forInstance('jf'),
      ),
      throwsA(isA<PluginException>()),
    );
    await plugin.dispose();
  });
  test(
    'Plex uses its own namespace and rejects arbitrary artwork paths',
    () async {
      const config = SourceConfig(
        id: 'plex',
        kind: SourceKind.plex,
        name: 'Plex',
        address: 'http://localhost',
      );
      final http = FixtureHttp(config)
        ..response = {
          'MediaContainer': {
            'Metadata': [
              {
                'ratingKey': '42',
                'title': 'Film',
                'type': 'movie',
                'summary': 'Story',
                'thumb': '/library/metadata/42/thumb',
                'Guid': [
                  {'id': 'tmdb://10'},
                ],
              },
            ],
          },
        };
      final plugin = PlexPlugin(config, http);
      final record = (await plugin.lookup(
        MetadataRequest(
          action: MetadataAction.details,
          kind: MediaKind.movie,
          ref: const MetadataRef('server:plex', MediaKind.movie, '42'),
        ),
        CallContext.forInstance('plex'),
      )).records.single;
      expect(record.externalIds.single.id, '10');
      expect(record.ref.provider, 'server:plex');
      await expectLater(
        plugin.readAttachment(
          const ResourceRef('plex', 'artwork:poster:../private'),
          CallContext.forInstance('plex'),
          maxBytes: 1024,
        ),
        throwsA(isA<PluginException>()),
      );
      await plugin.dispose();
    },
  );
}
