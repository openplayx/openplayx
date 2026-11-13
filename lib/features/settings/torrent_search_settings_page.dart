import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../services/torrent_search/torrent_search_client.dart';
import '../../services/torrent_search/torrent_search_config.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/settings/settings_adaptive.dart';
import '../../ui/components/settings/settings_section.dart';
import 'torrent_service_settings_page.dart' show formatBytes;

typedef TorrentSearchClientFactory = TorrentSearchClient Function(
  TorrentSearchConfig config,
);

TorrentSearchClient _defaultClient(
  TorrentSearchRegistry registry,
  TorrentSearchConfig c,
) => TorrentSearchClient(config: c, token: () => registry.credential(c));

/// Human text for service/client error codes shown on this page.
String torrentSearchErrorText(String code) => switch (code) {
  'service_unauthorized' => 'Token 无效或已撤销',
  'service_forbidden' => 'Token 没有所需权限',
  'service_token_missing' => '尚未保存 Token',
  'service_unreachable' => '无法连接到服务',
  'service_timeout' => '连接超时',
  'tls_verification_failed' => 'HTTPS 证书校验失败',
  'rate_limited' => '请求过于频繁，请稍后再试',
  _ => code,
};

/// Settings → 来源与下载 → Torrent 搜索服务. Configures read-only search
/// services (openplayx/torrent-search) for the AI assistant. Searching never
/// downloads; this is separate from the BitTorrent download service and
/// never shares its token.
class TorrentSearchSettingsPage extends StatefulWidget {
  const TorrentSearchSettingsPage({
    super.key,
    required this.registry,
    this.clientFor,
  });
  final TorrentSearchRegistry registry;
  final TorrentSearchClientFactory? clientFor;
  @override
  State<TorrentSearchSettingsPage> createState() =>
      _TorrentSearchSettingsPageState();
}

class _TorrentSearchSettingsPageState extends State<TorrentSearchSettingsPage> {
  final _status = <String, String>{};

  TorrentSearchRegistry get _registry => widget.registry;
  TorrentSearchClient _client(TorrentSearchConfig c) =>
      widget.clientFor?.call(c) ?? _defaultClient(_registry, c);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    for (final c in _registry.list()) {
      if (!c.enabled) continue;
      try {
        final caps = await _client(c).capabilities();
        final ops = caps['operations'] as Map? ?? const {};
        _status[c.id] = ops['resolve'] == true
            ? '可用 · 可搜索，可交给下载服务'
            : '可用 · 仅搜索（Token 无 resolve 权限）';
      } on TorrentSearchException catch (e) {
        _status[c.id] = '不可用（${torrentSearchErrorText(e.code)}）';
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _edit([TorrentSearchConfig? config]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TorrentSearchForm(
          registry: _registry,
          config: config,
          clientFor: widget.clientFor,
        ),
      ),
    );
    // The form may have saved (or tested) without popping true; always reload.
    if (mounted) {
      setState(_status.clear);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final configs = _registry.list();
    return AppPage(
      title: const Text('Torrent 搜索服务'),
      body: SettingsListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ShadButton(
              key: const ValueKey('tsearch-add-service'),
              onPressed: () => _edit(),
              child: const Text('添加搜索服务'),
            ),
          ),
          if (configs.isEmpty)
            const SettingsSection(
              footer:
                  '连接你自己部署的 OpenPlayX Torrent 搜索服务后，AI 助手可以按关键词查找种子候选。'
                  '搜索只读，不会自动下载；选定候选并明确要求下载后，才交给 BitTorrent 服务。',
              children: [
                SettingsRow(
                  key: ValueKey('tsearch-unconfigured'),
                  title: '尚未配置',
                ),
              ],
            ),
          for (final c in configs)
            SettingsSection(
              key: ValueKey('tsearch-service-${c.id}'),
              title: c.name,
              footer: '搜索结果来自外部索引，名称、大小和做种数未经验证，不代表可播放或已下载。',
              children: [
                SettingsRow(
                  title: '地址',
                  control: Text(c.host),
                  chevron: true,
                  onTap: () => _edit(c),
                ),
                SettingsRow(
                  title: '状态',
                  control: Text(c.enabled ? (_status[c.id] ?? '…') : '已停用'),
                ),
                SettingsRow(title: '默认分类', control: Text(c.defaultCategory)),
                if (c.enabled)
                  SettingsRow(
                    key: ValueKey('tsearch-try-${c.id}'),
                    title: '测试搜索',
                    description: '直接查询此服务，查看返回的候选（只读，不会下载）',
                    chevron: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TorrentSearchTryPage(config: c, client: _client(c)),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Edit form for one search service. The API token is written only to
/// secure storage and never shown again.
class TorrentSearchForm extends StatefulWidget {
  const TorrentSearchForm({
    super.key,
    required this.registry,
    this.config,
    this.clientFor,
  });
  final TorrentSearchRegistry registry;
  final TorrentSearchConfig? config;
  final TorrentSearchClientFactory? clientFor;
  @override
  State<TorrentSearchForm> createState() => _TorrentSearchFormState();
}

class _TorrentSearchFormState extends State<TorrentSearchForm> {
  static const _defaultName = 'Torrent 搜索';
  late final _name = TextEditingController(
    text: widget.config?.name ?? _defaultName,
  );
  late final _url = TextEditingController(text: widget.config?.url ?? '');
  final _token = TextEditingController();
  late final _category = TextEditingController(
    text: widget.config?.defaultCategory ?? 'all',
  );
  late bool _allowHttp = widget.config?.allowInsecureHttp ?? false;
  late bool _enabled = widget.config?.enabled ?? true;
  bool _hasToken = false, _busy = false;
  String? _message;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    if (c != null) {
      widget.registry.hasToken(c).then((v) {
        if (mounted) setState(() => _hasToken = v);
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _url, _token, _category]) {
      c.dispose();
    }
    super.dispose();
  }

  TorrentSearchConfig _build() => TorrentSearchConfig(
    id: widget.config?.id ?? TorrentSearchRegistry.newId(),
    name: _name.text.trim().isEmpty ? _defaultName : _name.text.trim(),
    url: _url.text.trim().replaceAll(RegExp(r'/+$'), ''),
    enabled: _enabled,
    allowInsecureHttp: _allowHttp,
    defaultCategory: _category.text.trim().isEmpty
        ? 'all'
        : _category.text.trim(),
  );

  void _fail(String message) => setState(() {
    _message = message;
    _error = true;
  });

  Future<void> _save({bool test = false}) async {
    final config = _build();
    if (_token.text.trim().isEmpty && !_hasToken) {
      return _fail('请填写 API Token');
    }
    setState(() => _busy = true);
    try {
      final saved = widget.registry.save(config);
      final token = _token.text.trim();
      if (token.isNotEmpty) await widget.registry.setCredential(saved, token);
      _hasToken = true;
      _token.clear();
      if (!test) {
        if (mounted) Navigator.pop(context, true);
        return;
      }
      final client =
          widget.clientFor?.call(saved) ??
          _defaultClient(widget.registry, saved);
      final caps = await client.capabilities();
      final cats = await client.categories();
      final keys = [
        for (final k in (cats['categories'] as List? ?? const []))
          if (k is Map && k['key'] is String) k['key'] as String,
      ];
      final resolve = (caps['operations'] as Map?)?['resolve'] == true;
      if (!keys.contains(saved.defaultCategory)) {
        _message =
            '连接成功，但服务不支持默认分类「${saved.defaultCategory}」。可用分类示例：'
            '${keys.take(8).join('、')}';
        _error = true;
      } else {
        _message = resolve
            ? '连接成功：可搜索，可将选定候选交给下载服务（${keys.length} 个分类）'
            : '连接成功：仅搜索。该 Token 没有 resolve 权限，无法把候选交给下载服务';
        _error = !resolve;
      }
    } on FormatException catch (e) {
      _message = switch (e.message) {
        'url_http_public' => '公网地址必须使用 HTTPS；HTTP 仅允许局域网地址',
        'url' => '地址无效：需要完整的 https:// 地址；局域网 HTTP 需打开“允许 HTTP”',
        'category' => '默认分类格式无效（例如 all、video、video.hd_movies）',
        _ => e.message,
      };
      _error = true;
    } on TorrentSearchException catch (e) {
      _message = '已保存，但连接失败：${torrentSearchErrorText(e.code)}';
      _error = true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showSettingsConfirm(
      context,
      title: '移除此搜索服务？',
      message: '只移除 App 中的地址和 Token，不影响服务本身和已有下载。',
      confirmLabel: '移除',
      cancelLabel: '取消',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await widget.registry.remove(widget.config!.id);
    if (mounted) Navigator.pop(context, true);
  }

  Widget _input(
    String id,
    TextEditingController c,
    String hint, {
    bool secret = false,
  }) => ShadInput(
    key: ValueKey('tsearch-field-$id'),
    controller: c,
    placeholder: Text(hint),
    obscureText: secret,
    autocorrect: false,
    enableSuggestions: false,
    decoration: ShadDecoration.none,
  );

  @override
  Widget build(BuildContext context) => AppPage(
    title: Text(widget.config == null ? '添加 Torrent 搜索服务' : '编辑 Torrent 搜索服务'),
    trailing: [
      ShadButton(
        key: const ValueKey('tsearch-save'),
        onPressed: _busy ? null : _save,
        child: const Text('保存'),
      ),
    ],
    body: SettingsListView(
      children: [
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _error
                ? ShadAlert.destructive(title: Text(_message!))
                : ShadAlert(title: Text(_message!)),
          ),
        SettingsSection(
          title: '连接',
          footer: 'Token 保存在系统安全存储中，与 BitTorrent 下载服务的 Token 相互独立。',
          children: [
            SettingsFieldRow(title: '名称', field: _input('name', _name, '名称')),
            SettingsFieldRow(
              title: '地址',
              field: _input('url', _url, 'https://search.example.com'),
            ),
            SettingsFieldRow(
              title: 'API Token',
              field: _input(
                'token',
                _token,
                _hasToken ? '已保存（留空不修改）' : 'Token',
                secret: true,
              ),
            ),
            SettingsRow(
              title: '允许 HTTP（仅局域网）',
              description: '只对局域网地址生效；证书校验从不关闭。',
              control: ShadSwitch(
                key: const ValueKey('tsearch-allow-http'),
                value: _allowHttp,
                onChanged: (v) => setState(() => _allowHttp = v),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: '搜索',
          children: [
            SettingsFieldRow(
              title: '默认分类',
              field: _input('category', _category, 'all'),
              description: '服务分类键，例如 all、video、video.hd_movies、apps。',
            ),
            SettingsRow(
              title: '启用',
              description: '停用后 AI 助手不再提供搜索工具。',
              control: ShadSwitch(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: ShadButton.outline(
                key: const ValueKey('tsearch-test'),
                onPressed: _busy ? null : () => _save(test: true),
                child: const Text('保存并测试连接'),
              ),
            ),
            if (widget.config != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ShadButton.destructive(
                  key: const ValueKey('tsearch-delete'),
                  onPressed: _busy ? null : _delete,
                  child: const Text('移除配置'),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

/// Settings → Torrent 搜索服务 → 测试搜索. Queries the service directly so the
/// configuration can be checked without the assistant. Read-only: shows
/// candidates and their detail, never resolves or downloads.
class TorrentSearchTryPage extends StatefulWidget {
  const TorrentSearchTryPage({
    super.key,
    required this.config,
    required this.client,
  });
  final TorrentSearchConfig config;
  final TorrentSearchClient client;
  @override
  State<TorrentSearchTryPage> createState() => _TorrentSearchTryPageState();
}

class _TorrentSearchTryPageState extends State<TorrentSearchTryPage> {
  static const _sorts = {
    'relevance': '相关度',
    'seeders_desc': '做种最多',
    'size_desc': '体积最大',
    'size_asc': '体积最小',
    'date_desc': '最新上传',
  };
  final _query = TextEditingController();
  late String _category = widget.config.defaultCategory;
  String _sort = 'relevance';
  List<String> _categories = const [];
  Map<String, dynamic>? _page;
  final _details = <String, Map<String, dynamic>>{};
  final _magnets = <String, String>{};
  final _magnetErrors = <String, String>{};
  String? _resolving;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.client
        .categories()
        .then((cats) {
          if (!mounted) return;
          setState(() {
            _categories = [
              for (final k in (cats['categories'] as List? ?? const []))
                if (k is Map && k['key'] is String) k['key'] as String,
            ];
            if (!_categories.contains(_category)) _category = 'all';
          });
        })
        .catchError((Object e) {
          if (mounted && e is TorrentSearchException) {
            setState(() => _error = torrentSearchErrorText(e.code));
          }
        });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search({int page = 1}) async {
    final query = _query.text.trim();
    if (query.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.client.search(
        query: query,
        category: _category,
        sort: _sort,
        page: page,
      );
      _page = result;
      _details.clear();
      _magnets.clear();
      _magnetErrors.clear();
    } on TorrentSearchException catch (e) {
      _error = torrentSearchErrorText(e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _detail(String ref) async {
    if (_details.containsKey(ref)) {
      setState(() => _details.remove(ref));
      return;
    }
    try {
      final d = await widget.client.detail(ref);
      if (mounted) setState(() => _details[ref] = d);
    } on TorrentSearchException catch (e) {
      if (mounted) setState(() => _error = torrentSearchErrorText(e.code));
    }
  }

  /// Asks the service to re-check the item and return its validated magnet
  /// (needs the token's resolve scope). Only on an explicit tap.
  Future<void> _resolve(String ref) async {
    setState(() {
      _resolving = ref;
      _magnetErrors.remove(ref);
    });
    try {
      final r = await widget.client.resolve(ref);
      _magnets[ref] = r.magnet;
    } on TorrentSearchException catch (e) {
      _magnetErrors[ref] = switch (e.code) {
        'service_forbidden' => 'Token 没有 resolve 权限',
        'candidate_changed' => '条目在来源上已变化，请重新搜索',
        'no_valid_magnet' => '该条目没有有效的 Magnet',
        'result_expired' => '结果已过期，请重新搜索',
        _ => torrentSearchErrorText(e.code),
      };
    } finally {
      if (mounted) setState(() => _resolving = null);
    }
  }

  Future<void> _copy(String magnet) async {
    await Clipboard.setData(ClipboardData(text: magnet));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(const SnackBar(content: Text('已复制 Magnet 地址')));
  }

  Widget _magnet(String ref, Map<String, dynamic> detail) {
    final theme = ShadTheme.of(context);
    final magnet = _magnets[ref];
    final error = _magnetErrors[ref];
    if (detail['has_magnet'] != true) {
      return Text('该条目没有 Magnet', style: theme.textTheme.muted);
    }
    if (magnet == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShadButton.outline(
            key: ValueKey('tsearch-magnet-get-$ref'),
            size: ShadButtonSize.sm,
            onPressed: _resolving != null ? null : () => _resolve(ref),
            child: Text(_resolving == ref ? '获取中…' : '获取 Magnet'),
          ),
          if (error != null)
            Text(
              error,
              style: theme.textTheme.muted.copyWith(
                color: theme.colorScheme.destructive,
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          magnet,
          key: ValueKey('tsearch-magnet-$ref'),
          maxLines: 4,
          style: theme.textTheme.muted.copyWith(fontFamily: 'monospace'),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: ShadButton.outline(
            key: ValueKey('tsearch-magnet-copy-$ref'),
            size: ShadButtonSize.sm,
            onPressed: () => _copy(magnet),
            child: const Text('复制 Magnet'),
          ),
        ),
      ],
    );
  }

  Widget _item(Map item) {
    final theme = ShadTheme.of(context);
    final ref = item['result_ref'] as String? ?? '';
    final detail = _details[ref];
    final meta = <String>[
      if (item['size_bytes'] is num) formatBytes(item['size_bytes'] as num),
      '做种 ${item['seeders'] ?? '?'} · 下载 ${item['leechers'] ?? '?'}',
      if ((item['uploaded_date'] ?? item['uploaded_text']) != null)
        '${item['uploaded_date'] ?? item['uploaded_text']}',
      if (item['category'] != null) '${item['category']}',
      if (item['has_magnet'] != true) '无 Magnet',
    ];
    return InkWell(
      key: ValueKey('tsearch-result-$ref'),
      onTap: ref.isEmpty ? null : () => _detail(ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${item['title']}', style: theme.textTheme.small),
            const SizedBox(height: 4),
            Text(meta.join(' · '), style: theme.textTheme.muted),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (detail['size_bytes'] is num)
                    '大小 ${formatBytes(detail['size_bytes'] as num)}'
                        '${detail['size_exact'] == true ? '（${detail['size_bytes']} 字节）' : ''}',
                  if (detail['file_count'] != null)
                    '${detail['file_count']} 个文件',
                  if (detail['uploaded_at'] != null)
                    '上传于 ${detail['uploaded_at']}',
                  if (detail['uploader'] != null) '上传者 ${detail['uploader']}',
                  if (detail['source_trusted'] == true) '来源标记：trusted',
                  if (detail['source_vip'] == true) '来源标记：VIP',
                  if (detail['changed'] == true) '注意：条目已变化',
                ].join(' · '),
                style: theme.textTheme.muted,
              ),
              if (detail['description'] is String) ...[
                const SizedBox(height: 6),
                Text(
                  detail['description'] as String,
                  maxLines: 12,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.muted,
                ),
              ],
              const SizedBox(height: 8),
              _magnet(ref, detail),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final items = (page?['items'] as List? ?? const []).whereType<Map>();
    final sourcePage = page?['source_page'] as int? ?? 1;
    return AppPage(
      title: Text('测试搜索 · ${widget.config.name}'),
      body: SettingsListView(
        children: [
          SettingsSection(
            title: '查询',
            footer: '结果来自外部索引，名称、大小和做种数未经验证。点按条目查看详情，可获取并复制 Magnet；此页不会下载。',
            children: [
              SettingsFieldRow(
                title: '关键词',
                field: ShadInput(
                  key: const ValueKey('tsearch-try-query'),
                  controller: _query,
                  placeholder: const Text('例如 ubuntu'),
                  autocorrect: false,
                  decoration: ShadDecoration.none,
                  onSubmitted: (_) => _search(),
                ),
              ),
              SettingsRow(
                title: '分类',
                control: ShadSelect<String>(
                  key: const ValueKey('tsearch-try-category'),
                  initialValue: _category,
                  enabled: !_busy && _categories.isNotEmpty,
                  options: [
                    for (final k in _categories)
                      ShadOption(value: k, child: Text(k)),
                  ],
                  selectedOptionBuilder: (_, v) => Text(v),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
              ),
              SettingsRow(
                title: '排序',
                control: ShadSelect<String>(
                  key: const ValueKey('tsearch-try-sort'),
                  initialValue: _sort,
                  enabled: !_busy,
                  options: [
                    for (final e in _sorts.entries)
                      ShadOption(value: e.key, child: Text(e.value)),
                  ],
                  selectedOptionBuilder: (_, v) => Text(_sorts[v] ?? v),
                  onChanged: (v) {
                    if (v != null) setState(() => _sort = v);
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ShadButton(
              key: const ValueKey('tsearch-try-run'),
              onPressed: _busy ? null : _search,
              child: const Text('搜索'),
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: ShadProgress(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ShadAlert.destructive(title: Text(_error!)),
            ),
          if (page != null)
            SettingsSection(
              key: const ValueKey('tsearch-try-results'),
              title:
                  '第 $sourcePage / ${page['page_count']} 页 · ${page['result_count']} 条'
                  '${(page['cache'] as Map?)?['hit'] == true ? ' · 缓存' : ''}',
              children: [
                if (items.isEmpty)
                  const SettingsRow(title: '没有结果')
                else
                  for (final item in items) _item(item),
              ],
            ),
          if (page != null)
            Row(
              children: [
                Expanded(
                  child: ShadButton.outline(
                    onPressed: _busy || sourcePage <= 1
                        ? null
                        : () => _search(page: sourcePage - 1),
                    child: const Text('上一页'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShadButton.outline(
                    key: const ValueKey('tsearch-try-next'),
                    onPressed: _busy || page['has_next_page'] != true
                        ? null
                        : () => _search(page: sourcePage + 1),
                    child: const Text('下一页'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
