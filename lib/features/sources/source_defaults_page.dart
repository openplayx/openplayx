import 'package:flutter/material.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_manager.dart';
import '../../data/sources/source_schema.dart';

class SourceDefaultsPage extends StatefulWidget {
  const SourceDefaultsPage({super.key, required this.manager});
  final SourceManager manager;
  @override
  State<SourceDefaultsPage> createState() => _SourceDefaultsPageState();
}

class _SourceDefaultsPageState extends State<SourceDefaultsPage> {
  String? _error;
  bool _busy = false;
  Future<void> _save(String capability, String? id) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.manager.setDefault(capability, id);
    } catch (error) {
      _error = error is PluginException ? error.message : '默认实例保存失败。';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _selected(String capability) {
    final id = widget.manager.bindings.defaults[capability];
    return widget.manager.configs.any(
          (c) =>
              c.id == id &&
              c.enabled &&
              SourceSchemas.forKind(c.kind).capabilities.contains(capability),
        )
        ? id!
        : '';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('能力默认实例与搜索范围')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('默认实例只用于未显式选择来源的操作。已有资源始终由原实例解析，不自动切换账号。'),
        for (final capability in ['source.browse', 'source.resolve'])
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: DropdownButtonFormField<String>(
              key: ValueKey(
                '$capability-${widget.manager.bindings.defaults[capability]}',
              ),
              initialValue: _selected(capability),
              decoration: InputDecoration(
                labelText: capability == 'source.browse'
                    ? '默认浏览实例'
                    : '默认资源解析实例',
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('每次选择')),
                for (final config in widget.manager.configs.where(
                  (c) =>
                      c.enabled &&
                      SourceSchemas.forKind(c.kind).capabilities
                          .contains(capability),
                ))
                  DropdownMenuItem(value: config.id, child: Text(config.name)),
              ],
              onChanged: _busy
                  ? null
                  : (value) => _save(capability, value == '' ? null : value),
            ),
          ),
        if (widget.manager.bindings.defaults.entries.any(
          (e) => _selected(e.key).isEmpty,
        ))
          const Text('存在不可用的默认实例绑定，请重新选择；没有自动替换为其他账号。'),
        const SizedBox(height: 24),
        const Text('多源搜索范围'),
        const Text(
          '范围以实例列表保存，可包含多个实例。当前四类插件仅实现浏览和解析，尚无可选搜索实例。字幕搜索等能力接入后才开放对应默认实例设置。',
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
  );
}
