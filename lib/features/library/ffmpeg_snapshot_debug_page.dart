import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/plugins/source_capability.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/media_processing/media_processing_service.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/tokens/app_spacing.dart';

/// Debug-only page (design §9.1): one random frame from 20%–80% of the
/// current video through the in-process FFmpeg path. No playback, LLM or
/// artwork change; the image is temporary and deleted on leave.
class FfmpegSnapshotDebugPage extends StatefulWidget {
  const FfmpegSnapshotDebugPage({
    super.key,
    required this.service,
    required this.resource,
    required this.title,
  });
  final MediaProcessingService? service;
  final ResourceRef resource;
  final String title;

  @override
  State<FfmpegSnapshotDebugPage> createState() =>
      _FfmpegSnapshotDebugPageState();
}

class _FfmpegSnapshotDebugPageState extends State<FfmpegSnapshotDebugPage> {
  DebugSnapshot? _snapshot;
  DebugSnapshotResult? _result;
  Uint8List? _bytes; // decoded from memory: deleting the file cannot race
  String? _error;

  bool get _running => _snapshot != null && _result == null && _error == null;

  @override
  void initState() {
    super.initState();
    _take();
  }

  @override
  void dispose() {
    // Leaving cancels unfinished work and deletes the temporary image.
    _snapshot?.dispose();
    super.dispose();
  }

  Future<void> _take() async {
    final service = widget.service;
    if (service == null || !service.available) {
      setState(() => _error = 'unavailable');
      return;
    }
    final previous = _snapshot;
    final snapshot = service.debugSnapshot(widget.resource);
    setState(() {
      _snapshot = snapshot;
      _result = null;
      _error = null;
    });
    await previous?.dispose();
    try {
      final result = await snapshot.result;
      final bytes = await result.file.readAsBytes();
      if (mounted && _snapshot == snapshot) {
        setState(() {
          _result = result;
          _bytes = bytes;
        });
      }
    } on MediaException catch (e) {
      if (mounted && _snapshot == snapshot) {
        setState(
          () => _error = e.reason == null
              ? e.code.name
              : '${e.code.name}: ${e.reason}',
        );
      }
    } catch (_) {
      if (mounted && _snapshot == snapshot) {
        setState(() => _error = MediaErrorCode.nativeFailure.name);
      }
    }
  }

  static String _clock(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}.$ms';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final result = _result;
    final Widget content;
    if (_error == 'unavailable') {
      content = Text(l.ffmpegUnavailable, style: theme.textTheme.muted);
    } else if (_error != null) {
      content = Text(
        l.ffmpegSnapshotFailed(_error!),
        key: const ValueKey('ffmpeg-snapshot-error'),
        style: theme.textTheme.muted,
      );
    } else if (result == null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l.loading),
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.ffmpegSnapshotAt(_clock(result.time), _clock(result.duration)),
            key: const ValueKey('ffmpeg-snapshot-time'),
            style: theme.textTheme.small,
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _bytes!,
                key: ValueKey(result.file.path),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      );
    }
    return AppPage(
      title: Text(l.ffmpegSnapshotDebug),
      trailing: [
        ShadButton.outline(
          key: const ValueKey('ffmpeg-snapshot-again'),
          onPressed: _running || _error == 'unavailable' ? null : _take,
          child: Text(_error != null ? l.retry : l.ffmpegSnapshotAgain),
        ),
      ],
      body: Padding(
        padding: AppSpacing.page(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.textTheme.muted, maxLines: 1),
            const SizedBox(height: AppSpacing.md),
            Expanded(child: Center(child: content)),
          ],
        ),
      ),
    );
  }
}
