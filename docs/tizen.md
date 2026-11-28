# 三星 Tizen TV 客户端（实验版）

三星智能电视主要使用 **Tizen**。OpenPlayX 新增本地打包的 Tizen Web 客户端，
目标为 **Tizen 6.5（2022）及更新版本**。该代 Web 引擎为 Chromium 85；
更旧平台不在当前支持范围，型号与引擎版本见
[三星官方规格](https://developer.samsung.com/smarttv/develop/specifications/web-engine-specifications.html)。

当前通过同一局域网内的电脑端共享媒体库工作，需要 macOS、Windows 或 Linux
上的 OpenPlayX 保持运行。电视端使用 HTML5 video 直接播放，支持情况取决于
电视的容器与音视频解码能力。尚未接入 AVPlay、DRM、转码、独立扫描或 AI。

## 准备与签名

从 Flutter App 仓库根目录执行：

```sh
python3 tool/build_tizen.py --prepare-only
```

生成以下文件：

- `build/tizen/widget/`：完整 Tizen Web 工程资源，包括 `config.xml`。
- `build/tizen/OpenPlayX-tizen-unsigned.zip`：未签名的资源归档，**不能直接安装**。

CI 的 `openplayx-tizen-unsigned-sources` 产物提供同样的资源。构建会复用
webOS 启动器和 Dart 服务内的电视 HTML/CSS/JS，避免维护两套媒体库和播放器界面。
Tizen 界面和脚本全部打包在电视本地，联网时不下载脚本。

安装需要 [Tizen Studio 和 TV Extension](https://developer.samsung.com/smarttv/develop/getting-started/setting-up-sdk/installing-tv-sdk.html)，
包括 Web CLI 和 Samsung Certificate Extension。先在 Certificate Manager 中
创建或导入自己的 Samsung 证书配置，并为目标电视配置 Distributor 证书及安装权限。
详见 [Samsung 证书说明](https://developer.samsung.com/smarttv/develop/getting-started/setting-up-sdk/creating-certificates.html)。

使用已配置的证书名称签名（示例名称为 `OpenPlayXTV`）：

```sh
python3 tool/build_tizen.py --profile OpenPlayXTV
```

若 CLI 未添加到 PATH，可指定位置：

```sh
python3 tool/build_tizen.py --profile OpenPlayXTV \
  --cli /path/to/tizen-studio/tools/ide/bin/tizen
```

成功后生成 `build/tizen/OpenPlayX.wgt`。脚本在临时副本上签名，不修改源码资源。
当前开发环境没有 Tizen Studio 或 Samsung 证书，因此这里只生成了未签名资源包；
签名和安装流程尚未在本机执行。

## 电视安装与使用

按 [三星真机调试说明](https://developer.samsung.com/smarttv/develop/getting-started/using-sdk/tv-device.html)
开启 Developer Mode，设置开发电脑地址、连接电视并允许安装。使用 `sdb devices`
查看设备名称，将下面的 `YOUR_TV` 替换为自己的 target 名称：

```sh
tizen install --target YOUR_TV --name OpenPlayX.wgt -- build/tizen
tizen run --target YOUR_TV --pkgid OpenPlayX1.OpenPlayX
```

包 ID 为 `OpenPlayX1`，应用 ID 为 `OpenPlayX1.OpenPlayX`。
也可以在 Tizen Studio 中导入 `build/tizen/widget/` 后使用图形界面构建和安装。
完整命令依据 [三星 TV CLI](https://developer.samsung.com/smarttv/develop/getting-started/using-sdk/command-line-interface.html)。

1. 电脑端进入 **设置 → Web 播放**，选择局域网网卡、开启服务并选择已扫描的分享文件夹。
2. 在电视 App 输入电脑端显示的 HTTP 私有 IPv4 地址，例如 `http://192.168.1.10:8090`。
3. 输入电脑端六位配对码，浏览和播放媒体；播放进度同步到电脑端媒体库。

启动器记忆服务地址；令牌仅放在本次应用会话的 sessionStorage 中。
变更电脑地址会清除旧地址关联的令牌，避免向另一台电脑发送旧令牌。
点击界面左上角品牌可回到连接设置。重启电脑端服务后需要重新配对。

## 遥控器与平台差异

方向键、确定键、返回键控制焦点。三星返回键代码 `10009` 与播放/暂停键 `10252`
已适配，也兼容只提供 keyCode 的按键事件。媒体键逐一注册；某个型号不支持某键
时，仍继续注册其余按键。未注册或拦截长按 Exit，保留系统强制退出行为。

聚焦时间轴后，左右键按十秒预览跳转，确定提交，返回取消。播放界面限制焦点，
返回关闭播放并恢复媒体按钮焦点。首页返回显示退出确认，确认后调用
`tizen.application.getCurrentApplication().exit()`。

三星 [不允许 hosted 应用使用 Tizen API](https://developer.samsung.com/smarttv/develop/faq/hosted-applications.html?device=htv)，
因此本地 widget 不会像 webOS 启动器那样跳到电脑端页面，也不使用 iframe。
普通三星浏览器仍能打开电脑端服务地址，自动启用电视界面；浏览器环境缺少原生
API 时不能保证媒体键注册和原生退出，请使用电视界面按钮及系统退出操作。

## LAN 接口

本地 widget 使用独立的 `/tv-api/` 配对和 Bearer 认证接口，不发送浏览器 Cookie。
文件页面的 Origin 序列化为 `null`；该值本身不是身份凭证，配对码及随机令牌才是。
仅该接口接受 opaque Origin 的 CORS 请求，且不允许携带 Cookie 凭证。
现有 `/api/` 浏览器接口保持同源限制，浏览器 Cookie 与电视令牌相互不可用。

媒体元素不能设置 Authorization 请求头，因此每个已授权播放会话使用单独随机的
`/tv-media/` 能力 URL，仅能读取该会话的媒体，不可用于浏览、删除会话或更新进度。
撤销分享、注销、服务重启、设备过期和会话回收会使其失效。分享范围、数据源可见性、
请求体限制和配对限流沿用 LAN 服务。源密码与真实路径不进入电视端。

传输仍为 HTTP，仅面向可信局域网。`config.xml` 的网络 access 允许动态电脑地址，
启动器及播放器配置均验证 HTTP 私有 IPv4 地址；脚本和样式使用本地 CSP。

## 验证与验收范围

```sh
flutter test test/capabilities/web_playback \
  test/features/settings/web_playback_settings_page_test.dart

OPX_PLAYWRIGHT_MODULE=/absolute/path/to/playwright-core/index.mjs \
  flutter test test/capabilities/web_playback/web_playback_browser_test.dart
```

浏览器测试会先准备 widget，在实际 `file:` 页面与真实 Dart 服务之间完成 CORS
预检、配对、流读取、跳转、进度同步和注销，同时回归 LG、桌面和手机界面。
Tizen API 在浏览器中由测试替身提供，用于验证媒体键注册和退出调用，不能代替硬件。
截图输出至 `build/web-playback/tizen-*.png`。

尚待真机验收：Samsung 证书签名与侧载、Tizen 本地文件 Origin 和 WARP 行为、
真实遥控器与软键盘、音视频硬解码、后台暂停/恢复及系统强制退出。
