// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get home => '首页';

  @override
  String get library => '媒体库';

  @override
  String get sources => '来源';

  @override
  String get settings => '设置';

  @override
  String get system => '跟随系统';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get appearance => '外观';

  @override
  String get themeMode => '主题模式';

  @override
  String get themeDescription => '立即应用并在下次启动时恢复';

  @override
  String get language => '界面语言';

  @override
  String get preferenceSaveFailed => '偏好保存失败';

  @override
  String get preferenceSaveRetry => '当前选择已生效，请重新选择以重试保存。';

  @override
  String get sourceDefaults => '来源默认配置';

  @override
  String get sourceDefaultsDescription => '管理浏览、搜索与扫描使用的默认来源';

  @override
  String get manage => '管理';

  @override
  String get about => '关于 OpenPlayX';

  @override
  String get aboutDescription => '你的媒体，一个安静的播放空间。';

  @override
  String get favorite => '收藏';

  @override
  String get unfavorite => '取消收藏';

  @override
  String get retry => '重试';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get add => '添加';

  @override
  String get delete => '删除';

  @override
  String get remove => '移除';

  @override
  String get close => '关闭';

  @override
  String get openFile => '打开文件';

  @override
  String get welcome => '欢迎使用 OpenPlayX';

  @override
  String get welcomeDescription => '从上次停下的地方继续，或浏览你的媒体库。';

  @override
  String get continueWatching => '继续观看';

  @override
  String get continueEmpty => '还没有未看完的视频，播放后会在这里显示。';

  @override
  String get recentlyPlayed => '最近播放';

  @override
  String get recentEmpty => '还没有播放记录。去媒体库或来源中选择视频。';

  @override
  String get rewatch => '已看完 · 重新播放';

  @override
  String get libraryOpenFailed => '无法打开媒体库，请重试';

  @override
  String get platformUnsupported => '当前平台暂不支持播放';

  @override
  String get historyUnavailable => '此播放记录的资源不可用';

  @override
  String get fileUnavailable => '文件不可用';

  @override
  String get historyOpenFailed => '无法打开此记录，请检查文件或来源连接';

  @override
  String get libraryLoadFailed => '媒体库打开失败，请返回后重试';

  @override
  String get createLibrary => '创建媒体库';

  @override
  String get contentType => '内容类型';

  @override
  String get mixed => '混合';

  @override
  String get movie => '电影';

  @override
  String get series => '剧集';

  @override
  String get homeVideos => '家庭视频';

  @override
  String get audio => '音频';

  @override
  String get chooseScopeSource => '选择来源（仅扫描选定范围）';

  @override
  String get addEnabledSource => '请先在媒体源中添加并启用来源';

  @override
  String get bindFailed => '无法添加来源，请检查连接后重试';

  @override
  String get scanFailedRetained => '扫描失败；已入库的内容保留，可重试';

  @override
  String get localUnavailable => '本地文件不可用';

  @override
  String get watchedSuffix => ' · 已看完';

  @override
  String get missingOnScan => '扫描未发现，可能已失联';

  @override
  String get verifyOnPlay => '播放时验证可用性';

  @override
  String get chooseVersion => '选择资源版本播放；不同版本不自动换算时间轴';

  @override
  String get season => '季';

  @override
  String get episode => '单集';

  @override
  String get media => '媒体';

  @override
  String get previousPage => '上一页';

  @override
  String get nextPage => '下一页';

  @override
  String get versionOpenFailed => '此版本无法打开，请检查来源或选择其他版本';

  @override
  String get addToLibrary => '加入其他媒体库';

  @override
  String get chooseLibrary => '选择媒体库';

  @override
  String get correctTitle => '修正标题';

  @override
  String get removeFromLibrary => '从当前库移除（保留原文件和媒体记录）';

  @override
  String get continueIncludingHistory => '继续观看（包括未入库的播放记录）';

  @override
  String get allLibraries => '全部媒体库';

  @override
  String get renameLibrary => '重命名媒体库';

  @override
  String get addSourceScope => '添加来源范围';

  @override
  String get deleteLibrary => '删除库';

  @override
  String get deleteLibraryConfirm => '删除当前媒体库？';

  @override
  String get deleteLibraryDescription => '仅删除库和成员关系，保留原文件、媒体和收藏。';

  @override
  String get searchLibrary => '搜索库内媒体';

  @override
  String get allSources => '全部来源';

  @override
  String get allTypes => '全部类型';

  @override
  String get video => '普通视频';

  @override
  String get allWatchStates => '全部观看状态';

  @override
  String get watched => '已看完';

  @override
  String get unwatched => '未看完';

  @override
  String get restoreIgnored => '取消移除忽略（下次扫描恢复）';

  @override
  String get sourceNeedsSetup => '需要配置来源';

  @override
  String get rescan => '重新扫描';

  @override
  String get removeBinding => '移除绑定';

  @override
  String get removeBindingConfirm => '移除扫描绑定？';

  @override
  String get createFirstLibrary => '创建第一个媒体库';

  @override
  String get noMatchingMedia => '没有符合条件的媒体';

  @override
  String get libraryEmpty => '暂无内容，请添加来源范围或刷新扫描';

  @override
  String get browseFailed => '无法浏览，请检查来源后重试';

  @override
  String get scopeDescription => '扫描会索引此范围内的媒体，不下载视频。请选择已授权的目录或服务端库。';

  @override
  String get parent => '上一级';

  @override
  String get loadMore => '加载更多';

  @override
  String get rootFolder => '根目录';

  @override
  String get confirmScanScope => '确认扫描此范围';

  @override
  String get chooseScanScope => '选择扫描范围';

  @override
  String get defaultSaveFailed => '默认实例保存失败。';

  @override
  String get defaultDescription => '默认实例只用于未显式选择来源的操作。已有资源始终由原实例解析，不自动切换账号。';

  @override
  String get defaultBrowse => '默认浏览实例';

  @override
  String get defaultResolve => '默认资源解析实例';

  @override
  String get chooseEachTime => '每次选择';

  @override
  String get defaultUnavailable => '存在不可用的默认实例绑定，请重新选择；没有自动替换为其他账号。';

  @override
  String get searchScope => '多源搜索范围';

  @override
  String get searchScopeDescription =>
      '选择参与聚合搜索的 Plex/Jellyfin 来源。本地文件夹与 SMB 通过已索引的媒体库查询。';

  @override
  String get sourceDefaultsTitle => '能力默认实例与搜索范围';

  @override
  String get localFolder => '本地文件夹';

  @override
  String get pickFolderFailed => '无法选择文件夹，请重试。';

  @override
  String get openBrowserFailed => '无法打开浏览器，请点击登录链接重试。';

  @override
  String get noPlexServers => '此 Plex 账号下没有可访问的服务器。';

  @override
  String get plexSignInFailed => 'Plex 登录失败，请重试。';

  @override
  String get enterToken => '请填写访问令牌后连接服务器。';

  @override
  String get signInPlexFirst => '请先登录 Plex 并选择服务器。';

  @override
  String get connectionFormFailed => '连接失败，请检查地址和登录信息。';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get showPassword => '显示密码';

  @override
  String get address => '地址';

  @override
  String get addressHint => '192.168.1.10 或 https://media.example.com';

  @override
  String get username => '用户名';

  @override
  String get guestHelp => '访客访问时，用户名和密码都留空';

  @override
  String get password => '密码';

  @override
  String get keepCredentials => '留空保留当前登录';

  @override
  String get advanced => '高级';

  @override
  String get port => '端口';

  @override
  String get optionalPath => '路径（可选）';

  @override
  String get smbPathHint => '共享文件夹/影片目录';

  @override
  String get serverPathHint => '例如 jellyfin，没有则留空';

  @override
  String get scanExtensions => '扫描的文件后缀';

  @override
  String get scanExtensionsHelp =>
      '用逗号分隔。预览和入库只保留这些后缀的文件，留空则保留所有文件。以点开头的隐藏文件始终会被忽略。';

  @override
  String get optionalDomain => '工作组（可选）';

  @override
  String get waitingPlex => '等待 Plex 授权…';

  @override
  String get signInPlex => '登录 Plex';

  @override
  String get signInPlexAgain => '重新登录 Plex';

  @override
  String get plexBrowserHelp => '在浏览器中登录 Plex，然后选择要连接的服务器。';

  @override
  String get reopenSignIn => '重新打开登录页';

  @override
  String get server => '服务器';

  @override
  String get manualServer => '手动连接服务器';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get portInAddress => '使用自定义端口时，请在地址中一并填写。';

  @override
  String get accessToken => '访问令牌';

  @override
  String get addSource => '添加媒体源';

  @override
  String get editSource => '编辑媒体源';

  @override
  String get type => '类型';

  @override
  String get optionalName => '名称（可选）';

  @override
  String get chooseFolder => '选择文件夹';

  @override
  String get folderAccessHelp => '请选择系统允许应用访问的文件夹。';

  @override
  String get loadSourcesFailed => '加载媒体源失败，请重试。';

  @override
  String get filePlayFailed => '无法播放此文件。';

  @override
  String get previewLimit => '已达到预览上限 500 个文件，结果不完整。';

  @override
  String get previewDescription => '已应用访问范围和扫描排除项；此操作不写入媒体库、不创建后台索引。';

  @override
  String get scanFailed => '扫描失败。';

  @override
  String get backToParent => '返回上一级';

  @override
  String get sourcesEmpty => '添加本地文件夹、SMB、Jellyfin 或 Plex 来源。';

  @override
  String get disableSourceConfirm => '禁用媒体源？';

  @override
  String get disable => '禁用';

  @override
  String get toggleSourceFailed => '启停失败，请重试。';

  @override
  String get verifyConnection => '验证连接';

  @override
  String get connectionFailed => '连接失败。';

  @override
  String get previewScan => '预览扫描';

  @override
  String get deleteSource => '删除媒体源';

  @override
  String get deleteSourceFailed => '删除源失败，请重试。';

  @override
  String get folderEmpty => '此目录没有可浏览的媒体。';

  @override
  String get reloadConfiguration => '重新加载配置';

  @override
  String get defaultBrowseUnavailable => '默认实例不可用，请重新选择，未自动切换其他账号。';

  @override
  String get browseDefault => '默认浏览';

  @override
  String get capabilityDefaults => '能力默认实例';

  @override
  String get addSourceShort => '添加源';

  @override
  String get playerClosed => '播放器已关闭';

  @override
  String get historySaveFailed => '观看记录暂时无法保存，仍可继续播放';

  @override
  String get adjustFailed => '调整失败，请重试。';

  @override
  String get audioTrack => '音轨';

  @override
  String get noAudioTracks => '此媒体没有可选音轨';

  @override
  String get subtitleTrack => '字幕';

  @override
  String get noSubtitleTracks => '此媒体没有可选字幕';

  @override
  String get subtitleOff => '关闭字幕';

  @override
  String numberedSubtitleTrack(int id) {
    return '字幕 $id';
  }

  @override
  String get playbackCommandFailed => '播放操作失败，请重新打开媒体文件。';

  @override
  String get openFileFailed => '无法打开文件，请重新选择。';

  @override
  String get stopPlaybackFailed => '停止播放失败，请重试返回';

  @override
  String get volume => '音量';

  @override
  String get brightness => '画面亮度';

  @override
  String get rewind => '快退 10 秒';

  @override
  String get pause => '暂停';

  @override
  String get play => '播放';

  @override
  String get forward => '快进 10 秒';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get morePlaybackSettings => '更多播放设置';

  @override
  String get lockControls => '锁定控制';

  @override
  String get playerVolume => '播放器音量';

  @override
  String get playerEmpty => '打开一个视频，开始播放';

  @override
  String get back => '返回';

  @override
  String get playbackFailed => '播放失败，请检查文件或重新选择。';

  @override
  String get boost => '临时 2× · 松手恢复';

  @override
  String get unlockControls => '解锁控制';

  @override
  String get loading => '正在加载…';

  @override
  String watchProgress(int position, int duration) {
    return '已看 $position / $duration 分钟';
  }

  @override
  String metadataProgressLabel(int done, int total) {
    return '刮削 $done/$total';
  }

  @override
  String metadataProgressTooltip(int done, int total) {
    return '元数据刮削进度：已处理 $done / 共 $total（找不到匹配的也算已处理）';
  }

  @override
  String watchedMinutes(int minutes) {
    return ' · 已看 $minutes 分钟';
  }

  @override
  String localResource(String progress) {
    return '本机文件（播放时检查访问权限）$progress';
  }

  @override
  String setupResource(String progress) {
    return '需要配置或启用来源$progress';
  }

  @override
  String removeBindingDescription(int count) {
    return '此绑定关联 $count 项内容。仅移除失去全部来源证据的自动成员，保留手动成员、共享媒体和原文件。';
  }

  @override
  String sourceVersion(String kind, String plugin, int config, int revision) {
    return '$kind · 插件 $plugin · 配置 v$config · r$revision';
  }

  @override
  String disableSourceDescription(int playing, int running, int defaults) {
    return '当前播放 $playing 个，进行中请求 $running 个，默认能力绑定 $defaults 项。禁用后拒绝新请求并清除默认绑定；当前播放可继续，结束后释放连接。配置、收藏和产物保留。';
  }

  @override
  String deleteSourceDescription(int defaults, int playing, int running) {
    return '仅删除此实例配置与凭据引用，不删除原始文件、收藏或产物。默认能力绑定 $defaults 项和搜索范围绑定将被清除。当前播放 $playing 个、进行中请求 $running 个可完成，之后释放连接。';
  }

  @override
  String previewTitle(String name) {
    return '扫描预览：$name';
  }

  @override
  String filesFound(int count) {
    return '发现 $count 个文件。';
  }

  @override
  String deleteNamedSource(String name) {
    return '删除 $name？';
  }

  @override
  String numberedAudioTrack(int id) {
    return '音轨 $id';
  }

  @override
  String remainingTime(String time) {
    return '剩余 $time';
  }

  @override
  String readSpeed(String speed) {
    return '读取 $speed MB/s';
  }

  @override
  String get notVerified => '尚未验证';

  @override
  String get disabled => '已禁用';

  @override
  String get pendingApply => '待应用';

  @override
  String get applied => '已应用';

  @override
  String get applyFailed => '应用失败';

  @override
  String get credentialsMissing => '需要登录';

  @override
  String get credentialsReady => '凭据已保存';

  @override
  String get localSource => '本地文件夹';

  @override
  String get credentialsUnknown => '凭据状态未知';

  @override
  String get screenOrientation => '屏幕方向';

  @override
  String get orientationSystem => '跟随系统';

  @override
  String get orientationPortrait => '竖屏';

  @override
  String get orientationLandscape => '横屏';

  @override
  String get videoRotation => '画面旋转';

  @override
  String get rotationOriginal => '原始方向（0°）';

  @override
  String get sourceReady => '已就绪';

  @override
  String get sourceConnectionFailed => '连接失败';

  @override
  String get sourceInitialized => '已初始化 · 待连接验证';

  @override
  String get sourceSaved => '已保存 · 下次访问生效';

  @override
  String get credentialsNotRequired => '无需账号凭据';

  @override
  String get credentialsUnverified => '凭据已保存 · 尚未验证';

  @override
  String get credentialsExpiring => '令牌将在 7 天内到期';

  @override
  String get credentialsExpired => '令牌已到期';

  @override
  String get credentialsRejected => '认证失败 · 请更新凭据';

  @override
  String get credentialsVerified => '连接已验证';

  @override
  String get playbackPosition => '播放进度';

  @override
  String get shadHours => '时';

  @override
  String get shadMinutes => '分';

  @override
  String get shadSeconds => '秒';

  @override
  String get shadPeriod => '时段';

  @override
  String get shadMorning => '上午';

  @override
  String get shadSelectDate => '选择日期';

  @override
  String get shadCut => '剪切';

  @override
  String get shadCopy => '复制';

  @override
  String get shadPaste => '粘贴';

  @override
  String get shadSelectAll => '全选';

  @override
  String get shadDone => '完成';

  @override
  String scanFoundMedia(int n) {
    return '已发现 $n 个媒体文件';
  }

  @override
  String get detailOverview => '简介';

  @override
  String get detailCast => '演员';

  @override
  String get detailDirectors => '导演';

  @override
  String seasonLabel(int n) {
    return '第 $n 季';
  }

  @override
  String episodeLabel(int n) {
    return '第 $n 集';
  }

  @override
  String get detailNoEpisodes => '还没有可播放的剧集。';

  @override
  String get metadata => '影视信息';

  @override
  String get metadataIdentify => '识别 / 重新匹配';

  @override
  String get metadataImport => '导入邻近 NFO 和图片';

  @override
  String get metadataRefresh => '刷新已关联作品';

  @override
  String get metadataSource => '字段来源';

  @override
  String get metadataQuery => '作品名称';

  @override
  String get metadataYear => '年份（可选）';

  @override
  String get metadataProviderId => 'TMDB ID（可选）';

  @override
  String get metadataLanguage => '元数据语言';

  @override
  String get metadataToken => 'TMDB 读取访问令牌';

  @override
  String get metadataConfigure => '配置 TMDB';

  @override
  String get metadataPrivacy =>
      '入库的影视会在后台自动识别，仅向 TMDB 发送必要的名称、年份、ID 和语言，不上传视频或私人路径。';

  @override
  String get metadataSaved => 'TMDB 配置已保存';

  @override
  String get metadataCandidates => '选择作品';

  @override
  String get metadataChooseChildren => '选择季 / 集';

  @override
  String get metadataConfirm => '确认匹配';

  @override
  String get metadataKeepLocks => '保留已锁定字段和海报，播放进度及资源版本不受影响。';

  @override
  String get metadataOverview => '简介';

  @override
  String get metadataOriginalTitle => '原名';

  @override
  String get metadataGenres => '类型';

  @override
  String get metadataEdit => '编辑并锁定字段';

  @override
  String get metadataRestore => '恢复自动来源';

  @override
  String get metadataArtwork => '选择海报';

  @override
  String get metadataArtworkLocked => '海报已锁定';

  @override
  String get metadataReset => '重置匹配';

  @override
  String get metadataResetDescription => '清除导入字段和作品关联，保留用户修改、锁定海报及播放数据。';

  @override
  String get metadataClearCache => '清理图片缓存';

  @override
  String get metadataBatch => '导入全库影视信息';

  @override
  String get metadataBatchDone => '全库导入完成，可查看各条目的识别状态。';

  @override
  String get metadataUnmatched => '未找到匹配信息';

  @override
  String get metadataAwaiting => '等待确认';

  @override
  String get metadataCompleted => '影视信息已保存';

  @override
  String get metadataCancelled => '已取消或中断，保留已保存信息';

  @override
  String get metadataBusy => '正在获取影视信息…';

  @override
  String get metadataNotStarted => '尚未识别';

  @override
  String get metadataFailed => '读取影视信息失败，已有媒体仍可使用。';

  @override
  String get metadataConflict => '作品身份冲突，请选择正确候选。';

  @override
  String get metadataStale => '查询期间信息已更改，请重新查询。';

  @override
  String get metadataAuth => '请配置有效的 TMDB 读取访问令牌。';

  @override
  String get metadataOffline => '网络请求失败，请联网后重试。';

  @override
  String get metadataPermission => '来源未授权读取此附件。';

  @override
  String get metadataRateLimited => 'TMDB 请求受限，请稍后重试。';

  @override
  String get metadataMissingSource => '来源文件已缺失';

  @override
  String get metadataAttribution => '本产品使用 TMDB API，但未经 TMDB 认可或认证。';

  @override
  String get metadataForgetToken => '移除 TMDB 凭据';

  @override
  String get metadataTokenSaved => '已在本机保存 TMDB 令牌。';

  @override
  String get metadataTokenMissing => '尚未配置 TMDB 令牌。';

  @override
  String get metadataSearch => '搜索 TMDB';

  @override
  String get aiAssistant => 'AI 助手';

  @override
  String get aiPrivacyNotice => '消息、选定上下文及工具结果会发送至你配置的模型供应商。';

  @override
  String get aiWelcome => '可以让我查找媒体、继续观看或控制播放。请先配置模型。';

  @override
  String get aiYou => '你';

  @override
  String get aiToolResult => '工具结果';

  @override
  String get aiConfirmAction => '确认这项变更';

  @override
  String get aiApprove => '同意执行';

  @override
  String get aiInputHint => '想看些什么？';

  @override
  String get aiStop => '停止生成';

  @override
  String get aiSend => '发送';

  @override
  String get aiToolFailed => '工具未完成';

  @override
  String get aiConfigureFirst => '请先在 AI 设置中配置模型、API Key 并授权发送至云端。';

  @override
  String get aiSendFailed => '无法发送，请检查输入长度后重试。';

  @override
  String get aiCancelled => '已停止生成，已完成操作会保留。';

  @override
  String get aiTimeout => '请求超时，已完成操作会保留。';

  @override
  String get aiBudgetReached => '已达到本回合上限，已完成结果会保留。';

  @override
  String get aiProviderFailed => '模型请求失败，请检查凭据、端点及模型支持情况。';

  @override
  String get aiInterrupted => '上次关闭时中断，不会重放操作。';

  @override
  String aiTokenUsage(int count) {
    return '供应商报告用量：$count tokens';
  }

  @override
  String get aiModelSettings => '模型设置';

  @override
  String get aiProviderDescription =>
      '使用 OpenAI 或兼容协议的 HTTPS 端点。API Key 保存在系统凭据存储中。';

  @override
  String get aiEndpoint => 'API 基址';

  @override
  String get aiModel => '模型 ID';

  @override
  String get aiApiKey => 'API Key';

  @override
  String get aiKeyRequired => '填写 API Key';

  @override
  String get aiKeySaved => '已保存凭据，留空保留';

  @override
  String get aiOutputLimit => '输出 token 上限（128–16384）';

  @override
  String get aiCloudConsent => '允许此供应商接收对话历史、媒体标题、来源名称及播放摘要，并请求已列出的媒体与播放工具。';

  @override
  String get aiTestText => '测试普通回复';

  @override
  String get aiTestStream => '测试流式回复';

  @override
  String get aiTestTools => '测试工具调用';

  @override
  String get aiTestPassed => '连接测试通过，保存后生效。';

  @override
  String get aiTestFailed => '测试失败，请检查凭据及协议支持。工具调用须单独通过测试。';

  @override
  String get aiToolsVerified => '工具调用已验证，将启用实际可用的业务工具。';

  @override
  String get aiTextOnly => '工具调用测试通过前仅启用纯对话。';

  @override
  String get aiSaveFailed => '保存失败，请检查配置及系统凭据存储权限。';

  @override
  String aiExecuting(String name) {
    return '正在执行 $name…';
  }

  @override
  String get aiAuthenticationFailed => '认证失败，请在模型设置中更新 API Key。';

  @override
  String get aiRateLimited => '已达到供应商限流，请稍后重试。';

  @override
  String get aiProtocolMismatch => '端点或模型不支持此请求，请检查连接测试结果。';

  @override
  String get metadataAutomaticQueued => '等待自动识别';

  @override
  String get metadataAutomaticWaitingConfig =>
      '后台刮削需要配置有效的 TMDB 读取令牌，本地 NFO 和播放不受影响。';

  @override
  String get metadataAutomaticRetry => '重试未完成的刮削';

  @override
  String metadataAutomaticStatus(
    int queued,
    int running,
    int waiting,
    int failed,
  ) {
    return '后台刮削：$queued 待处理 · $running 处理中 · $waiting 待确认 · $failed 失败';
  }

  @override
  String get fileSources => '文件源';

  @override
  String get addFileSource => '添加文件源';

  @override
  String get nameFileSource => '为文件源命名';

  @override
  String get fileSourceEnable => '启用';

  @override
  String get fileSourceDisable => '停用';

  @override
  String get fileSourceDisabled => '已停用';

  @override
  String get rescanAll => '重新扫描全部文件源';

  @override
  String get noFileSources => '还没有文件源，添加一个文件夹开始建立媒体库';

  @override
  String get removeFileSource => '删除文件源';

  @override
  String get removeFileSourceConfirm => '删除此文件源？';

  @override
  String get libraryEmptyNoMedia => '文件源中暂无可识别的媒体，请重新扫描或检查文件命名';

  @override
  String get chooseFolderDescription => '进入目录并确认作为文件源。仅索引其中的媒体，不下载视频。';

  @override
  String get confirmFolder => '使用此文件夹';

  @override
  String get libraryNoFileSources => '还没有文件源。请在「来源」中为连接添加文件夹';

  @override
  String get sourceTabConnections => '连接';

  @override
  String get sourceTabFileSources => '文件源';

  @override
  String get moreActions => '更多操作';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get home => '首页';

  @override
  String get library => '媒体库';

  @override
  String get sources => '来源';

  @override
  String get settings => '设置';

  @override
  String get system => '跟随系统';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get appearance => '外观';

  @override
  String get themeMode => '主题模式';

  @override
  String get themeDescription => '立即应用并在下次启动时恢复';

  @override
  String get language => '界面语言';

  @override
  String get preferenceSaveFailed => '偏好保存失败';

  @override
  String get preferenceSaveRetry => '当前选择已生效，请重新选择以重试保存。';

  @override
  String get sourceDefaults => '来源默认配置';

  @override
  String get sourceDefaultsDescription => '管理浏览、搜索与扫描使用的默认来源';

  @override
  String get manage => '管理';

  @override
  String get about => '关于 OpenPlayX';

  @override
  String get aboutDescription => '你的媒体，一个安静的播放空间。';

  @override
  String get favorite => '收藏';

  @override
  String get unfavorite => '取消收藏';

  @override
  String get retry => '重试';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get add => '添加';

  @override
  String get delete => '删除';

  @override
  String get remove => '移除';

  @override
  String get close => '关闭';

  @override
  String get openFile => '打开文件';

  @override
  String get welcome => '欢迎使用 OpenPlayX';

  @override
  String get welcomeDescription => '从上次停下的地方继续，或浏览你的媒体库。';

  @override
  String get continueWatching => '继续观看';

  @override
  String get continueEmpty => '还没有未看完的视频，播放后会在这里显示。';

  @override
  String get recentlyPlayed => '最近播放';

  @override
  String get recentEmpty => '还没有播放记录。去媒体库或来源中选择视频。';

  @override
  String get rewatch => '已看完 · 重新播放';

  @override
  String get libraryOpenFailed => '无法打开媒体库，请重试';

  @override
  String get platformUnsupported => '当前平台暂不支持播放';

  @override
  String get historyUnavailable => '此播放记录的资源不可用';

  @override
  String get fileUnavailable => '文件不可用';

  @override
  String get historyOpenFailed => '无法打开此记录，请检查文件或来源连接';

  @override
  String get libraryLoadFailed => '媒体库打开失败，请返回后重试';

  @override
  String get createLibrary => '创建媒体库';

  @override
  String get contentType => '内容类型';

  @override
  String get mixed => '混合';

  @override
  String get movie => '电影';

  @override
  String get series => '剧集';

  @override
  String get homeVideos => '家庭视频';

  @override
  String get audio => '音频';

  @override
  String get chooseScopeSource => '选择来源（仅扫描选定范围）';

  @override
  String get addEnabledSource => '请先在媒体源中添加并启用来源';

  @override
  String get bindFailed => '无法添加来源，请检查连接后重试';

  @override
  String get scanFailedRetained => '扫描失败；已入库的内容保留，可重试';

  @override
  String get localUnavailable => '本地文件不可用';

  @override
  String get watchedSuffix => ' · 已看完';

  @override
  String get missingOnScan => '扫描未发现，可能已失联';

  @override
  String get verifyOnPlay => '播放时验证可用性';

  @override
  String get chooseVersion => '选择资源版本播放；不同版本不自动换算时间轴';

  @override
  String get season => '季';

  @override
  String get episode => '单集';

  @override
  String get media => '媒体';

  @override
  String get previousPage => '上一页';

  @override
  String get nextPage => '下一页';

  @override
  String get versionOpenFailed => '此版本无法打开，请检查来源或选择其他版本';

  @override
  String get addToLibrary => '加入其他媒体库';

  @override
  String get chooseLibrary => '选择媒体库';

  @override
  String get correctTitle => '修正标题';

  @override
  String get removeFromLibrary => '从当前库移除（保留原文件和媒体记录）';

  @override
  String get continueIncludingHistory => '继续观看（包括未入库的播放记录）';

  @override
  String get allLibraries => '全部媒体库';

  @override
  String get renameLibrary => '重命名媒体库';

  @override
  String get addSourceScope => '添加来源范围';

  @override
  String get deleteLibrary => '删除库';

  @override
  String get deleteLibraryConfirm => '删除当前媒体库？';

  @override
  String get deleteLibraryDescription => '仅删除库和成员关系，保留原文件、媒体和收藏。';

  @override
  String get searchLibrary => '搜索库内媒体';

  @override
  String get allSources => '全部来源';

  @override
  String get allTypes => '全部类型';

  @override
  String get video => '普通视频';

  @override
  String get allWatchStates => '全部观看状态';

  @override
  String get watched => '已看完';

  @override
  String get unwatched => '未看完';

  @override
  String get restoreIgnored => '取消移除忽略（下次扫描恢复）';

  @override
  String get sourceNeedsSetup => '需要配置来源';

  @override
  String get rescan => '重新扫描';

  @override
  String get removeBinding => '移除绑定';

  @override
  String get removeBindingConfirm => '移除扫描绑定？';

  @override
  String get createFirstLibrary => '创建第一个媒体库';

  @override
  String get noMatchingMedia => '没有符合条件的媒体';

  @override
  String get libraryEmpty => '暂无内容，请添加来源范围或刷新扫描';

  @override
  String get browseFailed => '无法浏览，请检查来源后重试';

  @override
  String get scopeDescription => '扫描会索引此范围内的媒体，不下载视频。请选择已授权的目录或服务端库。';

  @override
  String get parent => '上一级';

  @override
  String get loadMore => '加载更多';

  @override
  String get rootFolder => '根目录';

  @override
  String get confirmScanScope => '确认扫描此范围';

  @override
  String get chooseScanScope => '选择扫描范围';

  @override
  String get defaultSaveFailed => '默认实例保存失败。';

  @override
  String get defaultDescription => '默认实例只用于未显式选择来源的操作。已有资源始终由原实例解析，不自动切换账号。';

  @override
  String get defaultBrowse => '默认浏览实例';

  @override
  String get defaultResolve => '默认资源解析实例';

  @override
  String get chooseEachTime => '每次选择';

  @override
  String get defaultUnavailable => '存在不可用的默认实例绑定，请重新选择；没有自动替换为其他账号。';

  @override
  String get searchScope => '多源搜索范围';

  @override
  String get searchScopeDescription =>
      '选择参与聚合搜索的 Plex/Jellyfin 来源。本地文件夹与 SMB 通过已索引的媒体库查询。';

  @override
  String get sourceDefaultsTitle => '能力默认实例与搜索范围';

  @override
  String get localFolder => '本地文件夹';

  @override
  String get pickFolderFailed => '无法选择文件夹，请重试。';

  @override
  String get openBrowserFailed => '无法打开浏览器，请点击登录链接重试。';

  @override
  String get noPlexServers => '此 Plex 账号下没有可访问的服务器。';

  @override
  String get plexSignInFailed => 'Plex 登录失败，请重试。';

  @override
  String get enterToken => '请填写访问令牌后连接服务器。';

  @override
  String get signInPlexFirst => '请先登录 Plex 并选择服务器。';

  @override
  String get connectionFormFailed => '连接失败，请检查地址和登录信息。';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get showPassword => '显示密码';

  @override
  String get address => '地址';

  @override
  String get addressHint => '192.168.1.10 或 https://media.example.com';

  @override
  String get username => '用户名';

  @override
  String get guestHelp => '访客访问时，用户名和密码都留空';

  @override
  String get password => '密码';

  @override
  String get keepCredentials => '留空保留当前登录';

  @override
  String get advanced => '高级';

  @override
  String get port => '端口';

  @override
  String get optionalPath => '路径（可选）';

  @override
  String get smbPathHint => '共享文件夹/影片目录';

  @override
  String get serverPathHint => '例如 jellyfin，没有则留空';

  @override
  String get scanExtensions => '扫描的文件后缀';

  @override
  String get scanExtensionsHelp =>
      '用逗号分隔。预览和入库只保留这些后缀的文件，留空则保留所有文件。以点开头的隐藏文件始终会被忽略。';

  @override
  String get optionalDomain => '工作组（可选）';

  @override
  String get waitingPlex => '等待 Plex 授权…';

  @override
  String get signInPlex => '登录 Plex';

  @override
  String get signInPlexAgain => '重新登录 Plex';

  @override
  String get plexBrowserHelp => '在浏览器中登录 Plex，然后选择要连接的服务器。';

  @override
  String get reopenSignIn => '重新打开登录页';

  @override
  String get server => '服务器';

  @override
  String get manualServer => '手动连接服务器';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get portInAddress => '使用自定义端口时，请在地址中一并填写。';

  @override
  String get accessToken => '访问令牌';

  @override
  String get addSource => '添加媒体源';

  @override
  String get editSource => '编辑媒体源';

  @override
  String get type => '类型';

  @override
  String get optionalName => '名称（可选）';

  @override
  String get chooseFolder => '选择文件夹';

  @override
  String get folderAccessHelp => '请选择系统允许应用访问的文件夹。';

  @override
  String get loadSourcesFailed => '加载媒体源失败，请重试。';

  @override
  String get filePlayFailed => '无法播放此文件。';

  @override
  String get previewLimit => '已达到预览上限 500 个文件，结果不完整。';

  @override
  String get previewDescription => '已应用访问范围和扫描排除项；此操作不写入媒体库、不创建后台索引。';

  @override
  String get scanFailed => '扫描失败。';

  @override
  String get backToParent => '返回上一级';

  @override
  String get sourcesEmpty => '添加本地文件夹、SMB、Jellyfin 或 Plex 来源。';

  @override
  String get disableSourceConfirm => '禁用媒体源？';

  @override
  String get disable => '禁用';

  @override
  String get toggleSourceFailed => '启停失败，请重试。';

  @override
  String get verifyConnection => '验证连接';

  @override
  String get connectionFailed => '连接失败。';

  @override
  String get previewScan => '预览扫描';

  @override
  String get deleteSource => '删除媒体源';

  @override
  String get deleteSourceFailed => '删除源失败，请重试。';

  @override
  String get folderEmpty => '此目录没有可浏览的媒体。';

  @override
  String get reloadConfiguration => '重新加载配置';

  @override
  String get defaultBrowseUnavailable => '默认实例不可用，请重新选择，未自动切换其他账号。';

  @override
  String get browseDefault => '默认浏览';

  @override
  String get capabilityDefaults => '能力默认实例';

  @override
  String get addSourceShort => '添加源';

  @override
  String get playerClosed => '播放器已关闭';

  @override
  String get historySaveFailed => '观看记录暂时无法保存，仍可继续播放';

  @override
  String get adjustFailed => '调整失败，请重试。';

  @override
  String get audioTrack => '音轨';

  @override
  String get noAudioTracks => '此媒体没有可选音轨';

  @override
  String get subtitleTrack => '字幕';

  @override
  String get noSubtitleTracks => '此媒体没有可选字幕';

  @override
  String get subtitleOff => '关闭字幕';

  @override
  String numberedSubtitleTrack(int id) {
    return '字幕 $id';
  }

  @override
  String get playbackCommandFailed => '播放操作失败，请重新打开媒体文件。';

  @override
  String get openFileFailed => '无法打开文件，请重新选择。';

  @override
  String get stopPlaybackFailed => '停止播放失败，请重试返回';

  @override
  String get volume => '音量';

  @override
  String get brightness => '画面亮度';

  @override
  String get rewind => '快退 10 秒';

  @override
  String get pause => '暂停';

  @override
  String get play => '播放';

  @override
  String get forward => '快进 10 秒';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get morePlaybackSettings => '更多播放设置';

  @override
  String get lockControls => '锁定控制';

  @override
  String get playerVolume => '播放器音量';

  @override
  String get playerEmpty => '打开一个视频，开始播放';

  @override
  String get back => '返回';

  @override
  String get playbackFailed => '播放失败，请检查文件或重新选择。';

  @override
  String get boost => '临时 2× · 松手恢复';

  @override
  String get unlockControls => '解锁控制';

  @override
  String get loading => '正在加载…';

  @override
  String watchProgress(int position, int duration) {
    return '已看 $position / $duration 分钟';
  }

  @override
  String metadataProgressLabel(int done, int total) {
    return '刮削 $done/$total';
  }

  @override
  String metadataProgressTooltip(int done, int total) {
    return '元数据刮削进度：已处理 $done / 共 $total（找不到匹配的也算已处理）';
  }

  @override
  String watchedMinutes(int minutes) {
    return ' · 已看 $minutes 分钟';
  }

  @override
  String localResource(String progress) {
    return '本机文件（播放时检查访问权限）$progress';
  }

  @override
  String setupResource(String progress) {
    return '需要配置或启用来源$progress';
  }

  @override
  String removeBindingDescription(int count) {
    return '此绑定关联 $count 项内容。仅移除失去全部来源证据的自动成员，保留手动成员、共享媒体和原文件。';
  }

  @override
  String sourceVersion(String kind, String plugin, int config, int revision) {
    return '$kind · 插件 $plugin · 配置 v$config · r$revision';
  }

  @override
  String disableSourceDescription(int playing, int running, int defaults) {
    return '当前播放 $playing 个，进行中请求 $running 个，默认能力绑定 $defaults 项。禁用后拒绝新请求并清除默认绑定；当前播放可继续，结束后释放连接。配置、收藏和产物保留。';
  }

  @override
  String deleteSourceDescription(int defaults, int playing, int running) {
    return '仅删除此实例配置与凭据引用，不删除原始文件、收藏或产物。默认能力绑定 $defaults 项和搜索范围绑定将被清除。当前播放 $playing 个、进行中请求 $running 个可完成，之后释放连接。';
  }

  @override
  String previewTitle(String name) {
    return '扫描预览：$name';
  }

  @override
  String filesFound(int count) {
    return '发现 $count 个文件。';
  }

  @override
  String deleteNamedSource(String name) {
    return '删除 $name？';
  }

  @override
  String numberedAudioTrack(int id) {
    return '音轨 $id';
  }

  @override
  String remainingTime(String time) {
    return '剩余 $time';
  }

  @override
  String readSpeed(String speed) {
    return '读取 $speed MB/s';
  }

  @override
  String get notVerified => '尚未验证';

  @override
  String get disabled => '已禁用';

  @override
  String get pendingApply => '待应用';

  @override
  String get applied => '已应用';

  @override
  String get applyFailed => '应用失败';

  @override
  String get credentialsMissing => '需要登录';

  @override
  String get credentialsReady => '凭据已保存';

  @override
  String get localSource => '本地文件夹';

  @override
  String get credentialsUnknown => '凭据状态未知';

  @override
  String get screenOrientation => '屏幕方向';

  @override
  String get orientationSystem => '跟随系统';

  @override
  String get orientationPortrait => '竖屏';

  @override
  String get orientationLandscape => '横屏';

  @override
  String get videoRotation => '画面旋转';

  @override
  String get rotationOriginal => '原始方向（0°）';

  @override
  String get sourceReady => '已就绪';

  @override
  String get sourceConnectionFailed => '连接失败';

  @override
  String get sourceInitialized => '已初始化 · 待连接验证';

  @override
  String get sourceSaved => '已保存 · 下次访问生效';

  @override
  String get credentialsNotRequired => '无需账号凭据';

  @override
  String get credentialsUnverified => '凭据已保存 · 尚未验证';

  @override
  String get credentialsExpiring => '令牌将在 7 天内到期';

  @override
  String get credentialsExpired => '令牌已到期';

  @override
  String get credentialsRejected => '认证失败 · 请更新凭据';

  @override
  String get credentialsVerified => '连接已验证';

  @override
  String get playbackPosition => '播放进度';

  @override
  String get shadHours => '时';

  @override
  String get shadMinutes => '分';

  @override
  String get shadSeconds => '秒';

  @override
  String get shadPeriod => '时段';

  @override
  String get shadMorning => '上午';

  @override
  String get shadSelectDate => '选择日期';

  @override
  String get shadCut => '剪切';

  @override
  String get shadCopy => '复制';

  @override
  String get shadPaste => '粘贴';

  @override
  String get shadSelectAll => '全选';

  @override
  String get shadDone => '完成';

  @override
  String scanFoundMedia(int n) {
    return '已发现 $n 个媒体文件';
  }

  @override
  String get detailOverview => '简介';

  @override
  String get detailCast => '演员';

  @override
  String get detailDirectors => '导演';

  @override
  String seasonLabel(int n) {
    return '第 $n 季';
  }

  @override
  String episodeLabel(int n) {
    return '第 $n 集';
  }

  @override
  String get detailNoEpisodes => '还没有可播放的剧集。';

  @override
  String get metadata => '影视信息';

  @override
  String get metadataIdentify => '识别 / 重新匹配';

  @override
  String get metadataImport => '导入邻近 NFO 和图片';

  @override
  String get metadataRefresh => '刷新已关联作品';

  @override
  String get metadataSource => '字段来源';

  @override
  String get metadataQuery => '作品名称';

  @override
  String get metadataYear => '年份（可选）';

  @override
  String get metadataProviderId => 'TMDB ID（可选）';

  @override
  String get metadataLanguage => '元数据语言';

  @override
  String get metadataToken => 'TMDB 读取访问令牌';

  @override
  String get metadataConfigure => '配置 TMDB';

  @override
  String get metadataPrivacy =>
      '入库的影视会在后台自动识别，仅向 TMDB 发送必要的名称、年份、ID 和语言，不上传视频或私人路径。';

  @override
  String get metadataSaved => 'TMDB 配置已保存';

  @override
  String get metadataCandidates => '选择作品';

  @override
  String get metadataChooseChildren => '选择季 / 集';

  @override
  String get metadataConfirm => '确认匹配';

  @override
  String get metadataKeepLocks => '保留已锁定字段和海报，播放进度及资源版本不受影响。';

  @override
  String get metadataOverview => '简介';

  @override
  String get metadataOriginalTitle => '原名';

  @override
  String get metadataGenres => '类型';

  @override
  String get metadataEdit => '编辑并锁定字段';

  @override
  String get metadataRestore => '恢复自动来源';

  @override
  String get metadataArtwork => '选择海报';

  @override
  String get metadataArtworkLocked => '海报已锁定';

  @override
  String get metadataReset => '重置匹配';

  @override
  String get metadataResetDescription => '清除导入字段和作品关联，保留用户修改、锁定海报及播放数据。';

  @override
  String get metadataClearCache => '清理图片缓存';

  @override
  String get metadataBatch => '导入全库影视信息';

  @override
  String get metadataBatchDone => '全库导入完成，可查看各条目的识别状态。';

  @override
  String get metadataUnmatched => '未找到匹配信息';

  @override
  String get metadataAwaiting => '等待确认';

  @override
  String get metadataCompleted => '影视信息已保存';

  @override
  String get metadataCancelled => '已取消或中断，保留已保存信息';

  @override
  String get metadataBusy => '正在获取影视信息…';

  @override
  String get metadataNotStarted => '尚未识别';

  @override
  String get metadataFailed => '读取影视信息失败，已有媒体仍可使用。';

  @override
  String get metadataConflict => '作品身份冲突，请选择正确候选。';

  @override
  String get metadataStale => '查询期间信息已更改，请重新查询。';

  @override
  String get metadataAuth => '请配置有效的 TMDB 读取访问令牌。';

  @override
  String get metadataOffline => '网络请求失败，请联网后重试。';

  @override
  String get metadataPermission => '来源未授权读取此附件。';

  @override
  String get metadataRateLimited => 'TMDB 请求受限，请稍后重试。';

  @override
  String get metadataMissingSource => '来源文件已缺失';

  @override
  String get metadataAttribution => '本产品使用 TMDB API，但未经 TMDB 认可或认证。';

  @override
  String get metadataForgetToken => '移除 TMDB 凭据';

  @override
  String get metadataTokenSaved => '已在本机保存 TMDB 令牌。';

  @override
  String get metadataTokenMissing => '尚未配置 TMDB 令牌。';

  @override
  String get metadataSearch => '搜索 TMDB';

  @override
  String get aiAssistant => 'AI 助手';

  @override
  String get aiPrivacyNotice => '消息、选定上下文及工具结果会发送至你配置的模型供应商。';

  @override
  String get aiWelcome => '可以让我查找媒体、继续观看或控制播放。请先配置模型。';

  @override
  String get aiYou => '你';

  @override
  String get aiToolResult => '工具结果';

  @override
  String get aiConfirmAction => '确认这项变更';

  @override
  String get aiApprove => '同意执行';

  @override
  String get aiInputHint => '想看些什么？';

  @override
  String get aiStop => '停止生成';

  @override
  String get aiSend => '发送';

  @override
  String get aiToolFailed => '工具未完成';

  @override
  String get aiConfigureFirst => '请先在 AI 设置中配置模型、API Key 并授权发送至云端。';

  @override
  String get aiSendFailed => '无法发送，请检查输入长度后重试。';

  @override
  String get aiCancelled => '已停止生成，已完成操作会保留。';

  @override
  String get aiTimeout => '请求超时，已完成操作会保留。';

  @override
  String get aiBudgetReached => '已达到本回合上限，已完成结果会保留。';

  @override
  String get aiProviderFailed => '模型请求失败，请检查凭据、端点及模型支持情况。';

  @override
  String get aiInterrupted => '上次关闭时中断，不会重放操作。';

  @override
  String aiTokenUsage(int count) {
    return '供应商报告用量：$count tokens';
  }

  @override
  String get aiModelSettings => '模型设置';

  @override
  String get aiProviderDescription =>
      '使用 OpenAI 或兼容协议的 HTTPS 端点。API Key 保存在系统凭据存储中。';

  @override
  String get aiEndpoint => 'API 基址';

  @override
  String get aiModel => '模型 ID';

  @override
  String get aiApiKey => 'API Key';

  @override
  String get aiKeyRequired => '填写 API Key';

  @override
  String get aiKeySaved => '已保存凭据，留空保留';

  @override
  String get aiOutputLimit => '输出 token 上限（128–16384）';

  @override
  String get aiCloudConsent => '允许此供应商接收对话历史、媒体标题、来源名称及播放摘要，并请求已列出的媒体与播放工具。';

  @override
  String get aiTestText => '测试普通回复';

  @override
  String get aiTestStream => '测试流式回复';

  @override
  String get aiTestTools => '测试工具调用';

  @override
  String get aiTestPassed => '连接测试通过，保存后生效。';

  @override
  String get aiTestFailed => '测试失败，请检查凭据及协议支持。工具调用须单独通过测试。';

  @override
  String get aiToolsVerified => '工具调用已验证，将启用实际可用的业务工具。';

  @override
  String get aiTextOnly => '工具调用测试通过前仅启用纯对话。';

  @override
  String get aiSaveFailed => '保存失败，请检查配置及系统凭据存储权限。';

  @override
  String aiExecuting(String name) {
    return '正在执行 $name…';
  }

  @override
  String get aiAuthenticationFailed => '认证失败，请在模型设置中更新 API Key。';

  @override
  String get aiRateLimited => '已达到供应商限流，请稍后重试。';

  @override
  String get aiProtocolMismatch => '端点或模型不支持此请求，请检查连接测试结果。';

  @override
  String get metadataAutomaticQueued => '等待自动识别';

  @override
  String get metadataAutomaticWaitingConfig =>
      '后台刮削需要配置有效的 TMDB 读取令牌，本地 NFO 和播放不受影响。';

  @override
  String get metadataAutomaticRetry => '重试未完成的刮削';

  @override
  String metadataAutomaticStatus(
    int queued,
    int running,
    int waiting,
    int failed,
  ) {
    return '后台刮削：$queued 待处理 · $running 处理中 · $waiting 待确认 · $failed 失败';
  }

  @override
  String get fileSources => '文件源';

  @override
  String get addFileSource => '添加文件源';

  @override
  String get nameFileSource => '为文件源命名';

  @override
  String get fileSourceEnable => '启用';

  @override
  String get fileSourceDisable => '停用';

  @override
  String get fileSourceDisabled => '已停用';

  @override
  String get rescanAll => '重新扫描全部文件源';

  @override
  String get noFileSources => '还没有文件源，添加一个文件夹开始建立媒体库';

  @override
  String get removeFileSource => '删除文件源';

  @override
  String get removeFileSourceConfirm => '删除此文件源？';

  @override
  String get libraryEmptyNoMedia => '文件源中暂无可识别的媒体，请重新扫描或检查文件命名';

  @override
  String get chooseFolderDescription => '进入目录并确认作为文件源。仅索引其中的媒体，不下载视频。';

  @override
  String get confirmFolder => '使用此文件夹';

  @override
  String get libraryNoFileSources => '还没有文件源。请在「来源」中为连接添加文件夹';

  @override
  String get sourceTabConnections => '连接';

  @override
  String get sourceTabFileSources => '文件源';

  @override
  String get moreActions => '更多操作';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get home => '首頁';

  @override
  String get library => '媒體庫';

  @override
  String get sources => '來源';

  @override
  String get settings => '設定';

  @override
  String get system => '跟隨系統';

  @override
  String get light => '淺色';

  @override
  String get dark => '深色';

  @override
  String get appearance => '外觀';

  @override
  String get themeMode => '主題模式';

  @override
  String get themeDescription => '立即套用並於下次啟動時恢復';

  @override
  String get language => '介面語言';

  @override
  String get preferenceSaveFailed => '偏好儲存失敗';

  @override
  String get preferenceSaveRetry => '目前選擇已生效，請重新選擇以重試儲存。';

  @override
  String get sourceDefaults => '來源預設設定';

  @override
  String get sourceDefaultsDescription => '管理瀏覽、搜尋及掃描使用的預設來源';

  @override
  String get manage => '管理';

  @override
  String get about => '關於 OpenPlayX';

  @override
  String get aboutDescription => '你的媒體，一個安靜的播放空間。';

  @override
  String get favorite => '收藏';

  @override
  String get unfavorite => '取消收藏';

  @override
  String get retry => '重試';

  @override
  String get cancel => '取消';

  @override
  String get save => '儲存';

  @override
  String get add => '新增';

  @override
  String get delete => '刪除';

  @override
  String get remove => '移除';

  @override
  String get close => '關閉';

  @override
  String get openFile => '開啟檔案';

  @override
  String get welcome => '歡迎使用 OpenPlayX';

  @override
  String get welcomeDescription => '從上次停下的地方繼續，或瀏覽你的媒體庫。';

  @override
  String get continueWatching => '繼續觀看';

  @override
  String get continueEmpty => '尚無未看完的影片，播放後會在這裡顯示。';

  @override
  String get recentlyPlayed => '最近播放';

  @override
  String get recentEmpty => '尚無播放紀錄。到媒體庫或來源中選擇影片。';

  @override
  String get rewatch => '已看完 · 重新播放';

  @override
  String get libraryOpenFailed => '無法開啟媒體庫，請重試';

  @override
  String get platformUnsupported => '目前平台暫不支援播放';

  @override
  String get historyUnavailable => '此播放紀錄的資源無法使用';

  @override
  String get fileUnavailable => '檔案無法使用';

  @override
  String get historyOpenFailed => '無法開啟此紀錄，請檢查檔案或來源連線';

  @override
  String get libraryLoadFailed => '媒體庫開啟失敗，請返回後重試';

  @override
  String get createLibrary => '建立媒體庫';

  @override
  String get contentType => '內容類型';

  @override
  String get mixed => '混合';

  @override
  String get movie => '電影';

  @override
  String get series => '影集';

  @override
  String get homeVideos => '家庭影片';

  @override
  String get audio => '音訊';

  @override
  String get chooseScopeSource => '選擇來源（僅掃描選定範圍）';

  @override
  String get addEnabledSource => '請先新增並啟用來源';

  @override
  String get bindFailed => '無法新增來源，請檢查連線後重試';

  @override
  String get scanFailedRetained => '掃描失敗；已入庫的內容保留，可重試';

  @override
  String get localUnavailable => '本機檔案無法使用';

  @override
  String get watchedSuffix => ' · 已看完';

  @override
  String get missingOnScan => '掃描未發現，可能已失聯';

  @override
  String get verifyOnPlay => '播放時驗證可用性';

  @override
  String get chooseVersion => '選擇資源版本播放；不同版本不自動換算時間軸';

  @override
  String get season => '季';

  @override
  String get episode => '單集';

  @override
  String get media => '媒體';

  @override
  String get previousPage => '上一頁';

  @override
  String get nextPage => '下一頁';

  @override
  String get versionOpenFailed => '此版本無法開啟，請檢查來源或選擇其他版本';

  @override
  String get addToLibrary => '加入其他媒體庫';

  @override
  String get chooseLibrary => '選擇媒體庫';

  @override
  String get correctTitle => '修正標題';

  @override
  String get removeFromLibrary => '從目前媒體庫移除（保留原檔案和媒體紀錄）';

  @override
  String get continueIncludingHistory => '繼續觀看（包括未入庫的播放紀錄）';

  @override
  String get allLibraries => '全部媒體庫';

  @override
  String get renameLibrary => '重新命名媒體庫';

  @override
  String get addSourceScope => '新增來源範圍';

  @override
  String get deleteLibrary => '刪除媒體庫';

  @override
  String get deleteLibraryConfirm => '刪除目前媒體庫？';

  @override
  String get deleteLibraryDescription => '僅刪除媒體庫和成員關係，保留原檔案、媒體及收藏。';

  @override
  String get searchLibrary => '搜尋庫內媒體';

  @override
  String get allSources => '全部來源';

  @override
  String get allTypes => '全部類型';

  @override
  String get video => '一般影片';

  @override
  String get allWatchStates => '全部觀看狀態';

  @override
  String get watched => '已看完';

  @override
  String get unwatched => '未看完';

  @override
  String get restoreIgnored => '取消移除忽略（下次掃描恢復）';

  @override
  String get sourceNeedsSetup => '需要設定來源';

  @override
  String get rescan => '重新掃描';

  @override
  String get removeBinding => '移除綁定';

  @override
  String get removeBindingConfirm => '移除掃描綁定？';

  @override
  String get createFirstLibrary => '建立第一個媒體庫';

  @override
  String get noMatchingMedia => '沒有符合條件的媒體';

  @override
  String get libraryEmpty => '尚無內容，請新增來源範圍或重新掃描';

  @override
  String get browseFailed => '無法瀏覽，請檢查來源後重試';

  @override
  String get scopeDescription => '掃描會索引此範圍內的媒體，不下載影片。請選擇已授權的目錄或伺服器媒體庫。';

  @override
  String get parent => '上一層';

  @override
  String get loadMore => '載入更多';

  @override
  String get rootFolder => '根目錄';

  @override
  String get confirmScanScope => '確認掃描此範圍';

  @override
  String get chooseScanScope => '選擇掃描範圍';

  @override
  String get defaultSaveFailed => '預設實例儲存失敗。';

  @override
  String get defaultDescription => '預設實例僅用於未明確選擇來源的操作。已有資源始終由原實例解析，不自動切換帳號。';

  @override
  String get defaultBrowse => '預設瀏覽實例';

  @override
  String get defaultResolve => '預設資源解析實例';

  @override
  String get chooseEachTime => '每次選擇';

  @override
  String get defaultUnavailable => '存在無法使用的預設實例綁定，請重新選擇；未自動替換為其他帳號。';

  @override
  String get searchScope => '多來源搜尋範圍';

  @override
  String get searchScopeDescription =>
      '選擇參與彙總搜尋的 Plex/Jellyfin 來源。本機資料夾與 SMB 透過已索引的媒體庫查詢。';

  @override
  String get sourceDefaultsTitle => '能力預設實例及搜尋範圍';

  @override
  String get localFolder => '本機資料夾';

  @override
  String get pickFolderFailed => '無法選擇資料夾，請重試。';

  @override
  String get openBrowserFailed => '無法開啟瀏覽器，請點選登入連結重試。';

  @override
  String get noPlexServers => '此 Plex 帳號下沒有可存取的伺服器。';

  @override
  String get plexSignInFailed => 'Plex 登入失敗，請重試。';

  @override
  String get enterToken => '請填寫存取權杖後連線至伺服器。';

  @override
  String get signInPlexFirst => '請先登入 Plex 並選擇伺服器。';

  @override
  String get connectionFormFailed => '連線失敗，請檢查位址及登入資訊。';

  @override
  String get hidePassword => '隱藏密碼';

  @override
  String get showPassword => '顯示密碼';

  @override
  String get address => '位址';

  @override
  String get addressHint => '192.168.1.10 或 https://media.example.com';

  @override
  String get username => '使用者名稱';

  @override
  String get guestHelp => '訪客存取時，使用者名稱及密碼均留空';

  @override
  String get password => '密碼';

  @override
  String get keepCredentials => '留空保留目前登入';

  @override
  String get advanced => '進階';

  @override
  String get port => '連接埠';

  @override
  String get optionalPath => '路徑（選填）';

  @override
  String get smbPathHint => '共用資料夾/影片目錄';

  @override
  String get serverPathHint => '例如 jellyfin，無則留空';

  @override
  String get scanExtensions => '掃描的檔案副檔名';

  @override
  String get scanExtensionsHelp =>
      '以逗號分隔。預覽與入庫只保留這些副檔名的檔案，留空則保留所有檔案。以點開頭的隱藏檔案一律忽略。';

  @override
  String get optionalDomain => '工作群組（選填）';

  @override
  String get waitingPlex => '等待 Plex 授權…';

  @override
  String get signInPlex => '登入 Plex';

  @override
  String get signInPlexAgain => '重新登入 Plex';

  @override
  String get plexBrowserHelp => '在瀏覽器中登入 Plex，再選擇要連線的伺服器。';

  @override
  String get reopenSignIn => '重新開啟登入頁面';

  @override
  String get server => '伺服器';

  @override
  String get manualServer => '手動連線至伺服器';

  @override
  String get serverAddress => '伺服器位址';

  @override
  String get portInAddress => '使用自訂連接埠時，請一併填入位址。';

  @override
  String get accessToken => '存取權杖';

  @override
  String get addSource => '新增媒體來源';

  @override
  String get editSource => '編輯媒體來源';

  @override
  String get type => '類型';

  @override
  String get optionalName => '名稱（選填）';

  @override
  String get chooseFolder => '選擇資料夾';

  @override
  String get folderAccessHelp => '請選擇系統允許應用程式存取的資料夾。';

  @override
  String get loadSourcesFailed => '載入媒體來源失敗，請重試。';

  @override
  String get filePlayFailed => '無法播放此檔案。';

  @override
  String get previewLimit => '已達預覽上限 500 個檔案，結果不完整。';

  @override
  String get previewDescription => '已套用存取範圍及掃描排除項目；此操作不寫入媒體庫、不建立背景索引。';

  @override
  String get scanFailed => '掃描失敗。';

  @override
  String get backToParent => '返回上一層';

  @override
  String get sourcesEmpty => '新增本機資料夾、SMB、Jellyfin 或 Plex 來源。';

  @override
  String get disableSourceConfirm => '停用媒體來源？';

  @override
  String get disable => '停用';

  @override
  String get toggleSourceFailed => '啟停失敗，請重試。';

  @override
  String get verifyConnection => '驗證連線';

  @override
  String get connectionFailed => '連線失敗。';

  @override
  String get previewScan => '預覽掃描';

  @override
  String get deleteSource => '刪除媒體來源';

  @override
  String get deleteSourceFailed => '刪除來源失敗，請重試。';

  @override
  String get folderEmpty => '此目錄沒有可瀏覽的媒體。';

  @override
  String get reloadConfiguration => '重新載入設定';

  @override
  String get defaultBrowseUnavailable => '預設實例無法使用，請重新選擇，未自動切換其他帳號。';

  @override
  String get browseDefault => '預設瀏覽';

  @override
  String get capabilityDefaults => '能力預設實例';

  @override
  String get addSourceShort => '新增來源';

  @override
  String get playerClosed => '播放器已關閉';

  @override
  String get historySaveFailed => '觀看紀錄暫時無法儲存，仍可繼續播放';

  @override
  String get adjustFailed => '調整失敗，請重試。';

  @override
  String get audioTrack => '音軌';

  @override
  String get noAudioTracks => '此媒體沒有可選音軌';

  @override
  String get subtitleTrack => '字幕';

  @override
  String get noSubtitleTracks => '此媒體沒有可選字幕';

  @override
  String get subtitleOff => '關閉字幕';

  @override
  String numberedSubtitleTrack(int id) {
    return '字幕 $id';
  }

  @override
  String get playbackCommandFailed => '播放操作失敗，請重新開啟媒體檔案。';

  @override
  String get openFileFailed => '無法開啟檔案，請重新選擇。';

  @override
  String get stopPlaybackFailed => '停止播放失敗，請重試返回';

  @override
  String get volume => '音量';

  @override
  String get brightness => '畫面亮度';

  @override
  String get rewind => '倒退 10 秒';

  @override
  String get pause => '暫停';

  @override
  String get play => '播放';

  @override
  String get forward => '快轉 10 秒';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get morePlaybackSettings => '更多播放設定';

  @override
  String get lockControls => '鎖定控制';

  @override
  String get playerVolume => '播放器音量';

  @override
  String get playerEmpty => '開啟影片，開始播放';

  @override
  String get back => '返回';

  @override
  String get playbackFailed => '播放失敗，請檢查檔案或重新選擇。';

  @override
  String get boost => '暫時 2× · 放開恢復';

  @override
  String get unlockControls => '解鎖控制';

  @override
  String get loading => '正在載入…';

  @override
  String watchProgress(int position, int duration) {
    return '已看 $position / $duration 分鐘';
  }

  @override
  String metadataProgressLabel(int done, int total) {
    return '刮削 $done/$total';
  }

  @override
  String metadataProgressTooltip(int done, int total) {
    return '元資料刮削進度：已處理 $done / 共 $total（找不到符合的也算已處理）';
  }

  @override
  String watchedMinutes(int minutes) {
    return ' · 已看 $minutes 分鐘';
  }

  @override
  String localResource(String progress) {
    return '本機檔案（播放時檢查存取權限）$progress';
  }

  @override
  String setupResource(String progress) {
    return '需要設定或啟用來源$progress';
  }

  @override
  String removeBindingDescription(int count) {
    return '此綁定關聯 $count 項內容。僅移除失去全部來源依據的自動成員，保留手動成員、共用媒體及原檔案。';
  }

  @override
  String sourceVersion(String kind, String plugin, int config, int revision) {
    return '$kind · 外掛程式 $plugin · 設定 v$config · r$revision';
  }

  @override
  String disableSourceDescription(int playing, int running, int defaults) {
    return '目前播放 $playing 個，進行中請求 $running 個，預設能力綁定 $defaults 項。停用後拒絕新請求並清除預設綁定；目前播放可繼續，結束後釋放連線。設定、收藏和產物保留。';
  }

  @override
  String deleteSourceDescription(int defaults, int playing, int running) {
    return '僅刪除此實例設定與憑證參照，不刪除原始檔案、收藏或產物。預設能力綁定 $defaults 項及搜尋範圍綁定將被清除。目前播放 $playing 個、進行中請求 $running 個可完成，之後釋放連線。';
  }

  @override
  String previewTitle(String name) {
    return '掃描預覽：$name';
  }

  @override
  String filesFound(int count) {
    return '找到 $count 個檔案。';
  }

  @override
  String deleteNamedSource(String name) {
    return '刪除 $name？';
  }

  @override
  String numberedAudioTrack(int id) {
    return '音軌 $id';
  }

  @override
  String remainingTime(String time) {
    return '剩餘 $time';
  }

  @override
  String readSpeed(String speed) {
    return '讀取 $speed MB/s';
  }

  @override
  String get notVerified => '尚未驗證';

  @override
  String get disabled => '已停用';

  @override
  String get pendingApply => '待套用';

  @override
  String get applied => '已套用';

  @override
  String get applyFailed => '套用失敗';

  @override
  String get credentialsMissing => '需要登入';

  @override
  String get credentialsReady => '憑證已儲存';

  @override
  String get localSource => '本機資料夾';

  @override
  String get credentialsUnknown => '憑證狀態未知';

  @override
  String get screenOrientation => '螢幕方向';

  @override
  String get orientationSystem => '跟隨系統';

  @override
  String get orientationPortrait => '直向';

  @override
  String get orientationLandscape => '橫向';

  @override
  String get videoRotation => '畫面旋轉';

  @override
  String get rotationOriginal => '原始方向（0°）';

  @override
  String get sourceReady => '已就緒';

  @override
  String get sourceConnectionFailed => '連線失敗';

  @override
  String get sourceInitialized => '已初始化 · 待連線驗證';

  @override
  String get sourceSaved => '已儲存 · 下次存取生效';

  @override
  String get credentialsNotRequired => '無需帳號憑證';

  @override
  String get credentialsUnverified => '憑證已儲存 · 尚未驗證';

  @override
  String get credentialsExpiring => '權杖將在 7 天內到期';

  @override
  String get credentialsExpired => '權杖已到期';

  @override
  String get credentialsRejected => '驗證失敗 · 請更新憑證';

  @override
  String get credentialsVerified => '連線已驗證';

  @override
  String get playbackPosition => '播放進度';

  @override
  String get shadHours => '時';

  @override
  String get shadMinutes => '分';

  @override
  String get shadSeconds => '秒';

  @override
  String get shadPeriod => '時段';

  @override
  String get shadMorning => '上午';

  @override
  String get shadSelectDate => '選擇日期';

  @override
  String get shadCut => '剪下';

  @override
  String get shadCopy => '複製';

  @override
  String get shadPaste => '貼上';

  @override
  String get shadSelectAll => '全選';

  @override
  String get shadDone => '完成';

  @override
  String scanFoundMedia(int n) {
    return '已發現 $n 個媒體檔案';
  }

  @override
  String get detailOverview => '簡介';

  @override
  String get detailCast => '演員';

  @override
  String get detailDirectors => '導演';

  @override
  String seasonLabel(int n) {
    return '第 $n 季';
  }

  @override
  String episodeLabel(int n) {
    return '第 $n 集';
  }

  @override
  String get detailNoEpisodes => '還沒有可播放的劇集。';

  @override
  String get metadata => '影視資訊';

  @override
  String get metadataIdentify => '識別 / 重新配對';

  @override
  String get metadataImport => '匯入鄰近 NFO 和圖片';

  @override
  String get metadataRefresh => '重新整理已關聯作品';

  @override
  String get metadataSource => '欄位來源';

  @override
  String get metadataQuery => '作品名稱';

  @override
  String get metadataYear => '年份（選填）';

  @override
  String get metadataProviderId => 'TMDB ID（選填）';

  @override
  String get metadataLanguage => '中繼資料語言';

  @override
  String get metadataToken => 'TMDB 讀取存取權杖';

  @override
  String get metadataConfigure => '設定 TMDB';

  @override
  String get metadataPrivacy =>
      '加入媒體庫的影視會在背景自動識別，僅向 TMDB 傳送必要的名稱、年份、ID 和語言，不上傳影片或私人路徑。';

  @override
  String get metadataSaved => 'TMDB 設定已儲存';

  @override
  String get metadataCandidates => '選擇作品';

  @override
  String get metadataChooseChildren => '選擇季 / 集';

  @override
  String get metadataConfirm => '確認配對';

  @override
  String get metadataKeepLocks => '保留已鎖定欄位和海報，播放進度及資源版本不受影響。';

  @override
  String get metadataOverview => '簡介';

  @override
  String get metadataOriginalTitle => '原名';

  @override
  String get metadataGenres => '類型';

  @override
  String get metadataEdit => '編輯並鎖定欄位';

  @override
  String get metadataRestore => '恢復自動來源';

  @override
  String get metadataArtwork => '選擇海報';

  @override
  String get metadataArtworkLocked => '海報已鎖定';

  @override
  String get metadataReset => '重設配對';

  @override
  String get metadataResetDescription => '清除匯入欄位和作品關聯，保留使用者修改、鎖定海報及播放資料。';

  @override
  String get metadataClearCache => '清理圖片快取';

  @override
  String get metadataBatch => '匯入全庫影視資訊';

  @override
  String get metadataBatchDone => '全庫匯入完成，可查看各項目的識別狀態。';

  @override
  String get metadataUnmatched => '找不到配對資訊';

  @override
  String get metadataAwaiting => '等待確認';

  @override
  String get metadataCompleted => '影視資訊已儲存';

  @override
  String get metadataCancelled => '已取消或中斷，保留已儲存資訊';

  @override
  String get metadataBusy => '正在取得影視資訊…';

  @override
  String get metadataNotStarted => '尚未識別';

  @override
  String get metadataFailed => '讀取影視資訊失敗，已有媒體仍可使用。';

  @override
  String get metadataConflict => '作品身分衝突，請選擇正確候選。';

  @override
  String get metadataStale => '查詢期間資訊已更改，請重新查詢。';

  @override
  String get metadataAuth => '請設定有效的 TMDB 讀取存取權杖。';

  @override
  String get metadataOffline => '網路請求失敗，請連網後重試。';

  @override
  String get metadataPermission => '來源未授權讀取此附件。';

  @override
  String get metadataRateLimited => 'TMDB 請求受限，請稍後重試。';

  @override
  String get metadataMissingSource => '來源檔案已遺失';

  @override
  String get metadataAttribution => '本產品使用 TMDB API，但未經 TMDB 認可或認證。';

  @override
  String get metadataForgetToken => '移除 TMDB 憑證';

  @override
  String get metadataTokenSaved => '已在本機儲存 TMDB 權杖。';

  @override
  String get metadataTokenMissing => '尚未設定 TMDB 權杖。';

  @override
  String get metadataSearch => '搜尋 TMDB';

  @override
  String get aiAssistant => 'AI 助手';

  @override
  String get aiPrivacyNotice => '訊息、選定上下文及工具結果會傳送至你設定的模型供應商。';

  @override
  String get aiWelcome => '可以讓我尋找媒體、繼續觀看或控制播放。請先設定模型。';

  @override
  String get aiYou => '你';

  @override
  String get aiToolResult => '工具結果';

  @override
  String get aiConfirmAction => '確認這項變更';

  @override
  String get aiApprove => '同意執行';

  @override
  String get aiInputHint => '想看些什麼？';

  @override
  String get aiStop => '停止生成';

  @override
  String get aiSend => '傳送';

  @override
  String get aiToolFailed => '工具未完成';

  @override
  String get aiConfigureFirst => '請先在 AI 設定中設定模型、API Key 並授權傳送至雲端。';

  @override
  String get aiSendFailed => '無法傳送，請檢查輸入長度後重試。';

  @override
  String get aiCancelled => '已停止生成，已完成操作會保留。';

  @override
  String get aiTimeout => '請求逾時，已完成操作會保留。';

  @override
  String get aiBudgetReached => '已達到本回合上限，已完成結果會保留。';

  @override
  String get aiProviderFailed => '模型請求失敗，請檢查憑據、端點及模型支援情況。';

  @override
  String get aiInterrupted => '上次關閉時中斷，不會重播操作。';

  @override
  String aiTokenUsage(int count) {
    return '供應商回報用量：$count tokens';
  }

  @override
  String get aiModelSettings => '模型設定';

  @override
  String get aiProviderDescription =>
      '使用 OpenAI 或相容協定的 HTTPS 端點。API Key 儲存在系統憑據儲存區。';

  @override
  String get aiEndpoint => 'API 基址';

  @override
  String get aiModel => '模型 ID';

  @override
  String get aiApiKey => 'API Key';

  @override
  String get aiKeyRequired => '填寫 API Key';

  @override
  String get aiKeySaved => '已儲存憑據，留空保留';

  @override
  String get aiOutputLimit => '輸出 token 上限（128–16384）';

  @override
  String get aiCloudConsent => '允許此供應商接收對話歷史、媒體標題、來源名稱及播放摘要，並請求已列出的媒體與播放工具。';

  @override
  String get aiTestText => '測試一般回覆';

  @override
  String get aiTestStream => '測試串流回覆';

  @override
  String get aiTestTools => '測試工具呼叫';

  @override
  String get aiTestPassed => '連線測試通過，儲存後生效。';

  @override
  String get aiTestFailed => '測試失敗，請檢查憑據及協定支援。工具呼叫須獨立通過測試。';

  @override
  String get aiToolsVerified => '工具呼叫已驗證，將啟用實際可用的業務工具。';

  @override
  String get aiTextOnly => '工具呼叫測試通過前僅啟用純對話。';

  @override
  String get aiSaveFailed => '儲存失敗，請檢查設定及系統憑據儲存權限。';

  @override
  String aiExecuting(String name) {
    return '正在執行 $name…';
  }

  @override
  String get aiAuthenticationFailed => '驗證失敗，請在模型設定中更新 API Key。';

  @override
  String get aiRateLimited => '已達到供應商速率限制，請稍後重試。';

  @override
  String get aiProtocolMismatch => '端點或模型不支援此請求，請檢查連線測試結果。';

  @override
  String get metadataAutomaticQueued => '等待自動識別';

  @override
  String get metadataAutomaticWaitingConfig =>
      '背景擷取需要設定有效的 TMDB 讀取權杖，本機 NFO 和播放不受影響。';

  @override
  String get metadataAutomaticRetry => '重試未完成的擷取';

  @override
  String metadataAutomaticStatus(
    int queued,
    int running,
    int waiting,
    int failed,
  ) {
    return '背景擷取：$queued 待處理 · $running 處理中 · $waiting 待確認 · $failed 失敗';
  }

  @override
  String get fileSources => '檔案來源';

  @override
  String get addFileSource => '新增檔案來源';

  @override
  String get nameFileSource => '為檔案來源命名';

  @override
  String get fileSourceEnable => '啟用';

  @override
  String get fileSourceDisable => '停用';

  @override
  String get fileSourceDisabled => '已停用';

  @override
  String get rescanAll => '重新掃描全部檔案來源';

  @override
  String get noFileSources => '尚無檔案來源，新增一個資料夾開始建立媒體庫';

  @override
  String get removeFileSource => '刪除檔案來源';

  @override
  String get removeFileSourceConfirm => '刪除此檔案來源？';

  @override
  String get libraryEmptyNoMedia => '檔案來源中尚無可辨識的媒體，請重新掃描或檢查檔名';

  @override
  String get chooseFolderDescription => '進入目錄並確認作為檔案來源。僅索引其中的媒體，不下載影片。';

  @override
  String get confirmFolder => '使用此資料夾';

  @override
  String get libraryNoFileSources => '尚無檔案來源。請在「來源」中為連線新增資料夾';

  @override
  String get sourceTabConnections => '連線';

  @override
  String get sourceTabFileSources => '檔案來源';

  @override
  String get moreActions => '更多操作';
}
