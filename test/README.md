# 单元测试与 Widget 测试

`test/` 是 Flutter/Dart 默认的测试目录，主要存放能够快速执行的单元测试、Widget 测试及小型测试素材，用于验证业务逻辑、界面状态和交互行为。

## 一般存放什么

| 内容 | 用途 |
| --- | --- |
| 单元测试 | 验证模型、业务规则、状态转换、服务逻辑等，不需要启动完整应用 |
| Widget 测试 | 在 Flutter 测试环境中构建页面或组件，模拟点击、拖动等操作，检查界面和状态是否符合预期 |
| Fake、Mock 和辅助工具 | 替代原生播放器、网络或文件访问等外部依赖，让测试可控且不依赖真实设备 |
| `fixtures/` | 小型、自有或允许分发的测试数据和媒体素材，也可供原生集成测试复用 |

新增测试文件使用 `_test.dart` 后缀。按被测代码的功能组织目录，文件名说明被测对象，例如 `features/player/player_page_test.dart`，避免继续使用含义宽泛的 `widget_test.dart`。

## 当前内容

```text
test/
├── README.md
├── features/
│   └── player/
│       └── player_page_test.dart
└── fixtures/
    └── test_video.mp4
```

- `player_page_test.dart`：使用模拟播放后端，验证播放器页面的按钮状态、取消选择、暂停、错误恢复、进度条交互和后端释放调用，不启动真实 VLC。
- `test_video.mp4`：原创的约 12 秒、160×90 无声 H.264 测试视频，供原生集成测试使用；生成工具位于主项目的 `tool/generate_test_video.swift`。

## 元数据测试

`metadata/` 使用临时目录、内存数据库与模拟 Provider，验证 NFO 安全导入、字段合并与锁定、作品候选确认、季集关系、来源权限、缓存配额和宽窄屏操作。不会访问个人目录、个人凭据或真实 TMDB。

## 运行方式

在主项目根目录运行：

```bash
# 自动发现并执行 test/ 中的测试
flutter test

# 只运行播放器页面测试
flutter test test/features/player/player_page_test.dart
```

## 与其他测试的边界

- 需要真实 libVLC、原生插件或平台构建环境的测试放在 [`integration_test/`](../integration_test/README.md)。
- 从应用外部模拟完整用户流程的端到端测试、跨平台系统验收和回归报告，放在独立的 `openplayx-test` 仓库。
- Widget 测试通过只能说明被覆盖的页面逻辑正确，不能据此认定真实音视频已经正常输出。

真实 TMDB 联调为显式启用的测试，运行时读取被 Git 忽略的 `.env` 中的 `TMDB_READ_ACCESS_TOKEN`，不通过编译参数携带令牌：

```sh
flutter test --no-pub test/metadata/tmdb_live_test.dart \
  --dart-define=OPENPLAYX_TMDB_LIVE_DIR=/tmp/openplayx-tmdb-live
```

输出真实图片解码报告、隔离的测试数据库和宽窄屏截图；不修改用户的媒体库或读取私人视频。默认测试套件不会联网运行此项。

## AI 助手测试

`flutter test test/ai` 覆盖模型事件适配、有限工具循环、Schema 校验、UI 确认、取消与预算、操作去重和持久化、密钥轮换、多来源搜索、过期播放会话及共享会话界面。SDK 协议测试只访问本地 HTTP/SSE 替身，不调用真实云服务或使用个人 API Key。真实供应商能力通过应用设置中的三项独立连接测试按需验证。
