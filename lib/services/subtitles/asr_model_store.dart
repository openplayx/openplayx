import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// `<application support>/asr_models`; null where unavailable (tests).
Future<Directory?> asrModelRoot() async {
  try {
    return Directory(
      '${(await getApplicationSupportDirectory()).path}/asr_models',
    );
  } catch (_) {
    return null;
  }
}

/// A pinned whisper.cpp (ggml) model file: id, checksum, size and licence
/// are fixed here; the runtime engine is pinned separately.
class AsrModelSpec {
  const AsrModelSpec({
    required this.id,
    required this.file,
    required this.bytes,
    required this.sha256,
    required this.label,
  });
  final String id;
  final String file;
  final int bytes;
  final String sha256;
  final String label;

  /// Every catalogue entry is multilingual: Chinese needs it (`.en` models
  /// are English-only and are deliberately not offered).
  bool get multilingual => true;
  String get license => 'MIT (OpenAI Whisper weights)';
  String get revision => sha256.substring(0, 12);
  Uri get url => Uri.parse(
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$file',
  );
}

const asrModelCatalog = [
  AsrModelSpec(
    id: 'whisper-tiny-multilingual',
    file: 'ggml-tiny.bin',
    bytes: 77691713,
    sha256: 'be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21',
    label: 'Whisper tiny',
  ),
  AsrModelSpec(
    id: 'whisper-base-multilingual',
    file: 'ggml-base.bin',
    bytes: 147951465,
    sha256: '60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe',
    label: 'Whisper base',
  ),
  AsrModelSpec(
    id: 'whisper-base-multilingual-q5_1',
    file: 'ggml-base-q5_1.bin',
    bytes: 59707625,
    sha256: '422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898',
    label: 'Whisper base (q5_1)',
  ),
  AsrModelSpec(
    id: 'whisper-small-multilingual',
    file: 'ggml-small.bin',
    bytes: 487601967,
    sha256: '1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b',
    label: 'Whisper small',
  ),
  AsrModelSpec(
    id: 'whisper-small-multilingual-q5_1',
    file: 'ggml-small-q5_1.bin',
    bytes: 190085487,
    sha256: 'ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb',
    label: 'Whisper small (q5_1)',
  ),
];

AsrModelSpec? asrModelSpec(String id) =>
    asrModelCatalog.where((m) => m.id == id).firstOrNull;

class AsrModelDownload {
  AsrModelDownload._(this.spec);
  final AsrModelSpec spec;
  final _progress = StreamController<int>.broadcast();
  final _done = Completer<void>();
  bool _cancelled = false;
  HttpClientRequest? _request;

  /// Bytes received so far (total is [AsrModelSpec.bytes]).
  Stream<int> get progress => _progress.stream;
  Future<void> get done => _done.future;

  void cancel() {
    _cancelled = true;
    _request?.abort();
  }
}

/// Installed models live in an app-private directory with a manifest. A
/// file is only enabled after its size and SHA-256 match the catalogue.
/// Nothing is downloaded unless [download] is called by an explicit action.
class AsrModelStore {
  AsrModelStore(this.root, {HttpClient Function()? client})
    : _client = client ?? HttpClient.new;
  final Future<Directory?> root;
  final HttpClient Function() _client;
  final _downloads = <String, AsrModelDownload>{};

  Future<Directory> _dir() async {
    final dir = await root;
    if (dir == null) throw const FileSystemException('unavailable');
    return dir.create(recursive: true);
  }

  Future<File> _manifest() async => File('${(await _dir()).path}/models.json');

  Future<Map<String, dynamic>> _read() async {
    try {
      final f = await _manifest();
      if (!await f.exists()) return {};
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, dynamic> m) async {
    final f = await _manifest();
    final tmp = File('${f.path}.part');
    await tmp.writeAsString(jsonEncode(m));
    await tmp.rename(f.path);
  }

  /// Installed + verified model ids.
  Future<Set<String>> installed() async {
    final m = await _read();
    final dir = await root;
    if (dir == null) return {};
    return {
      for (final id in m.keys)
        if (asrModelSpec(id) != null &&
            File('${dir.path}/${asrModelSpec(id)!.file}').existsSync())
          id,
    };
  }

  /// Absolute path of a verified model, or null when not installed.
  Future<String?> path(String id) async {
    final spec = asrModelSpec(id);
    if (spec == null || !(await installed()).contains(id)) return null;
    return '${(await _dir()).path}/${spec.file}';
  }

  AsrModelDownload? activeDownload(String id) => _downloads[id];

  static Future<String> sha256File(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  /// Downloads one catalogue model with progress and cancellation; the
  /// file becomes visible only after verification.
  AsrModelDownload download(String id) {
    final existing = _downloads[id];
    if (existing != null) return existing;
    final spec = asrModelSpec(id);
    if (spec == null) throw ArgumentError.value(id, 'id');
    final d = _downloads[id] = AsrModelDownload._(spec);
    unawaited(() async {
      final client = _client();
      File? part;
      try {
        final dir = await _dir();
        part = File('${dir.path}/${spec.file}.part');
        final request = d._request = await client.getUrl(spec.url);
        if (d._cancelled) throw const _Cancelled();
        final response = await request.close();
        if (response.statusCode != 200) {
          throw HttpException('status ${response.statusCode}');
        }
        final sink = part.openWrite();
        var received = 0;
        try {
          await for (final chunk in response) {
            if (d._cancelled) throw const _Cancelled();
            sink.add(chunk);
            received += chunk.length;
            if (received > spec.bytes) throw const FormatException('size');
            d._progress.add(received);
          }
        } finally {
          await sink.close();
        }
        await _install(spec, part);
        d._done.complete();
      } catch (e) {
        try {
          if (part != null && await part.exists()) await part.delete();
        } catch (_) {}
        d._done.completeError(e is _Cancelled ? const AsrModelCancelled() : e);
      } finally {
        client.close(force: true);
        _downloads.remove(id);
        unawaited(d._progress.close());
      }
    }());
    return d;
  }

  /// Imports a model file the user picked; it must match a catalogue entry.
  Future<AsrModelSpec> import(File file) async {
    final length = await file.length();
    final candidates = asrModelCatalog.where((m) => m.bytes == length);
    if (candidates.isEmpty) throw const FormatException('unknown_model');
    final digest = await sha256File(file);
    final spec = candidates.where((m) => m.sha256 == digest).firstOrNull;
    if (spec == null) throw const FormatException('checksum_mismatch');
    final dir = await _dir();
    final part = await file.copy('${dir.path}/${spec.file}.part');
    await _install(spec, part, digest: digest);
    return spec;
  }

  Future<void> _install(AsrModelSpec spec, File part, {String? digest}) async {
    if (await part.length() != spec.bytes) {
      throw const FormatException('size_mismatch');
    }
    if ((digest ?? await sha256File(part)) != spec.sha256) {
      throw const FormatException('checksum_mismatch');
    }
    final dir = await _dir();
    await part.rename('${dir.path}/${spec.file}');
    final m = await _read();
    m[spec.id] = {
      'file': spec.file,
      'sha256': spec.sha256,
      'bytes': spec.bytes,
      'license': spec.license,
      'verified_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _write(m);
  }

  Future<void> remove(String id) async {
    final spec = asrModelSpec(id);
    if (spec == null) return;
    final dir = await _dir();
    final m = await _read()
      ..remove(id);
    await _write(m);
    final f = File('${dir.path}/${spec.file}');
    if (await f.exists()) await f.delete();
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

class AsrModelCancelled implements Exception {
  const AsrModelCancelled();
}
