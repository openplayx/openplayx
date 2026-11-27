import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/assistant/plugins/library/media_tools.dart';
import 'package:openplayx/assistant/plugins/media_processing/media_processing_tools.dart';
import 'package:openplayx/assistant/plugins/speech/subtitle_tools.dart';
import 'package:openplayx/assistant/plugins/tools/tool_registry.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/media_processing/media_processing_service.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/capabilities/speech/asr_backend_config.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx/capabilities/speech/subtitle_generation_service.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/features/assistant/model/ai_chat_part.dart';
import 'package:openplayx/features/assistant/model/ai_tool_labels.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fake_media_processor.dart';

class _NoSources extends SourceManager {
  @override
  Future<void> load() async {}
}

void main() {
  group('SubtitleTools', () {
    late Directory tmp;
    late File sample;
    late LibraryService library;
    late FakeMediaProcessor processor;
    late MediaProcessingService media;
    late FakeAsrBackend fakeBackend;
    late SubtitleGenerationService subtitles;
    late MediaTools mediaTools;
    late MediaProcessingTools mpTools;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('opx_sub_tools_');
      sample = File('${tmp.path}/clip.mp4')..writeAsBytesSync([1, 2, 3]);
      library = LibraryService(sqlite3.openInMemory());
      final sources = _NoSources();
      processor = FakeMediaProcessor();
      media = MediaProcessingService(
        db: library.db,
        sources: sources,
        root: Future.value(Directory('${tmp.path}/media')),
        processor: processor,
      );
      fakeBackend = FakeAsrBackend();
      final registry = AsrBackendRegistry(
        db: library.configuration,
        models: AsrModelStore(Future.value(Directory('${tmp.path}/models'))),
        backendFactory: (_) => fakeBackend,
      );
      subtitles = SubtitleGenerationService(
        db: library.db,
        media: media,
        backends: registry,
        root: Future.value(Directory('${tmp.path}/subtitles')),
      );
      mediaTools = MediaTools(
        library: library,
        sources: sources,
        context: () => {},
        playbackSnapshot: () => {},
        playbackControl: (_, _) async => {},
        openResource: (_) async => {},
      );
      final entries = {
        'ref-clip': SourceEntry(
          ResourceRef('@local', sample.path),
          'clip.mp4',
          isFolder: false,
        ),
      };
      mpTools = MediaProcessingTools(
        registry: mediaTools.registry,
        service: media,
        library: library,
        sources: sources,
        entryForReference: (r) => entries[r],
      );
      SubtitleTools(
        registry: mediaTools.registry,
        service: subtitles,
        media: mpTools,
      );
    });

    tearDown(() {
      subtitles.dispose();
      media.dispose();
      library.close();
      tmp.deleteSync(recursive: true);
    });

    Future<Map<String, dynamic>> call(String name, Map<String, dynamic> args) =>
        ToolExecution.run(
          () => mediaTools.registry[name]!.execute(args),
          () => true,
        );

    test('status, generate, transcript, task_get, cancel and save', () async {
      final status = await call('speech_recognition_status', {});
      expect(status['available'], isTrue);

      final probe = await call('media_probe', {'resource_ref': 'ref-clip'});
      final audioRef = (probe['tracks'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((t) => t['type'] == 'audio')['track_ref'] as String;

      final gen = await call('subtitle_generate', {
        'resource_ref': 'ref-clip',
        'audio_track_ref': audioRef,
        'start_ms': 0,
        'end_ms': 5000,
        'language': 'en',
        'wait_seconds': 5,
      });
      expect(gen['status'], 'succeeded');
      expect(gen['next'], isNotNull);

      final got = await call('subtitle_task_get', {
        'task_id': gen['task_id'],
        'wait_seconds': 0,
      });
      expect(got['status'], 'succeeded');

      final savedSrt = await call('subtitle_save', {
        'task_id': gen['task_id'],
        'format': 'srt',
      });
      expect(savedSrt['format'], 'srt');

      final savedVtt = await call('subtitle_save', {
        'task_id': gen['task_id'],
        'format': 'vtt',
      });
      expect(savedVtt['format'], 'vtt');

      final tx = await call('transcript_generate', {
        'resource_ref': 'ref-clip',
        'start_ms': 5000,
        'end_ms': 10000,
        'wait_seconds': 5,
      });
      expect(tx['status'], 'succeeded');

      final cancelled = await call('subtitle_task_cancel', {
        'task_id': tx['task_id'],
      });
      expect(cancelled['status'], 'succeeded');

      // Error branches: missing end_ms when not whole_media, unavailable backend
      await expectLater(
        call('subtitle_generate', {'resource_ref': 'ref-clip', 'start_ms': 0}),
        throwsA(isA<ToolFailure>().having((e) => e.code, 'code', 'end_ms_required')),
      );

      fakeBackend.available = false;
      fakeBackend.unavailableReason = 'no_model';
      final downStatus = await call('speech_recognition_status', {});
      expect(downStatus['available'], isFalse);
      expect(downStatus['reason'], 'no_model');
      await expectLater(
        call('subtitle_generate', {
          'resource_ref': 'ref-clip',
          'start_ms': 0,
          'end_ms': 5000,
        }),
        throwsA(isA<ToolFailure>().having((e) => e.code, 'code', 'no_model')),
      );
    });
  });

  group('AiToolLabels', () {
    testWidgets('covers all tool names, arguments, phases, activity, reasoning and progress', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(AiToolLabels.tool(ctx, null), '');
      const knownTools = [
        'context_get',
        'source_list',
        'source_browse',
        'library_query',
        'media_get',
        'search_media',
        'progress_query',
        'playback_get',
        'playback_open',
        'playback_pause',
        'playback_resume',
        'playback_stop',
        'playback_seek',
        'playback_set_speed',
        'playback_set_volume',
        'playback_set_subtitle',
        'media_processing_capabilities',
        'media_probe',
        'media_transcode',
        'media_extract_audio',
        'media_snapshot',
        'external_file_save_to_source',
        'media_save_to_source',
        'task_get',
        'task_list',
        'task_cancel',
        'task_retry',
        'speech_recognition_status',
        'subtitle_generate',
        'transcript_generate',
        'subtitle_task_get',
        'subtitle_task_cancel',
        'subtitle_save',
        'plugin_status',
        'mcp_tavily_web_search',
        'web_fetch',
      ];
      for (final name in knownTools) {
        expect(AiToolLabels.tool(ctx, name), isNotEmpty, reason: name);
      }
      expect(AiToolLabels.tool(ctx, 'mcp_orrent_add_magnet'), 'Mcp Torrent add magnet');
      expect(AiToolLabels.tool(ctx, 'custom_ext_tool'), 'Custom ext tool');

      final summary = AiToolLabels.arguments(ctx, {
        'query': 'a very long query string that definitely exceeds forty characters in length',
        'url': 'https://example.com/some/very/long/path/to/test/truncation',
        'start_ms': 1000,
        'end_ms': 3665000,
        'whole_media': true,
        'time_ms': 12000,
        'position_ms': 45000,
        'preset_id': 'video.mobile.720p',
        'language': 'en',
        'format': 'srt',
        'speed': 1.5,
        'volume': 80,
        'off': true,
        'wait_seconds': 30,
      });
      expect(summary, contains('1.5x'));
      expect(summary, contains('80%'));
      expect(AiToolLabels.arguments(ctx, {'start_ms': 0}), isNotEmpty);

      for (final phase in AiToolPhase.values) {
        expect(AiToolLabels.toolStep(ctx, phase, 'Probe'), isNotEmpty);
      }
      expect(AiToolLabels.toolInput(ctx), isNotEmpty);
      expect(AiToolLabels.showAll(ctx, 120), isNotEmpty);
      expect(AiToolLabels.toolOutput(ctx), isNotEmpty);
      expect(AiToolLabels.step(ctx, 2), isNotEmpty);
      expect(AiToolLabels.stillRunning(ctx), isNotEmpty);

      for (final act in ['thinking', 'answering', 'tool', 'confirm', 'other']) {
        expect(AiToolLabels.activity(ctx, act, null), isNotEmpty);
        expect(AiToolLabels.activity(ctx, act, 'media_probe'), isNotEmpty);
      }

      expect(AiToolLabels.reasoning(ctx, streaming: true), isNotEmpty);
      expect(AiToolLabels.reasoning(ctx, streaming: false), isNotEmpty);
      expect(
        AiToolLabels.reasoning(ctx, streaming: false, duration: const Duration(milliseconds: 500)),
        isNotEmpty,
      );
      expect(
        AiToolLabels.reasoning(ctx, streaming: false, duration: const Duration(seconds: 25)),
        isNotEmpty,
      );
      expect(
        AiToolLabels.reasoning(ctx, streaming: false, duration: const Duration(minutes: 2)),
        isNotEmpty,
      );

      for (final st in ['queued', 'preparing', 'running', 'cancelling', 'succeeded', 'failed', 'cancelled', 'interrupted', 'other']) {
        expect(AiToolLabels.progress(ctx, {'status': st}), isNotEmpty);
      }
      for (final stage in ['extracting', 'uploading', 'queued', 'transcribing', 'formatting', 'custom']) {
        expect(
          AiToolLabels.progress(ctx, {
            'status': 'running',
            'stage': stage,
            'progress': 0.5,
            'processed_ms': 10000,
            'total_ms': 20000,
          }),
          contains('50%'),
        );
      }

      expect(AiToolLabels.elapsed(ctx, const Duration(seconds: 42)), '42s');
      expect(AiToolLabels.elapsed(ctx, const Duration(seconds: 125)), '2m05s');
    });
  });
}
