import 'dart:convert';

import '../../core/capabilities/source_capability.dart';
import '../../l10n/l10n.dart';
import 'cloud_file_source.dart';

/// Drive ID and item ID together are the stable resource identity.
class OneDriveSource extends CloudFileSource {
  OneDriveSource(
    super.config,
    super.session, {
    super.client,
    super.ownsSession,
  });
  @override
  String get apiHost => 'graph.microsoft.com';
  String? _drive;
  String? _root;
  Future<void> _initialize() async {
    if (_drive != null) return;
    final drive = await api(Uri.https(apiHost, '/v1.0/me/drive'));
    if (drive['driveType'] != 'personal') {
      throw PluginException('unsupported', appStrings.cloudPersonalOnly);
    }
    final driveId = drive['id'] as String;
    if (config.cloudDriveId.isNotEmpty && config.cloudDriveId != driveId) {
      throw PluginException('authRequired', appStrings.cloudReauthorize);
    }
    final root = await api(
      Uri(
        scheme: 'https',
        host: apiHost,
        pathSegments: ['v1.0', 'drives', driveId, 'root'],
      ),
    );
    _root = identity(driveId, root['id'] as String);
    _drive = driveId;
  }

  static String identity(String drive, String item) =>
      base64UrlEncode(utf8.encode(jsonEncode([drive, item])))
          .replaceAll('=', '');
  (String, String) _identity(String value) {
    try {
      final parts = (jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(value))),
      ) as List).cast<String>();
      if (parts.length != 2 || parts[0] != _drive || parts[1].isEmpty) {
        throw const FormatException();
      }
      return (parts[0], parts[1]);
    } catch (_) {
      throw PluginException('permissionDenied', appStrings.errPathOutsideRoot);
    }
  }

  String itemPath(String id) {
    final (drive, item) = _identity(id);
    return '/v1.0/drives/${Uri.encodeComponent(drive)}/items/${Uri.encodeComponent(item)}';
  }

  CloudFile _file(Map<String, dynamic> j) {
    final parent = j['parentReference'] as Map<String, dynamic>?;
    final parentId = parent?['id'] as String?;
    return CloudFile(
      identity(_drive!, j['id'] as String),
      j['name'] as String,
      folder: j['folder'] != null,
      parent: parentId == null
          ? null
          : identity(parent?['driveId'] as String? ?? _drive!, parentId),
      size: (j['size'] as num?)?.toInt(),
    );
  }

  @override
  Future<CloudFile> root() async {
    await _initialize();
    return metadata(config.cloudRootId.isEmpty ? _root! : config.cloudRootId);
  }

  Future<String> get driveId async {
    await _initialize();
    return _drive!;
  }

  @override
  Future<CloudFile> metadata(String id) async {
    await _initialize();
    return _file(await api(Uri.parse('https://$apiHost${itemPath(id)}')));
  }

  @override
  Future<(List<CloudFile>, String?)> children(String id, String? cursor) async {
    final result = await api(
      cursor == null
          ? Uri.parse('https://$apiHost${itemPath(id)}/children')
                .replace(queryParameters: {r'$top': '200'})
          : Uri.parse(cursor),
    );
    // Shortcuts/shared remote items are outside this personal drive grant.
    return (
      (result['value'] as List)
          .cast<Map<String, dynamic>>()
          .where((j) => j['remoteItem'] == null && j['deleted'] == null)
          .map(_file)
          .toList(),
      result['@odata.nextLink'] as String?,
    );
  }

  @override
  Future<Uri> download(String id) async {
    final j = await api(Uri.parse('https://$apiHost${itemPath(id)}'));
    final link = j['@microsoft.graph.downloadUrl'] as String?;
    if (link == null) {
      throw PluginException('notFound', appStrings.errFileNotFound);
    }
    return Uri.parse(link);
  }
}
