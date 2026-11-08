# OpenPlayX

Flutter + libVLC 的基础本地播放器。打开本地视频或音频，体验播放、暂停和进度跳转。

## 在 macOS 运行

```bash
flutter pub get
flutter run -d macos
```

首次构建自动通过 CocoaPods 下载 VLCKit，不需要单独安装 VLC 桌面应用。

共用播放接口支持接入 Android、iOS、macOS、Windows、Linux；当前主要验证 macOS。**Web 播放暂不支持**，浏览器打开时仅显示不支持提示，不创建播放器。后续 Web 支持需另行设计配套服务及能力边界。

## 验证

```bash
flutter analyze
flutter test
flutter test integration_test/playback_test.dart -d macos
```

[libVLC 接入、平台配置与验证记录](docs/implement/libvlc_basic_player.md)

## 媒体源

播放器右上角的“媒体源”支持添加、编辑、删除独立的本地文件夹、SMB、Plex 和 Jellyfin 实例；打开源后可逐级浏览、分页加载并选择文件播放。Plex 使用服务器 URL 与 X-Plex-Token；Jellyfin 使用服务器 URL、用户 ID 与访问令牌/API Key；SMB 使用 `smb://主机/共享名/可选目录`、用户名、密码和可选域（标准 445 端口）。编辑时密码或令牌留空保留原凭据。

宿主通过类型化 `SourceCapability.browse/resolve` 路由到四个内置插件，校验实例归属和目录范围。配置与凭据分开保存，凭据使用系统安全存储。SMB 通过有界随机读取提供本机 HTTP Range 流，Plex/Jellyfin 通过本机认证代理提供直接播放流，临时 URL 不包含远端凭据；切换媒体和退出播放器时释放播放句柄。媒体服务器的多个版本/分段作为独立文件供选择，不自动拼接；暂未实现转码、服务发现、账号交互式登录或观看进度回写。

macOS 使用系统目录选择器与安全作用域书签恢复文件夹访问；Android/iOS 的文件夹源目前仅限应用可访问的普通目录，单文件仍可使用“打开文件”（含 Android content URI）。其他平台尚需各自的原生验收。协议与集成测试说明见 [临时服务说明](tool/source_services/README.md)。

SMB 客户端当前支持 SMB 2.0/2.1，不支持仅允许 SMB 3.x 的共享。macOS 的网络 MP4/M4V/MOV 使用 avformat 解复用，避免原生 MP4 路径播放时间停留在 250ms 的问题；已用真实服务验证 MP4 的播放进度和 Seek。
