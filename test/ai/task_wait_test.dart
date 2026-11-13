import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/services/ai_tools/media_processing_tools.dart';
import 'package:openplayx/services/ai_tools/task_wait.dart';
import 'package:openplayx/services/ai_tools/tool_registry.dart';

void main() {
  late StreamController<String> changes;
  late Map<String, dynamic> task;
  setUp(() {
    changes = StreamController<String>.broadcast();
    task = {'task_id': 't1', 'status': 'running'};
  });
  tearDown(() => changes.close());

  Future<Map<String, dynamic>> wait(int seconds) => TaskWait.until(
    taskId: 't1',
    read: () => Map.of(task),
    changes: changes.stream,
    seconds: seconds,
  );

  test('returns as soon as the task finishes', () async {
    final started = DateTime.now();
    final result = wait(60);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    task['status'] = 'succeeded';
    changes.add('t1');
    expect((await result)['status'], 'succeeded');
    expect(DateTime.now().difference(started), lessThan(seconds(2)));
  });

  test('a timed-out wait reports running, never failure', () async {
    final result = await wait(1);
    expect(result['status'], 'running');
    expect(result['wait_timed_out'], isTrue);
    expect(result['note'], contains('NOT stopped'));
  });

  test('stopping the reply ends the wait but not the task', () async {
    var active = true;
    final result = ToolExecution.run(() => wait(60), () => active);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    active = false;
    final r = await result.timeout(seconds(3));
    expect(r['status'], 'running');
    expect(changes.hasListener, isFalse);
  });

  test('wait 0 is a plain query', () async {
    final r = await wait(0);
    expect(r.containsKey('wait_timed_out'), isFalse);
  });

  test('clip names come from the source title and range only', () {
    expect(
      MediaProcessingTools.clipName(
        '/movie/Darkest Hour (2017)/Darkest.Hour.mkv',
        600000,
        660000,
        'mp4',
      ),
      'Darkest.Hour [clip 10m00s-11m00s].mp4',
    );
    expect(
      MediaProcessingTools.clipName('a:b*?.mkv', 3600000, null, 'mp4'),
      'a_b__ [clip 1h00m00s-end].mp4',
    );
  });
}

Duration seconds(int s) => Duration(seconds: s);
