import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/debug_seed/seed_template.dart';
import 'package:openplayx/capabilities/media_processing/media_processing_service.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/sources/file_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx_ffmpeg/openplayx_ffmpeg.dart';

class ProbeSources extends SourceManager {
  ProbeSources(this.plugin);
  final SmbPlugin plugin;

  @override
  Future<PlayableStream> resolve(ResourceRef ref) => plugin.resolve(
    ResolveRequest(ref),
    CallContext.forInstance(ref.instanceId),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Parent defaults < project .env < process environment. Never print values.
  final env = <String, String>{
    for (final file in [File('../.env'), File('.env')])
      if (file.existsSync()) ...parseEnv(file.readAsStringSync()),
    ...Platform.environment,
  };
  final prefixes = [
    'COVER_PROBE',
    if ((env['COVER_PROBE_2_SMB_ADDRESS'] ?? '').isNotEmpty ||
        (env['COVER_PROBE_2_MEDIA_PATH'] ?? '').isNotEmpty)
      'COVER_PROBE_2',
  ];
  final missing = [
    for (final prefix in prefixes)
      for (final field in ['SMB_ADDRESS', 'MEDIA_PATH'])
        if ((env['${prefix}_$field'] ?? '').trim().isEmpty) '${prefix}_$field',
  ];
  final skip = Platform.environment['COVER_PROBE'] != '1'
      ? 'Set COVER_PROBE=1 to enable this live SMB diagnostic.'
      : false;

  test(
    'SMB automatic cover diagnostic',
    () async {
      if (missing.isNotEmpty) {
        fail(
          'Missing configuration: ${missing.join(', ')}. '
          'See tool/source_services/cover_probe.env.example.',
        );
      }
      final defaultLibrary = Platform.isMacOS
          ? '../ffmpeg-package/build/host/libopenplayx_ffmpeg.dylib'
          : Platform.isWindows
          ? '../ffmpeg-package/build/host/openplayx_ffmpeg.dll'
          : '../ffmpeg-package/build/host/libopenplayx_ffmpeg.so';
      final library = env['COVER_PROBE_FFMPEG_LIBRARY'] ?? defaultLibrary;
      expect(
        File(library).existsSync(),
        isTrue,
        reason:
            'Build the FFmpeg host library or set COVER_PROBE_FFMPEG_LIBRARY.',
      );
      final processor = MediaProcessor(
        libraryPath: File(library).absolute.path,
      );
      addTearDown(processor.dispose);
      final output = Directory(
        env['COVER_PROBE_OUTPUT_DIR'] ??
            '${Directory.systemTemp.path}/opx-cover-probe',
      )..createSync(recursive: true);
      var failures = 0;
      for (var i = 0; i < prefixes.length; i++) {
        final prefix = prefixes[i];
        final name = 'case_${i + 1}';
        final address = env['${prefix}_SMB_ADDRESS']!.trim();
        final uri = Uri.tryParse(address);
        expect(
          uri != null &&
              uri.scheme == 'smb' &&
              uri.host.isNotEmpty &&
              uri.pathSegments.any((part) => part.isNotEmpty) &&
              uri.userInfo.isEmpty &&
              !uri.hasQuery &&
              !uri.hasFragment,
          isTrue,
          reason:
              '${prefix}_SMB_ADDRESS must be smb://host/share without credentials.',
        );
        final config = SourceConfig(
          id: name,
          kind: SourceKind.smb,
          name: name,
          address: address,
          username: env['${prefix}_SMB_USER'] ?? '',
        );
        final plugin = SmbPlugin(config, env['${prefix}_SMB_PASSWORD'] ?? '');
        final sources = ProbeSources(plugin);
        final ref = ResourceRef(name, env['${prefix}_MEDIA_PATH']!);
        try {
          final stream = await sources.resolve(ref);
          try {
            final probe = await processor.probe(stream.uri.toString());
            // ignore: avoid_print
            print(
              '$name probe: duration=${probe.duration}, container=${probe.container}',
            );
          } finally {
            await stream.release();
          }
          final bytes = await MediaProcessingService.videoCover(
            sources,
            ref,
            processor: processor,
          );
          await File('${output.path}/$name.jpg').writeAsBytes(bytes);
          // ignore: avoid_print
          print('$name COVER OK: ${bytes.length} bytes');
        } catch (error) {
          failures++;
          // Exceptions can include private URLs, paths or credentials.
          // ignore: avoid_print
          print('$name COVER FAILED: ${error.runtimeType}');
        } finally {
          await plugin.dispose();
          await sources.dispose();
        }
      }
      expect(failures, 0);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
