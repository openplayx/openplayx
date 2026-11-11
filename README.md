# OpenPlayX

**基于 Flutter 与 libVLC 的跨平台媒体播放器，面向本地文件、网络存储和媒体服务器。**

OpenPlayX 将媒体来源接入、媒体库管理和播放体验组合在一个应用中。项目正在开发，当前以 macOS 为主要验证平台；已接入可配置云模型与受控 AI 助手；可扩展插件体系和跨设备同步仍在建设中。

[快速开始](#快速开始) · [功能](#功能) · [平台支持](#平台支持) · [开发与测试](#开发与测试) · [文档](#文档) · [参与贡献](#参与贡献)

## 项目定位

- **本地运行**：打开本机文件即可播放，无需部署 OpenPlayX 服务端；网络来源按需连接用户自己的服务。
- **统一媒体入口**：直接浏览来源，也可以把指定范围扫描到本机媒体库。
- **Flutter + libVLC**：Dart 实现界面与业务，通过独立播放桥接包调用 libVLC，无需安装 VLC 桌面应用。
- **面向扩展**：以类型化来源能力组织现有接入；后续让插件能力同时服务于传统界面和 AI 工具调用。

## 功能

### 当前已实现

| 模块 | 能力 |
| --- | --- |
| 应用导航 | 首页、媒体库、来源、设置；宽屏侧栏与窄屏底部导航 |
| 本地播放 | 系统文件选择器、播放/暂停、拖动定位、前后跳转、结束后重播 |
| 播放控制 | 0.5–2 倍速、长按临时加速、播放器音量、静音、音轨选择、画面调暗、控制锁定、键盘快捷键 |
| 媒体来源 | 本地文件夹、SMB、Jellyfin、Plex 的浏览、资源选择与直接播放 |
| 媒体库 | 创建与管理库、绑定来源范围、扫描、搜索、筛选、收藏、详情与资源版本选择 |
| 影视信息 | NFO 与邻近图片导入、TMDB 候选识别、季集关系、字段与海报锁定、服务端信息刷新 |
| AI 助手 | 云模型配置、流式对话、共享会话、受控媒体查询与基础播放工具、Plex/Jellyfin 聚合搜索 |
| 家庭远程访问 | 内嵌 sing-box；配套 relay/home；Jellyfin、Emby、Plex 与 SMB 远程访问，HTTP 媒体服务支持已配对 HTTPS 局域网优先 |
| 观看记录 | 本机进度保存、续播、继续观看与最近播放 |
| 来源配置 | 实例启停、连接编辑、默认来源、SQLite 持久化；密码和令牌单独存入系统安全存储 |

扫描不会下载视频。影视媒体入库后自动排队导入已授权范围内的 NFO 和图片；配置 TMDB 读取令牌后，自动查询并采用名称、年份一致的唯一候选，其余候选保留待确认。Android 使用 WorkManager 在页面关闭后继续处理，桌面端在应用运行期间处理；列表自动展示刮削后的标题和封面。媒体详情中的“影视信息”提供重新匹配、字段纠错与海报选择，播放进度和资源版本独立保留。详见 [影视元数据与刮削](docs/implement/media_metadata_scraping.md)。

### 规划与建设中

- **统一前端设计系统**：整体引入 flutter-shadcn-ui 与 Lucide，统一主题、样式和组件。
- **更多 AI 工作流**：字幕、语义检索、视觉与长任务卡片按真实业务能力逐项接入。
- **更多来源与内容能力**：WebDAV、网盘、元数据、封面、字幕等插件扩展。
- **可选跨设备同步**：同步业务数据与适用偏好，考虑苹果生态、其他云服务及自建方案。
- **多语言与更完整的平台适配**。

设计文档描述目标能力，不代表这些功能均已可用。

## 平台支持

| 平台 | 当前状态 |
| --- | --- |
| macOS | 主要开发与验证平台，已有原生播放和来源集成验证记录 |
| iOS | 已有宿主工程与播放适配路径，尚需签名、设备和完整功能验收 |
| Android | 已有宿主工程与播放适配路径，尚需构建及设备验收；当前 minSdk 为 29 |
| Windows / Linux | 播放依赖提供接入路径，尚未完成本项目构建和完整验收 |
| Web | 当前不支持播放 |
| Apple TV / Android TV | 尚未完成平台及遥控器交互适配 |

共用 Dart 接口或存在平台工程，不等于该平台已经通过验收。详细原生配置见 [libVLC 实现说明](docs/implement/libvlc_basic_player.md#各平台配置)。

## 快速开始

当前建议先在 macOS 运行源码。

### 环境要求

- Flutter SDK，所带 Dart 需满足 `pubspec.yaml` 的 `^3.13.7` 约束；已有实现记录使用 Flutter 3.47.9 / Dart 3.13.7。
- Xcode、macOS 开发工具和 CocoaPods。
- Go 1.24+ 与 C 工具链，用于构建内嵌 sing-box；Android 需要 Flutter 固定的 NDK。
- 首次构建需能下载 Flutter 包及 VLCKit 原生依赖。

### 获取代码并运行

```bash
git clone https://github.com/openplayx/openplayx.git
cd openplayx
flutter doctor
flutter pub get
flutter run -d macos
```

首次构建通过 CocoaPods 获取 VLCKit，不需要单独安装 VLC 桌面应用。其他平台的构建要求与验证边界见上方平台说明。

### 第一次使用

1. 在首页点击“打开文件”，选择本地视频或音频，体验播放控制。
2. 在“来源”中添加本地文件夹、SMB 或媒体服务器，浏览并播放内容。
3. 在“媒体库”中创建库、添加来源范围并扫描，将内容纳入本机媒体库。
4. 再次打开已有资源时恢复对应资源的进度；首页可查看继续观看和最近播放。
5. 如需 AI 助手，在「设置 → AI 助手 → 模型设置」填写 HTTPS API 基址、模型与 API Key，执行连接测试并授权云端数据发送。详见 [AI 接入实现](docs/implement/langchain_dart_integration.md)。

来源连接与媒体库分开管理：**来源解决从哪里读取，媒体库负责如何组织内容**。直接播放无需先完成媒体库扫描。

## 连接媒体来源

| 来源 | 添加方式 | 可选配置 |
| --- | --- | --- |
| 本地文件夹 | 使用系统目录选择器授权 | 自定义名称 |
| SMB | 地址、用户名、密码；访客账号密码留空 | 工作组、共享名、子目录；当前端口固定 445 |
| Jellyfin | 服务器地址、用户名、密码 | HTTPS、端口、反向代理子路径 |
| Plex | 浏览器登录并选择可访问服务器 | 手动服务器连接方式 |

名称可留空自动生成，服务器地址支持粘贴完整 URL。SMB 只填写主机时会先浏览共享列表；Jellyfin 自动取得用户 ID 和令牌，Plex 无需用户手动提取 Token。编辑时登录字段留空表示保留现有登录；更换 Jellyfin 服务器或账号需重新认证。

配置由 SQLite 管理，凭据由系统安全存储管理。临时播放句柄在切换媒体和退出播放器时释放；具体安全与生命周期边界见 [来源配置实现说明](docs/implement/source_instance_configuration.md)。

### 当前限制

- SMB 客户端支持 SMB 2.0/2.1，暂不支持只允许 SMB 3.x 的共享。
- macOS 文件夹访问使用安全作用域书签恢复授权；Android/iOS 文件夹来源目前限于应用可访问的普通目录。单文件选择支持范围与文件夹授权不同。
- Plex/Jellyfin 当前以直接播放为主，尚无转码、服务发现或观看进度回写；多版本和分段资源供分别选择，不自动拼接。
- 尚无自动在线刮削、封面管理、字幕附件管理、跨来源作品智能合并或跨设备同步。
- 应用隐藏或进入后台时暂停，恢复前台后手动继续；尚不承诺后台持续播放。

## 技术结构

```text
Flutter 页面与自适应导航
  ├── 来源能力 → 本地文件 / SMB / Jellyfin / Plex
  ├── 媒体库与配置 → SQLite + 系统安全存储
  └── 播放桥接 → libVLC / VLCKit
```

| 技术 | 用途 |
| --- | --- |
| Flutter / Dart | 跨平台界面、业务逻辑和应用装配 |
| libVLC，经 `packages/playback` 封装 | 解码、视频输出与播放控制；当前通过 `vlc_player` 接入 |
| SQLite | 媒体库、观看进度与来源实例配置 |
| 系统安全存储 | 密码、访问令牌等机密 |
| flutter-shadcn-ui / Lucide | 正在整体接入的基础组件、主题与图标体系 |

```text
lib/
├── app/                 # 应用外壳、导航与主题
├── features/            # 播放器、媒体库和来源页面
├── core/plugins/        # 当前来源能力与配置契约
├── services/            # 媒体库等业务服务
├── data/                # 来源实现、文件访问与配置存储
└── ui/                  # 公共组件、布局、图标与设计变量
packages/playback/       # libVLC 播放桥接
test/                  # 单元测试与 Widget 测试
integration_test/        # 原生插件及真实服务集成测试
tool/                    # 测试素材生成与临时服务工具
docs/implement/          # 实现边界与历史验证记录
```

## 开发与测试

在本仓库根目录运行：

```bash
flutter analyze
flutter test
```

需要真实 macOS 环境的原生测试：

```bash
flutter test integration_test/playback_test.dart -d macos
flutter test integration_test/source_storage_test.dart -d macos
```

真实 SMB、Jellyfin、Plex 集成测试需要临时服务，按 [测试服务说明](tool/source_services/README.md) 准备后运行。不要使用个人生产账号或把真实凭据提交到仓库。

- [单元与 Widget 测试说明](test/README.md)
- [原生集成测试说明](integration_test/README.md)

单元测试通过不代表所有平台的真实音视频均已验证；历史实现文档中的测试结果只对应其记录的实现和环境。

## 文档

### 本仓库实现说明

| 文档 | 内容 |
| --- | --- |
| [libVLC 基础播放](docs/implement/libvlc_basic_player.md) | 播放链路、原生依赖与平台配置 |
| [播放器控制](docs/implement/basic_player_controls.md) | 倍速、音轨、控制层、读取速度与快捷键 |
| [媒体库](docs/implement/media_library.md) | 扫描、身份、资源、观看进度与当前边界 |
| [来源实例配置](docs/implement/source_instance_configuration.md) | 配置、凭据、实例生命周期与验证 |
| [工程初始化](docs/implement/flutter_project_initialization.md) | 初始环境和工程配置记录 |

### 设计文档

完整设计独立维护在 [openplayx/design](https://github.com/openplayx/design) 仓库的 `tech/` 目录，无需克隆该仓库即可运行播放器。

建议依次阅读：`architecture_draft.md`（总览）、`navigation_design.md`（导航）、`media_library.md`（媒体库）、`plugin_system.md`（插件）、`frontend_design_system.md`（主题与组件）。该目录还包含 AI 交互、数据管理、配置、多语言及同步设计。

## 参与贡献

欢迎通过 [Issues](https://github.com/openplayx/openplayx/issues) 报告问题或讨论改进，通过 [Pull Requests](https://github.com/openplayx/openplayx/pulls) 提交代码和文档。

- 报告问题请提供操作步骤、预期与实际结果、平台和 Flutter 版本；日志先移除账号、令牌和私人媒体路径。
- 较大的功能或架构调整建议先开 Issue 讨论范围。
- 提交前运行静态分析与相关测试；涉及原生播放时注明实际验证的平台。
- 保持 Widget、业务服务和播放桥接职责清晰；界面改动遵循统一设计系统。

## 许可证与致谢

当前仓库尚未提供主项目 `LICENSE` 文件，主项目授权范围有待维护者明确；不能据依赖的许可证推定本项目的许可证。

感谢 [Flutter](https://github.com/flutter/flutter)、[VideoLAN / VLC](https://www.videolan.org/vlc/)、[vlc_player](https://pub.dev/packages/vlc_player)、[flutter-shadcn-ui](https://github.com/nank1ro/flutter-shadcn-ui) 和 [Lucide](https://github.com/lucide-icons/lucide) 等项目。各依赖保留各自许可证；发布含 VLC/VLCKit 的构建时，还需遵循对应运行库的分发要求。

家庭远程访问的配置、构建、验证与待验收边界见 [sing-box + frp 实现记录](docs/implement/remote_access_singbox_frp.md)。

三端配置入口：App“设置 → 远程访问”、Relay/Home 本机 Web 管理页；配置分别保存为 remote_access.json、relay.json、home.json。详见 [三端配置管理](docs/implement/remote_access_configuration.md)。
