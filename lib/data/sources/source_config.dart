enum SourceKind {
  local('本地文件夹', files: true),
  smb('SMB', files: true, scheme: 'smb', standardPort: 445),
  webdav('WebDAV', files: true, scheme: 'http'),
  ftp('FTP', files: true, scheme: 'ftp', standardPort: 21),
  sftp('SFTP', files: true, scheme: 'sftp', standardPort: 22),
  s3('S3', files: true, scheme: 'http'),
  plex('Plex', scheme: 'http', defaultPort: 32400),
  jellyfin('Jellyfin', scheme: 'http', defaultPort: 8096),
  emby('Emby', scheme: 'http', defaultPort: 8096),
  dlna('DLNA', scheme: 'http');

  const SourceKind(
    this.label, {
    this.files = false,
    this.scheme,
    this.standardPort,
    this.defaultPort,
  });
  final String label;

  /// Path-addressed file tree that can be scanned into the library.
  final bool files;

  /// URL scheme of the address; `http` also accepts `https`.
  final String? scheme;

  /// Protocol port implied when the address has none (never written out).
  final int? standardPort;

  /// Port filled in for a bare host on an HTTP media server.
  final int? defaultPort;

  List<String> get schemes => scheme == 'http' ? ['http', 'https'] : [scheme!];
  bool get isHttp => scheme == 'http';

  /// Media servers that only work with a sign-in token.
  bool get requiresSecret => this == plex || this == jellyfin || this == emby;

  /// Username/password are optional (anonymous or guest access).
  bool get optionalCredential =>
      this == smb || this == webdav || this == ftp || this == s3;

  /// Jellyfin and Emby share the same server API.
  bool get mediaBrowser => this == jellyfin || this == emby;
}

enum ScanMode { manual, disabled }

/// Host-owned immutable instance snapshot. Secrets are represented by a scoped
/// credential reference; permissions and live authorization aren't booleans here.
const defaultScanExtensions = [
  'mp4', 'mkv', 'avi', 'mov', 'webm', 'm4v', 'ts', 'm2ts', 'wmv', //
  'mp3', 'flac', 'm4a', 'wav', 'ogg',
];

/// Parses user input such as "mp4, .MKV；avi" into normalized suffixes.
List<String> parseScanExtensions(String text) => text
    .split(RegExp(r'[\s,;，；、]+'))
    .map((e) => e.replaceFirst(RegExp(r'^\*?\.'), '').toLowerCase())
    .where((e) => e.isNotEmpty)
    .toSet()
    .toList();

/// Whether a scan keeps a file with this name. Hidden files (leading dot, such
/// as macOS `._movie.mp4` or `.DS_Store`) are always dropped; empty
/// [extensions] keeps every other file.
bool matchesScanExtension(String name, List<String> extensions) {
  if (name.startsWith('.')) return false;
  if (extensions.isEmpty) return true;
  final dot = name.lastIndexOf('.');
  return dot >= 0 && extensions.contains(name.substring(dot + 1).toLowerCase());
}

class SourceConfig {
  const SourceConfig({
    required this.id,
    required this.kind,
    required this.name,
    required this.address,
    this.username = '',
    this.domain = '',
    this.userId = '',
    this.bookmark,
    this.logicalSourceId = '',
    this.enabled = true,
    this.pluginVersion = '1.0.0',
    this.configVersion = 2,
    this.revision = 0,
    this.credentialRef,
    this.credentialExpiresAt,
    this.includeInSearch = false,
    this.browseMode,
    this.requestTimeoutSeconds = 30,
    this.maxConcurrentRequests = 2,
    this.allowedPaths = const [''],
    this.scanExclusions = const [],
    this.scanMode = ScanMode.manual,
    this.backgroundIndexing = false,
  });
  final String id;
  final SourceKind kind;
  final String name;
  final String address;
  final String username;
  final String domain;
  final String userId;
  final String? bookmark;
  final String logicalSourceId;
  final bool enabled;
  final String pluginVersion;
  final int configVersion;
  final int revision;
  final String? credentialRef;
  final DateTime? credentialExpiresAt;
  final bool includeInSearch;
  final String? browseMode;
  final int requestTimeoutSeconds;
  final int maxConcurrentRequests;
  final List<String> allowedPaths;
  final List<String> scanExclusions;

  final ScanMode scanMode;
  final bool backgroundIndexing;

  /// Name shown when the connection appears in another place (pickers,
  /// filters, file source rows): always prefixed with the type. A blank name
  /// falls back to the address, so the default is "type + address".
  String get displayName =>
      '${kind.label} · ${name.trim().isEmpty ? address : name.trim()}';

  /// Name for the connection's own management row: the user's name, or the
  /// type-prefixed default when none was entered.
  String get titleName => name.trim().isEmpty ? displayName : name.trim();
  bool get isFileSource => kind.files;

  /// Decoded root path inside the server ("/" or "/share/movies"); resource ids
  /// of remote file sources are decoded absolute paths below it.
  String get rootPath {
    if (kind == SourceKind.local) return address;
    final segments = Uri.parse(address).pathSegments.where((s) => s.isNotEmpty);
    return '/${segments.join('/')}';
  }

  String get effectiveBrowseMode =>
      browseMode ?? (isFileSource ? 'files' : 'library');
  String get pluginId => 'source.${kind.name}';

  SourceConfig copyWith({
    String? name,
    String? address,
    String? username,
    String? domain,
    String? userId,
    String? bookmark,
    String? logicalSourceId,
    bool? enabled,
    String? pluginVersion,
    int? configVersion,
    int? revision,
    String? credentialRef,
    DateTime? credentialExpiresAt,
    bool clearExpiry = false,
    bool? includeInSearch,
    String? browseMode,
    int? requestTimeoutSeconds,
    int? maxConcurrentRequests,
    List<String>? allowedPaths,
    List<String>? scanExclusions,
    ScanMode? scanMode,
    bool? backgroundIndexing,
  }) => SourceConfig(
    id: id,
    kind: kind,
    name: name ?? this.name,
    address: address ?? this.address,
    username: username ?? this.username,
    domain: domain ?? this.domain,
    userId: userId ?? this.userId,
    bookmark: bookmark ?? this.bookmark,
    logicalSourceId: logicalSourceId ?? this.logicalSourceId,
    enabled: enabled ?? this.enabled,
    pluginVersion: pluginVersion ?? this.pluginVersion,
    configVersion: configVersion ?? this.configVersion,
    revision: revision ?? this.revision,
    credentialRef: credentialRef ?? this.credentialRef,
    credentialExpiresAt: clearExpiry
        ? null
        : credentialExpiresAt ?? this.credentialExpiresAt,
    includeInSearch: includeInSearch ?? this.includeInSearch,
    browseMode: browseMode ?? this.browseMode,
    requestTimeoutSeconds: requestTimeoutSeconds ?? this.requestTimeoutSeconds,
    maxConcurrentRequests: maxConcurrentRequests ?? this.maxConcurrentRequests,
    allowedPaths: List.unmodifiable(allowedPaths ?? this.allowedPaths),
    scanExclusions: List.unmodifiable(scanExclusions ?? this.scanExclusions),
    scanMode: scanMode ?? this.scanMode,
    backgroundIndexing: backgroundIndexing ?? this.backgroundIndexing,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'name': name,
    'address': address,
    'username': username,
    'domain': domain,
    'userId': userId,
    'bookmark': bookmark,
    'logicalSourceId': logicalSourceId,
    'enabled': enabled,
    'pluginVersion': pluginVersion,
    'configVersion': configVersion,
    'revision': revision,
    'credentialRef': credentialRef,
    'credentialExpiresAt': credentialExpiresAt?.toUtc().toIso8601String(),
    'includeInSearch': includeInSearch,
    'browseMode': effectiveBrowseMode,
    'requestTimeoutSeconds': requestTimeoutSeconds,
    'maxConcurrentRequests': maxConcurrentRequests,
    'allowedPaths': allowedPaths,
    'scanExclusions': scanExclusions,
    'scanMode': scanMode.name,
    'backgroundIndexing': backgroundIndexing,
  };
  factory SourceConfig.fromJson(Map<String, dynamic> j) {
    const keys = {
      'id',
      'kind',
      'name',
      'address',
      'username',
      'domain',
      'userId',
      'bookmark',
      'logicalSourceId',
      'enabled',
      'pluginVersion',
      'configVersion',
      'revision',
      'credentialRef',
      'credentialExpiresAt',
      'includeInSearch',
      'browseMode',
      'requestTimeoutSeconds',
      'maxConcurrentRequests',
      'allowedPaths',
      'scanExclusions',
      'scanExtensions', // legacy per-source value, now a global setting
      'scanMode',
      'backgroundIndexing',
    };
    if (j.keys.any((key) => !keys.contains(key))) {
      throw const FormatException('配置包含未知字段，原始配置必须保留。');
    }
    return SourceConfig(
      id: j['id'] as String,
      kind: SourceKind.values.byName(j['kind'] as String),
      name: j['name'] as String,
      address: j['address'] as String,
      username: j['username'] as String? ?? '',
      domain: j['domain'] as String? ?? '',
      userId: j['userId'] as String? ?? '',
      bookmark: j['bookmark'] as String?,
      logicalSourceId: j['logicalSourceId'] as String? ?? '',
      enabled: j['enabled'] as bool? ?? true,
      pluginVersion: j['pluginVersion'] as String? ?? '1.0.0',
      configVersion: j['configVersion'] as int? ?? 2,
      revision: j['revision'] as int? ?? 0,
      credentialRef: j['credentialRef'] as String?,
      credentialExpiresAt: j['credentialExpiresAt'] == null
          ? null
          : DateTime.parse(j['credentialExpiresAt'] as String),
      includeInSearch: j['includeInSearch'] as bool? ?? false,
      browseMode: j['browseMode'] as String?,
      requestTimeoutSeconds: j['requestTimeoutSeconds'] as int? ?? 30,
      maxConcurrentRequests: j['maxConcurrentRequests'] as int? ?? 2,
      allowedPaths: List.unmodifiable(
        (j['allowedPaths'] as List? ?? ['']).cast<String>(),
      ),
      scanExclusions: List.unmodifiable(
        (j['scanExclusions'] as List? ?? []).cast<String>(),
      ),
      scanMode: ScanMode.values.byName(j['scanMode'] as String? ?? 'manual'),
      backgroundIndexing: j['backgroundIndexing'] as bool? ?? false,
    );
  }

  void validate() {
    if (configVersion != 2) throw const FormatException('配置版本不兼容，不能覆盖保存。');
    if (id.isEmpty || address.trim().isEmpty) {
      throw const FormatException('请填写地址。');
    }
    if (requestTimeoutSeconds < 1 ||
        requestTimeoutSeconds > 120 ||
        maxConcurrentRequests < 1 ||
        maxConcurrentRequests > 8) {
      throw const FormatException('请求超时须为 1–120 秒，并发须为 1–8。');
    }
    if (allowedPaths.isEmpty ||
        allowedPaths.length > 100 ||
        scanExclusions.length > 100) {
      throw const FormatException('至少设置一个访问范围，范围和排除项最多各 100 条。');
    }
    for (final path in [...allowedPaths, ...scanExclusions]) {
      if (path.startsWith('/') ||
          path.contains('\\') ||
          path.contains(':') ||
          path.split('/').any((p) => p == '..' || p == '.')) {
        throw const FormatException('访问范围和排除项须为根目录内的相对路径，不允许 .. 或绝对路径。');
      }
    }
    if (effectiveBrowseMode != (isFileSource ? 'files' : 'library')) {
      throw const FormatException('此插件不支持该浏览方式。');
    }
    if (includeInSearch || backgroundIndexing) {
      throw const FormatException('此插件尚未提供搜索或后台索引能力。');
    }
    if (!isFileSource &&
        (allowedPaths.any((p) => p.isNotEmpty) || scanExclusions.isNotEmpty)) {
      throw const FormatException('媒体库来源暂不支持文件目录策略。');
    }
    if (kind == SourceKind.local) {
      if (!address.startsWith('/') &&
          !RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(address)) {
        throw const FormatException('请选择本地文件夹。');
      }
      return;
    }
    if (address
        .split('/')
        .any(
          (s) =>
              Uri.decodeComponent(s) == '..' || Uri.decodeComponent(s) == '.',
        )) {
      throw const FormatException('地址不能包含相对路径片段。');
    }
    final uri = Uri.tryParse(address);
    if (uri == null ||
        !kind.schemes.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.hasQuery && kind != SourceKind.dlna) ||
        uri.hasFragment ||
        uri.pathSegments.contains('..')) {
      throw const FormatException('请输入有效的服务器地址，凭据请填在单独字段。');
    }
    if (kind == SourceKind.smb && uri.hasPort && uri.port != 445) {
      throw const FormatException('SMB 使用标准 445 端口：smb://主机/共享名/可选目录。');
    }
    if (kind.mediaBrowser && userId.trim().isEmpty) {
      throw FormatException('请填写 ${kind.label} 用户 ID。');
    }
    if (kind == SourceKind.sftp && username.trim().isEmpty) {
      throw const FormatException('请填写 SFTP 用户名。');
    }
  }

  bool allows(String relative, {bool directory = false}) => allowedPaths.any(
    (root) =>
        root.isEmpty ||
        relative == root ||
        relative.startsWith('$root/') ||
        (directory && (relative.isEmpty || root.startsWith('$relative/'))),
  );

  bool excludedFromScan(String relative) => scanExclusions.any((pattern) {
    if (pattern.endsWith('/**') &&
        relative == pattern.substring(0, pattern.length - 3)) {
      return true;
    }
    final expression = StringBuffer('^');
    for (var i = 0; i < pattern.length; i++) {
      if (pattern.startsWith('**/', i)) {
        expression.write('(?:.*/)?');
        i += 2;
      } else if (pattern.startsWith('**', i)) {
        expression.write('.*');
        i++;
      } else if (pattern[i] == '*') {
        expression.write('[^/]*');
      } else {
        expression.write(RegExp.escape(pattern[i]));
      }
    }
    expression.write(r'(?:/.*)?$');
    return RegExp(expression.toString()).hasMatch(relative);
  });
}
