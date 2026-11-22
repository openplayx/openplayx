import '../sources/source_config.dart';
import 'remote_config.dart';

/// A directory entry, never a runnable connection until the user signs in.
class DiscoveredSource {
  const DiscoveredSource({
    required this.accountId,
    required this.connectorId,
    required this.serviceId,
    required this.name,
    required this.connectorName,
    required this.type,
    required this.status,
    this.descriptor,
  });
  final String accountId,
      connectorId,
      serviceId,
      name,
      connectorName,
      type,
      status;
  final Map<String, dynamic>? descriptor;
  SourceKind? get kind => switch (type) {
    'smb' => SourceKind.smb,
    'jellyfin' => SourceKind.jellyfin,
    'emby' => SourceKind.emby,
    'webdav' => SourceKind.webdav,
    _ => null,
  };
  bool get enabled => status == 'enabled';
  String get identity => '$accountId/$connectorId/$serviceId';
  Map<String, dynamic>? get localAccess =>
      descriptor?['localAccess'] as Map<String, dynamic>?;
  bool get supportsLocal => kind != SourceKind.smb && localAccess != null;

  SourceConfig draft({String? id}) {
    final k = kind!;
    final app = descriptor?['application'] as Map<String, dynamic>?;
    final scheme =
        app?['scheme'] as String? ?? (k == SourceKind.smb ? 'smb' : 'http');
    final address = Uri(
      scheme: scheme,
      host:
          app?['tlsServerName'] as String? ??
          'source-${serviceId.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '-')}.opx.invalid',
      path: app?['basePath'] as String? ?? '',
    ).toString();
    return SourceConfig(
      id: id ?? 'connector:$identity',
      kind: k,
      name: name,
      address: address,
      remote: SourceRemote(
        proxy: serviceId,
        accountId: accountId,
        connectorId: connectorId,
        serviceName: name,
        managedLocal: supportsLocal,
        mode: supportsLocal
            ? RemoteConnectionMode.automatic
            : RemoteConnectionMode.remoteOnly,
        localAddress: localAccess?['endpoint'] as String?,
        localTlsSha256: (localAccess?['identity'] as Map?)?['value'] as String?,
      ),
    );
  }

  static List<DiscoveredSource> parseCatalog(Map<String, dynamic> profile) {
    final user = profile['userId'] as String;
    final catalog = profile['sourceCatalog'];
    final List raw;
    if (catalog == null) {
      raw = profile['services'] as List;
    } else {
      if (catalog is! Map ||
          catalog['schemaVersion'] != 1 ||
          catalog['userId'] != user ||
          catalog['revision'] != profile['revision'] ||
          catalog['items'] is! List) {
        throw const FormatException('Invalid source catalog');
      }
      raw = catalog['items'] as List;
    }
    final result = <DiscoveredSource>[];
    final ids = <String>{};
    for (final item in raw) {
      // Legacy profiles may expose routing fields only.
      if (catalog == null &&
          (item is! Map ||
              item['connectorId'] is! String ||
              item['name'] is! String ||
              item['type'] is! String)) {
        continue;
      }
      if (item is! Map ||
          item['serviceId'] is! String ||
          item['connectorId'] is! String ||
          item['name'] is! String ||
          item['type'] is! String ||
          !ids.add(item['serviceId'] as String)) {
        throw const FormatException('Invalid source catalog entry');
      }
      final state = item['status'] as String? ?? 'enabled';
      if (!{'enabled', 'disabled', 'removed'}.contains(state)) {
        throw const FormatException('Invalid source lifecycle');
      }
      final descriptor = item['sourceDescriptor'];
      if (descriptor != null) {
        _validateDescriptor(descriptor, item['type'] as String);
      }
      result.add(
        DiscoveredSource(
          accountId: user,
          connectorId: item['connectorId'] as String,
          serviceId: item['serviceId'] as String,
          name: item['name'] as String,
          connectorName: item['connectorName'] as String? ?? '',
          type: item['type'] as String,
          status: state,
          descriptor: descriptor == null
              ? null
              : Map<String, dynamic>.from(descriptor as Map),
        ),
      );
    }
    return List.unmodifiable(result);
  }

  static void _validateDescriptor(Object value, String type) {
    if (value is! Map ||
        value['schemaVersion'] != 1 ||
        value['kind'] != type ||
        value['application'] is! Map) {
      throw const FormatException('Invalid source descriptor');
    }
    final app = value['application'] as Map;
    if (!(type == 'smb' ? {'smb'} : {'http', 'https'}).contains(
      app['scheme'],
    )) {
      throw const FormatException('Invalid source scheme');
    }
    final path = app['basePath'] ?? '';
    if (path is! String ||
        path.isNotEmpty &&
            (!path.startsWith('/') ||
                path.startsWith('//') ||
                RegExp(r'[?#\\\s]').hasMatch(path))) {
      throw const FormatException('Invalid source base path');
    }
    if (app['scheme'] == 'https' &&
        (app['tlsServerName'] is! String ||
            !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9.-]*$')
                .hasMatch(app['tlsServerName'] as String))) {
      throw const FormatException('Invalid source TLS identity');
    }
    final local = value['localAccess'];
    if (local != null) {
      if (type == 'smb' ||
          local is! Map ||
          local['mode'] != 'direct_https' ||
          local['endpoint'] is! String ||
          local['identity'] is! Map) {
        throw const FormatException('Unsupported local access');
      }
      final endpoint = Uri.tryParse(local['endpoint'] as String);
      final identity = local['identity'] as Map;
      if (endpoint == null ||
          endpoint.scheme != 'https' ||
          endpoint.host.isEmpty ||
          endpoint.userInfo.isNotEmpty ||
          endpoint.hasQuery ||
          endpoint.hasFragment ||
          endpoint.path.replaceFirst(RegExp(r'/$'), '') !=
              path.replaceFirst(RegExp(r'/$'), '') ||
          identity['kind'] != 'tls_certificate_sha256' ||
          identity['value'] is! String ||
          !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(identity['value'] as String)) {
        throw const FormatException('Invalid local identity');
      }
    }
  }
}
