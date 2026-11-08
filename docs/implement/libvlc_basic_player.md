# libVLC 基础播放体验

实现日期：2026-11-08。Flutter 3.47.9 / Dart 3.13.7。

## 功能与入口

启动应用后点击“打开文件”，选择本地视频或音频。打开后自动播放，可以暂停、继续、拖动进度条，更换文件或播放结束后重播。取消选择保留当前媒体；加载失败时可以重新选择。应用隐藏或进入后台时暂停，恢复前台后手动继续。

这是一个最小本地播放体验，不包含媒体库、播放列表、网络媒体输入或业务插件系统。

## 依赖与结构

- `packages/playback`：本地 Flutter 包 `openplayx_playback`，封装 `vlc_player ^2.1.2`。实际安装版本由根目录 `pubspec.lock` 固定为 2.1.2。
- `lib/features/player/player_page.dart`：共用 Flutter 页面，只依赖 `PlayerBackend`、`PlayerSnapshot` 和 `PlayerVideoView`，不直接使用 VLC 插件类型。
- `lib/data/files/local_media_picker.dart`：通过 `file_selector ^1.1.0` 调用系统文件选择器，实际安装版本为 1.1.0。
- `lib/main.dart`：应用入口和平台支持判断。

播放链路：页面 → `PlayerBackend` → `LibVlcBackend` → `VlcPlayerController` → 各平台 libVLC。视频由插件原生视图或纹理输出，Dart 不搬运视频帧。

最小调用位于播放包：

```dart
await controller.setMedia(
  VlcMediaSource(uri: uri),
  autoPlay: true,
);
```

页面销毁时释放控制器。播放包的 `dispose()` 可以重复调用。

## VLCKit 状态适配

实际测试发现 macOS VLCKit 默认启用播放结尾暂停，因此播放器使用 `--no-play-and-pause` 获取正常结束事件，同时忽略用户 VLC 配置。播放开始后，VLCKit 仍可能上报缓冲事件；适配器将缓冲作为独立字段保留，不因此禁用暂停。结束事件之后紧随的 stopped 事件保留“播放结束”状态；重播重新加载同一媒体。

## 各平台配置

| 平台 | 底层依赖 / 配置 | 验证边界 |
| --- | --- | --- |
| macOS | CocoaPods 集成 VLCKit 3.7.3；Debug/Profile 和 Release 启用用户所选文件只读权限 | 本机验证，详见下方测试结果 |
| iOS | CocoaPods 集成 MobileVLCKit 3.7.3；插件要求 iOS 13+，项目现有部署版本满足要求 | 未实机验证，需配置签名及设备/模拟器 |
| Android | 插件集成 libVLC；应用 `minSdk` 设为 29 | 未构建验证，本机 Android 工具链仍需完善 |
| Windows | 插件在构建时下载并打包 VLC 运行库 | 未构建验证，需 Windows 构建环境和网络 |
| Linux | 系统安装 `libvlc-dev`、`vlc`，插件通过 pkg-config 链接 | 未构建验证，需 Linux 构建环境 |
| Web | 明确标记为暂不支持；应用入口显示专用提示，播放包拒绝创建 Web 播放器 | 不提供 Web 播放功能 |

`file_selector` 的 Android 实现会读取所选文件数据并复制到缓存，本体验尚未优化大文件选择和缓存清理。Android 大视频接入前需替换为流式文件访问或内容 URI 授权桥接。桌面端直接使用系统选择器返回的本地文件引用。

当前明确暂不支持 Web 播放，已撤回试装但未使用的 `video_player` 依赖。应用入口为 Web 显示专用提示，`LibVlcBackend.isSupported` 返回 false，构造器也会拒绝在 Web 创建实例。后续如支持 Web，需另行设计浏览器前端与配套服务，以补齐文件访问、下载、协议接入和必要的转码能力，并明确浏览器仍存在的编码与输出限制；本阶段不接入仅浏览器端的播放后端。

## 执行过的命令

最初在工程根目录安装依赖：

```bash
cd /Users/zyl/codes/mygithub/openplayx/openplayx
flutter pub add vlc_player file_selector
```

随后将 VLC 依赖移入 `packages/playback/pubspec.yaml`，根工程改为通过 path 依赖 `openplayx_playback`；添加 Flutter SDK 自带的 `integration_test` 开发依赖后执行：

```bash
flutter pub get
dart format lib packages/playback/lib test integration_test
flutter analyze
flutter test
flutter test integration_test/playback_test.dart -d macos
```

macOS 构建及日常启动命令：

```bash
flutter build macos --debug
flutter run -d macos
```

首次 macOS 构建会执行 `pod install` 并下载 VLCKit；不需要另装 VLC 桌面应用。当前插件使用 CocoaPods，不支持 Swift Package Manager，Flutter 会提示并回退至 CocoaPods。

## 验证

- 静态分析通过。
- 三个 Widget 测试覆盖取消文件选择、暂停与释放、命令失败后的重试、拖动结束后只提交一次 Seek。
- 原生集成测试将仓库内原创的 12 秒 160×90 H.264 MP4 复制到应用沙箱，无外部媒体和网络依赖，验证视频尺寸、进度、暂停、Seek、更换媒体、结束后重播及释放。该测试使用无声视频，不代表已人工确认音频输出。测试素材约 29 KB，由 `tool/generate_test_video.swift` 使用 macOS AVFoundation 生成。
- 集成测试独立验证原生引擎，不依赖测试窗口能否自动切到前台；应用页面自身仍保留后台暂停策略。
- 最终验证：`flutter analyze`、三个 Widget 测试、一个 macOS 原生集成测试及 `flutter build macos --debug` 均通过；已实际启动普通应用，通过系统文件选择器打开测试 MP4，确认画面正常显示、页面显示“正在播放”及 12 秒时长。

## 重新生成原创测试视频

仅 macOS 需要此生成步骤，其他平台直接使用已提交的 MP4 素材。输出文件必须尚不存在，可以指定新的路径：

```bash
swift tool/generate_test_video.swift /tmp/openplayx-test-video.mp4
```

## 参考

- [vlc_player 包及平台要求](https://pub.dev/packages/vlc_player)
- [file_selector](https://pub.dev/packages/file_selector)
- [VLC 运行库分发说明](https://github.com/lingjhf/vlc_player/blob/main/THIRD_PARTY_NOTICES.md)

发布应用时需同时遵循所打包 VLC/VLCKit 运行库的开源分发要求，插件自身的许可证不替代运行库许可证。
