import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/assistant/voice/voice_service.dart';
import 'package:openplayx/assistant/voice/voice_settings.dart';
import 'package:openplayx/data/configuration/configuration_database.dart';
import 'package:openplayx/data/configuration/source_secure_store.dart';
import 'package:openplayx/features/assistant/controller/voice_input_controller.dart';
import 'package:sqlite3/sqlite3.dart';

class MemoryVoiceSecrets implements SourceSecureStore {
  final values = <String, String>{};
  bool failWrites = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('secure storage unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class FakeVoiceRecorder implements VoiceRecorder {
  @override
  bool supported = true;
  int starts = 0, stops = 0, cancellations = 0;
  Completer<void>? permission;
  bool denied = false;
  bool disposed = false;
  @override
  Future<void> start() async {
    starts++;
    await permission?.future;
    if (denied) throw const VoiceFailure('permission');
  }

  @override
  Future<Uint8List> stop() async {
    stops++;
    return Uint8List(100);
  }

  @override
  Future<void> cancel() async {
    cancellations++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class FakeVoiceTranscriber implements VoiceTranscriber {
  int calls = 0;
  bool cancelled = false, fail = false;
  Completer<String>? pending;
  @override
  Future<String> transcribe(
    VoiceConfig config,
    String key,
    Uint8List audio,
  ) async {
    calls++;
    if (fail) throw StateError('mock service failure');
    return pending == null ? 'recognized words' : await pending!.future;
  }

  @override
  void cancel() {
    cancelled = true;
  }
}

void main() {
  late Database db;
  late MemoryVoiceSecrets secrets;
  late VoiceSettings settings;
  late FakeVoiceRecorder recorder;
  late FakeVoiceTranscriber transcriber;
  late TextEditingController draft;
  late VoiceInputController controller;
  late String conversation;
  setUp(() async {
    db = sqlite3.openInMemory();
    ConfigurationDatabase.initialize(db);
    secrets = MemoryVoiceSecrets();
    settings = VoiceSettings(db, secrets: secrets);
    await settings.save(const VoiceConfig(), 'mock-voice-key');
    recorder = FakeVoiceRecorder();
    transcriber = FakeVoiceTranscriber();
    draft = TextEditingController(text: 'existing draft');
    conversation = 'first';
    controller = VoiceInputController(
      settings: settings,
      draft: draft,
      conversationId: () => conversation,
      recorder: recorder,
      transcriber: transcriber,
    );
  });
  tearDown(() {
    controller.dispose();
    draft.dispose();
    db.close();
  });

  test(
    'settings and key stay independent of chat and key stays out of SQLite',
    () async {
      ConfigurationDatabase.writeSetting(db, 'assistant', 'config', {
        'model': 'chat-model',
      });
      await settings.save(const VoiceConfig(model: 'custom-transcription'), '');
      expect(settings.load().model, 'custom-transcription');
      expect(await settings.key(), 'mock-voice-key');
      expect(ConfigurationDatabase.readSetting(db, 'assistant', 'config'), {
        'model': 'chat-model',
      });
      expect(
        db.select('SELECT value_json FROM settings').toString(),
        isNot(contains('mock-voice-key')),
      );
      expect(
        VoiceConfig.normalizeEndpoint(
          'https://api.example.com/v1/audio/transcriptions/',
        ),
        'https://api.example.com/v1',
      );
      expect(
        () =>
            const VoiceConfig(endpoint: 'http://remote.example/v1').validate(),
        throwsFormatException,
      );
      expect(
        () =>
            const VoiceConfig(endpoint: 'https://user:password@example.com/v1')
                .validate(),
        throwsFormatException,
      );
    },
  );

  test('secure storage failure does not save a new configuration', () async {
    secrets.failWrites = true;
    await expectLater(
      settings.save(const VoiceConfig(model: 'changed'), 'new-mock-key'),
      throwsStateError,
    );
    expect(settings.load().model, 'whisper-1');
  });

  test('stop appends to the latest editable draft and does not send', () async {
    await controller.toggle();
    expect(controller.state, VoiceInputState.recording);
    expect(transcriber.calls, 0);
    draft.text = 'edited during recording';
    await controller.toggle();
    expect(draft.text, 'edited during recording\nrecognized words');
    expect(draft.selection.baseOffset, draft.text.length);
    expect(controller.state, VoiceInputState.idle);
    expect(recorder.stops, 1);
  });

  test(
    'repeated clicks during permission and transcription are ignored',
    () async {
      recorder.permission = Completer<void>();
      final starting = controller.toggle();
      await Future<void>.delayed(Duration.zero);
      await controller.toggle();
      expect(recorder.starts, 1);
      recorder.permission!.complete();
      await starting;
      transcriber.pending = Completer<String>();
      final stopping = controller.toggle();
      await Future<void>.delayed(Duration.zero);
      await controller.toggle();
      expect(recorder.stops, 1);
      expect(transcriber.calls, 1);
      transcriber.pending!.complete('words');
      await stopping;
    },
  );

  test(
    'cancel while permission is pending cleans up and preserves draft',
    () async {
      recorder.permission = Completer<void>();
      final starting = controller.toggle();
      await Future<void>.delayed(Duration.zero);
      final cancelling = controller.cancel();
      recorder.permission!.complete();
      await starting;
      await cancelling;
      expect(controller.state, VoiceInputState.idle);
      expect(recorder.cancellations, 1);
      expect(transcriber.calls, 0);
      expect(draft.text, 'existing draft');
    },
  );

  test('cancel recording discards audio without transcription', () async {
    await controller.toggle();
    await controller.cancel();
    expect(recorder.cancellations, 1);
    expect(transcriber.calls, 0);
    expect(draft.text, 'existing draft');
  });

  test('cancel transcription ignores a late response', () async {
    transcriber.pending = Completer<String>();
    await controller.toggle();
    final stopping = controller.toggle();
    await Future<void>.delayed(Duration.zero);
    await controller.cancel();
    transcriber.pending!.complete('late response');
    await stopping;
    expect(transcriber.cancelled, true);
    expect(draft.text, 'existing draft');
  });

  test(
    'a response from another conversation cannot change the draft',
    () async {
      transcriber.pending = Completer<String>();
      await controller.toggle();
      final stopping = controller.toggle();
      await Future<void>.delayed(Duration.zero);
      conversation = 'second';
      draft.text = 'second draft';
      transcriber.pending!.complete('first conversation response');
      await stopping;
      expect(draft.text, 'second draft');
    },
  );

  test(
    'permission, unsupported, missing key and request failures preserve drafts',
    () async {
      recorder.denied = true;
      await controller.toggle();
      expect(controller.error, 'permission');
      recorder.denied = false;
      recorder.supported = false;
      await controller.toggle();
      expect(controller.error, 'unsupported');
      recorder.supported = true;
      secrets.values.clear();
      await controller.toggle();
      expect(controller.error, 'settings');
      await settings.save(const VoiceConfig(), 'mock');
      transcriber.fail = true;
      await controller.toggle();
      await controller.toggle();
      expect(controller.error, 'transcription');
      expect(draft.text, 'existing draft');
      expect(controller.busy, false);
    },
  );

  test('empty speech preserves draft and allows another recording', () async {
    transcriber.pending = Completer<String>()..complete('  ');
    await controller.toggle();
    await controller.toggle();
    expect(controller.error, 'empty');
    expect(draft.text, 'existing draft');
    transcriber.pending = null;
    await controller.toggle();
    await controller.toggle();
    expect(controller.error, isNull);
    expect(draft.text, 'existing draft\nrecognized words');
  });

  test(
    'OpenAI SDK sends multipart audio with independent model and bearer key',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final captured = Completer<(String, String?, String)>();
      server.listen((request) async {
        final body = await utf8.decodeStream(request);
        captured.complete((
          request.uri.path,
          request.headers.value('authorization'),
          body,
        ));
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'text': 'mock transcript'}));
        await request.response.close();
      });
      final service = OpenAiVoiceTranscriber();
      final text = await service.transcribe(
        VoiceConfig(
          endpoint: 'http://127.0.0.1:${server.port}/v1',
          model: 'mock-transcription',
        ),
        'mock-key',
        Uint8List.fromList([1, 2, 3]),
      );
      final (path, auth, body) = await captured.future;
      expect(text, 'mock transcript');
      expect(path, '/v1/audio/transcriptions');
      expect(auth, 'Bearer mock-key');
      expect(body, contains('mock-transcription'));
      expect(body, contains('voice.wav'));
    },
  );
}
