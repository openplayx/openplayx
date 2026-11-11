# sing-box + frp 远程来源访问

对应设计：`design/tech/remote_access_singbox_frp.md`。本次实现采用设计中“先完成浏览与播放前路径选择”的顺序；真实跨境网络仍需验收。

## 已实现

- 原生 Go core 固定 sing-box 1.12.12，`go.sum` 锁定依赖；通过 C ABI 暴露 start/stop/内存分配。只注册 VLESS、direct 出站与本地 DNS，生产入口仅接受开启校验的 VLESS TLS/REALITY。没有 TUN、系统 VPN、frp visitor、P2P 或独立 Rust core。
- Go 每个实例创建一个随机回环 TCP 端口，目标固定为 VPS 回环映射端口。停止会取消拨号并关闭监听、现有套接字与 sing-box；日志关闭，不返回含配置的上游异常文本。Dart 使用受引用计数管理的实例，不把临时端口保存为媒体身份。
- Android 的 NDK 构建打包 arm64-v8a、armeabi-v7a、x86_64 三种动态库；macOS/iOS 的本地 Pod 编译 Go 静态归档并强制链接 C ABI；Linux/Windows 的 CMake 构建动态库。Apple 系统信任、应用生命周期和局域网权限继续由平台管理。
- `SourceConfig.remoteAccess` 保存线路/家庭/服务引用、两条路径、连接模式和凭据引用。导入配对后 outbound UUID/TLS 配置存入 `flutter_secure_storage`，不复用原有媒体凭据的 SQLite 存储。来源 ID、媒体资源 ID、字幕关系和进度保持原有身份。
- Jellyfin/Emby 的用户名密码认证，以及 Jellyfin/Emby/Plex 的浏览、搜索、元数据、图片、附件和视频，都经相同的 `SourceHttp` 连接上下文；视频仍经宿主 StreamGateway 暴露给 libVLC。Plex 可使用手动服务器 token 配对；官方账户发现流程仍保留原有行为。
- HTTP 连接工厂先创建受控原始套接字，HTTPS 再显式 `SecureSocket.secure(host: logicalHost)`，保留 SNI、主机名与证书校验，不将 HTTPS 明文发送进隧道。只允许已选来源 origin，不跟随带凭据重定向。
- SMB 在该来源的 Zone 内注入 Socket.connect，把依赖固定的 445 连接转交给本机随机隧道端口；不会修改依赖、全局套接字或其他来源。当前 SMB 仅支持远程模式，保留来源认证与媒体网关，不承诺通过 NTLM 自动确认陌生局域网服务身份。
- 自动模式先对显式配置的 HTTPS 局域网端点做无凭据探测，系统 TLS 验证与已配对 SHA-256 指纹都成功才使用。每条实际局域网连接也再次检查指纹，然后才允许 HTTP 发送凭据。失败/身份不匹配回退至独立配对的远程入口；仅局域网模式不启动 relay。
- 同来源并发探测合并，结果保持 30 秒作为稳定与退避窗口；回到前台使探测缓存失效，前台持续使用时最长 30 秒后重新评估。新请求可换路径，已建立视频保留租约。401、403、404 不触发自动重试或路径轮换。
- 来源表单提供配对 JSON 导入与连接模式；中英文/简繁体界面已补齐。配对说明要求用户确认同服务绑定关系；失败导入清理临时密钥，成功旋转和移除来源清理旧密钥。

## 部署工程

配套 [openplayx-relay](https://github.com/openplayx/openplayx-relay) 与 [openplayx-home](https://github.com/openplayx/openplayx-home) 固定 sing-box 1.12.12 / frp 0.65.0。

relay 创建单家庭配对、两类 VLESS 身份、私有 frps TLS 身份；媒体映射与 frps 控制端口只绑定 VPS 回环。home 强制经过本机 SOCKS5，确认入口就绪再启动 frpc。Linux/systemd 安装器包含下载 SHA-256 校验、上游配置检查、证书副本权限、更新前版本备份、原子切换与失败恢复、显式回退、保留数据的卸载。所有凭据均由部署环境保存。

当前是单家庭/多服务实例，App 身份可访问该家庭的全部分配映射。多家庭、多用户的每服务 ACL/凭据与 frp 登录隔离不在此默认配置中。不要用共享 token 实现多租户。

## 构建和检查

开发环境需要 Go 1.24+、C 工具链、Flutter；Android 还需要 Flutter 固定的 NDK，Apple 需要 Xcode/CocoaPods。无需安装外部 sing-box App。

```bash
flutter analyze --no-pub
flutter test --no-pub test/data/remote_access test/data/sources test/features/sources
cd native/remote_access
./build.sh
# 原生并发/关闭测试
 go test -race -tags with_reality,with_utls ./...
```

`build.sh` 默认输出 macOS 开发用 dylib；Linux 设置相应输出文件名，Windows 的 Go c-shared 构建需要 MinGW-w64。App 构建通过 Pod/Gradle/CMake 自动完成库构建。构建会下载 go.sum 固定的 Go 依赖，不把二进制提交到仓库。

已完成 macOS debug/release App、Android debug APK（三 ABI）、iOS arm64 模拟器构建；检查 macOS release 包含四个 C ABI 导出、APK 包含各 ABI 动态库。Apple 链接配置显式保留并导出 FFI 符号，防止 release dead stripping。Linux/Windows 未做实际构建；iOS 真机/后台、各 NAS 厂商和 systemd 主机尚未验收。

2026-11-11 验证：`flutter analyze --no-pub` 无问题；完整 `flutter test --no-pub` 为 223 项通过、5 项按环境条件跳过；home 5 项、relay 6 项 Python 测试通过；Go `-race` 测试通过。

本机链路测试命令位于 relay 的 `tests/e2e.py`：运行真实 sing-box、frpc、frps、测试媒体服务和本 App 编译出的 C ABI 库，验证媒体认证、Host、Range、用户/端口 ACL 和禁止家庭直连回退。配置检查由固定版本上游程序执行；两个部署仓库还各有配置/凭据/版本锁测试。

## 后续验收与明确边界

- 先通过真实 VPS + 家庭 NAS 的配置和网络验收；当前默认是 VLESS/TLS，不是可用性承诺。REALITY 客户端支持已编译，但 relay/home 默认生成器没有自动发放 REALITY 服务配置，需另选并实测协议部署。
- 自动 LAN 当前要求 HTTPS + 系统信任 + 显式证书指纹；纯 HTTP/SMB 的自动 LAN 服务配对身份尚未实现。证书轮换要通过可信渠道更新指纹，不能关闭校验。
- 断开中的视频不会自动跨端点拼接字节或续建媒体服务器转码会话；播放器保留既有进度记录，用户重新打开时可走新路径并使用现有续播。已有会话保持路径，新会话重新选择。后续恢复需要资源长度/版本一致性验证和会话级取消，不应直接重放任意 Range 到新端点。
- App 设置页与 Relay/Home Web 管理、权威 JSON 和显式应用流程已补齐，见 [三端配置管理](remote_access_configuration.md)。备用线路目前支持保存和手动切换；自动备用线路切换、服务端动态授权和长期跨境稳定性测试尚未实现。更换线路时保留来源及稳定引用。

上游许可证和命名条款保留于 `native/remote_access/LICENSE`，完整 GNU GPL v3 文本见 `COPYING`。这会影响包含内核的 App 分发，发布流程须保留对应源代码、构建信息与许可声明。

配置管理补充实现与验证边界见 [remote_access_configuration.md](remote_access_configuration.md)。
