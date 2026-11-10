# 影视元数据与刮削

基于工作区 `design/tech/media_metadata_scraping.md` 实现本机 NFO 导入、TMDB 在线识别与人工纠错，复用现有媒体、资源、媒体库和来源实例。

## 分支

`feature/frontend-design-system` 已合入本地 `dev`，合并提交 `af0cedd`。本功能位于从该提交创建的 `feature/media-metadata-scraping`，未推送远端。

## 使用

1. 将本地文件夹或 SMB 范围绑定到影视库。扫描或手动入库后自动登记持久任务，已有媒体在启动时补齐队列。后台先导入邻近 NFO 和图片，再按需查询在线信息；家庭录像和音频不发送到影视查询服务。也可以在选中的库使用“导入全库影视信息”手动导入。
2. 点击媒体卡片进入详情，再点击“影视信息”。可以单独导入 NFO、刷新已关联作品、编辑并锁定标题/原名/年份/简介、恢复自动来源、选择和锁定海报、清理图片缓存、重置匹配。
3. 在线查询需在“配置 TMDB”填入个人 **API Read Access Token**（Bearer 读取令牌）。凭据进入现有系统安全存储；SQLite 仅保存元数据语言和配置修订。清空输入表示保留现有凭据，“移除 TMDB 凭据”会删除它。
4. 输入名称、可选年份或 TMDB ID，预览候选后确认。剧集文件先搜索剧集，再选季和集；不会直接采用搜索第一条。刷新只获取当前对象。来源为 Jellyfin/Plex 时使用同一来源实例的认证获取服务端详情和图片。

打开一个未入库的本机文件不授予其邻近目录权限，也不触发在线查询。配置 TMDB 后，入库的影视资源自动查询；本地 NFO 和播放不依赖 TMDB。

## 数据和权限

- `MetadataCapability` 统一搜索、详情、季集目录模型；`MetadataRegistry` 检查已注册动作并管理 NFO/TMDB 插件生命周期。Jellyfin/Plex 实现相同能力，通过 `SourceManager` 的现有实例运行时调用。
- `SourceAttachmentCapability` 为本地、SMB 和服务端提供有上限的附件读取。文件读取继续校验实例、授权路径、符号链接和文件类型；服务端图片只接受受限对象引用，不接受任意下载地址。不复用临时播放 URL 获取附件。
- `MediaNameParser` 保留原始名称、年份、SxxExx、多集候选、明确的中文数字季集和技术标签。规则版本和查询证据随任务保存；数字片名不强行解释为年份，不生成虚假分集 Seek 点。
- NFO 支持 movie/tvshow/season/episodedetails、标题、原名、年份、简介、类型、演员、导演、来源评分、外部 ID、编号、日期和安全的相对图片。大小限制 1 MiB，拒绝实体/DTD，限制嵌套、节点和字段长度。不导入观看状态，不读取 NFO 内远端图片 URL。
- 同名 NFO 优先。仅独占一个视频的电影目录使用 `movie.nfo` 和目录级图片；共用目录只使用精确关联文件。相互矛盾的外部 ID 进入待确认；损坏的一份侧车不阻止其他有效侧车导入。没有 NFO 时仍可导入明确关联的图片。
- 剧集 NFO 沿已授权、已绑定目录内查找 tvshow.nfo/season.nfo；明确的季号可创建季容器。只为已拥有的媒体建立层级，目录中其他剧集不生成资源。TMDB 对象 ID 与所属剧集 ID 分开保存，季集详情使用所属剧集和编号查询。
- SQLite schema 从 1 升至 2，在原数据库增加关联修订、观察、用户覆盖、展示投影、任务、历史、图片选择和本地层级表。v1 人工改过的文件标题迁移为锁定值。标题不参与作品去重；确认作品不会合并或删除资源。
- 字段选择顺序为用户锁定、服务端、NFO、在线、文件证据。空字段不删除已有有效值；作品不一致的旧观察不参与投影。评分保留 Provider 名称，影视片长不写入资源播放时长。
- 任务固定媒体修订、语言、凭据配置修订和来源修订，提交前重新校验。operationId 防止重复提交；相同内容重复导入不增加媒体修订。活动任务中断后标为 cancelled，等待确认的候选保留。可以重试单项或重新运行批量导入，成功条目独立保留。
- 图片由宿主检查 MIME/内容签名、20 MiB 体积和 4000 万像素解码上限，并以临时文件原子发布；最多两项同时加载。默认缓存配额 256 MiB，优先淘汰可再生图片，保护用户锁定的图片；清缓存保留数据库选择。TMDB 图片尺寸和 CDN 来自 `/configuration`，不在页面拼接固定 CDN 地址。
- TMDB 请求区分认证、未找到、限流和网络错误，采用有上限的重试、请求超时以及短时搜索/空结果缓存。图片配置或图片下载失败不回滚文字信息。关于页和元数据页展示 TMDB 官方标志和署名。

## 当前边界

自动在线匹配采用保守规则：标题或原名规范化后完全一致，文件名包含年份时年份也必须一致，结果页完整且唯一时才采用。多候选、模糊名称、身份冲突和多集文件保留待确认，不直接采用第一条。已关联媒体刷新同一对象，用户锁定的字段和图片继续保留。语言配置支持一个请求语言，暂未提供多语言回退编辑界面。

没有视频重命名、源目录写回、NFO 导出和观看进度回写。

## Android 自动刮削服务

Android 通过 WorkManager 启动独立 Flutter 后台引擎，入口为 `metadataCallbackDispatcher`，不依赖媒体库页面或前台定时器执行刮削。不使用常驻前台 Service：刮削是可延迟、可重试的有限任务，不需要一直显示通知。桌面端复用同一队列，在应用进程运行期间处理。

- SQLite schema v3 增加 `metadata_queue`，入库与任务登记一起提交。启动时为旧库补齐任务；扫描、手动加入、AI 调用等入口均经过媒体库服务。
- 本地导入和联网处理分别调度。联网任务要求网络连接、电量不低；每批最多 12 项或 3 分钟，剩余项目由系统重试。另有 15 分钟周期恢复任务，实际执行时间由 Android 决定。
- 前后台共享任务租约。进程退出后过期任务可重新认领，原持有者不能提交；配置、媒体修订变化或移出媒体库会使旧结果失效。每项暂时错误指数退避，最多尝试 5 次；认证错误等待更新配置，不无限重试。
- 凭据仅从系统安全存储读取，WorkManager 输入和队列表不保存令牌。开发 `.env` 不打包进 APK，真机仍需在应用内配置 TMDB。
- 媒体库和影视信息页监听提交事件，并检测后台连接写入的数据库变化，自动更新标题、封面和待确认状态。海报不存在时依次使用单集缩略图、背景图，再显示占位图；已选图片由后台下载到共享缓存。
- 划走页面不取消任务；系统强行停止应用后，需重新打开应用才能恢复系统调度。Doze、省电策略和厂商限制可能延后执行，不承诺固定开始时间。

原生集成验证使用隔离数据库和临时 NFO/图片，不加载个人媒体库或 TMDB 凭据：

```sh
flutter test integration_test/metadata_background_test.dart -d emulator-5554 \
  --dart-define=OPENPLAYX_METADATA_DATABASE=metadata_workmanager_test.sqlite3
```

该测试直接登记系统任务，不创建媒体库页面或应用协调器；检查系统返回成功、共享数据库标题更新以及图片已缓存。调度依据参见 [Android WorkManager](https://developer.android.com/develop/background-work/background-tasks/persistent)。

本次验证：静态检查无问题；全量测试 155 项通过、3 项按条件跳过；Android 模拟器原生后台集成测试通过；Android 调试 APK 与 macOS 调试应用均构建成功。未将这一离线原生测试视为 Android 真机 TMDB 联网验收，后者仍需在应用内配置读取令牌。

## 验证

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter build macos --debug --no-pub
flutter test --no-pub test/metadata/metadata_preview_test.dart \
  --dart-define=OPENPLAYX_METADATA_PREVIEW_DIR=/tmp/openplayx-metadata-preview
```

新增测试覆盖安全 XML、受限附件、同名/目录级冲突、重复导入、字段/图片锁定、过期查询、来源修订、任务幂等、播放数据保留、季集 ID/本地层级、服务器实例命名空间、图片缓存配额和宽窄屏编辑。线上测试使用模拟响应，不读取个人媒体或个人凭据。真实 TMDB、SMB、Jellyfin/Plex 服务器的联调需使用相应测试账号，未将单元测试结果视为线上服务验收。

TMDB 原始文档：[查询](https://developer.themoviedb.org/docs/search-and-query-for-details)、[图片配置](https://developer.themoviedb.org/docs/image-basics)、[署名](https://developer.themoviedb.org/docs/faq)。标志来自 [官方品牌页](https://www.themoviedb.org/about/logos-attribution)，SVG 仅将 CSS class 的 fill 内联以适配 Flutter SVG，路径、渐变、颜色和比例不变。

## 2026-11-10 真实 TMDB 联调

新增显式启用的 `test/metadata/tmdb_live_test.dart`：运行时读取本地 `.env` 的 `TMDB_READ_ACCESS_TOKEN`，使用生产 `TmdbTransport`、`MetadataService` 和 `ArtworkService`，验证搜索、确认、文字信息、真实 CDN 图片解码、季集层级与锁定后刷新。令牌不进入 dart-define、应用资源、数据库、报告或截图；普通 `flutter test` 跳过该联网测试。

```sh
flutter test --no-pub test/metadata/tmdb_live_test.dart \
  --dart-define=OPENPLAYX_TMDB_LIVE_DIR=/tmp/openplayx-tmdb-live

# 已有真实联调结果时，仅重绘界面，不重复请求线上服务。
flutter test --no-pub test/metadata/tmdb_live_test.dart \
  --dart-define=OPENPLAYX_TMDB_LIVE_DIR=/tmp/openplayx-tmdb-live \
  --dart-define=OPENPLAYX_TMDB_SCREENSHOTS_ONLY=true
```

用《星际穿越》《盗梦空间》《千与千寻》《沙丘》《蝙蝠侠：黑暗骑士》验证了中文标题/简介、500×750 海报和 780×439 背景图；用《绝命毒师》S01E01 验证了剧集 → 季 → 集及 300×169 缩略图。测试采用隔离的临时媒体库和虚拟资源定位，不访问用户的真实视频目录，不把联网测试结果写入用户媒体库。

此次验证补齐了详情页已选海报与背景图展示，媒体库改为适合竖版封面的卡片比例，图片候选先加载 12 张并支持继续加载。按图片类型选择 CDN 尺寸：单集优先 300px，海报优先 500px，背景优先 780px；缓存键包含实际图片地址和来源修订，避免同一候选的不同尺寸或来源变化复用旧图。统一主题的弱化文字也保留中文字体回退。

联网测试生成 `report.json`、无凭据的测试数据库和桌面/窄屏的媒体库、详情、海报选择截图。渲染断言检查已解码的 `RawImage`，并非只检查图片 Widget 或占位图是否存在。开发截图文件与下载缓存保留在显式指定的输出目录，不作为仓库资源提交。
