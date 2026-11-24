import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import '../../core/capabilities/source_capability.dart';
import 'file_sources.dart';
import 'network_file_sources.dart';
import 'source_config.dart';
import 'source_schema.dart';
import '../../l10n/l10n.dart';

/// A UPnP media server found on the local network.
class DlnaDevice {
  const DlnaDevice(this.name, this.location);
  final String name;

  /// Device description URL, stored as the connection address.
  final Uri location;
}

/// SSDP discovery of UPnP/DLNA media servers.
class DlnaDiscovery {
  static const _target = 'urn:schemas-upnp-org:device:MediaServer:1';

  static Future<List<DlnaDevice>> search({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final locations = <Uri>{};
    Object? sendError;
    final subscription = socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        final text = utf8.decode(datagram.data, allowMalformed: true);
        for (final line in const LineSplitter().convert(text)) {
          final colon = line.indexOf(':');
          if (colon < 0 ||
              line.substring(0, colon).trim().toLowerCase() != 'location') {
            continue;
          }
          final uri = Uri.tryParse(line.substring(colon + 1).trim());
          if (uri != null &&
              ['http', 'https'].contains(uri.scheme) &&
              uri.host.isNotEmpty) {
            locations.add(uri);
          }
        }
      },
      // Send failures (e.g. iOS without the multicast entitlement, or no
      // Wi-Fi: "No route to host") arrive as stream errors, not as throws
      // from send(). Unhandled, they reach the zone and crash the app.
      onError: (Object error) => sendError ??= error,
    );
    final message = utf8.encode(
      'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 2\r\n'
      'ST: $_target\r\n\r\n',
    );
    final group = InternetAddress('239.255.255.250');
    try {
      for (var i = 0; i < 2; i++) {
        socket.send(message, group, 1900);
      }
      await Future<void>.delayed(timeout);
    } finally {
      await subscription.cancel();
      socket.close();
    }
    if (locations.isEmpty && sendError != null) {
      throw PluginException(
        'networkUnavailable',
        '$sendError',
        retryable: true,
      );
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final devices = await Future.wait(
        locations.map((location) async {
          try {
            final document = await _fetchXml(
              client,
              location,
              const Duration(seconds: 3),
            );
            final type = xmlText(document, 'deviceType') ?? '';
            if (!type.contains('MediaServer')) return null;
            return DlnaDevice(
              xmlText(document, 'friendlyName') ?? location.host,
              location,
            );
          } catch (_) {
            return null;
          }
        }),
      );
      return devices.whereType<DlnaDevice>().toList();
    } finally {
      client.close(force: true);
    }
  }
}

Future<XmlDocument> _fetchXml(
  HttpClient client,
  Uri uri,
  Duration timeout, {
  String method = 'GET',
  Map<String, String> headers = const {},
  String? body,
}) async {
  final request = await client.openUrl(method, uri);
  request.followRedirects = false;
  headers.forEach(request.headers.set);
  if (body != null) {
    // Embedded UPnP servers often reject chunked request bodies.
    final bytes = utf8.encode(body);
    request.contentLength = bytes.length;
    request.add(bytes);
  }
  final response = await request.close().timeout(
    timeout,
    onTimeout: () {
      request.abort();
      throw TimeoutException('DLNA');
    },
  );
  final text = await utf8.decoder.bind(response).join().timeout(timeout);
  if (response.statusCode != 200) {
    throw PluginException(
      'networkUnavailable',
      appStrings.errDlnaHttp(response.statusCode),
      retryable: true,
    );
  }
  return XmlDocument.parse(text);
}

/// Browses a UPnP ContentDirectory. Containers are folders (`c:` + id),
/// playable items are files (`i:` + id); media URLs are re-read on playback.
class DlnaPlugin implements Plugin, SourceCapability {
  DlnaPlugin(this.config);
  final SourceConfig config;
  late final HttpClient _client = HttpClient()..connectionTimeout = _timeout;
  Future<(Uri, String)>? _service;
  Duration get _timeout => Duration(seconds: config.requestTimeoutSeconds);
  Uri get _location => Uri.parse(config.address);

  @override
  PluginManifest get manifest => SourceSchemas.forKind(SourceKind.dlna);

  Future<(Uri, String)> _contentDirectory() =>
      _service ??= _findService().catchError((Object error) {
        _service = null;
        throw error;
      });

  Future<(Uri, String)> _findService() async {
    final document = await _fetchXml(_client, _location, _timeout);
    final base = Uri.tryParse(xmlText(document, 'URLBase') ?? '') ?? _location;
    for (final service in xmlElements(document, 'service')) {
      final type = xmlText(service, 'serviceType') ?? '';
      final control = xmlText(service, 'controlURL');
      if (!type.contains(':service:ContentDirectory:') || control == null) {
        continue;
      }
      final uri = (base.hasAuthority ? base : _location).resolve(control);
      if (uri.host != _location.host) {
        throw PluginException(
          'permissionDenied',
          appStrings.errDlnaForeignHost,
        );
      }
      return (uri, type);
    }
    throw PluginException('unsupported', appStrings.errDlnaNotMediaServer);
  }

  Future<({XmlDocument didl, int returned, int total})> _browse(
    String objectId,
    String flag, {
    int start = 0,
    int count = 0,
  }) async {
    final (control, type) = await _contentDirectory();
    final body =
        '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body><u:Browse xmlns:u="${const HtmlEscape().convert(type)}">'
        '<ObjectID>${const HtmlEscape().convert(objectId)}</ObjectID>'
        '<BrowseFlag>$flag</BrowseFlag><Filter>*</Filter>'
        '<StartingIndex>$start</StartingIndex>'
        '<RequestedCount>$count</RequestedCount>'
        '<SortCriteria></SortCriteria></u:Browse></s:Body></s:Envelope>';
    final response = await _fetchXml(
      _client,
      control,
      _timeout,
      method: 'POST',
      headers: {
        'Content-Type': 'text/xml; charset="utf-8"',
        'SOAPACTION': '"$type#Browse"',
      },
      body: body,
    );
    final result = xmlText(response, 'Result') ?? '';
    return (
      didl: XmlDocument.parse(result.isEmpty ? '<DIDL-Lite/>' : result),
      returned: int.tryParse(xmlText(response, 'NumberReturned') ?? '') ?? 0,
      total: int.tryParse(xmlText(response, 'TotalMatches') ?? '') ?? 0,
    );
  }

  Uri? _media(XmlElement item) {
    Uri? fallback;
    for (final res in xmlElements(item, 'res')) {
      final uri = Uri.tryParse(res.innerText.trim());
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host != _location.host) {
        continue;
      }
      final info = res.getAttribute('protocolInfo') ?? '';
      if (info.contains(':video/') || info.contains(':audio/')) return uri;
      fallback ??= uri;
    }
    return fallback;
  }

  @override
  Future<BrowseResult> browse(
    BrowseRequest request,
    CallContext context,
  ) async {
    checkOwnership(config.id, request.node, context);
    final node = request.node?.id;
    if (node != null && !node.startsWith('c:')) {
      throw PluginException('invalidInput', appStrings.errChooseFolder);
    }
    final page = await _browse(
      node?.substring(2) ?? '0',
      'BrowseDirectChildren',
      start: request.offset,
      count: request.limit,
    );
    final entries = <SourceEntry>[];
    for (final element in page.didl.rootElement.childElements) {
      final id = element.getAttribute('id');
      final title = xmlText(element, 'title') ?? appStrings.untitled;
      if (id == null) continue;
      if (element.name.local == 'container') {
        entries.add(
          SourceEntry(ResourceRef(config.id, 'c:$id'), title, isFolder: true),
        );
      } else if (element.name.local == 'item' && _media(element) != null) {
        entries.add(
          SourceEntry(ResourceRef(config.id, 'i:$id'), title, isFolder: false),
        );
      }
    }
    final next = request.offset + page.returned;
    return BrowseResult(
      entries,
      nextOffset: page.returned > 0 && next < page.total ? next : null,
    );
  }

  @override
  Future<PlayableStream> resolve(
    ResolveRequest request,
    CallContext context,
  ) async {
    checkOwnership(config.id, request.resource, context);
    final id = request.resource.id;
    if (!id.startsWith('i:')) {
      throw PluginException('invalidInput', appStrings.errChooseVideoOrAudio);
    }
    final page = await _browse(id.substring(2), 'BrowseMetadata');
    final item = page.didl.rootElement.childElements
        .where((e) => e.name.local == 'item')
        .firstOrNull;
    final media = item == null ? null : _media(item);
    if (media == null) {
      throw PluginException('notFound', appStrings.errNoPlayableAddress);
    }
    // No credentials are involved, so the player reads the server directly.
    return PlayableStream(media);
  }

  @override
  Future<void> dispose() async => _client.close(force: true);
}
