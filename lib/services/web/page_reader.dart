import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import 'safe_http.dart';

class WebPage {
  const WebPage({required this.url, required this.title, required this.text});
  final Uri url;
  final String title;

  /// Readable content as light Markdown.
  final String text;
}

/// Fetches a public web page and reduces it to its readable text.
///
/// The extraction is deliberately simple: drop scripts, navigation and other
/// chrome, prefer `<article>` / `<main>` when they hold real content, and
/// render headings, paragraphs, lists, links, code and tables as Markdown.
class PageReader {
  PageReader({SafeHttp? http}) : http = http ?? SafeHttp();
  final SafeHttp http;

  Future<WebPage> read(Uri url, {bool Function()? active}) async {
    final res = await http.request(url, active: active);
    if (res.status >= 400) throw WebException('http${res.status}');
    final type = res.contentType;
    final mime = type == null
        ? 'text/html'
        : '${type.primaryType}/${type.subType}';
    if (mime == 'text/plain' || mime == 'text/markdown') {
      return WebPage(url: res.url, title: '', text: res.body.trim());
    }
    if (mime != 'text/html' && mime != 'application/xhtml+xml') {
      throw const WebException('unsupportedContent');
    }
    return extract(res.body, res.url);
  }

  static const _drop =
      'script, style, noscript, template, svg, canvas, iframe, object, embed, '
      'form, button, input, select, textarea, nav, header, footer, aside, '
      'dialog, [hidden], [aria-hidden="true"], [role="navigation"], '
      '[role="banner"], [role="contentinfo"], [role="dialog"]';

  static WebPage extract(String page, Uri base) {
    final doc = html.parse(page);
    final title = _clean(
      doc.querySelector('meta[property="og:title"]')?.attributes['content'] ??
          doc.querySelector('title')?.text ??
          '',
    );
    for (final e in doc.querySelectorAll(_drop)) {
      e.remove();
    }
    final body = doc.body;
    if (body == null) return WebPage(url: base, title: title, text: '');
    Element root = body;
    for (final selector in ['article', 'main', '[role="main"]', '#content']) {
      final candidates = doc.querySelectorAll(selector);
      if (candidates.isEmpty) continue;
      candidates.sort((a, b) => b.text.length.compareTo(a.text.length));
      if (candidates.first.text.trim().length >= 200) {
        root = candidates.first;
        break;
      }
    }
    final out = _Markdown(base)..block(root);
    return WebPage(url: base, title: title, text: out.result());
  }

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _Markdown {
  _Markdown(this.base);
  final Uri base;
  final _buf = StringBuffer();
  final _line = StringBuffer();
  var _listDepth = 0;

  static const _blocks = {
    'address',
    'article',
    'blockquote',
    'dd',
    'details',
    'div',
    'dl',
    'dt',
    'figcaption',
    'figure',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'hr',
    'li',
    'main',
    'ol',
    'p',
    'pre',
    'section',
    'summary',
    'table',
    'tbody',
    'td',
    'tfoot',
    'th',
    'thead',
    'tr',
    'ul',
    'body',
  };

  void _flush() {
    final text = _line.toString().replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    _line.clear();
    if (text.isEmpty) return;
    _buf.writeln(text);
  }

  void _gap() {
    _flush();
    if (_buf.isNotEmpty && !_buf.toString().endsWith('\n\n')) _buf.writeln();
  }

  void block(Node node) {
    for (final child in node.nodes) {
      _node(child);
    }
  }

  void _node(Node node) {
    if (node is Text) {
      _line.write(node.text.replaceAll(RegExp(r'\s+'), ' '));
      return;
    }
    if (node is! Element) return;
    final tag = node.localName ?? '';
    switch (tag) {
      case 'br':
        _flush();
      case 'hr':
        _gap();
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        _gap();
        _line.write('${'#' * int.parse(tag.substring(1))} ');
        block(node);
        _gap();
      case 'pre':
        _gap();
        final code = node.text.trimRight();
        if (code.isNotEmpty) _buf.writeln('```\n$code\n```');
        _gap();
      case 'code':
        final t = node.text;
        _line.write(t.contains('\n') ? t : '`$t`');
      case 'ul' || 'ol':
        _flush();
        _listDepth++;
        var i = 0;
        for (final li in node.children.where((c) => c.localName == 'li')) {
          i++;
          _flush();
          _line.write(
            '${'  ' * (_listDepth - 1)}${tag == 'ol' ? '$i.' : '-'} ',
          );
          block(li);
          _flush();
        }
        _listDepth--;
        if (_listDepth == 0) _gap();
      case 'tr':
        _flush();
        final cells = node.children
            .where((c) => c.localName == 'td' || c.localName == 'th')
            .map((c) => c.text.replaceAll(RegExp(r'\s+'), ' ').trim())
            .toList();
        if (cells.any((c) => c.isNotEmpty)) {
          _buf.writeln('| ${cells.join(' | ')} |');
        }
      case 'img':
        final alt = node.attributes['alt']?.trim() ?? '';
        if (alt.isNotEmpty) _line.write('[图片: $alt]');
      case 'a':
        final start = _line.length;
        block(node);
        final label = _line.toString().substring(start).trim();
        final href = node.attributes['href'];
        final target = href == null ? null : _resolve(href);
        if (label.isNotEmpty && target != null) {
          final before = _line.toString().substring(0, start);
          _line
            ..clear()
            ..write('$before[$label]($target)');
        }
      case 'strong' || 'b':
        _line.write('**');
        block(node);
        _line.write('**');
      case 'blockquote':
        _gap();
        _line.write('> ');
        block(node);
        _gap();
      default:
        if (_blocks.contains(tag)) {
          if (tag == 'li' || tag == 'td' || tag == 'th') {
            block(node);
            return;
          }
          if (_listDepth > 0) {
            _flush();
          } else {
            _gap();
          }
          block(node);
          if (_listDepth > 0) {
            _flush();
          } else {
            _gap();
          }
        } else {
          block(node);
        }
    }
  }

  String? _resolve(String href) {
    final h = href.trim();
    if (h.startsWith('#') || h.isEmpty) return null;
    final uri = Uri.tryParse(h);
    if (uri == null) return null;
    final abs = base.resolveUri(uri);
    if (!abs.isScheme('http') && !abs.isScheme('https')) return null;
    return abs.toString();
  }

  String result() {
    _flush();
    return _buf
        .toString()
        .replaceAll(RegExp(r'\*\*\s*\*\*'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
