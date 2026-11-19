# 使用统计接入

PostHog Flutter SDK 5.61.0，美国区项目 748276。实现位于 `lib/data/analytics/analytics_service.dart`，正式构建启动时默认启用统计，不提供统计设置项，独立于 Sentry。旧版 `analytics/enabled` 值不再控制采集。

Release 默认包含公开 Project Token；debug 默认不配置。Personal API Key 不进入本仓库或安装包。

```sh
flutter test test/analytics_privacy_test.dart
flutter test integration_test/analytics_smoke_test.dart -d macos \
  --dart-define=POSTHOG_PROJECT_TOKEN=YOUR_PUBLIC_PROJECT_TOKEN \
  --dart-define=ANALYTICS_ENVIRONMENT=validation
```

配置了公开 Project Token 的构建启动时自动初始化 SDK。显式事件包括首次可观测、会话开始、来源连接、媒体库扫描、播放请求/开始/失败、Agent 与字幕任务完成。上报仅允许有限枚举和布尔业务属性；禁止路径、文件名、来源地址、对话和密钥。回放、原生自动生命周期、问卷、用户画像和功能旗标均关闭。

桌面播放器子窗口只向主窗口转交白名单事件，由主窗口统一检查初始化状态与发送，避免重复 SDK 实例。业务异常、SDK 不可达和上报失败不影响播放。

macOS debug 构建和原生真实上报已验证；其他平台的 SDK 及多窗口行为需各自验收。原生测试覆盖旧版关闭偏好与 SDK opt-out 状态下自动启动统计。首次可观测是 SDK 首次记录到的安装标识，不能当作准确安装量；网络、构建配置和初始化失败都可能造成观测缺失。

运维、后台看板和采集说明见兄弟仓库 `build/docs/posthog.md`；完整设计见 `design/engineering/posthog_growth_analytics.md`。
