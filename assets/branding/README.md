# OpenPlayX 应用图标

采用设计仓库 `design/assets/icon/` 中的 J 橙色 X 方案，保留黑底和播放三角形留白。字标颜色未修改。

- `app_icon.png`：4096 × 4096 不透明正方形母版。
- `app_icon_foreground.png`：4096 × 4096 透明前景，用于 Android 自适应图标。

在 macOS 的 Flutter 工程根目录运行以下命令，重新生成各平台资源：

```sh
swift tool/generate_app_icons.swift
```

生成范围：iOS/macOS AppIcon 资源集、Android 启动图标与自适应前景、Windows 多尺寸 ICO、Linux GTK 默认窗口图标、Web favicon 与 PWA 图标。母版只用于构建资源，不作为 Flutter 运行时图片资产加载。

iOS 和普通 Android/PWA 图标使用不透明正方形；macOS/Windows/Linux 生成透明外角的圆角黑底版本。Android 和 PWA 的自适应图标额外保留安全边距。

重新构建应用后生效。桌面或启动器可能缓存旧图标；必要时退出旧应用后重启或重新安装新构建，不需要删除应用业务数据。
