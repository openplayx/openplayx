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
