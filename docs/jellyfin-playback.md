# Jellyfin 原生播放协商与受控回退（ALL-328）

视频先通过 POST Items/{id}/PlaybackInfo 带入已选择的 MediaSourceId、用户和原生客户端 DeviceProfile。可 Direct Play 时保留静态原流；服务判定不兼容时使用其渐进 HTTP 转封装/转码地址。音频和 Emby 保留原入口。

PlayableStream 记录 DirectPlay、Remux 或 Transcode。渐进 URL 中的目标编码名称不一定是 copy；容器错误且输入/输出编码兼容时，Jellyfin 的编码器实际可以选择 stream copy。真实服务验收应同时检查编码器日志，不能只凭 TranscodingUrl 字段命名下结论。

原生后端打开抛错或报告播放错误时，PlayerController 最多触发一次服务器回退：停止后端，释放旧代理及旧 PlaySessionId，再创建新流。重试后的流没有下一层回退。用户取消、更换媒体或退出期间完成的过期回退流会立即释放，不再送入播放器。

远端鉴权只由 SourceHttp/StreamGateway 持有。返回给播放器的是随机 loopback 地址；服务返回的绝对 URL 必须匹配配置的源和基路径，重定向不携带凭据；api key 从播放地址 query 中移除，使用既有认证请求头。释放流时关闭代理并通知 Sessions/Playing/Stopped；源销毁时回收仍持有的流。

当前回退范围是视频、渐进 HTTP MPEG-TS。未接入 HLS 嵌套清单代理、动态码率或转码流的任意 Seek；服务只提供 HLS 时明确报错，不把顶层清单直接交给不能转发分段鉴权的单文件代理。浏览器验证见 package-media/tool/web_playback_probe.mjs，运行方式见 package-media 的 README。

## 验证

- test/data/sources/jellyfin_playback_test.dart：协商、Range/鉴权、外域拒绝、单次重试、释放幂等和源销毁。
- test/features/player/player_stream_recovery_test.dart：后端错误自动触发重试，以及取消期间的过期流清理。
- integration_test/live/jellyfin_live_test.dart：显式指定独立 Jellyfin 会话配置，使用真实服务的 H.264/AAC 和 AV1/Opus 原创样本，将 Direct Play、Remux、Transcode 流交给 package-media 的原生集成测试，并验证释放后 loopback 不再可访问。

```sh
flutter test integration_test/live/jellyfin_live_test.dart \
  --dart-define=OPX_JELLYFIN_SESSION=/tmp/session.json \
  --dart-define=OPX_JELLYFIN_REPORT=/absolute/path/to/report
```

session.json 的字段为 address、userId、token，不能提交到仓库。测试只针对隔离服务；准备两个 8 秒、320×240、25 fps、1 kHz 音轨的条目，路径包含 /test-media/Remux/ 和 /test-media/Transcode/，后者使用 AV1/Opus。未传配置时该真实服务测试跳过，普通单元测试照常执行。
