// Builds and delivers the debug configuration seed (see
// docs/debug_seed.md). Plain Dart, run from the openplayx directory:
//
//   dart run tool/debug_seed.dart build  [--seed debug-seed.json] [--env .env]
//   dart run tool/debug_seed.dart push   --platform macos|ios-sim|android|linux|windows
//   dart run tool/debug_seed.dart define   # prints the --dart-define argument
//
// `build` fills `${VAR}` in the seed template from .env and writes
// build/debug-seed.json; `push` copies that file into the installed App's
// support directory; `define` prints it as `--dart-define` for `flutter run`.
import 'dart:convert';
import 'dart:io';

import 'package:openplayx/app/debug_seed/seed_template.dart';

const bundleId = 'com.openplayx.openplayx';
const output = 'build/debug-seed.json';

Future<void> main(List<String> args) async {
  if (args.isEmpty) _usage();
  final options = <String, String>{};
  for (var i = 1; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--') || i + 1 >= args.length) _usage();
    options[a.substring(2)] = args[++i];
  }
  switch (args.first) {
    case 'build':
      _build(options['seed'] ?? 'debug-seed.json', options['env'] ?? '.env');
    case 'push':
      await _push(options['platform'] ?? _usage());
    case 'define':
      stdout.write(
        '--dart-define=OPENPLAYX_DEBUG_SEED='
        '${base64.encode(utf8.encode(_resolved()))}',
      );
    default:
      _usage();
  }
}

Never _usage() {
  stderr.writeln(
    'usage: dart run tool/debug_seed.dart build [--seed FILE] [--env FILE]\n'
    '       dart run tool/debug_seed.dart push --platform '
    'macos|ios-sim|android|linux|windows\n'
    '       dart run tool/debug_seed.dart define',
  );
  exit(64);
}

Never _fail(String message) {
  stderr.writeln('debug-seed: $message');
  exit(1);
}

void _build(String seedPath, String envPath) {
  final seed = File(seedPath);
  if (!seed.existsSync()) {
    _fail('$seedPath not found (start from tool/debug_seed.example.json)');
  }
  final envFile = File(envPath);
  final env = {
    ...Platform.environment,
    if (envFile.existsSync()) ...parseEnv(envFile.readAsStringSync()),
  };
  final Object? resolved;
  try {
    resolved = resolveSeed(jsonDecode(seed.readAsStringSync()), env);
  } on MissingSeedVariables catch (e) {
    _fail('$e (add them to $envPath)');
  } on FormatException catch (e) {
    _fail('$seedPath is not valid JSON: ${e.message}');
  }
  if (resolved is! Map || resolved['version'] != 1) {
    _fail('$seedPath must be an object with "version": 1');
  }
  File(output)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(resolved));
  // It holds the credentials from .env: readable by the owner only.
  if (!Platform.isWindows) Process.runSync('chmod', ['600', output]);
  stdout.writeln('debug-seed: wrote $output');
}

String _resolved() {
  final file = File(output);
  if (!file.existsSync()) _fail('$output not found; run `build` first');
  return file.readAsStringSync();
}

Future<void> _push(String platform) async {
  final text = _resolved();
  final home = Platform.environment['HOME'] ?? '';
  Future<void> copyTo(String directory) async {
    final dir = Directory(directory)..createSync(recursive: true);
    File('${dir.path}/debug-seed.json').writeAsStringSync(text);
    stdout.writeln('debug-seed: copied to ${dir.path}/debug-seed.json');
  }

  switch (platform) {
    case 'macos':
      // Debug builds are not sandboxed (DebugProfile.entitlements).
      await copyTo('$home/Library/Application Support/$bundleId');
    case 'ios-sim':
      final container = await _run('xcrun', [
        'simctl',
        'get_app_container',
        'booted',
        bundleId,
        'data',
      ]);
      await copyTo('${container.trim()}/Library/Application Support');
    case 'android':
      // Needs a debuggable build (run-as). ANDROID_SERIAL picks the device.
      const staging = '/data/local/tmp/openplayx-debug-seed.json';
      await _run('adb', ['push', output, staging]);
      await _run('adb', [
        'shell',
        'run-as $bundleId sh -c '
            "'mkdir -p files && cat $staging > files/debug-seed.json'",
      ]);
      await _run('adb', ['shell', 'rm', '-f', staging]);
      stdout.writeln('debug-seed: copied into $bundleId files/');
    case 'linux':
      final data =
          Platform.environment['XDG_DATA_HOME'] ?? '$home/.local/share';
      await copyTo('$data/$bundleId');
    case 'windows':
      final appData = Platform.environment['APPDATA'] ?? _fail('APPDATA unset');
      await copyTo('$appData\\com.openplayx\\openplayx');
    default:
      _usage();
  }
  stdout.writeln('debug-seed: it is imported on the next App start');
}

Future<String> _run(String command, List<String> args) async {
  final result = await Process.run(command, args);
  if (result.exitCode != 0) {
    _fail('$command ${args.join(' ')} failed:\n${result.stderr}');
  }
  return result.stdout as String;
}
