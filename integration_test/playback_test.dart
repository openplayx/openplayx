import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx_playback/playback.dart';

import 'support/test_video.dart';

void main() {
  // 初始化集成测试环境，让测试运行在真正的应用和原生插件环境中。
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native VLC decodes video, pauses, seeks, reopens and releases', (
    tester,
  ) async {
    // 1. 在应用可访问的临时目录中准备测试视频。
    // createTestVideo 将仓库中的无声 MP4 素材复制到该目录，不依赖网络或用户文件。
    final directory = await Directory.systemTemp.createTemp('openplayx-vlc-');
    final file = await createTestVideo(directory);

    // 2. 创建真正的 libVLC 播放后端，并打印状态、进度和时长，方便排查失败。
    final backend = LibVlcBackend();
    backend.addListener(
      () => debugPrint(
        'VLC test: ${backend.value.status} ${backend.value.position} ${backend.value.duration}',
      ),
    );
    // 无论测试通过还是中途失败，都尝试释放播放器并删除临时文件。
    // 后端允许重复调用 dispose，避免与后续清理发生冲突。
    addTearDown(() async {
      backend.dispose();
      await directory.delete(recursive: true);
    });

    // 等待原生播放器的异步事件：每隔约 100 毫秒处理一帧并检查条件，
    // 最多检查 150 次（约 15 秒，不含额外调度耗时）；超时则打印当前状态并使测试失败。
    Future<void> waitFor(bool Function() condition) async {
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (condition()) return;
      }
      fail(
        'Timed out: ${backend.value.status}, ${backend.value.position}, ${backend.value.videoSize}',
      );
    }

    // 3. 将视频组件挂载到真实应用中，使其创建原生视频视图并绑定播放后端。
    // 这里不使用带后台暂停策略的 PlayerPage：macOS 测试窗口未必能切到前台，
    // 避免窗口前后台状态干扰对原生播放引擎的验证。
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlayerVideoView(backend: backend)),
      ),
    );
    // 给原生视图约一秒的创建时间，然后打开测试视频（后端默认自动播放）。
    await tester.pump(const Duration(seconds: 1));
    await backend.open(file.uri);
    // 4. 等待进入播放状态、进度超过 0.5 秒且取得视频尺寸。
    // 这样可以确认原生层已经开始处理视频，而不只是 open 方法成功返回。
    await waitFor(
      () =>
          backend.value.status == PlaybackStatus.playing &&
          backend.value.position > const Duration(milliseconds: 500) &&
          backend.value.videoSize != null,
    );
    // 素材约 12 秒、尺寸为 160×90；时长检查预留原生读取和取整差异。
    expect(backend.value.duration.inSeconds, inInclusiveRange(11, 13));
    expect(backend.value.videoSize, const Size(160, 90));

    // Input-byte statistics are sampled independently of playback progress.
    await waitFor(() => backend.value.readSpeedMBps != null);
    expect(backend.value.readSpeedMBps, greaterThanOrEqualTo(0));

    // Confirm adjustments through native events, not just method completion.
    await backend.setSpeed(1.5);
    await waitFor(() => (backend.value.speed - 1.5).abs() < 0.01);
    await backend.setVolume(40);
    await waitFor(() => backend.value.volume == 40);
    await backend.setSpeed(1);
    await waitFor(() => (backend.value.speed - 1).abs() < 0.01);
    await backend.setVolume(100);
    // This fixture is silent; track discovery must still be safe.
    final tracks = await backend.getAudioTracks();
    expect(tracks.where((track) => track.id >= 0), isEmpty);

    // 5. 请求暂停，并等待原生事件确认暂停状态。
    await backend.pause();
    await waitFor(() => backend.value.status == PlaybackStatus.paused);
    // 6. 确认媒体支持跳转，跳到第 7 秒后继续播放。
    // 等待进度达到至少第 6 秒，给原生 Seek 的定位和事件上报预留余量。
    expect(backend.value.canSeek, isTrue);
    await backend.seek(const Duration(seconds: 7));
    await backend.play();
    await waitFor(() => backend.value.position >= const Duration(seconds: 6));
    // 7. 重新打开同一个文件，验证重新加载媒体后能从头播放。
    // 这里不验证两个不同文件之间的切换，只检查重新打开这一条调用链路。
    await backend.open(file.uri);
    await waitFor(
      () =>
          backend.value.status == PlaybackStatus.playing &&
          backend.value.position < const Duration(seconds: 3),
    );
    // 8. 跳到接近结尾的第 11 秒，等待真正的播放结束事件。
    await backend.seek(const Duration(seconds: 11));
    await waitFor(() => backend.value.status == PlaybackStatus.ended);
    // 9. 结束后再次播放，验证重播回到开头，而不是停留在结尾。
    await backend.play();
    await waitFor(
      () =>
          backend.value.status == PlaybackStatus.playing &&
          backend.value.position < const Duration(seconds: 3),
    );
    // 10. 移除视频组件，触发原生视图解绑，并留出异步清理时间。
    // 最终由上方 addTearDown 释放后端、删除临时文件；此处没有直接断言原生资源计数。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
  });
}
