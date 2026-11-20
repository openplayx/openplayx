# 百度网盘文件源

## 接入范围和已核实资料

VidHub 的[官方挂载教程](https://zh.okaapps.com/blog/655b02cc948009206c562f6b)
说明“文件源 → 添加文件源 → 添加百度网盘 → 网页登录 → 挂载个人资源”；
[官方新手教程](https://zh.okaapps.com/blog/672c5a0e4a8410481012329f)
说明登录后选择全部文件、添加并返回媒体库。这些资料只用于确定体验范围，
没有公开其鉴权协议；本实现没有使用 VidHub 的应用参数、凭据或品牌素材。

本应用采用百度开放平台授权码流程及只读 xpan 接口：

- [授权码接入文档](https://pan.baidu.com/union/doc/al0rwqzzl)
- [目录列表](https://pan.baidu.com/union/doc/nksg0sat9)
- [文件元信息](https://pan.baidu.com/union/doc/Fksg0sbcm)
- [下载流程](https://pan.baidu.com/union/doc/pkuo3snyp)
- 百度发布的 [Go SDK](https://github.com/baidu-netdisk/baidu-drive-sdk-go/tree/main/baidudriver/api)
  中的 `auth_code2token.go`、`file_list.go`、`download_meta.go`、
  `download_file.go` 和 `transport.go` 可核对请求字段、fs_id、dlink、
  access_token 查询参数和 `pan.baidu.com` 下载 User-Agent。
- [百度账号 OAuth 说明](https://tongji.baidu.com/api/manual/Chapter2/openapi.html)
  及[百度网盘 MCP 的授权接口](https://github.com/baidu-netdisk/mcp/blob/main/src/baidu-netdisk/openapi_client/api/auth_api.py)
  说明 refresh_token 换取新令牌的接口。

调研时网盘文档页面未能直接加载，接口实现同时核对了百度发布的 SDK。
SDK 示例不等于当前应用已获权限，也不能证明 VidHub 使用相同协议。

## 用户操作

1. 插件/文件源管理中添加 **百度网盘**，点击“使用浏览器登录”。在系统浏览器
   中登录百度账号并授权，取消登录不保存凭据。
2. 登录后默认选择 `/`，表示账号授权范围内的全部文件。也可打开目录，将当前
   目录设为根目录；“返回上级”回退选择，“选择全部文件”重新选择账号根目录。
3. 保存连接，在连接下添加文件来源并扫描。扫描递归分页读取视频文件，进入
   既有媒体库和刮削队列，不另建媒体库。默认扫描扩展名和手动扫描策略与其他
   文件源一致；音频等项目也遵循现有扩展名策略。
4. 从媒体库或文件浏览器播放。播放器接收本地临时流地址，百度 token 和下载
   链接不写入播放器历史或媒体资源引用。Range/拖动通过既有 loopback 网关转发。
5. 授权失效后编辑连接，重新点击浏览器登录并保存。成功刷新会立即更新系统
   安全存储；无法刷新的授权会明确提示重新授权。
6. “断开账号”或删除连接会清除系统安全存储中的本地凭据并停止此账号请求。
   禁用连接保留凭据。平台授权的撤销还需在百度账号/网盘授权管理中解除。

目录选择限制的是 OpenPlayX 的访问范围，不改变百度授权范围。保存的资源使用
稳定 fs_id；每次操作重新检查文件当前位置，文件移到所选目录之外即不可访问。
“全部文件”仅指百度实际授予本应用访问的个人文件，不代表可以绕过权限读取全盘。

## 发布方配置

**必须使用 OpenPlayX 发布方自己的百度应用**。发布方需要在百度网盘开放平台
注册应用，完成平台要求的身份认证、审核及目录读取/下载等权限申请。
是否获准访问全盘、真实下载和播放能力，应以该应用控制台及百度审核结果为准。
没有应用参数或服务端配置时，此功能明确显示当前构建未配置；不降级为抓 Cookie、
粘贴 token 或借用其他应用密钥。注册/权限尚未落实时不能宣称真实账号接入验收通过。

授权码换 token 需要应用 SecretKey。原生程序不能保密该密钥，因此配套实现位于
独立 `api` 仓库的 `src/baidu-oauth.js`，由现有 Worker 入口分派。服务端环境：

| 参数 | 用途 |
| --- | --- |
| `BAIDU_CLIENT_ID` | 本应用的 AppKey |
| `BAIDU_CLIENT_SECRET` | 本应用 SecretKey，只经服务端密钥管理配置 |
| `BAIDU_OAUTH_ORIGIN` | 服务端 HTTPS origin，无路径和尾随 `/` |

例如 origin 为 `https://api.example.com` 时，在百度后台注册的回调必须是
`https://api.example.com/v1/oauth/baidu/callback`。服务端只允许固定原生回调
`com.openplayx.app://oauth/baidu`；现有 Android 回调 activity 和 iOS/macOS
系统认证会话已处理该 scheme。本次没有变更部署配置或设置任何真实密钥。

客户端仅配置公开参数：

```sh
flutter build macos --debug \
  --dart-define=BAIDU_CLIENT_ID=YOUR_OWN_PUBLIC_APP_KEY \
  --dart-define=BAIDU_OAUTH_BROKER=https://api.example.com/v1/oauth/baidu
```

客户端与服务端 AppKey 必须一致。不要给客户端设置 SecretKey。
原生登录复用 OneDrive/Dropbox 的 macOS、iOS、Android 平台支持；
Windows/Linux/Web 的原生云盘登录仍受现有平台实现限制。

桥接的授权状态为 5 分钟 AES-GCM 加密封装，回调换成 60 秒有效的加密授权码票据，
然后回到原生会话。客户端必须提供原始 PKCE verifier 才能换 token；
票据中的百度授权码由上游一次性消费，不在服务端长期存储用户 token。
PKCE 是 **OpenPlayX 客户端到桥接服务**的保护，未假定百度支持 PKCE。
后台刷新同样经桥接服务完成。限制流量、HTTPS、固定回调、no-store 响应和错误
脱敏在服务端实现；部署时应禁止记录请求体、token、完整回调查询串和上游凭据。

## 错误和限制

- 断网、超时或服务端不可达：网络错误；允许重试。
- token 过期/无效：合并同账号并发刷新，失败时提示重新授权；账号隔离沿用现有实现。
- API 权限拒绝、缺失 dlink 或下载持续 403：提示检查账号权限、下载权益及应用获批权限。
  播放前会发起最小 Range 探测，以便在交给播放器之前显示原因。
- 下载链接过期：重新获取链接并重试一次。只向百度 HTTPS 域名请求下载，
  不把访问 token 转发给任意重定向域名。
- 百度套餐、带宽、下载限制、地区和文件风控均由平台决定；本实现不承诺会员速度，
  不绕过权限，也不提供转码接口或写入功能。
- 播放过程中才出现的新限制会终止上游流；回到文件页重新播放可重新执行权限探测。

## 验证和待验收

新增 `test/data/sources/baidu_source_test.dart`，覆盖 OAuth 配置与回调校验、
完整 API 页与下一页、中文/大文件、根目录范围、失效 token、安全存储/退出、
扫描入媒体库、权限和网络反馈、下载重试、Range/UA 和恶意重定向。
`api/test/baidu-oauth.test.js` 覆盖完整桥接、PKCE、状态封装篡改/过期、取消、
刷新、错误脱敏、体积及速率限制。均使用 mock，不需要真实账号。

调用方执行 Flutter 受影响单元测试及 `api` 的 `npm test`，然后按既有流水线检查、
提交和推送。本次工作树修改不执行这些 git 状态变更。真实账号/设备待验收：

- 发布方应用、回调和权限获批后，在 macOS/iOS/Android 完成登录、取消与重新授权。
- 分别选择全部文件和多层中文目录；超过 200 个文件的目录分页及扫描。
- 视频进入既有刮削/媒体库后播放、拖动与恢复；长期 token 刷新及重启恢复。
- 非会员/受限文件、撤销授权、断网、退出时播放中断及多账号隔离。

这份清单不表示上述真实账号验收已完成。
