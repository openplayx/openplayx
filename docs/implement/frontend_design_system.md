# 前端设计系统接入

依据工作区 `design/ui/frontend_design_system.md`，对现有 Flutter 前端统一接入 shadcn_ui。没有创建尚未实现的 AI、搜索、任务或插件界面入口。

## 分支

- 将 `feature/media-library` 合入本地 `dev`，合并提交为 `10a1ddd`。
- 从更新后的 `dev` 创建 `feature/frontend-design-system`。
- 不自动推送远端；工作区中其他任务的改动保留。

## 实现

- `app/app.dart` 使用官方支持的 `ShadApp.custom → MaterialApp → ShadAppBuilder` 结构。仅 MaterialApp 管理应用主导航，分支 Navigator 保留原页面栈。
- `app/theme/` 集中提供中性背景、青绿色强调、明暗主题、字体及必要的 Material 基础设施映射。控件使用 Shad 主题；没有提供旧版 Material 视觉开关。
- `AppThemeController` 通过现有配置服务的 `settings` 表保存主题和语言。启动读取失败不阻止打开应用；保存失败在设置页明确显示。主题和语言修改不创建新的播放后端、SourceManager 或媒体库服务。
- `ui/tokens/` 提供间距、圆角、尺寸、动效及额外状态色和播放器覆盖层颜色。Geist 随组件包发布，中文使用系统字体回退，不运行时下载字体。
- `ui/icons/app_icons.dart` 集中声明业务语义与 Lucide 图标映射，导航与业务控件不再使用散布的 Material Icons。
- `AppSidebar` / `AppBottomBar` 统一导航模型和选中语义。600 以下使用底栏、600–839 使用紧凑侧栏、840 起使用完整侧栏；大字体时按有效可用宽度回退布局。
- `AppPage` 页头允许动作换行。`ContentRow` 明确适配键盘焦点和悬停表面；海报卡片、设置分组和内容状态有可复用的业务组件。
- 首页、媒体库、来源、来源配置、默认来源设置和播放器操作统一使用 Shad 按钮、输入、选择、开关、卡片、进度、弹窗、Sheet、Alert 和 Toast。原有浏览、连接、入库和播放接口保留。
- 来源状态通过无 Widget 依赖的状态枚举和宿主呈现映射翻译；保留原服务的兼容文案接口。
- 播放器保持独立深色控件作用域。`PlaybackProgress` 以 ShadSlider 呈现，提供 48px 交互区域、连续预览、松手后一次 seek、可见焦点、键盘与读屏增减操作。
- 英文、简体中文、繁体中文使用 ARB / gen-l10n。应用和组件库共享解析后的 locale；针对 shadcn_ui 0.59 缺少的繁体中文内置文案，使用公开的本地化扩展点补齐。
- `/design-system` 为内部组件状态展示路由，不加入一级导航。

## 依赖

应用显式依赖 `shadcn_ui ^0.59.0`、`lucide_icons_flutter ^3.1.25`、Flutter 本地化及 `intl ^0.20.3`，并更新锁文件。Lucide 4.x 不符合当前 shadcn_ui 的依赖约束；不通过 dependency_overrides 强行安装。

## 验证

```sh
flutter analyze
flutter test
flutter build macos --debug
flutter test integration_test/playback_test.dart -d macos
```

- 应用测试覆盖来源管理、表单草稿与连接、媒体库扫描/筛选/收藏/移除、响应式导航状态、播放进度/倍速/音轨/音量、快捷键、旋转，以及主题与语言切换时的播放器身份和进度。
- 设计系统测试覆盖偏好持久化与读取/保存失败、繁体中文组件文案、320/700/1200 宽度、1.7 倍文字和 RTL。
- macOS 原生回归使用临时目录内的仓库测试素材，验证解码、暂停、seek、重新打开、重播、资源释放、视频旋转；同时验证主题切换及 Shad 弹窗打开/关闭保留同一个原生视频组件和暂停位置。不读取或修改用户媒体和偏好。

可重复导出四个主入口在手机/桌面、明暗主题下的 16 张页面预览：

```sh
flutter test test/ui_preview_test.dart \
  --dart-define=OPENPLAYX_UI_PREVIEW_DIR=/tmp/openplayx-ui
```

该导出测试默认跳过，显式开启后加载本地字体并检查真实页面组合，不把预览文件写入仓库。

## 边界

本次验证了 macOS 原生播放和 Flutter 层布局；Android/iOS 真机、其他桌面平台的原生视频层叠仍需在对应设备回归。RTL 检查针对布局，不代表已发布阿拉伯语等翻译。

外部服务及插件返回的异常 message 保持原业务行为；未来按插件/多语言设计引入结构化错误和插件私有翻译时，应由宿主解析文案。当前没有为此改写数据库、来源协议或播放后端。
