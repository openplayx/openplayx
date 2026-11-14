import 'package:flutter/widgets.dart';

import '../../core/ai/page_context.dart';
export '../../core/ai/page_context.dart';

/// A page-owned context source, shared by standard and custom page layouts.
/// Keep a reference to [PageContextSource.read] when opening the assistant:
/// rebuilds update it, and disposal freezes the last exported snapshot.
class PageContextSource {
  PageContextSource(PageContextData data) : _snapshot = data.toJson();
  Map<String, dynamic> _snapshot;

  void update(PageContextData data) => _snapshot = data.toJson();

  Map<String, dynamic> read() => {
    ..._snapshot,
    // Return fresh nested JSON so a consumer cannot mutate the source.
    'entity': _copy(_snapshot['entity']),
    'state': _copy(_snapshot['state']),
  };

  static dynamic _copy(dynamic value) => switch (value) {
    Map<String, dynamic> map => map.map(
      (key, value) => MapEntry(key, _copy(value)),
    ),
    List list => list.map(_copy).toList(),
    _ => value,
  };
}

class PageContextScope extends StatefulWidget {
  const PageContextScope({super.key, required this.data, required this.child});
  final PageContextData data;
  final Widget child;

  static PageContextSource? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_PageContextInherited>()
      ?.source;

  @override
  State<PageContextScope> createState() => _PageContextScopeState();
}

class _PageContextScopeState extends State<PageContextScope> {
  late final source = PageContextSource(widget.data);

  @override
  void didUpdateWidget(PageContextScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    source.update(widget.data);
  }

  @override
  Widget build(BuildContext context) =>
      _PageContextInherited(source: source, child: widget.child);
}

class _PageContextInherited extends InheritedWidget {
  const _PageContextInherited({required this.source, required super.child});
  final PageContextSource source;

  @override
  bool updateShouldNotify(_PageContextInherited oldWidget) =>
      source != oldWidget.source;
}
