# Debug 配置预加载（seed）

测试时不用在 App 里逐项手填：写一份 JSON 模板，凭据放 `.env`，生成一份可直接用的 seed，App 在 debug / profile 构建启动时导入。release 构建不会读取。

## 文件

| 文件 | 说明 | 提交 |
|---|---|---|
| `tool/debug_seed.example.json` | 模板示例，覆盖所有段 | 是 |
| `debug-seed.json` | 你的模板（从示例复制） | 否（已 gitignore） |
| `.env` | 模板里 `${VAR}` 的取值 | 否（已 gitignore） |
| `build/debug-seed.json` | 生成的 seed，凭据已填入 | 否 |

`.env` 支持 `KEY=VALUE`、`#` 注释、`export` 前缀、单引号或双引号（双引号里可用 `\"` `\\` `\n`）。同名的系统环境变量也会被使用，`.env` 优先。缺少任何变量时 `make seed` 直接报错并列出变量名。

## 用法

```sh
cp tool/debug_seed.example.json debug-seed.json   # 首次：按需修改
make seed                                          # 生成 build/debug-seed.json
```

改完 seed 或 `.env` 后先检查一遍：

```sh
make seed-check
```

它用 App 自己的代码把 seed 导入一个临时配置库（不碰 App 里的配置），然后逐项真实连接：每个媒体源和文件源都浏览一次目录，外部服务做 MCP 握手并列出工具，TMDB token 和模型 API Key 各发一个免费的只读请求（模型还会确认 `model` 在服务端的模型列表里）。任何一项不可用都会失败并给出原因。需要能访问 seed 里的服务。

把 seed 交给 App，二选一：

| 方式 | 命令 | 适用 |
|---|---|---|
| 启动时带入 | `make run-seeded [DEVICE=<flutter 设备 id>]` | 任何平台、任何设备，经 `flutter run` 启动 |
| 推进已安装的 App | `make seed-push PLATFORM=macos\|ios-sim\|android\|linux\|windows` | 已装好的 debug 版，下次启动导入 |

`seed-push` 写入的位置（App 支持目录下的 `debug-seed.json`，导入后改名为 `debug-seed.applied.json`）：

| 平台 | 位置 |
|---|---|
| macOS | `~/Library/Application Support/com.openplayx.openplayx/`（debug 构建未开沙盒） |
| iOS 模拟器 | `xcrun simctl get_app_container booted com.openplayx.openplayx data` 下的 `Library/Application Support/` |
| Android | 应用的 `files/`，经 `adb push` + `run-as`，需 debuggable 构建；多台设备用 `ANDROID_SERIAL` 选择 |
| Linux | `$XDG_DATA_HOME`（默认 `~/.local/share`）`/com.openplayx.openplayx/` |
| Windows | `%APPDATA%\com.openplayx\openplayx\` |

iOS 真机没有可写入的位置，用 `make run-seeded`。

## 导入规则

- 在 `main()` 里、界面启动前导入，各段经设置页使用的同一套存储写入 `configuration.sqlite3`。
- 所有条目按固定 `id` 新增或更新，重复导入不会产生重复项。
- 同一份 seed（内容 hash 相同）只导入一次；改了内容才会再导入，并覆盖对应条目，包括你在 App 里改过的同一条目。
- 单个条目失败不影响其他条目；结果打印在日志里：`[debug-seed] applied N: …; failed M: …`。

## 各段

| 段 | 内容 | 说明 |
|---|---|---|
| `sources` | 媒体源；字段同 `SourceConfig`，凭据写 `secret` | 本地文件夹需要用户授权，不能导入 |
| `fileSources` | `id`、`source`（媒体源 id）、`root`、`name`、`enabled` | 导入后不会自动扫描 |
| `scanExtensions` | 扫描的文件后缀 | |
| `externalServices` | `id`、`name`、`baseUrl`、`token` | 先存为未检查，App 启动后自动探测 MCP 端点和工具 |
| `asr` | `id`、`kind`、`name`、`url`、`modelId`、`language`、`allowInsecureHttp`、`uploadConsent`、`token` | `uploadConsent: true` 视为已同意上传音频 |
| `assistant` | `endpoint`、`model`、`cloudAllowed`、`toolsSupported`、`maxTokens`、`apiKey` | |
| `metadata` | `language`、`tmdbToken` | |
| `remoteAccess` | `pairing`：Relay 导出的 App 配置（JSON 对象或字符串） | |
| `appearance` | `themeMode`、`language`、`developerMode` | |
| `diagnostics` | `true` / `false` | |

不需要的段直接省略。
