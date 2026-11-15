# OpenPlayX

[English](README.md) | 简体中文

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

基于 Flutter 与 libVLC 的媒体播放器，支持本地文件、网络存储和媒体服务器，提供本机媒体库及可选 AI 助手。

项目仍在开发，macOS 是主要开发平台。[GitHub Releases](https://github.com/openplayx/openplayx/releases) 提供 macOS Apple Silicon 和 Android 安装包；存在平台工程或共用 Dart 代码不代表所有设备都已完成验证。

## 功能

| 模块 | 当前实现 |
|---|---|
| 播放 | 本地与远程媒体、拖动定位、倍速、音量、音轨、外部字幕和键盘控制 |
| 来源 | 本地文件夹、SMB、WebDAV、FTP、SFTP、S3、Plex、Jellyfin、Emby、DLNA 适配；各来源能力不同 |
| 媒体库 | 扫描、搜索、筛选、收藏、观看进度、季集、花絮和资源版本 |
| 元数据 | 文件名解析、NFO/图片导入、TMDB 匹配、候选确认、字段锁定与海报选择 |
| AI | 可配置 OpenAI 兼容模型、流式对话、受限工具调用和操作确认 |
| 外部工具 | 用户配置的 MCP 服务、可移除的联网搜索预置和内置公网网页读取 |
| 媒体处理 | 进程内 FFmpeg、whisper.cpp、字幕生成与本机产物；可用性取决于平台和构建 |
| 远程访问 | 内嵌 sing-box，可配合 [Home](https://github.com/openplayx/openplayx-home) 与 [Relay](https://github.com/openplayx/openplayx-relay) |
| 界面 | 首页/媒体库、来源、AI、设置；自适应导航、shadcn_ui、Lucide 和多语言文案 |

应用在本机运行，无需部署 OpenPlayX 服务端。模型、在线元数据、联网搜索及远程服务按需连接。完整跨设备同步、直播/IPTV/EPG 和电视遥控器界面尚未提供。不支持 Flutter Web 播放；[openplayx.com](https://openplayx.com) 是独立的项目官网。

## 下载

从 [Release 页面](https://github.com/openplayx/openplayx/releases) 选择平台和架构对应的安装包，并阅读安装说明。Windows、Linux 和 iOS 工程的存在不代表已有可直接安装的正式版本。

## 源码构建

依赖：Dart 满足 `^3.13.7` 的 Flutter、平台开发工具（macOS/iOS 需要 Xcode、CocoaPods），以及原生组件所需的 Go/C 工具链。另见 [播放原生依赖](docs/implement/libvlc_basic_player.md) 和 [远程访问实现](docs/implement/remote_access_singbox_frp.md)。

当前需要同级目录中的 `ffmpeg-package`、`package-whisper` 和 `smb_connect`。其中 FFmpeg 包及 SMB 分支是私有依赖，仅克隆公开主仓无法复现当前构建。已有访问权限的贡献者可准备：

```sh
git clone https://github.com/openplayx/openplayx.git
git clone https://github.com/openplayx/package-whisper.git
git clone git@github.com:openplayx/ffmpeg-package.git
git clone git@github.com:openplayx/smb_connect.git
cd openplayx
flutter doctor
flutter pub get
flutter run -d macos
```

依赖以 `pubspec.yaml` 为准，其中包含本地 SMB override。还需准备原生库和各平台工具链；不必安装 VLC 桌面应用。源码构建权限与安装包是否可下载是两回事。

## 初次使用

1. 打开本机文件，或在“来源”中添加连接后直接浏览播放。
2. 创建媒体库并扫描已授权目录，组织媒体内容。
3. 按需配置在线影视信息查询，对不明确的候选人工确认。
4. 在“AI”中配置模型及凭据、测试连接并查看数据发送授权；外部 MCP 服务也在此管理。
5. 在“设置”中管理外观、语言、识别、远程访问和可选诊断。

扫描不会下载视频。服务器下载工具由独立服务提供，操作需要用户确认。联网搜索通过预置 mcp-tavily 连接提供，移除后不会自动重新添加。公网网页读取在设备上执行，拒绝本地和私有地址。

## 数据与隐私

- `configuration.sqlite3` 在所属配置项中保存设置、来源凭据、API Key 和服务 token。目前不使用独立系统钥匙串，也未提供应用层数据库加密，请保护应用数据目录及其备份。
- `library.sqlite3` 保存媒体记录、进度、对话、任务与产物。开发阶段的数据库升级可能重建旧表并丢弃数据，尚不保证无损迁移。
- 模型请求可能包含对话及已授权工具上下文；联网搜索发送至配置的搜索服务，网页读取直接访问目标公网网站。本地播放不需要 AI 模型。
- 诊断默认关闭，收集及构建配置见 [SENTRY.md](SENTRY.md)。不要公开含凭据的数据库、调试种子或日志。

另见 [安全报告](SECURITY.md) 与 [当前实现说明](docs/README.md)。

## 开发与测试

```sh
flutter analyze
flutter test
```

原生播放器、模型、真实服务与设备测试有额外要求，见 [单元/Widget 测试](test/README.md)、[原生集成测试](integration_test/README.md) 和 [测试服务准备](tool/source_services/README.md)。真实联网检查需显式启用；模拟测试通过不等于所有设备和媒体格式均已验证。

`lib/app` 负责界面装配，`lib/features` 存放功能页面，`lib/services` 提供业务服务，`lib/data` 实现来源与存储，`packages/playback` 封装播放桥接。

## 文档与贡献

入口见 [文档索引](docs/README.md)。实现说明包含带日期的历史验证记录，部分内容描述早期设计，请优先核对当前概览和代码。内部部署资料独立维护，使用公开安装包无需访问内部仓库。

欢迎 issue 与 PR，见 [CONTRIBUTING.md](CONTRIBUTING.md)。安全问题按 [SECURITY.md](SECURITY.md) 私下报告。

## 许可证与致谢

OpenPlayX 原创应用代码与文档采用 **MIT**，完整条款及版权见 [LICENSE](LICENSE) 和 [NOTICE.md](NOTICE.md)。应用链接 sing-box，并保留其 GPL 与命名声明；原创代码的 MIT 授权不替代组合构建适用的 GPL 条款。第三方代码仍适用各自条款，许可清单及二进制发布所需源码材料见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。私有构建依赖仍需单独授权访问，主项目许可不会使这些仓库自动公开。

感谢 Flutter、VideoLAN/libVLC、vlc_player、shadcn_ui、Lucide、whisper.cpp、FFmpeg 等项目。依赖仍适用各自的许可和分发义务，见对应包及 [`native/remote_access/LICENSE`](native/remote_access/LICENSE)。
