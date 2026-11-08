# Flutter 项目初始化记录

初始化日期：2026-11-08。

## 环境与项目

- 工程路径：`/Users/zyl/codes/mygithub/openplayx/openplayx`
- Flutter：`3.47.9`，`stable` 通道。
- Dart：`3.13.7`。
- 项目名称：`openplayx`。
- 模板：Flutter 默认应用模板，保留计数器示例及其 Widget 测试。
- 生成平台：Android、iOS、macOS、Windows、Linux、Web。
- 当前组织标识：`com.openplayx`；应用标识为 `com.openplayx.openplayx`（组织标识加项目名）。

本次使用电脑上已安装的 SDK，没有执行 Flutter 升级。初始化前目标目录仅包含已有的 `.git/`，直接在该目录创建工程，没有额外嵌套项目目录。

初始化后执行以下命令核对实际 SDK 版本，输出为上述版本；与此前环境检查时的 Flutter 3.44.1 不同，本记录以本次实际使用的版本为准：

```bash
flutter --version
```

## 实际执行的初始化命令

在终端进入项目目录后执行：

```bash
cd /Users/zyl/codes/mygithub/openplayx/openplayx
flutter create --project-name openplayx .
```

参数说明：

- `--project-name openplayx`：明确 Dart 包名及项目名称。
- `.`：在当前目录生成工程。
- 未指定 `--platforms`，由当前 SDK 默认生成上述六个平台工程。

`flutter create` 已自动解析和下载依赖，生成 `pubspec.lock`，因此本次没有另外执行 `flutter pub get`。

## 实际执行的验证命令

在工程根目录运行：

```bash
flutter analyze && flutter test
```

验证结果：

- `flutter analyze`：`No issues found!`。
- `flutter test`：默认的 `Counter increments smoke test` 通过，`All tests passed!`，共 1 个测试。

以上验证覆盖 Dart 静态分析和默认 Widget 测试；本次未执行各平台构建或启动应用。

## 组织标识调整

初始化后根据项目要求，将模板默认组织标识改为 `com.openplayx`，同步修改 Android 的 namespace、applicationId、Kotlin 包声明和源码目录，iOS/macOS 应用与测试的 Bundle ID，Linux APPLICATION_ID，以及 Windows/macOS 的公司和版权信息。

当前应用标识为 `com.openplayx.openplayx`，测试 Bundle ID 为 `com.openplayx.openplayx.RunnerTests`；Android 入口位于 `android/app/src/main/kotlin/com/openplayx/openplayx/MainActivity.kt`。

随后按要求在当前工程实际执行了重新初始化命令，直接由 Flutter 模板生成该组织标识的配置，保留 `.git/` 和 `docs/`：

```bash
cd /Users/zyl/codes/mygithub/openplayx/openplayx
flutter create --overwrite --org com.openplayx --project-name openplayx .
flutter analyze && flutter test
```

`--overwrite` 会覆盖已有模板文件，适用于本次重置初始工程；已有业务代码的工程使用时应先备份。重新初始化后检查确认各平台无旧组织标识残留，iOS/macOS 工程文件通过 `plutil -lint` 检查。

如需从空目录创建相同组织标识的新工程，可使用以下命令：

```bash
flutter create --org com.openplayx --project-name openplayx .
```

## 后续常用命令（本次未执行）

```bash
# 依赖发生变化或重新拉取工程后安装依赖
flutter pub get

# 在浏览器运行
flutter run -d chrome

# 在 macOS 桌面运行
flutter run -d macos
```

此前的 `flutter doctor -v` 检查显示 Web 和 macOS 开发环境通过；Android 缺少 SDK Command-line Tools，许可证状态未确认；iOS 缺少模拟器运行时。对应平台运行前需补齐环境。
