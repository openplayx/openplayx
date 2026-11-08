enum SourceKind {
  local('本地文件夹'),
  smb('SMB'),
  plex('Plex'),
  jellyfin('Jellyfin');

  const SourceKind(this.label);
  final String label;
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
  });
  final String id;
  final SourceKind kind;
  final String name;
  // Local root, smb://host/share/path or http(s) server base (with subpath).
  final String address;
  final String username;
  final String domain;
  final String userId;
  final String? bookmark;
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'name': name,
    'address': address,
    'username': username,
    'domain': domain,
    'userId': userId,
    'bookmark': bookmark,
  };
  factory SourceConfig.fromJson(Map<String, dynamic> j) => SourceConfig(
    id: j['id'] as String,
    kind: SourceKind.values.byName(j['kind'] as String),
    name: j['name'] as String,
    address: j['address'] as String,
    username: j['username'] as String? ?? '',
    domain: j['domain'] as String? ?? '',
    userId: j['userId'] as String? ?? '',
    bookmark: j['bookmark'] as String?,
  );

  void validate() {
    if (id.isEmpty || name.trim().isEmpty || address.trim().isEmpty) {
      throw const FormatException('请填写名称和地址。');
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
    if (kind == SourceKind.smb &&
        (uri.pathSegments.where((s) => s.isNotEmpty).isEmpty || uri.hasPort)) {
      throw const FormatException('SMB 地址格式：smb://主机/共享名，可带子目录，使用标准 445 端口。');
    }
    if (kind == SourceKind.jellyfin && userId.trim().isEmpty) {
      throw const FormatException('请填写 Jellyfin 用户 ID。');
    }
  }
}
