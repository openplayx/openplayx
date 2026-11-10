# 媒体库业务与存储分层

## 职责

- `lib/services/library/library_service.dart`：面向页面和工具的业务入口。负责输入校验、资源身份与服务端元数据合并策略、库成员关系、来源扫描和过滤、进度有效性校验、变更通知，以及等待正在执行的扫描/元数据操作结束后关闭资源。
- `lib/data/library/library_repository.dart`：负责媒体库查询、资源/绑定/成员关系/扫描游标/观看进度的 SQL 读写，以及元数据仓储和队列的存储接入。不依赖页面或 SourceManager，不发起网络访问或扫描遍历。
- `lib/data/library/library_database.dart`：负责数据库文件位置和名称验证、建表、索引、版本迁移、异常退出后的恢复，以及 SQLite 事务的提交和回滚。

调用方向：页面/AI 工具 → LibraryService → LibraryRepository → SQLite。LibraryRepository 使用 LibraryDatabase 初始化存储；LibraryService 的静态 open 通过 LibraryDatabase 打开文件。

扫描中的异步来源请求仍由业务层编排，事务仅包围同步的持久化步骤。完整遍历成功后才标记未观察到的资源缺失；失败保留扫描任务供恢复。来源凭据和临时播放 URL 不进入媒体库。

## 兼容与边界

本次分层不改变数据库版本（仍为 v4）、表结构、查询语义或现有 LibraryService 方法签名。服务通过 getter 暴露原有 `db` 和 `metadata`，元数据任务、会话存储及现有页面可继续使用。MetadataRepository 的实例创建与迁移已转入存储层。

`db` 是现有跨模块持久化代码的兼容入口，并不代表这些调用方已全部消除直接 SQL。新增媒体库 SQL 应写入 LibraryRepository；元数据自己的持久化操作应归入 MetadataRepository，避免重新加入 LibraryService。

LibraryService 仍返回原有 SQLite Row，避免此次重构扩展到页面和 AI 的数据模型迁移。若未来需要支持其他数据库，可单独引入领域记录和仓储接口。

## 验证

新增仓储测试覆盖：不创建业务服务即可初始化存储、跨表事务回滚及回滚后继续提交、后台连接不恢复活跃扫描、启动恢复保留扫描队列和观察结果、拒绝新版本数据库、数据库名称校验，以及业务层只发布成功提交的变更。

回归测试覆盖原有扫描、分页、身份、成员关系、播放进度、元数据迁移与并发任务、媒体库页面和 AI 媒体/播放工具。
