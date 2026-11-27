import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

import '../../../capabilities/subtitles/subtitle_alignment.dart';
import '../../../data/storage/app_directories.dart';
import '../model/subtitle_state.dart';
import 'subtitle_controller.dart';

enum AlignmentPhase { idle, reading, matching, result, review, failed }

AlignmentResult _align((String, String, int) input) =>
    alignReference(input.$1, input.$2, input.$3);

/// Session state independent of the panel lifetime. Files are local only;
/// generated copies live in application support because the player's saved
/// subtitle choice can refer to them after this session ends.
class SubtitleAlignmentController extends ChangeNotifier {
  SubtitleAlignmentController({
    required this.subtitles,
    required this.duration,
    this.outputDirectory = appSupportDirectory,
  }) {
    subtitles.addListener(_selectionChanged);
  }
  final SubtitleController subtitles;
  final Duration Function() duration;
  final Future<Directory> Function() outputDirectory;
  AlignmentPhase phase = AlignmentPhase.idle;
  AlignmentResult? result;
  Uri? reference;
  String? error;
  bool changing = false, applied = false, previewing = false;
  final List<DateTime> history = [];
  final List<(DateTime, Duration)> manualHistory = [];
  Duration? manualBefore, manualAfter;
  int get generation => _generation;
  bool get canRestoreManual =>
      manualBefore != null &&
      manualAfter == subtitles.state.delay &&
      !changing &&
      !running &&
      !previewing &&
      !applied;
  String? _sourceKey, _outputKey;
  Uri? _output, _sourceFile;
  String? _sourceDigest;
  Duration? _originalDelay;
  int _generation = 0;
  bool _disposed = false;

  bool get running =>
      phase == AlignmentPhase.reading || phase == AlignmentPhase.matching;
  bool get sourceUnchanged =>
      subtitles.state.selected?.key == _sourceKey ||
      (_outputKey != null && subtitles.state.selected?.key == _outputKey);
  bool get canApply =>
      result?.safe == true && sourceUnchanged && !changing && !running;
  bool get canUndo => (previewing || applied) && sourceUnchanged && !changing;
  static Uri? fileOf(SubtitleOption? option) => switch (option?.source) {
    ExternalSubtitle(:final file) when file.scheme == 'file' => file,
    RecognizedSubtitleSource(:final saved)
        when saved.format.toLowerCase() == 'srt' =>
      Uri.file(saved.path),
    _ => null,
  };

  void _selectionChanged() {
    if (_disposed || changing) return;
    if ((previewing || applied) &&
        subtitles.state.selected?.key != _outputKey) {
      previewing = false;
      applied = false;
      _originalDelay = null;
      _publish();
    }
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  bool _stale(int token) => _disposed || token != _generation;

  void setReference(Uri file) {
    if (running || changing || previewing || applied) return;
    reference = file;
    result = null;
    error = null;
    phase = AlignmentPhase.idle;
    _publish();
  }

  static Future<String> _read(Uri uri) async {
    if (uri.scheme != 'file' || !uri.path.toLowerCase().endsWith('.srt')) {
      throw const FormatException('unsupported');
    }
    const limit = 4 * 1024 * 1024;
    final bytes = await File.fromUri(uri)
        .openRead(0, limit + 1)
        .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
    if (bytes.length > limit) throw const FormatException('too_large');
    return utf8.decode(bytes);
  }

  Future<void> start() async {
    if (running || changing || previewing || applied) return;
    final selected = subtitles.state.selected, ref = reference;
    final source = fileOf(selected);
    if (source == null || ref == null || source == ref) {
      error = 'choose_files';
      phase = AlignmentPhase.failed;
      _publish();
      return;
    }
    final token = ++_generation;
    _sourceKey = selected!.key;
    _sourceFile = source;
    _sourceDigest = null;
    _output = null;
    _outputKey = null;
    result = null;
    error = null;
    phase = AlignmentPhase.reading;
    _publish();
    try {
      final texts = await Future.wait([_read(source), _read(ref)])
          .timeout(const Duration(seconds: 10));
      if (_stale(token)) return;
      _sourceDigest = sha256.convert(utf8.encode(texts[0])).toString();
      phase = AlignmentPhase.matching;
      _publish();
      final candidate = await compute(_align, (
        texts[0],
        texts[1],
        duration().inMilliseconds,
      )).timeout(const Duration(seconds: 15));
      if (_stale(token)) return;
      result = candidate;
      phase = candidate.safe ? AlignmentPhase.result : AlignmentPhase.review;
    } on FormatException catch (e) {
      if (_stale(token)) return;
      error = e.message;
      phase = AlignmentPhase.failed;
    } catch (_) {
      if (_stale(token)) return;
      error = 'read_failed';
      phase = AlignmentPhase.failed;
    }
    _publish();
  }

  void cancel() {
    if (!running) return;
    ++_generation;
    phase = AlignmentPhase.idle;
    error = null;
    _publish();
  }

  /// Preview is an explicit player operation, reversible independently of
  /// acceptance. Reopening a panel must never start or restart this operation.
  Future<bool> useCandidate({bool accept = false}) async {
    if (!canApply) return false;
    final token = _generation;
    changing = true;
    error = null;
    _publish();
    final originalKey = _sourceKey!, delay = subtitles.state.delay;
    try {
      final currentText = await _read(_sourceFile!)
          .timeout(const Duration(seconds: 10));
      if (_stale(token) || !sourceUnchanged) return false;
      if (sha256.convert(utf8.encode(currentText)).toString() !=
          _sourceDigest) {
        error = 'source_changed';
        return false;
      }
      if (previewing || applied) {
        if (accept && !applied) {
          applied = true;
          previewing = false;
          history.add(DateTime.now());
        }
        return true;
      }
      var output = _output;
      if (output == null) {
        final root = await outputDirectory();
        final folder = await Directory('${root.path}/subtitle-alignments')
            .create(recursive: true);
        final run = await folder.createTemp('alignment-');
        final file = File(
          '${run.path}/aligned-${DateTime.now().microsecondsSinceEpoch}.srt',
        );
        await file.writeAsString(
          result!.source.export(result!.mapping),
          flush: true,
        );
        output = file.uri;
      }
      if (_stale(token) || !sourceUnchanged) return false;
      _output = output;
      _outputKey = SubtitleOption.externalKey(output);
      _originalDelay = delay;
      if (!await subtitles.addFile(output)) {
        error = 'apply_failed';
        return false;
      }
      if (_stale(token) || subtitles.state.selected?.key != _outputKey) {
        return false;
      }
      // Timeline is absolute; do not add the old manual delay a second time.
      if (delay != Duration.zero && !await subtitles.setDelay(Duration.zero)) {
        await subtitles.choose(originalKey);
        error = 'apply_failed';
        return false;
      }
      if (_stale(token)) return false;
      applied = accept;
      previewing = !accept;
      if (accept) history.add(DateTime.now());
      return true;
    } catch (_) {
      if (!_stale(token)) error = 'apply_failed';
      return false;
    } finally {
      if (!_stale(token)) {
        changing = false;
        _selectionChanged();
        _publish();
      }
    }
  }

  Future<bool> restore() async {
    if (!canUndo) return false;
    final token = _generation;
    changing = true;
    _publish();
    try {
      if (!await subtitles.choose(_sourceKey!)) {
        error = 'apply_failed';
        return false;
      }
      if (_stale(token)) return false;
      if (_originalDelay case final delay?) {
        if (!await subtitles.setDelay(delay) && delay != Duration.zero) {
          error = 'apply_failed';
          return false;
        }
      }
      if (_stale(token)) return false;
      previewing = false;
      applied = false;
      error = null;
      return true;
    } finally {
      if (!_stale(token)) {
        changing = false;
        _selectionChanged();
        _publish();
      }
    }
  }

  Future<bool> setManualDelay(Duration value) async {
    if (running || changing || previewing || applied) return false;
    final token = _generation;
    if (manualAfter != subtitles.state.delay) {
      manualBefore = subtitles.state.delay;
    }
    changing = true;
    error = null;
    _publish();
    try {
      if (!await subtitles.setDelay(value) || _stale(token)) return false;
      manualAfter = value;
      manualHistory.add((DateTime.now(), value));
      if (manualHistory.length > 100) manualHistory.removeAt(0);
      return true;
    } finally {
      if (!_stale(token)) {
        changing = false;
        _publish();
      }
    }
  }

  Future<bool> restoreManual() async {
    if (!canRestoreManual) return false;
    final restored = await setManualDelay(manualBefore!);
    if (restored) {
      manualBefore = null;
      manualAfter = null;
      _publish();
    }
    return restored;
  }

  void reset() {
    ++_generation;
    phase = AlignmentPhase.idle;
    result = null;
    reference = null;
    error = null;
    changing = false;
    applied = false;
    previewing = false;
    _sourceKey = null;
    _outputKey = null;
    _output = null;
    _sourceFile = null;
    _sourceDigest = null;
    _originalDelay = null;
    history.clear();
    manualHistory.clear();
    manualBefore = null;
    manualAfter = null;
    _publish();
  }

  @override
  void dispose() {
    subtitles.removeListener(_selectionChanged);
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
