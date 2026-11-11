# AI 聊天前端

依据 `design/tech/ai_chat_frontend.md`，并沿用 AI 交互、前端设计系统和 LangChain 集成文档的职责划分。

## 已接入

- `flutter_chat_ui 2.12.0`、`flutter_chat_core 2.9.1` 负责有界、惰性消息列表。`FlyerChatAdapter` 只投影宿主记录；模型与工具仍由 `ConversationCoordinator` / `ToolGateway` 执行。
- Shad 主题映射、Lucide 图标、自定义多行输入及 Markdown renderer。Markdown 使用 `flutter_markdown_plus`，代码块可横向滚动，图片不自动加载，HTTP(S) 外链需用户确认。
- 首页先展示媒体与建议问题，发送后进入完整聊天；页头可返回媒体内容。其他页面用窄屏 Sheet / 桌面侧面板，共享会话和草稿，可展开至首页。首页没有重复悬浮按钮。
- 桌面 Enter 发送、Shift+Enter 换行，输入法组合阶段 Enter 不发送；手机使用按钮发送。回复中可编辑下一条草稿，并停止当前回复。
- 流式更新合并为约 40ms 刷新，始终更新同一消息 ID。向上阅读不追随新消息；历史分页由 Flyer 保持位置，面板展开按消息 ID 与偏移恢复锚点。
- SQLite 为历史和每会话草稿的本地存储。原 `assistant_turns` 表增量迁移，旧消息补齐持久 ID；新建与切换会话均显式执行。恢复中的回合标记中断，不重放工具。
- 每次加载 40 回合；模型上下文从持久化完整回合按预算读取，与界面已加载数量无关。
- 宿主工具结果展示为状态、媒体/来源列表、部分失败和内联确认卡片。结果限制 20 项，已有分页信息提示继续查询。模型自行输出的 JSON 始终为普通文本。
- 媒体播放重新检查资源与来源，经现有播放入口执行；多版本须明确选择。收藏通过现有媒体库服务执行。
- 确认绑定回合、助手消息及调用 ID，显示宿主提供的媒体标题；原始参数和凭据不进入卡片。重复模型调用 ID 在不同轮次仍有不同的卡片与确认身份。
- 停止后取消请求截止计时器并拒绝晚到事件。纯文本失败可建立新回合重试，包含工具调用的回合没有可能重复副作用的重试按钮。

## 现有能力边界

当前宿主没有附件上传、语音、字幕生成等长任务后端，因此未增加这些入口。卡片不会编造任务进度。上下文显示现有页面快照，尚未加入业务层没有提供的目标固定功能。TV 遥控交互尚未验证。

## 验证

```sh
flutter test test/ai test/features/app_shell_test.dart test/features/design_system_test.dart
flutter analyze lib test/ai test/features/app_shell_test.dart test/features/design_system_test.dart
flutter build macos --debug --no-pub
```

前端测试使用 Fake 模型与内存数据库，覆盖流式身份、取消晚到事件、输入法、草稿共享、历史迁移/分页、确认防重复、真实宿主卡片、部分失败、阅读锚点、明暗主题、大字体与 RTL。

可选预览采用实际组件与打包字体，使用示例媒体，不发送模型请求：

```sh
flutter test test/ai/chat_preview_test.dart \
  --dart-define=OPENPLAYX_CHAT_PREVIEW_DIR=/tmp/openplayx-chat-preview
```
