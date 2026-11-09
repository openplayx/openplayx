# OpenPlayX

Flutter + libVLC 的基础本地播放器。打开本地视频或音频，体验播放、暂停和进度跳转。

## 在 macOS 运行

```bash
flutter pub get
flutter run -d macos
```

首次构建自动通过 CocoaPods 下载 VLCKit，不需要单独安装 VLC 桌面应用。

macOS 默认窗口为 1280×800，较小屏幕会自动缩到可用区域内；媒体源添加弹窗宽度为 520。调整默认窗口后需重新启动应用。

共用播放接口支持接入 Android、iOS、macOS、Windows、Linux；当前主要验证 macOS。**Web 播放暂不支持**，浏览器打开时仅显示不支持提示，不创建播放器。后续 Web 支持需另行设计配套服务及能力边界。

## 验证

```bash
flutter analyze
flutter test
flutter test integration_test/playback_test.dart -d macos
```

[libVLC 接入、平台配置与验证记录](docs/implement/libvlc_basic_player.md)

## 媒体源

播放器右上角的“媒体源”支持本地文件夹、SMB、Plex 和 Jellyfin，名称可留空自动生成：

| 来源 | 添加方式 | 按需填写 |
| --- | --- | --- |
| 本地文件夹 | 点击“选择文件夹”并授权 | 自定义名称 |
| SMB | 地址、用户名、密码；访客访问时账号密码都留空 | “高级”中的工作组、共享/子目录路径；端口固定 445 |
| Jellyfin | 地址、用户名、密码 | “高级”中的 HTTPS、端口、反向代理子路径 |
| Plex | 浏览器登录 Plex，选择可访问服务器 | “高级”保留手动服务器连接方式 |

可直接粘贴完整服务器 URL。SMB 只填主机时先浏览共享列表；Jellyfin 自动取得用户 ID 和访问令牌；Plex 不要求用户自行提取 Token。编辑时登录字段留空保留当前登录，更换 Jellyfin 服务器或账号时重新认证。

宿主通过类型化 `SourceCapability.browse/resolve` 路由到四个内置插件，校验实例归属和目录范围。配置与凭据分开保存，凭据使用系统安全存储。SMB 通过有界随机读取提供本机 HTTP Range 流，Plex/Jellyfin 通过本机认证代理提供直接播放流，临时 URL 不包含远端凭据；切换媒体和退出播放器时释放播放句柄。媒体服务器的多个版本/分段作为独立文件供选择，不自动拼接；暂未实现转码、服务发现、账号交互式登录或观看进度回写。

macOS 使用系统目录选择器与安全作用域书签恢复文件夹访问；Android/iOS 的文件夹源目前仅限应用可访问的普通目录，单文件仍可使用“打开文件”（含 Android content URI）。其他平台尚需各自的原生验收。协议与集成测试说明见 [临时服务说明](tool/source_services/README.md)。

SMB 客户端当前支持 SMB 2.0/2.1，不支持仅允许 SMB 3.x 的共享。macOS 的网络 MP4/M4V/MOV 使用 avformat 解复用，避免原生 MP4 路径播放时间停留在 250ms 的问题；已用真实服务验证 MP4 的播放进度和 Seek。

## 数据源实例配置管理

媒体源页可查看插件/配置版本、修订、连接及凭据状态，启停实例、编辑逻辑来源绑定、设置能力默认实例。添加表单只显示连接和登录信息，不暴露版本、修订、逻辑 ID、并发或索引等管理参数。后台仍保留实例策略与版本校验，编辑连接不会重置既有访问范围及扫描策略；手动扫描预览仍可从媒体源列表使用。禁用不清空配置，删除前展示活动播放及绑定影响。

配置以 SQLite 为唯一权威源，首次访问自动迁移旧 shared preferences 配置；密码/令牌仍保存在系统安全存储。保存使用修订检查避免覆盖其他窗口的修改；修改或禁用实例后，当前播放使用原连接完成，新操作按新配置处理。尚无搜索/后台索引能力的插件不会提供可开启的设置。详细边界和测试见 [实现说明](docs/implement/source_instance_configuration.md)。
