import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

// Live services every integration test depends on. They are required: a
// missing define or an unreachable service fails the test, it never skips.
// `make integration-defines` writes build/integration-defines.json from
// tool/source_services/defines.local.json and .env; pass it with
// --dart-define-from-file (see integration_test/README.md).

/// Host of the tool/source_services stack (the Mac's test VM).
const sourceHost = String.fromEnvironment('SOURCE_HOST');

/// Read-write SMB share with real movies, for the assistant movie flow.
const movieSmbAddress = String.fromEnvironment('MOVIE_SMB_ADDRESS');
const movieSmbUser = String.fromEnvironment('MOVIE_SMB_USER');
const movieSmbPassword = String.fromEnvironment('MOVIE_SMB_PASSWORD');

/// OpenAI-compatible endpoint and model of the local Ollama server.
const ollamaEndpoint = String.fromEnvironment('OLLAMA_ENDPOINT');
const ollamaModel = String.fromEnvironment('OLLAMA_MODEL');

/// Host directory with the pinned whisper.cpp ggml models (ggml-tiny.bin).
const asrModelDirectory = String.fromEnvironment('ASR_MODEL_DIR');

const _hint =
    'Run `make integration-defines` and pass '
    '--dart-define-from-file=build/integration-defines.json';

/// Fails unless every named define is set.
void requireDefines(Map<String, String> defines) {
  final missing = [
    for (final e in defines.entries)
      if (e.value.isEmpty) e.key,
  ];
  if (missing.isNotEmpty) {
    fail('Missing required defines ${missing.join(', ')}. $_hint');
  }
}

/// Fails unless [host]:[port] accepts a TCP connection within 5 seconds.
Future<void> requireReachable(String what, String host, int port) async {
  try {
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 5),
    );
    socket.destroy();
  } catch (error) {
    fail('$what at $host:$port is required but unreachable: $error');
  }
}

/// Points path_provider at [directory] for this engine, so the App's
/// configuration, library, models and caches live there instead of the
/// user's data. Desktop player windows start from the same test entrypoint,
/// so calling this first in `main` covers them too.
void useAppDataDirectory(Directory directory) {
  final real = PathProviderPlatform.instance;
  if (real is _ScratchPathProvider) return;
  PathProviderPlatform.instance = _ScratchPathProvider(real, directory.path);
}

class _ScratchPathProvider extends PathProviderPlatform {
  _ScratchPathProvider(this._real, this._root);
  final PathProviderPlatform _real;
  final String _root;

  @override
  Future<String?> getApplicationSupportPath() async => _root;
  @override
  Future<String?> getApplicationDocumentsPath() async => '$_root/documents';
  @override
  Future<String?> getApplicationCachePath() async => '$_root/cache';
  @override
  Future<String?> getLibraryPath() async => '$_root/library';
  @override
  Future<String?> getTemporaryPath() => _real.getTemporaryPath();
  @override
  Future<String?> getDownloadsPath() => _real.getDownloadsPath();
}
