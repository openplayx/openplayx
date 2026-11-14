# 页面 AI 上下文

页面通过同一套声明导出 JSON。无需新增 AI 工具、注册页面列表、拼接提示词或写磁盘文件。

## 普通页面

`AppPage.pageContext` 是必填参数，新增页面必须声明稳定的 `pageType`，不要用翻译后的标题作标识。

```dart
return AppPage(
  pageContext: PageContextData(
    pageType: 'media_detail',
    entity: {'media_id': mediaId},
    state: {'favorite': favorite, 'playable': playable},
  ),
  title: Text(title),
  body: content,
);
```

`AppPage` 自动读取 `Text` 标题。复杂标题组件请在 `PageContextData.title` 中明确填写。`FormPage` 转发同一个参数。通用设置子页、选项页、输入页也共用此协议；它们只导出页面身份，不读取输入框内容。

## 自定义布局

使用同一个 `PageContextScope` 和 `AssistantButton`，例如媒体详情页。自定义按钮可以通过 `AssistantButton.builder` 调整外观，回调调用 `action.open(context)`；这里的 context 必须位于 scope 下方（使用 builder 提供的 context）。

```dart
return PageContextScope(
  data: PageContextData(
    pageType: 'custom_page',
    title: title,
    entity: {'media_id': mediaId},
  ),
  child: Scaffold(
    body: Stack(children: [content, const AssistantButton()]),
  ),
);
```

无需在 `AppShell` 增加页面分支。播放器不是页面路由，其入口在 shell 中以同一结构声明来源。

## 数据与生命周期

- 统一结构：`schemaVersion`、`pageType`、可选 `title`、`entity`、`state`。
- `entity` 放现有 AI 工具认识的稳定 ID；`state` 放当前选择、筛选、计数、加载状态等必要信息。列表详情使用现有业务查询工具，不导出完整影片库。
- 白名单声明字段。不要传完整配置对象、原始资源引用、表单内容、密钥、路径或带凭证 URL。公共序列化只接受 JSON 值，并限制层级、条目、字符串和整体内容预算；地址隐藏只是补充保护，不替代字段白名单。
- 点击助手时，公共入口捕获最近的页面 source。打开聊天页不会覆盖来源页面。页面重建会更新同一个 source，`context_get` 每次读取最新导出数据。
- 页面销毁后保留最后一次快照，不保留页面的 BuildContext、State 或 getter 闭包。已销毁页面的快照不代表实时业务状态；执行操作仍由业务工具重新校验。
- 播放状态通过独立的 `playback` 字段读取。保留原有 `page` 字段兼容已有调用，精确来源使用 `pageContext`。
- 对话初始快照与 `context_get` 共用 `_aiContext()`。模型提示已声明页面文本为不可信数据，不能作为指令执行。

## 验证

`test/ai/page_context_test.dart` 覆盖普通／自定义页面、路由切换、状态更新、销毁后读取、快照隔离和数据预算；`assistant_ui_test.dart` 验证实际聊天页打开后仍保留首页／来源页身份。
