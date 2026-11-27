# OpenPlayX

[English](README.md) | 简体中文

[![CI](https://github.com/openplayx/openplayx/actions/workflows/ci.yml/badge.svg)](https://github.com/openplayx/openplayx/actions/workflows/ci.yml)
[![CodeFactor](https://www.codefactor.io/repository/github/openplayx/openplayx/badge)](https://www.codefactor.io/repository/github/openplayx/openplayx)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=openplayx_openplayx&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=openplayx_openplayx)
[![Coverage](https://img.shields.io/sonar/coverage/openplayx_openplayx?server=https%3A%2F%2Fsonarcloud.io)](https://sonarcloud.io/summary/new_code?id=openplayx_openplayx)
[![Release](https://badgen.net/github/release/openplayx/openplayx/stable)](https://github.com/openplayx/openplayx/releases)
[![Dart SDK](https://badgen.net/badge/Dart/%5E3.13.7/0175C2)](pubspec.yaml)
[![License](https://badgen.net/badge/license/MIT/green)](LICENSE)
[![Docs](https://badgen.net/badge/docs/openplayx.com/blue)](https://openplayx.com/docs/zh-Hans/)
[![Repo Size](https://img.shields.io/github/repo-size/openplayx/openplayx)](https://github.com/openplayx/openplayx)
[![Code Size](https://img.shields.io/github/languages/code-size/openplayx/openplayx)](https://github.com/openplayx/openplayx)

基于 Flutter 与 libVLC 的媒体播放器，支持本地文件、网络存储和媒体服务器，提供本机媒体库及可选 AI 助手。

项目仍在开发，macOS 是主要开发平台。[GitHub Releases](https://github.com/openplayx/openplayx/releases) 提供 macOS Apple Silicon 和 Android 安装包；存在平台工程或共用 Dart 代码不代表所有设备都已完成验证。

## 功能

| 模块 | 当前实现 |
|---|---|
| 播放 | 本地与远程媒体、拖动定位、倍速、音量、音轨、外部字幕和键盘控制 |
| 来源 | 本地文件夹、SMB、WebDAV、FTP、SFTP、S3、Plex、Jellyfin、Emby、DLNA 适配；各来源能力不同 |
| 媒体库 | 扫描、搜索、筛选、观看进度、季集、花絮和资源版本 |
| 元数据 | 文件名解析、NFO/图片导入、TMDB 匹配、候选确认、字段锁定与海报选择 |
| AI | 可配置 OpenAI 兼容模型、流式对话、受限工具调用和操作确认 |
| 外部工具 | 用户配置的 MCP 服务、可移除的联网搜索预置和内置公网网页读取 |
| 媒体处理 | 进程内 FFmpeg、whisper.cpp、字幕生成与本机产物；可用性取决于平台和构建 |
| 远程访问 | 内嵌 sing-box，可配合 [Home](https://github.com/openplayx/openplayx-home) 与 [Relay](https://github.com/openplayx/openplayx-relay) |
| 界面 | 首页/媒体库、来源、AI、设置；自适应导航、shadcn_ui、Lucide 和多语言文案 |

应用在本机运行，无需部署 OpenPlayX 服务端。模型、在线元数据、联网搜索及远程服务按需连接。完整跨设备同步和直播/IPTV/EPG 尚未提供。[电视遥控器界面初版](docs/implement/tv_experience.md) 已覆盖媒体库、详情和播放，仍待真机验收。不支持 Flutter Web 播放；[openplayx.com](https://openplayx.com) 是独立的项目官网。

云盘新增坚果云/123 WebDAV 预设及 OneDrive/Dropbox 只读适配；OAuth 需发布者配置应用，真实账号验收待完成。详见[配置与验收记录](docs/cloud_drive_sources.md)。

## 字幕对齐

桌面端打开 **音轨与字幕 → 字幕智能对齐**，移动端打开 **字幕 → 字幕智能对齐**。桌面使用停靠侧栏，移动竖屏使用底部抽屉、横屏使用侧边抽屉。手动延迟支持 0.25 秒步进、重置及本次播放内撤销。

参考字幕对齐将当前本地 UTF-8 SRT 与已同步、对白语言相同的 SRT 比较，也可选择已保存的完整 ASR 字幕作为参考。基于唯一的归一化对白匹配计算固定偏移或线性漂移，并通过预留锚点、覆盖范围和时间边界检查。这是保守的基础实现，阈值尚未经真实基准校准，指标不表示正确概率。结果需手动预览或应用。生成副本保留在应用存储中，原件不变；撤销恢复原始轨道与延迟。关闭面板不停止分析，可取消，切换媒体会使旧任务失效。记录仅限本次播放。

每份输入最多 4 MB、12,000 条。此基础实现尚不支持内嵌/图片字幕、跨语言或模糊匹配、VAD/FFT、分段剪辑校正和 LLM 编排，不上传媒体。桌面与移动布局测试使用模拟播放后端，仍需原生 VLC 与真机验收。

## 下载

从 [Release 页面](https://github.com/openplayx/openplayx/releases) 选择平台和架构对应的安装包，并阅读安装说明。Windows、Linux 和 iOS 工程的存在不代表已有可直接安装的正式版本。

## 源码构建

依赖：Dart 满足 `^3.13.7` 的 Flutter、平台开发工具（macOS/iOS 需要 Xcode、CocoaPods），以及原生组件所需的 Go/C 工具链。另见 [播放原生依赖](docs/implement/libvlc_basic_player.md) 和 [远程访问实现](docs/implement/remote_access_singbox_frp.md)。

当前需要同级目录中的 `ffmpeg-package`、`package-libvlc`、`package-media` 和 `package-whisper`。FFmpeg 仓库已公开为 [openplayx/package-ffmpeg](https://github.com/openplayx/package-ffmpeg)，本地目录仍保留 `ffmpeg-package`，以兼容 pubspec path 和 CI checkout name。SMB 依赖通过 HTTPS 从公开仓库 [openplayx/package-smb](https://github.com/openplayx/package-smb) 自动获取，并固定到不可变的提交，无需单独克隆。准备源码：

```sh
git clone https://github.com/openplayx/openplayx.git
git clone https://github.com/openplayx/package-libvlc.git
git clone https://github.com/openplayx/package-media.git
git clone https://github.com/openplayx/package-whisper.git
git clone https://github.com/openplayx/package-ffmpeg.git ffmpeg-package
cd openplayx
flutter doctor
flutter pub get
flutter run -d macos
```

依赖来源和版本以 `pubspec.yaml` 与 `pubspec.lock` 为准。还需准备原生库和各平台工具链；不必安装 VLC 桌面应用。源码构建权限与安装包是否可下载是两回事。

## 初次使用

1. 打开本机文件，或在“来源”中添加连接后直接浏览播放。
2. 创建媒体库并扫描已授权目录，组织媒体内容。
3. 按需配置在线影视信息查询，对不明确的候选人工确认。
4. 在“AI”中配置模型及凭据、测试连接并查看数据发送授权；外部 MCP 服务也在此管理。
5. 在“设置”中管理外观、语言、识别、远程访问。

扫描不会下载视频。服务器下载工具由独立服务提供，操作需要用户确认。联网搜索通过预置 mcp-tavily 连接提供，移除后不会自动重新添加。公网网页读取在设备上执行，拒绝本地和私有地址。

## 数据与隐私

- `configuration.sqlite3` 在所属配置项中保存设置、来源凭据、API Key 和服务 token。目前不使用独立系统钥匙串，也未提供应用层数据库加密，请保护应用数据目录及其备份。
- `library.sqlite3` 保存媒体记录、进度、对话、任务与产物。开发阶段的数据库升级可能重建旧表并丢弃数据，尚不保证无损迁移。
- 模型请求可能包含对话及已授权工具上下文；联网搜索发送至配置的搜索服务，网页读取直接访问目标公网网站。本地播放不需要 AI 模型。
- Sentry 错误上报默认开启，收集及构建配置见 [SENTRY.md](SENTRY.md)。不要公开含凭据的数据库、调试种子或日志。

另见 [安全报告](SECURITY.md) 与 [当前实现说明](docs/README.md)。

## 开发与测试

```sh
flutter analyze
flutter test
```

原生播放器、模型、真实服务与设备测试有额外要求，见 [单元/Widget 测试](test/README.md)、[原生集成测试](integration_test/README.md) 和 [测试服务准备](tool/source_services/README.md)。真实联网检查需显式启用；模拟测试通过不等于所有设备和媒体格式均已验证。

`lib/` 分层组织，每层只依赖其下的层（由 `test/architecture_test.dart` 检查）：`core`（接口与纯模型）、`data`（存储与来源连接器）、`capabilities`（App 与 AI 共用的基础能力：来源、媒体库、元数据、媒体处理、语音识别、播放入口，以及它们的全局开关）、`assistant`（AI：模型接入、会话，以及把基础能力包装成 AI 工具的插件）、`ui`（设计系统）、`features`（各界面，按 `model`/`controller`/`view` 拆分）和 `app`（装配与导航）。libVLC 播放桥接位于同级仓库 [package-libvlc](https://github.com/openplayx/package-libvlc)，文件格式播放测试也在其中。

## 文档与贡献

入口见 [文档索引](docs/README.md)。实现说明包含带日期的历史验证记录，部分内容描述早期设计，请优先核对当前概览和代码。内部部署资料独立维护，使用公开安装包无需访问内部仓库。

欢迎 issue 与 PR，见 [CONTRIBUTING.md](CONTRIBUTING.md)。安全问题按 [SECURITY.md](SECURITY.md) 私下报告。

## 许可证与致谢

OpenPlayX 原创应用代码与文档采用 **MIT**，完整条款及版权见 [LICENSE](LICENSE) 和 [NOTICE.md](NOTICE.md)。应用链接 sing-box，并保留其 GPL 与命名声明；原创代码的 MIT 授权不替代组合构建适用的 GPL 条款。第三方代码仍适用各自条款，许可清单及二进制发布所需源码材料见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。私有构建依赖仍需单独授权访问，主项目许可不会使这些仓库自动公开。

感谢 Flutter、VideoLAN/libVLC、vlc_player、shadcn_ui、Lucide、whisper.cpp、FFmpeg 等项目。依赖仍适用各自的许可和分发义务，见对应包及 [`native/remote_access/LICENSE`](native/remote_access/LICENSE)。

### 把外部下载文件保存到数据源

外部 MCP 服务下载完成后，助手可调用
`external_file_save_to_source(service_id, job_id, file_index, target_instance_id,
folder?, transfer_mode?)`。在插件管理里为目标源开启 **source.write**，并在对话中确认。
SMB、WebDAV、SFTP 支持写入新文件；同名时加数字后缀，永不替换已有文件。
`folder` 相对于配置的源根目录：省略时为 `OpenPlayX/Downloads`，空字符串为根目录。
SMB 目标地址须包含共享名。

默认 `transfer_mode: "stream"` 边收边写，以背压控制内存，不使用本机文件空间。
`"cache"` 先下载到 App 私有临时目录，检查剩余空间并保留 64 MiB 余量，再上传本地文件。
成功或取消后删除缓存；失败或中断缓存留作续传，超过 24 小时后在下次缓存任务中清理。
数据均经过 App，需承担下载服务 → 设备 → 数据源两段流量。

任务立即返回，聊天卡片显示进度并支持取消；可用 `task_get(wait_seconds)` 等待，
`task_list` 查询，`task_cancel` 取消，`task_retry` 重试。下载地址由 App 根据服务配置和
任务索引生成，仅请求服务根地址下的 `/files/{job_id}/{file_index}`，保留反向代理前缀，
拒绝重定向。token 和文件内容不会发送给模型。通过 HEAD、强 ETag、精确长度、Range
和 If-Range 校验续传，避免拼接不同版本文件。

HTTP 下载中断时自动从已传输字节续传；缓存下载在 App 重启后也可通过 `task_retry`
恢复，并重新检查服务地址及写入权限。SMB/SFTP 在任务运行期间可重连目标并继续写入；进程退出后直接写入任务需重新独占创建。
WebDAV 目标连接断开时须重新上传，通用 WebDAV PUT 没有追加写入约定。SFTP 使用独占创建，写入时可能看到未完成文件，
失败或取消会尝试删除。系统挂起 App 时任务暂停，待 App 恢复运行后继续处理。

新安装默认使用平台 Relay 配置：在“设置 → 远程访问”登录账号后订阅就绪节点与设备已授权服务。用户仍可导入自建配置，导入后优先使用自建配置，点击“恢复平台默认”即可切回；已有配置保留。订阅每分钟刷新，刷新时间戳过期后继续使用上次配置；首次推荐节点选定后保持固定，用户根据 TCP/TLS 测试结果手动调整，后台刷新不自动切换。空节点池显示不可用。

Apple TV：提供实验版 tvOS 0.0.4 IPA，需重新签名后侧载。安装、构建方式与功能限制见 [tvOS 说明](docs/tvos.md)。
