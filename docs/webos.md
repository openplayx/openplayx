# LG webOS TV 客户端（实验版）

OpenPlayX 提供可侧载的 webOS Web 应用。当前是 **局域网电视客户端**：
电脑上的 OpenPlayX 负责媒体库、数据源访问和播放进度，电视通过自身的 HTML5
播放器直接播放。它不是完整 Flutter App 的原生移植，也不提供电视端独立扫描、
SMB 登录、AI、FFmpeg 转码或 whisper 识别。

目标为 **webOS 6.x（2021）及更新版本**，最低浏览器引擎为 Chromium 79。
已进行当前桌面 Chrome 的浏览器测试，尚未完成 LG 真机或 webOS 模拟器验收。
更旧版本不在当前支持范围。编解码器、容器、HDR、音轨和字幕支持取决于电视；
本版只有 Direct Play，不会自动转换不能播放的格式。

## 打包与安装

需要 Node.js 和 [LG webOS CLI](https://webostv.developer.lge.com/develop/tools/cli-installation)。
从 Flutter App 仓库根目录执行（不是上一级多仓库目录）：

```sh
npm install -g @webos-tools/cli@3.2.6
./tool/build_webos.sh
```

生成 `build/webos/com.openplayx.app_0.0.1_all.ipk`。
也可以通过脚本第一个参数指定输出目录。此步骤不依赖 Flutter 编译。
CI 的 webOS 独立任务也会生成 `openplayx-webos-experimental` 构建产物。

在电视上安装并开启 LG Developer Mode，按
[LG 真机测试说明](https://webostv.developer.lge.com/develop/getting-started/developer-mode-app)
登录开发者账户、开启 Key Server，并配置自己的电视：

```sh
ares-setup-device
ares-novacom --device tv --getkey
ares-install --device tv build/webos/com.openplayx.app_0.0.1_all.ipk
ares-launch --device tv com.openplayx.app
```

`tv` 是在 `ares-setup-device` 中填写的设备名称。Developer Mode 的有效期及续期
以电视提示为准。这是开发者侧载包，未提交 LG 商店。

## 首次使用

1. 在 macOS、Windows 或 Linux 的 OpenPlayX 中打开 **设置 → Web 播放**。
2. 选择局域网网卡，开启服务，选择已扫描的媒体库文件夹作为分享范围。
3. 电视和电脑连接同一局域网，在电视 App 中输入电脑端显示的地址，例如
   `http://192.168.1.10:8090`，然后选择“连接媒体库”。
4. 输入电脑端显示的六位配对码，浏览和播放已分享的媒体。

启动器仅保存上次的服务地址，每次打开可修改并确认连接。电脑离线或地址变更时，
退出并重新打开电视 App 修改地址。地址只接受 HTTP 私有 IPv4 根地址，与现有
LAN 服务的监听规则一致。电脑端重启服务会使旧配对失效，需要重新输入配对码。

启动器使用 `location.replace` 进入电脑端的 HTTP 页面；不使用 iframe，也不从
`file:` 页面跨域调用 API。LG 的打包 Web 应用不支持 Cookie，而 hosted HTTP
页面支持 Cookie，因此认证继续使用现有 HttpOnly 同源 Cookie 和配对机制。
源密码、文件路径和 Cookie 均不写入启动器存储。网络传输仍为 HTTP，请使用可信局域网。

## 遥控器

- 方向键移动焦点，确定键激活按钮。输入框左右键保留给文本编辑。
- 播放器使用电视专用按钮，焦点限制在播放界面内，支持播放、暂停、停止及媒体键。
- 聚焦时间轴后，左右键按十秒预览，确定提交，返回取消预览。
- 播放中返回退出播放器并恢复原媒体按钮焦点；首页返回显示退出确认。
- Magic Remote 指针同样可点击按钮。时间轴通过方向键操作。
- App 转入后台时暂停播放。播放进度沿用电脑端媒体库同步和续播机制。

普通浏览器可用电脑端服务地址后加 `/?tv=1` 预览电视界面；LG webOS User-Agent
也会自动启用电视界面。普通桌面和手机浏览器保留原界面。

## 验证

```sh
flutter test test/capabilities/web_playback \
  test/features/settings/web_playback_settings_page_test.dart

# 指定本机 Playwright Core ES module；Chrome 路径可通过 CHROME_PATH 覆盖。
OPX_PLAYWRIGHT_MODULE=/absolute/path/to/playwright-core/index.mjs \
  flutter test test/capabilities/web_playback/web_playback_browser_test.dart
```

浏览器测试启动真实 Dart 服务，以 fixture 媒体完成配对、播放、跳转和进度保存，
并检查启动器地址校验/记忆、电视方向键、焦点隔离、跳转确认/取消、返回和退出确认。
截图位于 `build/web-playback/webos-library.png` 和 `webos-player.png`。
测试不会把桌面 Chromium 伪装 User-Agent 等同于真实 Chromium 79 或 LG 硬件验证。

真机验收仍需覆盖：Developer Mode 安装、从打包页面跳转到 hosted 页面后的
Cookie/返回键行为、软键盘与 Magic Remote、1080p/4K 安全边距、媒体硬解码、
后台/恢复以及电脑离线后的退出重开。

## 相关实现与平台依据

- [现有 LAN 服务与限制](implement/web_playback.md)
- `webos/`：打包启动器、manifest 和由既有品牌图标缩放的图标。
- `lib/capabilities/web_playback/web_playback_tv_assets.dart`：电脑端托管的电视界面。
- [LG Web 引擎版本](https://webostv.developer.lge.com/develop/specifications/web-api-and-web-engine)
- [LG 应用类型与 hosted 页面](https://webostv.developer.lge.com/develop/getting-started/web-app-types)
- [LG 返回键处理](https://webostv.developer.lge.com/develop/guides/back-button)

LG 的 [Flutter SDK 公告](https://webostv.developer.lge.com/news/flutter-for-webos-tv-is-now-available-for-developers)
将原生 Flutter TV 支持限定在 webOS 26 Re:New 及以后版本。独立原生移植需要另行
适配播放、存储、平台插件和打包工具链，不是给现有 Flutter 工程增加一个平台名称。
