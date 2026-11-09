enum SourceKind {
  local('本地文件夹'),
  smb('SMB'),
  plex('Plex'),
  jellyfin('Jellyfin');

  const SourceKind(this.label);
  final String label;
}

enum ScanMode { manual, disabled }

/// Host-owned immutable instance snapshot. Secrets are represented by a scoped
/// credential reference; permissions and live authorization aren't booleans here.
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
  bool get isFileSource => kind == SourceKind.local || kind == SourceKind.smb;
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
    if (id.isEmpty || name.trim().isEmpty || address.trim().isEmpty) {
      throw const FormatException('请填写名称和地址。');
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
    final schemes = kind == SourceKind.smb ? ['smb'] : ['http', 'https'];
    if (uri == null ||
        !schemes.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.contains('..')) {
      throw const FormatException('请输入有效的服务器地址，凭据请填在单独字段。');
    }
    if (kind == SourceKind.smb && uri.hasPort && uri.port != 445) {
      throw const FormatException('SMB 使用标准 445 端口：smb://主机/共享名/可选目录。');
    }
    if (kind == SourceKind.jellyfin && userId.trim().isEmpty) {
      throw const FormatException('请填写 Jellyfin 用户 ID。');
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
