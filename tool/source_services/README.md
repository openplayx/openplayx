# 临时媒体源服务

为 SMB、WebDAV、FTP、SFTP、S3、Plex、Jellyfin、Emby、DLNA 各起一个只读的临时测试服务，素材都是 `test/fixtures` 里的测试视频。

## 在本机运行

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

DLNA 服务使用 host 网络（SSDP 和媒体地址都需要本机真实地址），只能在 Linux 上运行；macOS 的 Docker Desktop 不支持，本机测试时 DLNA 会失败。

## 在局域网测试机上运行

把 `tool/source_services/` 和 `test/fixtures/` 按相同相对路径复制到测试机，在测试机上：

```sh
BIND=0.0.0.0 HOST_IP=<测试机地址> docker compose -f tool/source_services/compose.yaml up -d
```

然后在开发机上执行（`SOURCE_HOST` 写进 `defines.local.json`，probe 和集成测试都会用它）：

```sh
SOURCE_HOST=<测试机地址> python3 tool/source_services/bootstrap.py
dart run tool/source_services/probe.dart          # 可只跑部分：probe.dart webdav ftp
flutter test integration_test/sources_test.dart -d macos \
  --dart-define-from-file=tool/source_services/defines.local.json
```

## 服务与端口

| 类型 | 端口 | 地址 / 账号 |
| --- | --- | --- |
| SMB | 445 | `smb://HOST/media`，`openplayx` / `test-only-password` |
| WebDAV | 18080 | `http://HOST:18080/media`，同上（rclone） |
| FTP | 2121，被动 30000–30009 | `ftp://HOST:2121/media`，同上（rclone） |
| SFTP | 2222 | `sftp://HOST:2222/media`，同上（rclone） |
| S3 | 19000 | `http://HOST:19000/media`，Access Key `openplayx`，Secret `test-only-password`（rclone） |
| Plex | 13240 | `http://HOST:13240`，免登录 |
| Jellyfin | 18096 | `http://HOST:18096`，`openplayx` / `test-only-password` |
| Emby | 18097 | `http://HOST:18097`，同上 |
| DLNA | 8200 | `http://HOST:8200/rootDesc.xml`（MiniDLNA，host 网络） |

镜像按 digest 固定。SMB 使用标准 445 端口，若机器上已有文件共享服务，请换一台测试机，不要停止已有服务。媒体素材只读挂载，Jellyfin、Plex、Emby 的配置在容器 tmpfs 里，重建后需要重新 bootstrap。Plex 在这个独立临时容器中允许免登录访问，仅供测试。

`bootstrap.py` 创建 Jellyfin 和 Emby 测试账号，初始化 Jellyfin、Plex、Emby 的视频库并等待扫描完成，生成被 git 忽略的 `defines.local.json`。此文件包含临时令牌，不要提交。

`probe.dart` 是不依赖 Flutter UI 的协议验证：逐个服务浏览到测试视频，比较完整视频和非零偏移 Range 的字节内容，并列出媒体服务器的“最近添加”。原生集成测试另外验证 libVLC 视频尺寸、播放进度、暂停和 Seek。没有传入服务配置时，集成测试只运行本地源，其余测试明确跳过。服务配置与 probe 共用 `integration_test/support/source_services.dart`。
