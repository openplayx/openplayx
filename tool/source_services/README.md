# 临时媒体源服务

从 Flutter 工程目录执行：

```sh
docker compose -f tool/source_services/compose.yaml up -d
python3 tool/source_services/bootstrap.py
dart run tool/source_services/probe.dart
flutter test integration_test/sources_test.dart -d macos \
  --dart-define-from-file=tool/source_services/defines.local.json
# 完成后清理本项目的容器、网络与临时配置
docker compose -f tool/source_services/compose.yaml down -v
```

镜像按 digest 固定。SMB 绑定 `127.0.0.1:445`，Jellyfin 绑定 `127.0.0.1:18096`，Plex 绑定 `127.0.0.1:13240`。SMB 使用标准 445 端口，若本机已有文件共享服务，请先换一台测试机，不要停止已有服务。媒体素材只读挂载，服务配置存放在容器 tmpfs；重建后需要重新 bootstrap。Plex 在这个独立临时容器中允许免登录访问，仅供本机测试。

`bootstrap.py` 创建 Jellyfin 测试账号（`openplayx` / `test-only-password`），初始化 Jellyfin 和 Plex 的个人视频库，等待素材扫描，并生成被 git 忽略的 `defines.local.json`。此文件包含临时令牌，不要提交。运行测试时需要本机 Python 3、Docker、Flutter 和 macOS 构建工具；其他设备需调整地址，设备中的 localhost 不是开发机。

`probe.dart` 是不依赖 Flutter UI 的协议验证：遍历三个真实服务，比较完整视频和非零偏移 Range 的字节内容。原生集成测试另外验证 libVLC 视频尺寸、播放进度、暂停和 Seek。没有传入服务配置时，集成测试只运行本地源，其余测试明确 skip。
