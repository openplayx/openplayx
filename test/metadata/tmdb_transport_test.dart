import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/metadata/providers/tmdb_metadata_plugin.dart';

import '../data/sources/cloud_sources_test.dart' show Client, Response;

class _Client extends Client {
  _Client() : super((_) => Response(200, {'results': <Object?>[]}));
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
}

void main() {
  test(
    'cloud uses public API without credentials; local uses direct TMDB bearer',
    () async {
      final cloudClient = _Client();
      final cloud = TmdbTransport.platform(client: cloudClient);
      expect(await cloud.get('/search/movie', {'query': 'Arrival'}), {
        'results': <Object?>[],
      });
      // ignore: close_sinks — recorded request, already closed by TmdbTransport.get.
      final cloudRequest = cloudClient.requests.single;
      expect(
        cloudRequest.uri.toString(),
        'https://api.openplayx.com/v1/tmdb/search/movie?query=Arrival',
      );
      expect(cloudRequest.headers.value('Authorization'), isNull);
      expect(cloudRequest.followRedirects, false);
      cloud.close();
      expect(cloudClient.closed, true);

      final localClient = _Client();
      final local = TmdbTransport('own-token', client: localClient);
      await local.get('/movie/1', {'language': 'zh-CN'});
      // ignore: close_sinks — recorded request, already closed by TmdbTransport.get.
      final localRequest = localClient.requests.single;
      expect(
        localRequest.uri.toString(),
        'https://api.themoviedb.org/3/movie/1?language=zh-CN',
      );
      expect(localRequest.headers.value('Authorization'), 'Bearer own-token');
      local.close();
    },
  );
}
