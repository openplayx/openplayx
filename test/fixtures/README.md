# 集成测试素材

这些素材由项目生成，不含用户媒体或真实录音。MP4 的原始画面为程序生成的动态渐变，音轨为静音；不能据此确认真实声音输出。

| 文件 | 特征 | 用途 |
| --- | --- | --- |
| `test_video.mp4` | 约 12 秒，160×90 H.264，静音 AAC | 现有播放、媒体源测试 |
| `test_video_short.mp4` | 前 5 秒，保留视频与 AAC，faststart | 区分切换后的媒体与旧媒体 |
| `test_video_no_audio.mp4` | 约 12 秒，仅视频，faststart | 移动端 HTTP 无音轨播放缺陷回归 |
| `asr_en.wav` | 约 5.64 秒，16 kHz 单声道 PCM s16 | 真实 Whisper 英文识别与时间戳 |

生成 MP4：在主项目目录执行：

```sh
swift tool/generate_test_video.swift test/fixtures/test_video.mp4
swift tool/generate_regression_videos.swift
```

`asr_en.wav` 复制自同级 `package-whisper/test/fixtures/en.wav`，该包记录其来源为 macOS 文字转语音生成的英文语音，识别断言使用 `quick brown fox`。若更新源素材，需要同步此副本并重新验证 tiny 模型识别结果。

新素材只由对应测试显式加载；不需要同步到媒体源 VM，不应替换该 VM 已有的 `test_video.mp4`。

当前副本的 SHA-256（重新导出 MP4 的容器元数据可能变化）：

```text
9ecf584cc5feebb2ddfd9225fb20680651418ff12eec06d97ea654ab51bcd6cd  test_video_short.mp4
168c5a279055905be5acd80c008ebd04f2c8d77ec190f90666212970c3e05329  test_video_no_audio.mp4
87bc535c958008121f262b68228b1c5775fe5683fd06bfb810a2fedf71c44da1  asr_en.wav
```
