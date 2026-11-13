import 'dart:async';
import 'dart:math';

import 'tool_registry.dart';

/// Bounded synchronous wait over a background task. The task itself always
/// keeps running in its service: a wait that times out, or a user who stops
/// the reply, only ends the wait — never the work.
abstract final class TaskWait {
  /// Longest wait one tool call may hold.
  static const maxSeconds = 120;

  /// Default wait of submit tools, so a short job finishes in one call.
  static const defaultSeconds = 90;

  /// Gateway timeout for tools that wait (wait + margin).
  static const toolTimeout = Duration(seconds: maxSeconds + 15);

  static const field = ToolField('integer', minimum: 0, maximum: maxSeconds);

  static const _terminal = {'succeeded', 'failed', 'cancelled', 'interrupted'};
  static bool terminal(Map<String, dynamic> task) =>
      _terminal.contains(task['status']);

  /// Re-reads [read] whenever [changes] reports [taskId] (and at least every
  /// second) until the task is terminal, [seconds] elapse or the host turn is
  /// no longer active. The result says whether the wait timed out.
  static Future<Map<String, dynamic>> until({
    required String taskId,
    required Map<String, dynamic>? Function() read,
    required Stream<String> changes,
    required int seconds,
  }) async {
    var task = read() ?? (throw const ToolFailure('notFound'));
    final wait = seconds.clamp(0, maxSeconds);
    final deadline = DateTime.now().add(Duration(seconds: wait));
    Completer<void>? wake;
    final subscription = changes.listen((id) {
      final w = wake;
      if (id == taskId && w != null && !w.isCompleted) w.complete();
    }, onError: (Object _) {});
    try {
      void report() => ToolExecution.report({
        for (final k in const [
          'status',
          'stage',
          'progress',
          'processed_ms',
          'total_ms',
          'resource_name',
        ])
          if (task[k] != null) k: task[k],
      });
      report();
      while (!terminal(task) && ToolExecution.active) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) break;
        final w = wake = Completer<void>();
        // Wakes on the task's change event, or after at most a second to
        // notice the user stopping the reply.
        await w.future.timeout(
          Duration(milliseconds: min(1000, remaining.inMilliseconds)),
          onTimeout: () {},
        );
        task = read() ?? task;
        report();
      }
    } finally {
      await subscription.cancel();
    }
    if (terminal(task) || wait == 0) return task;
    return {
      ...task,
      'wait_timed_out': true,
      'waited_seconds': wait,
      'note':
          'Still running in the background; it was NOT stopped and has NOT failed. '
          'Tell the user the current progress and stop. When the user asks again, '
          'call the task query tool with wait_seconds to keep waiting. '
          'Repeating the same request re-attaches to this task instead of starting a new one.',
    };
  }
}
