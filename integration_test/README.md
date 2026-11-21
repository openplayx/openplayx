# 原生集成测试

`integration_test/` 存放需要启动真实 Flutter 应用、连接实际插件或平台能力的集成测试，用于验证 Dart 代码与原生实现之间的协作是否正常。

## 一般存放什么

| 内容 | 用途 |
| --- | --- |
| 原生插件集成测试 | 验证播放控制器、方法调用、事件回传、视频视图等能否与实际原生插件协作 |
| 平台能力集成测试 | 按需验证真实文件访问、数据库或其他依赖平台环境的功能 |
| 模块协作测试 | 在真实应用环境中验证多个模块的调用链路，而不只检查单个类或 Widget |
| `support/` | 测试数据准备、临时文件管理、等待条件等辅助代码，本身不是独立测试用例 |

测试文件使用 `_test.dart` 后缀，并初始化 `IntegrationTestWidgetsFlutterBinding`。测试需要目标平台的构建工具、设备或模拟器；原生异步操作应使用明确的等待条件与超时，并在结束或失败时清理资源。

## 当前内容

```text
integration_test/
├── playback_test.dart
├── playback_recovery_test.dart
├── ffmpeg_bridge_test.dart
├── whisper_bridge_test.dart
├── source_storage_test.dart
├── sources_test.dart
├── mobile_ai_playback_test.dart
├── metadata_background_test.dart
├── metadata_matching_test.dart
├── player_window_test.dart
├── assistant_movie_flow_test.dart
├── ui_screenshots_test.dart
└── support/
```

- `playback_test.dart`：调用真实 libVLC，验证视频时长、尺寸、播放进度、暂停、Seek、重新打开同一媒体及结束后重播；最后解绑视频视图并清理播放后端。
- `support/test_video.dart`：将 `test/fixtures/test_video.mp4` 复制到应用沙箱内的临时目录，使原生播放器可以访问，不依赖网络或用户文件。

当前播放测试直接挂载视频组件，不通过完整播放器页面操作。这样可以将原生引擎验证与应用窗口前后台策略隔离。它不是对完整用户流程的端到端验收，也没有直接断言原生资源计数；静音音轨不能验证声音输出。

## 运行方式

在主项目根目录运行已验证的 macOS 播放测试：

```bash
flutter test integration_test/playback_test.dart -d macos
```

其他原生平台需要准备相应构建环境和设备，并确认该测试及其素材适用后再执行，不能将 macOS 的通过结果视为所有平台都通过。当前 Web 播放明确不支持，不应在浏览器上运行此原生播放测试。

普通的 `flutter test` 用于默认的 `test/` 目录；运行此目录的集成测试时，显式指定测试路径与目标设备。

## 与其他测试的边界

- 不依赖真实原生实现的单元测试和 Widget 测试，放在 [`test/`](../test/README.md)，优先快速验证局部逻辑。
- 本目录中的测试与主项目代码、插件注册及平台构建环境紧密关联，因此保留在主项目中。
- 从应用外部操作完整产品的端到端测试、验收场景、跨平台矩阵及可追溯报告，放在独立的 `openplayx-test` 仓库；本目录的执行结果可以作为其验收证据的一部分。

## 依赖的真实服务（必需）

集成测试不再按开关跳过：缺少配置或服务连不上时，测试直接失败并说明缺什么。依赖如下：

| 服务 | 用途 | 位置 |
| --- | --- | --- |
| 媒体源测试服务（SMB、WebDAV、FTP、SFTP、S3、Plex、Jellyfin、Emby、DLNA） | `sources_test`、`player_window_test` | 本机测试 VM，见 [source_services/README.md](../tool/source_services/README.md) |
| 可读写的电影 SMB 共享（`smb://<SOURCE_HOST>/movie`） | `assistant_movie_flow_test` | 同一 VM，账号来自 `../design/.env` 的 `SMB_USER`、`SMB_PASSWORD` |
| Ollama 本地模型 `openplayx-it` | `assistant_movie_flow_test` | 本机，`make integration-ollama` 由 `qwen3:14b` 派生，上下文 32K 以容纳全部工具定义 |
| whisper.cpp `ggml-tiny.bin` | `assistant_movie_flow_test` 的本地识别 | `~/.cache/openplayx-asr-models`，缺失时自动下载并校验 |

准备与运行：

```sh
SOURCE_HOST=<VM 地址> python3 tool/source_services/bootstrap.py  # 生成 defines.local.json
make integration-ollama        # 创建测试模型（换模型：OLLAMA_BASE=<名称>）
make integration-defines       # 汇总为 build/integration-defines.json（含凭据，已 gitignore）
make integration-macos         # macOS 全部集成测试
make integration-ios           # 已启动的 iOS 模拟器（或 IOS_SIM=<UDID>）
make integration-android       # emulator-5554（或 ANDROID_DEVICE=<id>）
```

单独运行某个测试时，带上 `--dart-define-from-file=build/integration-defines.json`。桌面多窗口测试（`player_window_test`、`assistant_movie_flow_test`）用 `flutter drive --driver=test_driver/integration_test.dart -d macos --target=...`：`flutter test` 的包装入口会丢弃子窗口参数。

## AI 电影处理流程

手机端的 `mobile_ai_playback_test.dart` 使用脚本模型、内存媒体库和随应用打包的本地视频，通过真实 `playback_open` 工具验证聊天页退出、播放器可见、键盘收起及原生视频进度推进，不调用模型 API 或 SMB。对应的 `test/ai/mobile_playback_navigation_test.dart` 覆盖 Android/iOS 手机布局，并检查退出聊天页不会取消后续工具调用。

`assistant_movie_flow_test.dart` 启动完整应用，通过聊天控制器提交原始提问：从 SMB 电影共享挑一部电影截取 60 秒、存回共享、本地识别字幕、保存、播放并选择字幕。应用运行在临时数据目录上（主窗口与播放子窗口共用，不读写用户的配置和媒体库），测试通过 debug seed 写入 Ollama 模型、电影共享和本地 whisper tiny，不模拟模型或工具。流程会在共享的 `OpenPlayX` 文件夹新增子视频，测试结束时（无论成败）通过 SMB 删除本次运行存入的子视频，不触碰其他文件；测试只自动批准原提问中 `media_save_to_source` 的确认。失败时日志包含逐步工具调用与实际结果；测试检查各阶段成功，最后从真实子窗口读回播放状态与字幕绑定，而不把助手的“已完成”文字当成成功证据。

模型选择（2026-11-18，同一提示词）：`qwen3.5:4b` 与 `qwen3.5:9b` 把“10%-80% 之间选起点截取 60 秒”误解为截到 80%；`qwen3:8b` 范围正确，能根据 `invalidArguments` 的缺失/无效字段和 `staleReference` 的提示纠正参数，但 3 次只过 2 次（失败时先识别了原电影，绕回子视频后超出单轮 64000 字符的上下文预算 `contextBudget`）；`qwen3:14b`（默认）连续 3 次首轮通过，每次 3–4 分钟、约 6 万 token。测试在断言失败时于新对话中整体重试一次，首次失败原因保留在日志（`FLOW attempt 1 failed`）；服务缺失等环境问题在重试之前检查，直接失败。

`player_window_test.dart` 不调用模型：在独立播放窗口中播放本地素材和 SMB 测试服务上的视频，验证真实子窗口的播放状态。子窗口选择已保存识别字幕由电影流程覆盖。

## 媒体源集成测试

`sources_test.dart` 验证本地文件夹及 SMB、WebDAV、FTP、SFTP、S3、Plex、Jellyfin、Emby、DLNA 的真实浏览、资源解析、完整文件/Range 读取和原生 libVLC 播放、暂停、Seek，并在播放中禁用实例，确认新请求被拒绝、已有播放句柄可继续暂停和 Seek。远程源缺少 `SOURCE_HOST` 或服务端口连不上时失败。

`source_storage_test.dart` 在真实应用中验证配置持久化、系统安全存储读写和本地目录书签恢复（macOS 与 iOS 保存书签），不依赖测试服务。

## iOS 模拟器与 Android 模拟器

`make integration-ios` / `make integration-android` 运行适用于移动端的 8 个测试文件：`playback`、`playback_recovery`、`ffmpeg_bridge`、`whisper_bridge`、`source_storage`、`sources`、`mobile_ai_playback`、`metadata_background`（仅 Android，带隔离数据库参数）。`player_window_test`、`ui_screenshots_test` 和 `assistant_movie_flow_test` 只在 macOS 运行。

Android 的 FFmpeg 与 whisper.cpp 桥接需要先构建预编译静态库，否则 CMake 退回 stub，`ffmpeg_bridge_test` 与 `whisper_bridge_test` 会因 `available == false` 失败：

```sh
export ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/<版本>
for abi in arm64-v8a armeabi-v7a x86_64; do
  (cd ../ffmpeg-package && bash tool/build_ffmpeg.sh android-$abi)
  (cd ../package-whisper && bash tool/build_whisper.sh android-$abi)
done
rm -rf ../ffmpeg-package/android/.cxx ../package-whisper/android/.cxx  # 丢弃旧的 stub 配置
```

## 验证记录

### 剧集自动匹配回归（真实 SMB + TMDB）

`metadata_matching_test.dart` 从 seed JSON 读取 VM 的 `/movie` SMB 连接和 TMDB 令牌，
在临时目录导入配置和存储图片，媒体库使用内存数据库，不修改共享文件或用户媒体库。

```sh
make integration-metadata DEVICE=<iOS 模拟器 UDID>
# 不传 DEVICE 时使用 macOS；seed 模板默认是 debug-seed.json。
```

需要 seed 中存在一个地址以 `/movie` 结尾的 SMB 源、有效的 TMDB 令牌，
以及共享中的 `Modern Family Season 1…` 文件夹（第一季 24 集）。缺失配置或服务不可用会失败，不跳过。

测试覆盖英文、中文两种刮削语言下的整季自动识别、旧版 `ambiguousMatch` 任务自动重试、
24 集归到同一部剧和同一季、剧集和季保持 TMDB 身份、海报和分集缩略图下载，
以及队列再次运行不重复搜索。额外用固定 TMDB 响应验证两个完全相同的原名仍需用户选择；
该负面用例不依赖线上目录是否恰好存在重名条目。

2026-11-21 在 iPhone 17 Pro 仿真机（iOS 26.5）用上述命令验证，3 项全部通过。
英文、中文各自完整识别 24 集；固定同原名冲突用例保留 `awaitingSelection`。
`flutter test test/metadata` 同次验证为 76 项通过、2 项需显式启用的用例跳过；
此次未执行 Android 或 macOS 的新增集成用例。

2026-11-18，服务在本机测试 VM（192.168.1.107），测试素材带静音音轨：

| 平台 | 设备 | 结果 |
| --- | --- | --- |
| macOS | Mac Studio | `make integration-macos` 全部通过：14 项（1 项仅 Android 跳过）、`player_window_test` 2 项、`assistant_movie_flow_test`（`qwen3:14b`，连续 3 次首轮通过，每次 3–4 分钟） |
| iOS | iPhone 17 Pro 模拟器，iOS 26.5 | 15 通过（含 9 个远程源），`metadata_background` 仅 Android 而跳过 |
| Android | Medium_Phone 模拟器，API 37，arm64-v8a | 16 全部通过（含 9 个远程源） |

已知问题：iOS 与 Android 上 VLC 经网络（HTTP，含应用的本地网关与 Plex 等直连）播放**无声**视频时，进度停在 0.25 秒不再推进，随后结束；本地文件和 macOS 不受影响，带音轨的视频经同一 SMB 网关在 Android 上正常播放。与 MP4 的 moov 位置无关（faststart 版本表现相同）。测试素材原本无音轨，移动端远程源测试因此全部失败；现已为 `test/fixtures/test_video.mp4` 加入静音 AAC 音轨，无声视频的网络播放问题仍未修复。

## 播放恢复与真实语音回归

`playback_recovery_test.dart` 使用真实 VLC 与测试进程内的 HTTP 服务，不需要 VM 或模型服务，覆盖：

- 12 秒 A → 5 秒 B → A：检查时长、尺寸、进度推进和 B 的实际结束事件，避免仅以 open 返回成功判断切换。
- A → 损坏 MP4 → B：要求损坏文件上报错误，随后有效媒体正常播放。
- HTTP 服务返回 503 → 恢复服务 → 重新打开同一 URL：检查实际失败请求、错误事件和恢复后的进度。这验证服务不可用后的手动重试；尚不覆盖播放中物理断网、系统网络切换或自动重连。
- 无音轨 MP4 经 HTTP 播放：必须持续推进并正常结束，不跳过 iOS/Android 已知缺陷。该缺陷修复前，移动端的集成套件可能因此失败，应保留失败证据。

```sh
flutter test -d macos integration_test/playback_recovery_test.dart
flutter test -d macos integration_test/whisper_bridge_test.dart \
  --dart-define=ASR_MODEL_DIR="$HOME/.cache/openplayx-asr-models"
```

`whisper_bridge_test.dart` 除引擎与非法模型检查外，还使用已知英文语音检查真实识别关键词 `quick brown fox`、语言、音频时长及字幕片段时间戳的顺序和边界。优先读取 `ASR_MODEL_DIR` 中 SHA-256 校验通过的 tiny 模型；移动端无法读取构建机目录时，在测试临时目录下载模型清单中固定校验值的约 78 MB 模型，失败直接报错，结束时清理。下载超时 5 分钟、识别超时 2 分钟，不使用个人模型配置。此用例不验证字幕保存、绑定或音频提取，完整保存与播放绑定仍由电影流程测试覆盖。

新增素材及来源见 [`test/fixtures/README.md`](../test/fixtures/README.md)。本节描述测试断言；跨平台实际执行结果应另行记录，不能沿用上方历史验证结果。

### 本次新增用例的执行记录（2026-11-18）

基于主应用 `64bc8bb` 加未提交工作区修改执行（包含本次测试和执行前已有修改），仅运行上述两个测试文件，不代表整个集成套件通过：

| 场景 | macOS arm64，27.2.1 | Android 模拟器 arm64，API 37 |
| --- | --- | --- |
| 不同媒体切换 | 通过 | 通过 |
| 损坏媒体错误状态与恢复 | 失败：实际为 `ended` | 失败：实际为 `ended` |
| HTTP 503 错误状态与重试 | 失败：实际为 `idle` | 失败：实际为 `idle` |
| 无音轨 HTTP 播放 | 通过 | 失败：停在 0.25 秒后结束 |
| 原生 Whisper 引擎与非法模型 | 通过 | 通过 |
| tiny 模型真实英文识别及时间戳 | 通过，读取宿主机校验模型 | 通过，下载并校验模型 |

macOS 与 Android 的最终恢复用例均确认损坏文件后可重新播放 A/B、HTTP 服务恢复后可重新播放；错误状态断言仍失败，不将重试成功记为整项通过。iOS 本次未执行新增用例。`flutter analyze --no-pub integration_test/playback_recovery_test.dart integration_test/whisper_bridge_test.dart` 无问题，`git diff --check` 通过。

Android 运行命令：

```sh
flutter test --no-pub -d emulator-5554 \
  integration_test/playback_recovery_test.dart \
  integration_test/whisper_bridge_test.dart --reporter expanded
```

macOS 同样指定这两个文件，并传入上文的 `ASR_MODEL_DIR`。新增失败断言已接入 Makefile 的平台集成测试入口；修复原生错误状态和移动端无音轨播放之前，相关入口会报告失败。
