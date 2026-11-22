import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/assistant/voice/voice_service.dart';
import 'package:openplayx/assistant/voice/voice_settings.dart';

void main() {
  test(
    'connection probe sends a valid silent WAV to the transcription route',
    () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      addTearDown(() => server.close(force: true));
      final request = server.first;
      final probe = OpenAiVoiceTranscriber();
      final testing = probe.testConnection(
        VoiceConfig(
          endpoint: 'http://127.0.0.1:${server.port}/v1',
          model: 'test-whisper',
        ),
        'draft-key',
      );
      final r = await request;
      expect(r.method, 'POST');
      expect(r.uri.path, '/v1/audio/transcriptions');
      expect(r.headers.value('authorization'), 'Bearer draft-key');
      final bytes = await r.fold<List<int>>(
        [],
        (all, chunk) => all..addAll(chunk),
      );
      final body = latin1.decode(bytes);
      expect(body, contains('test-whisper'));
      final start = body.indexOf('RIFF');
      expect(start, greaterThan(0));
      final wav = Uint8List.fromList(bytes.sublist(start, start + 32044));
      expect(latin1.decode(wav.sublist(8, 12)), 'WAVE');
      expect(ByteData.sublistView(wav).getUint32(24, Endian.little), 16000);
      expect(wav.sublist(44).every((b) => b == 0), true);
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode({'text': ''}));
      await r.response.close();
      await testing; // An empty transcript is expected for silence.
    },
  );

  test('connection probe reports rejected credentials', () async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    addTearDown(() => server.close(force: true));
    server.listen((r) async {
      await r.drain<void>();
      r.response.statusCode = 401;
      r.response.headers.contentType = ContentType.json;
      r.response.write(
        jsonEncode({
          'error': {'message': 'Invalid key', 'type': 'authentication_error'},
        }),
      );
      await r.response.close();
    });
    await expectLater(
      OpenAiVoiceTranscriber().testConnection(
        VoiceConfig(endpoint: 'http://127.0.0.1:${server.port}/v1'),
        'bad-key',
      ),
      throwsA(
        isA<VoiceFailure>().having((e) => e.code, 'code', 'authentication'),
      ),
    );
  });
}
