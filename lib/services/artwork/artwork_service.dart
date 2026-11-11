import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/plugins/metadata_capability.dart';
import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_manager.dart';

/// Host-controlled, bounded artwork fetching. Cache removal never changes
/// logical artwork selections. No credentials or arbitrary NFO URLs are used.
class ArtworkService {
  ArtworkService(
    this.sources, {
    Directory? directory,
    this.retainedArtwork,
    this.cacheQuotaBytes = 256 * 1024 * 1024,
  })
    // ignore: prefer_initializing_formals
    : _directory = directory;
  final List<ArtworkDescriptor> Function()? retainedArtwork;
  final int cacheQuotaBytes;
  Future<void> _writeTail = Future.value();
  final SourceManager sources;
  Directory? _directory;
  final _pending = <String, Future<File>>{};
  final _waiters = <Completer<void>>[];
  final _client = HttpClient();
  int _active = 0;
  bool _closed = false;
  static const maxBytes = 20 * 1024 * 1024;
  Future<Directory> _root() async => _directory ??= Directory(
    '${(await getApplicationCacheDirectory()).path}/artwork',
  );
  Future<File> load(ArtworkDescriptor artwork) {
    final key = cacheKey(artwork);
    return _pending[key] ??= _load(key, artwork).whenComplete(() {
      _pending.remove(key);
    });
  }

  String cacheKey(ArtworkDescriptor artwork) {
    final revision = sources.configs
        .where((c) => c.id == artwork.source?.instanceId)
        .firstOrNull
        ?.revision;
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              artwork.id,
              revision,
              artwork.remote?.toString(),
              artwork.source?.instanceId,
              artwork.source?.id,
            ]),
          ),
        )
        .toString();
  }

  Future<void> _makeRoom(Directory directory, int incoming) async {
    final entries = <(File, int, DateTime)>[];
    var total = 0;
    await for (final file in directory.list()) {
      if (file is! File || file.path.endsWith('.tmp')) continue;
      final stat = await file.stat();
      total += stat.size;
      entries.add((file, stat.size, stat.modified));
    }
    if (_closed) throw const PluginException('cancelled', '图片加载已取消');
    final retained = (retainedArtwork?.call() ?? []).map(cacheKey).toSet();
    entries.sort((a, b) => a.$3.compareTo(b.$3));
    for (final entry in entries) {
      if (total + incoming <= cacheQuotaBytes) break;
      if (retained.contains(entry.$1.uri.pathSegments.last)) continue;
      await entry.$1.delete();
      total -= entry.$2;
    }
    if (total + incoming > cacheQuotaBytes) {
      throw const PluginException('quotaExceeded', '图片缓存额度不足');
    }
  }

  Future<File> _publish(File temporary, File file, int length) {
    final previous = _writeTail;
    final operation = (() async {
      await previous;
      await _makeRoom(file.parent, length);
      if (_closed) throw const PluginException('cancelled', '图片加载已取消');
      return temporary.rename(file.path);
    })();
    _writeTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<File> _load(String key, ArtworkDescriptor artwork) async {
    if (_closed) throw const PluginException('cancelled', '图片加载已取消');
    final dir = await _root();
    await dir.create(recursive: true);
    final file = File('${dir.path}/$key');
    if (await file.exists()) return file;
    while (_active >= 2 && !_closed) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    if (_closed) throw const PluginException('cancelled', '图片加载已取消');
    _active++;
    File? temporary;
    try {
      final List<int> bytes;
      if (artwork.source != null) {
        bytes = await sources.readAttachment(
          artwork.source!,
          maxBytes: maxBytes,
        );
      } else {
        final uri = artwork.remote;
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host != 'image.tmdb.org' ||
            uri.userInfo.isNotEmpty ||
            uri.hasQuery ||
            uri.hasFragment ||
            (uri.hasPort && uri.port != 443)) {
          throw const PluginException('permissionDenied', '图片地址未经授权');
        }
        bytes = await (() async {
          final request = await _client.getUrl(uri);
          request.followRedirects = false;
          final response = await request.close();
          if (response.statusCode != 200 ||
              ![
                'image/jpeg',
                'image/png',
                'image/webp',
              ].contains(response.headers.contentType?.mimeType) ||
              response.contentLength > maxBytes) {
            throw const PluginException('invalidArtwork', '图片类型或大小无效');
          }
          final data = <int>[];
          await for (final chunk in response) {
            if (data.length + chunk.length > maxBytes) {
              throw const PluginException('quotaExceeded', '图片过大');
            }
            data.addAll(chunk);
          }
          return data;
        })().timeout(const Duration(seconds: 20));
      }
      if (bytes.isEmpty || bytes.length > maxBytes) {
        throw const PluginException('invalidArtwork', '图片为空或过大');
      }
      final png =
          bytes.length >= 8 &&
          bytes.take(8).join(',') == '137,80,78,71,13,10,26,10';
      final jpeg =
          bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      final webp =
          bytes.length >= 12 &&
          ascii.decode(bytes.take(4).toList(), allowInvalid: true) == 'RIFF' &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
      if (!png && !jpeg && !webp) {
        throw const PluginException('invalidArtwork', '不支持的图片内容类型');
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        Uint8List.fromList(bytes),
      );
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          if (descriptor.width > 12000 ||
              descriptor.height > 12000 ||
              descriptor.width * descriptor.height > 40000000) {
            throw const PluginException('quotaExceeded', '图片解码尺寸过大');
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
      if (_closed) throw const PluginException('cancelled', '图片加载已取消');
      temporary = File(
        '${file.path}.${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}.tmp',
      );
      await temporary.writeAsBytes(bytes, flush: true);
      return await _publish(temporary, file, bytes.length);
    } finally {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete();
      }
      _active--;
      if (_waiters.isNotEmpty) _waiters.removeAt(0).complete();
    }
  }

  Future<void> clear() async {
    // Caller disables clearing while loads are active. The DB retains choices.
    if (_pending.isNotEmpty) {
      throw const PluginException('conflict', '请等待图片加载完成');
    }
    final dir = await _root();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  void dispose() {
    _closed = true;
    _client.close(force: true);
    for (final w in _waiters) {
      w.complete();
    }
    _waiters.clear();
  }
}
