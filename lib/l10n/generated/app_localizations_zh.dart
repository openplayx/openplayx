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
  String get defaultDescription => '默认实例只用于未显式选择来源的操作。已有资源始终由原实例解析，不自动切换账号。';

  @override
  String get defaultBrowse => '默认浏览实例';

  @override
  String get defaultResolve => '默认资源解析实例';

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
  String get connectionFailed => '连接失败。';

  @override
  String get deleteSourceFailed => '删除源失败，请重试。';

  @override
  String get folderEmpty => '此目录没有可浏览的媒体。';

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
  String disableSourceDescription(int playing, int running) {
    return '当前播放 $playing 个，进行中请求 $running 个。禁用后拒绝新请求；当前播放可继续，结束后释放连接。配置、收藏和产物保留。';
  }

  @override
  String deleteSourceDescription(int playing, int running) {
    return '仅删除此实例配置与凭据引用，不删除原始文件、收藏或产物。当前播放 $playing 个、进行中请求 $running 个可完成，之后释放连接。';
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
  String get metadataTokenStatusSaved => '已保存';

  @override
  String get metadataTokenStatusMissing => '未配置';

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
  String get aiConfigureFirst => '请先在模型设置中填写 API 域名、模型名和 Key。';

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
      '支持 OpenAI 兼容接口，例如 DeepSeek。Key 保存在系统钥匙串中。';

  @override
  String get aiEndpoint => 'API 域名';

  @override
  String get aiModel => '模型名';

  @override
  String get aiApiKey => 'API Key';

  @override
  String get aiKeyRequired => '填写 API Key';

  @override
  String get aiKeySaved => '已保存凭据，留空保留';

  @override
  String get aiSaveFailed => '保存失败，请检查配置及系统凭据存储权限。';

  @override
  String aiExecuting(String name) {
    return '正在执行 $name…';
  }

  @override
  String get aiAuthenticationFailed => '认证失败，请检查 API Key 和 API 基址是否属于同一服务商。';

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
  String get nameFileSource => '为文件源命名';

  @override
  String get fileSourceEnable => '启用';

  @override
  String get fileSourceDisable => '停用';

  @override
  String get fileSourceDisabled => '已停用';

  @override
  String get noFileSources => '还没有文件源，添加一个文件夹开始建立媒体库';

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
  String get aiNewChat => '新建对话';

  @override
  String get aiChatHistory => '会话历史';

  @override
  String get aiShowMedia => '返回首页内容';

  @override
  String get aiExpandChat => '在首页展开';

  @override
  String get aiLatest => '回到最新';

  @override
  String get aiDraftNext => '正在回复，你可以先编辑下一条消息。';

  @override
  String get aiSuggestMedia => '帮我找一部电影';

  @override
  String get aiSuggestResume => '我上次看到哪里了？';

  @override
  String get aiToolPreparing => '准备执行';

  @override
  String get aiToolRunning => '执行中';

  @override
  String get aiToolWaiting => '等待确认';

  @override
  String get aiToolSucceeded => '已完成';

  @override
  String get aiToolCancelled => '未执行或已取消';

  @override
  String get aiActionExpired => '此操作已失效，请重新选择。';

  @override
  String get aiRemoteImageBlocked => '远程图片未自动加载';

  @override
  String get aiOpenLink => '打开外部链接？';

  @override
  String get aiLinkBlocked => '无法打开此链接';

  @override
  String get aiTaskSubmitted => '已提交任务';

  @override
  String get aiPartialFailure => '部分来源暂不可用';

  @override
  String get aiMoreResults => '还有更多结果，可继续提问查看。';

  @override
  String get aiNoResults => '没有找到匹配内容';

  @override
  String get aiUntitledChat => '新对话';

  @override
  String get aiHistoryEmpty => '还没有会话记录';

  @override
  String get aiReplying => '正在回复…';

  @override
  String get aiToolSummary => '操作及结果来自本机服务';

  @override
  String get aiEarlier => '加载更早消息';

  @override
  String get diagnosticsTitle => '发送诊断信息';

  @override
  String get diagnosticsDescription =>
      '可选向配置的 Sentry 服务发送应用版本及脱敏错误堆栈，不含媒体路径、凭据或聊天内容。开启后重启生效，关闭立即停止所有窗口及后台任务的新上报。暂不收集原生崩溃。';

  @override
  String get anonymousHelp => '匿名访问时，用户名和密码都留空';

  @override
  String get s3AccessKey => 'Access Key ID';

  @override
  String get s3SecretKey => 'Secret Access Key';

  @override
  String get s3AnonymousHelp => '公开存储桶可以不填密钥';

  @override
  String get s3Region => '区域（可选，默认 us-east-1）';

  @override
  String get s3PathHint => '存储桶/可选前缀，例如 media/movies';

  @override
  String get remotePathHint => '例如 media/movies，留空为根目录';

  @override
  String get dlnaSearch => '搜索局域网设备';

  @override
  String get dlnaSearching => '正在搜索…';

  @override
  String get dlnaNoDevices => '没有找到媒体服务器，可以手动填写设备描述地址。';

  @override
  String get dlnaDevice => '设备';

  @override
  String get dlnaAddress => '设备描述地址';

  @override
  String get dlnaAddressHelp => '选择搜索到的设备会自动填写，也可以手动填写。';

  @override
  String get aiOpenExternal => '打开链接';

  @override
  String get serverBrowseAll => '全部';

  @override
  String get serverUnavailable => '无法连接此服务器';

  @override
  String get serverEmpty => '这里还没有内容';

  @override
  String get serverLoadMore => '加载更多';

  @override
  String get localLibrary => '本地媒体库';

  @override
  String get remoteHomeAccess => '家庭远程访问';

  @override
  String get remoteProxy => '服务（frpc proxy）';

  @override
  String get remoteNoProxies => '还没有可用的 proxy：请先在 设置 → 远程访问 导入 Relay 的 App 配置。';

  @override
  String remoteProxyMissing(String name) {
    return '$name（当前 App 配置中没有）';
  }

  @override
  String get remoteLanAddress => '已配对的局域网 HTTPS 地址';

  @override
  String get remoteLanFingerprint => '局域网服务证书 SHA-256';

  @override
  String get remoteLanIdentityHelp => '通过可信途径确认的 64 位十六进制指纹；服务证书还须通过系统信任校验。';

  @override
  String get remoteAutomatic => '自动：验证局域网后使用，否则走远程';

  @override
  String get remoteLocalOnly => '仅局域网';

  @override
  String get remoteRemoteOnly => '仅远程';

  @override
  String get developerMode => '开发调试';

  @override
  String get developerModeDescription => '开启后显示调试入口，例如媒体详情页右上角的“影视信息”按钮。';

  @override
  String get metadataConfigureInSettings => '请在“设置 → TMDB”中配置读取访问令牌后再搜索。';

  @override
  String get scrapeManagement => '刮削管理';

  @override
  String get scrapedCount => '已刮削条目';

  @override
  String scrapedCountValue(int count) {
    return '$count 条';
  }

  @override
  String get scrapeStorage => '占用空间';

  @override
  String scrapeStorageDetail(String database, String artwork) {
    return '数据库 $database · 图片缓存 $artwork';
  }

  @override
  String get scrapeLoading => '正在统计…';

  @override
  String get scrapeClear => '清除全部刮削信息';

  @override
  String get scrapeClearHint => '删除从 TMDB 和 NFO 获取的影视信息及海报缓存。';

  @override
  String get scrapeClearTitle => '清除全部刮削信息？';

  @override
  String get scrapeClearDescription =>
      '将删除从 TMDB 和 NFO 获取的影视信息、匹配结果和已下载的海报，无法撤销。视频文件、播放进度、媒体服务器提供的信息和你手动修改的内容都会保留。如果已配置 TMDB，后台会重新开始刮削。';

  @override
  String get scrapeCleared => '已清除全部刮削信息。';

  @override
  String get scrapeClearFailed => '清除失败，请稍后重试。';

  @override
  String get metadataProgressDone => '刮削完成';

  @override
  String get edit => '编辑';

  @override
  String get refresh => '刷新';

  @override
  String get addFileSourceShort => '添加文件源';

  @override
  String shelfViewAll(int count) {
    return '全部 · $count';
  }

  @override
  String get recentlyAdded => '最近添加';

  @override
  String get tvShows => '电视剧';

  @override
  String seasonCount(int n) {
    return '共$n季';
  }

  @override
  String seasonEpisodeShort(int season, int episode) {
    return '第$season季 第$episode集';
  }

  @override
  String get detailCastAndCrew => '演职人员';

  @override
  String get detailGenres => '风格';

  @override
  String get detailCollection => '系列电影';

  @override
  String get detailVersions => '版本';

  @override
  String get detailViewAll => '查看全部';

  @override
  String get detailScrollStart => '回到开头';

  @override
  String get detailScrollEnd => '跳到末尾';

  @override
  String detailEpisodeCount(int n) {
    return '共 $n 集';
  }

  @override
  String detailMovieCount(int n) {
    return '共 $n 部';
  }

  @override
  String detailRuntime(int n) {
    return '$n 分钟';
  }

  @override
  String get markWatched => '标记为已看';

  @override
  String get markUnwatched => '标记为未看';

  @override
  String get removeFavorite => '取消收藏';

  @override
  String get aiMore => '更多';

  @override
  String get aiGreeting => '有什么可以帮你？';

  @override
  String get aiSuggestTonight => '推荐一部今晚看的电影';

  @override
  String get aiSuggestContinue => '继续看上次没看完的';

  @override
  String get aiSuggestSciFi => '我的片库里有哪些科幻片？';

  @override
  String get aiTestConnection => '测试连接';

  @override
  String get aiCheckingConnection => '正在测试连接…';

  @override
  String get aiConnectionOk => '连接成功，可以聊天和使用工具。';

  @override
  String get aiConnectionOkNoTools => '连接成功，但该模型不支持工具调用，只能纯聊天。';

  @override
  String get aiInvalidSettings => '请填写有效的 HTTPS API 域名和模型名。';

  @override
  String get remoteConnectionMode => '连接方式';

  @override
  String get ffmpegSnapshotDebug => 'FFmpeg 截图调试';

  @override
  String get ffmpegSnapshotAgain => '再截一张';

  @override
  String ffmpegSnapshotAt(String time, String duration) {
    return '截图时间点 $time / $duration';
  }

  @override
  String ffmpegSnapshotFailed(String reason) {
    return '截图失败（$reason）。';
  }

  @override
  String get ffmpegUnavailable => '此构建未包含 FFmpeg 媒体处理模块。';

  @override
  String get asrDebugTitle => '音频与字幕调试';

  @override
  String get asrChooseEpisode => '选择单集';

  @override
  String get asrSectionResource => '当前资源';

  @override
  String get asrSectionInput => '输入选择';

  @override
  String get asrSectionBackend => '识别方式';

  @override
  String get asrSectionActions => '操作';

  @override
  String get asrSectionStatus => '执行状态';

  @override
  String get asrSectionAudio => '音频结果';

  @override
  String get asrSectionSubtitles => '字幕结果';

  @override
  String get asrSectionDebug => '调试信息';

  @override
  String get asrTitle => '剧名';

  @override
  String get asrEpisode => '季/集';

  @override
  String get asrVersion => '媒体版本';

  @override
  String get asrDuration => '时长';

  @override
  String get asrUnknown => '未知';

  @override
  String get asrStart => '开始（秒或 分:秒）';

  @override
  String get asrEnd => '结束（秒或 分:秒）';

  @override
  String get asrWhole => '整集';

  @override
  String get asrRangeHint => '默认处理开头 60 秒；整集需主动选择。';

  @override
  String get asrWholeUnavailable => '时长未知，暂不支持整集处理。';

  @override
  String get asrRangeInvalid => '区间无效：结束须晚于开始且在媒体时长内。';

  @override
  String asrChannels(int n) {
    return '$n 声道';
  }

  @override
  String get asrNotDecodable => '无法解码';

  @override
  String get asrEmbedded => '本机内嵌';

  @override
  String get asrHttp => 'HTTP 服务';

  @override
  String get asrNoBackends => '未配置识别后端。';

  @override
  String get asrChecking => '检查中…';

  @override
  String asrBackendReady(String engine, String revision) {
    return '可用 · $engine · 模型 $revision';
  }

  @override
  String asrBackendUnavailable(String reason) {
    return '不可用：$reason';
  }

  @override
  String get asrExtractOnly => '仅提取音频';

  @override
  String get asrExtractAndTranscribe => '提取并识别字幕';

  @override
  String get asrStagePreparing => '资源准备';

  @override
  String get asrStageExtracting => '音频提取';

  @override
  String get asrStageUploading => '上传';

  @override
  String get asrStageQueued => '排队';

  @override
  String get asrStageTranscribing => '识别';

  @override
  String get asrStageFormatting => '字幕生成';

  @override
  String get asrCancelling => '取消中…';

  @override
  String get asrCancelled => '已取消';

  @override
  String get asrSucceeded => '已完成';

  @override
  String asrFailed(String reason) {
    return '失败：$reason';
  }

  @override
  String get asrAudioTrack => '实际音轨';

  @override
  String get asrAudioFormat => '格式';

  @override
  String get asrAudioSize => '大小';

  @override
  String get asrAudioReused => '复用了配置一致的已有提取结果';

  @override
  String get asrNoSpeech => '此区间未识别到语音。';

  @override
  String get asrWholeResult => '整集';

  @override
  String asrPartialResult(String start, String end) {
    return '部分区间：$start – $end（非整集）';
  }

  @override
  String get asrSave => '保存字幕';

  @override
  String get asrExport => '导出…';

  @override
  String get asrExported => '已导出。';

  @override
  String get asrSaved => '已保存为此版本的新字幕。';

  @override
  String get asrSavedPartial => '已保存为此版本的新字幕（部分区间）。';

  @override
  String get asrSaveHint => '未保存的结果离开页面后清除；保存不会替换已有字幕或影响播放。';

  @override
  String get asrTaskId => '任务 ID';

  @override
  String get asrBackendLabel => '后端';

  @override
  String get asrModel => '模型';

  @override
  String get asrEngine => '引擎';

  @override
  String get asrLanguage => '语言（auto / zh / en …）';

  @override
  String get asrRemoteJob => '远端任务';

  @override
  String get asrError => '错误';

  @override
  String get asrContinue => '继续';

  @override
  String get asrWholeTitle => '处理整集？';

  @override
  String asrWholeBody(String duration, String size) {
    return '时长 $duration，音频约 $size。识别可能耗时较长。';
  }

  @override
  String get asrUploadTitle => '上传音频到识别服务？';

  @override
  String asrUploadBody(String host, String range, String insecure) {
    return '将上传 $range 的音频到 $host。$insecure';
  }

  @override
  String get asrUploadInsecure => '该服务使用未加密的 HTTP，音频传输不加密。';

  @override
  String get asrUploadAllow => '允许上传';

  @override
  String get asrUploadAuthorized => '已授权上传';

  @override
  String get asrErrorNoAudio => '该资源没有音轨。';

  @override
  String get asrErrorDurationUnknown => '时长未知。';

  @override
  String get asrErrorModelMissing => '模型未安装。';

  @override
  String get asrErrorEngineUnavailable => '此构建未包含本机识别引擎。';

  @override
  String get asrErrorUnreachable => '服务不可达。';

  @override
  String get asrErrorUnauthorized => '服务拒绝了凭据。';

  @override
  String get asrErrorUploadConsent => '尚未授权上传到该服务。';

  @override
  String get asrErrorTls => '无法验证服务证书。';

  @override
  String get asrErrorRemoteStream => '该来源暂不支持本机读取。';

  @override
  String get asrErrorTrackChanged => '文件已变化，请重新选择音轨。';

  @override
  String get asrSettingsTitle => '语音识别';

  @override
  String get asrModelFooter => '本机 Whisper 多语言模型。文件按大小与 SHA-256 校验后启用，不会自动下载。';

  @override
  String get asrModelDownload => '下载';

  @override
  String asrModelDownloading(String done, String total) {
    return '下载中 $done / $total';
  }

  @override
  String get asrModelDownloadFailed => '下载失败或文件校验未通过。';

  @override
  String get asrModelImport => '导入模型文件…';

  @override
  String get asrModelImportRejected => '不是已知的模型文件（大小或校验值不符）。';

  @override
  String get asrModelInstalled => '已安装';

  @override
  String get asrModelInUse => '已安装 · 使用中';

  @override
  String get asrModelNotInstalled => '未安装';

  @override
  String get asrModelUse => '使用';

  @override
  String get asrModelRemove => '删除';

  @override
  String get asrServicesTitle => '识别服务';

  @override
  String get asrAddService => '添加 HTTP 服务';

  @override
  String get asrEditService => '编辑服务';

  @override
  String get asrRemoveService => '删除';

  @override
  String get asrServicePrivacy => '仅在你允许后上传提取的音频，不发送视频链接或 NAS 凭据。';

  @override
  String get asrServiceName => '名称';

  @override
  String get asrServiceUrl => '服务地址（https://…）';

  @override
  String get asrServiceToken => '访问令牌';

  @override
  String get asrServiceUrlInvalid => '请输入不含凭据的 https:// 地址（仅在下方允许时可用 http://）。';

  @override
  String get asrServiceInvalid => '请检查模型与语言。';

  @override
  String get asrAllowHttp => '允许未加密 HTTP（仅局域网）';

  @override
  String get asrAllowHttpHint => '音频将以明文传输。HTTPS 证书校验不会被关闭。';

  @override
  String get asrInstallModel => '安装或选择模型';

  @override
  String get asrRecheck => '重新检查';

  @override
  String asrTranscribeBlocked(String reason) {
    return '暂不能识别：$reason';
  }
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
  String get defaultDescription => '默认实例只用于未显式选择来源的操作。已有资源始终由原实例解析，不自动切换账号。';

  @override
  String get defaultBrowse => '默认浏览实例';

  @override
  String get defaultResolve => '默认资源解析实例';

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
  String get connectionFailed => '连接失败。';

  @override
  String get deleteSourceFailed => '删除源失败，请重试。';

  @override
  String get folderEmpty => '此目录没有可浏览的媒体。';

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
  String disableSourceDescription(int playing, int running) {
    return '当前播放 $playing 个，进行中请求 $running 个。禁用后拒绝新请求；当前播放可继续，结束后释放连接。配置、收藏和产物保留。';
  }

  @override
  String deleteSourceDescription(int playing, int running) {
    return '仅删除此实例配置与凭据引用，不删除原始文件、收藏或产物。当前播放 $playing 个、进行中请求 $running 个可完成，之后释放连接。';
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
  String get metadataTokenStatusSaved => '已保存';

  @override
  String get metadataTokenStatusMissing => '未配置';

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
  String get aiConfigureFirst => '请先在模型设置中填写 API 域名、模型名和 Key。';

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
      '支持 OpenAI 兼容接口，例如 DeepSeek。Key 保存在系统钥匙串中。';

  @override
  String get aiEndpoint => 'API 域名';

  @override
  String get aiModel => '模型名';

  @override
  String get aiApiKey => 'API Key';

  @override
  String get aiKeyRequired => '填写 API Key';

  @override
  String get aiKeySaved => '已保存凭据，留空保留';

  @override
  String get aiSaveFailed => '保存失败，请检查配置及系统凭据存储权限。';

  @override
  String aiExecuting(String name) {
    return '正在执行 $name…';
  }

  @override
  String get aiAuthenticationFailed => '认证失败，请检查 API Key 和 API 基址是否属于同一服务商。';

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
  String get nameFileSource => '为文件源命名';

  @override
  String get fileSourceEnable => '启用';

  @override
  String get fileSourceDisable => '停用';

  @override
  String get fileSourceDisabled => '已停用';

  @override
  String get noFileSources => '还没有文件源，添加一个文件夹开始建立媒体库';

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
  String get aiNewChat => '新建对话';

  @override
  String get aiChatHistory => '会话历史';

  @override
  String get aiShowMedia => '返回首页内容';

  @override
  String get aiExpandChat => '在首页展开';

  @override
  String get aiLatest => '回到最新';

  @override
  String get aiDraftNext => '正在回复，你可以先编辑下一条消息。';

  @override
  String get aiSuggestMedia => '帮我找一部电影';

  @override
  String get aiSuggestResume => '我上次看到哪里了？';

  @override
  String get aiToolPreparing => '准备执行';

  @override
  String get aiToolRunning => '执行中';

  @override
  String get aiToolWaiting => '等待确认';

  @override
  String get aiToolSucceeded => '已完成';

  @override
  String get aiToolCancelled => '未执行或已取消';

  @override
  String get aiActionExpired => '此操作已失效，请重新选择。';

  @override
  String get aiRemoteImageBlocked => '远程图片未自动加载';

  @override
  String get aiOpenLink => '打开外部链接？';

  @override
  String get aiLinkBlocked => '无法打开此链接';

  @override
  String get aiTaskSubmitted => '已提交任务';

  @override
  String get aiPartialFailure => '部分来源暂不可用';

  @override
  String get aiMoreResults => '还有更多结果，可继续提问查看。';

  @override
  String get aiNoResults => '没有找到匹配内容';

  @override
  String get aiUntitledChat => '新对话';

  @override
  String get aiHistoryEmpty => '还没有会话记录';

  @override
  String get aiReplying => '正在回复…';

  @override
  String get aiToolSummary => '操作及结果来自本机服务';

  @override
  String get aiEarlier => '加载更早消息';

  @override
  String get diagnosticsTitle => '发送诊断信息';

  @override
  String get diagnosticsDescription =>
      '可选向配置的 Sentry 服务发送应用版本及脱敏错误堆栈，不含媒体路径、凭据或聊天内容。开启后重启生效，关闭立即停止所有窗口及后台任务的新上报。暂不收集原生崩溃。';

  @override
  String get anonymousHelp => '匿名访问时，用户名和密码都留空';

  @override
  String get s3AccessKey => 'Access Key ID';

  @override
  String get s3SecretKey => 'Secret Access Key';

  @override
  String get s3AnonymousHelp => '公开存储桶可以不填密钥';

  @override
  String get s3Region => '区域（可选，默认 us-east-1）';

  @override
  String get s3PathHint => '存储桶/可选前缀，例如 media/movies';

  @override
  String get remotePathHint => '例如 media/movies，留空为根目录';

  @override
  String get dlnaSearch => '搜索局域网设备';

  @override
  String get dlnaSearching => '正在搜索…';

  @override
  String get dlnaNoDevices => '没有找到媒体服务器，可以手动填写设备描述地址。';

  @override
  String get dlnaDevice => '设备';

  @override
  String get dlnaAddress => '设备描述地址';

  @override
  String get dlnaAddressHelp => '选择搜索到的设备会自动填写，也可以手动填写。';

  @override
  String get aiOpenExternal => '打开链接';

  @override
  String get serverBrowseAll => '全部';

  @override
  String get serverUnavailable => '无法连接此服务器';

  @override
  String get serverEmpty => '这里还没有内容';

  @override
  String get serverLoadMore => '加载更多';

  @override
  String get localLibrary => '本地媒体库';

  @override
  String get remoteHomeAccess => '家庭远程访问';

  @override
  String get remoteProxy => '服务（frpc proxy）';

  @override
  String get remoteNoProxies => '还没有可用的 proxy：请先在 设置 → 远程访问 导入 Relay 的 App 配置。';

  @override
  String remoteProxyMissing(String name) {
    return '$name（当前 App 配置中没有）';
  }

  @override
  String get remoteLanAddress => '已配对的局域网 HTTPS 地址';

  @override
  String get remoteLanFingerprint => '局域网服务证书 SHA-256';

  @override
  String get remoteLanIdentityHelp => '通过可信途径确认的 64 位十六进制指纹；服务证书还须通过系统信任校验。';

  @override
  String get remoteAutomatic => '自动：验证局域网后使用，否则走远程';

  @override
  String get remoteLocalOnly => '仅局域网';

  @override
  String get remoteRemoteOnly => '仅远程';

  @override
  String get developerMode => '开发调试';

  @override
  String get developerModeDescription => '开启后显示调试入口，例如媒体详情页右上角的“影视信息”按钮。';

  @override
  String get metadataConfigureInSettings => '请在“设置 → TMDB”中配置读取访问令牌后再搜索。';

  @override
  String get scrapeManagement => '刮削管理';

  @override
  String get scrapedCount => '已刮削条目';

  @override
  String scrapedCountValue(int count) {
    return '$count 条';
  }

  @override
  String get scrapeStorage => '占用空间';

  @override
  String scrapeStorageDetail(String database, String artwork) {
    return '数据库 $database · 图片缓存 $artwork';
  }

  @override
  String get scrapeLoading => '正在统计…';

  @override
  String get scrapeClear => '清除全部刮削信息';

  @override
  String get scrapeClearHint => '删除从 TMDB 和 NFO 获取的影视信息及海报缓存。';

  @override
  String get scrapeClearTitle => '清除全部刮削信息？';

  @override
  String get scrapeClearDescription =>
      '将删除从 TMDB 和 NFO 获取的影视信息、匹配结果和已下载的海报，无法撤销。视频文件、播放进度、媒体服务器提供的信息和你手动修改的内容都会保留。如果已配置 TMDB，后台会重新开始刮削。';

  @override
  String get scrapeCleared => '已清除全部刮削信息。';

  @override
  String get scrapeClearFailed => '清除失败，请稍后重试。';

  @override
  String get metadataProgressDone => '刮削完成';

  @override
  String get edit => '编辑';

  @override
  String get refresh => '刷新';

  @override
  String get addFileSourceShort => '添加文件源';

  @override
  String shelfViewAll(int count) {
    return '全部 · $count';
  }

  @override
  String get recentlyAdded => '最近添加';

  @override
  String get tvShows => '电视剧';

  @override
  String seasonCount(int n) {
    return '共$n季';
  }

  @override
  String seasonEpisodeShort(int season, int episode) {
    return '第$season季 第$episode集';
  }

  @override
  String get detailCastAndCrew => '演职人员';

  @override
  String get detailGenres => '风格';

  @override
  String get detailCollection => '系列电影';

  @override
  String get detailVersions => '版本';

  @override
  String get detailViewAll => '查看全部';

  @override
  String get detailScrollStart => '回到开头';

  @override
  String get detailScrollEnd => '跳到末尾';

  @override
  String detailEpisodeCount(int n) {
    return '共 $n 集';
  }

  @override
  String detailMovieCount(int n) {
    return '共 $n 部';
  }

  @override
  String detailRuntime(int n) {
    return '$n 分钟';
  }

  @override
  String get markWatched => '标记为已看';

  @override
  String get markUnwatched => '标记为未看';

  @override
  String get removeFavorite => '取消收藏';

  @override
  String get aiMore => '更多';

  @override
  String get aiGreeting => '有什么可以帮你？';

  @override
  String get aiSuggestTonight => '推荐一部今晚看的电影';

  @override
  String get aiSuggestContinue => '继续看上次没看完的';

  @override
  String get aiSuggestSciFi => '我的片库里有哪些科幻片？';

  @override
  String get aiTestConnection => '测试连接';

  @override
  String get aiCheckingConnection => '正在测试连接…';

  @override
  String get aiConnectionOk => '连接成功，可以聊天和使用工具。';

  @override
  String get aiConnectionOkNoTools => '连接成功，但该模型不支持工具调用，只能纯聊天。';

  @override
  String get aiInvalidSettings => '请填写有效的 HTTPS API 域名和模型名。';

  @override
  String get remoteConnectionMode => '连接方式';

  @override
  String get ffmpegSnapshotDebug => 'FFmpeg 截图调试';

  @override
  String get ffmpegSnapshotAgain => '再截一张';

  @override
  String ffmpegSnapshotAt(String time, String duration) {
    return '截图时间点 $time / $duration';
  }

  @override
  String ffmpegSnapshotFailed(String reason) {
    return '截图失败（$reason）。';
  }

  @override
  String get ffmpegUnavailable => '此构建未包含 FFmpeg 媒体处理模块。';

  @override
  String get asrDebugTitle => '音频与字幕调试';

  @override
  String get asrChooseEpisode => '选择单集';

  @override
  String get asrSectionResource => '当前资源';

  @override
  String get asrSectionInput => '输入选择';

  @override
  String get asrSectionBackend => '识别方式';

  @override
  String get asrSectionActions => '操作';

  @override
  String get asrSectionStatus => '执行状态';

  @override
  String get asrSectionAudio => '音频结果';

  @override
  String get asrSectionSubtitles => '字幕结果';

  @override
  String get asrSectionDebug => '调试信息';

  @override
  String get asrTitle => '剧名';

  @override
  String get asrEpisode => '季/集';

  @override
  String get asrVersion => '媒体版本';

  @override
  String get asrDuration => '时长';

  @override
  String get asrUnknown => '未知';

  @override
  String get asrStart => '开始（秒或 分:秒）';

  @override
  String get asrEnd => '结束（秒或 分:秒）';

  @override
  String get asrWhole => '整集';

  @override
  String get asrRangeHint => '默认处理开头 60 秒；整集需主动选择。';

  @override
  String get asrWholeUnavailable => '时长未知，暂不支持整集处理。';

  @override
  String get asrRangeInvalid => '区间无效：结束须晚于开始且在媒体时长内。';

  @override
  String asrChannels(int n) {
    return '$n 声道';
  }

  @override
  String get asrNotDecodable => '无法解码';

  @override
  String get asrEmbedded => '本机内嵌';

  @override
  String get asrHttp => 'HTTP 服务';

  @override
  String get asrNoBackends => '未配置识别后端。';

  @override
  String get asrChecking => '检查中…';

  @override
  String asrBackendReady(String engine, String revision) {
    return '可用 · $engine · 模型 $revision';
  }

  @override
  String asrBackendUnavailable(String reason) {
    return '不可用：$reason';
  }

  @override
  String get asrExtractOnly => '仅提取音频';

  @override
  String get asrExtractAndTranscribe => '提取并识别字幕';

  @override
  String get asrStagePreparing => '资源准备';

  @override
  String get asrStageExtracting => '音频提取';

  @override
  String get asrStageUploading => '上传';

  @override
  String get asrStageQueued => '排队';

  @override
  String get asrStageTranscribing => '识别';

  @override
  String get asrStageFormatting => '字幕生成';

  @override
  String get asrCancelling => '取消中…';

  @override
  String get asrCancelled => '已取消';

  @override
  String get asrSucceeded => '已完成';

  @override
  String asrFailed(String reason) {
    return '失败：$reason';
  }

  @override
  String get asrAudioTrack => '实际音轨';

  @override
  String get asrAudioFormat => '格式';

  @override
  String get asrAudioSize => '大小';

  @override
  String get asrAudioReused => '复用了配置一致的已有提取结果';

  @override
  String get asrNoSpeech => '此区间未识别到语音。';

  @override
  String get asrWholeResult => '整集';

  @override
  String asrPartialResult(String start, String end) {
    return '部分区间：$start – $end（非整集）';
  }

  @override
  String get asrSave => '保存字幕';

  @override
  String get asrExport => '导出…';

  @override
  String get asrExported => '已导出。';

  @override
  String get asrSaved => '已保存为此版本的新字幕。';

  @override
  String get asrSavedPartial => '已保存为此版本的新字幕（部分区间）。';

  @override
  String get asrSaveHint => '未保存的结果离开页面后清除；保存不会替换已有字幕或影响播放。';

  @override
  String get asrTaskId => '任务 ID';

  @override
  String get asrBackendLabel => '后端';

  @override
  String get asrModel => '模型';

  @override
  String get asrEngine => '引擎';

  @override
  String get asrLanguage => '语言（auto / zh / en …）';

  @override
  String get asrRemoteJob => '远端任务';

  @override
  String get asrError => '错误';

  @override
  String get asrContinue => '继续';

  @override
  String get asrWholeTitle => '处理整集？';

  @override
  String asrWholeBody(String duration, String size) {
    return '时长 $duration，音频约 $size。识别可能耗时较长。';
  }

  @override
  String get asrUploadTitle => '上传音频到识别服务？';

  @override
  String asrUploadBody(String host, String range, String insecure) {
    return '将上传 $range 的音频到 $host。$insecure';
  }

  @override
  String get asrUploadInsecure => '该服务使用未加密的 HTTP，音频传输不加密。';

  @override
  String get asrUploadAllow => '允许上传';

  @override
  String get asrUploadAuthorized => '已授权上传';

  @override
  String get asrErrorNoAudio => '该资源没有音轨。';

  @override
  String get asrErrorDurationUnknown => '时长未知。';

  @override
  String get asrErrorModelMissing => '模型未安装。';

  @override
  String get asrErrorEngineUnavailable => '此构建未包含本机识别引擎。';

  @override
  String get asrErrorUnreachable => '服务不可达。';

  @override
  String get asrErrorUnauthorized => '服务拒绝了凭据。';

  @override
  String get asrErrorUploadConsent => '尚未授权上传到该服务。';

  @override
  String get asrErrorTls => '无法验证服务证书。';

  @override
  String get asrErrorRemoteStream => '该来源暂不支持本机读取。';

  @override
  String get asrErrorTrackChanged => '文件已变化，请重新选择音轨。';

  @override
  String get asrSettingsTitle => '语音识别';

  @override
  String get asrModelFooter => '本机 Whisper 多语言模型。文件按大小与 SHA-256 校验后启用，不会自动下载。';

  @override
  String get asrModelDownload => '下载';

  @override
  String asrModelDownloading(String done, String total) {
    return '下载中 $done / $total';
  }

  @override
  String get asrModelDownloadFailed => '下载失败或文件校验未通过。';

  @override
  String get asrModelImport => '导入模型文件…';

  @override
  String get asrModelImportRejected => '不是已知的模型文件（大小或校验值不符）。';

  @override
  String get asrModelInstalled => '已安装';

  @override
  String get asrModelInUse => '已安装 · 使用中';

  @override
  String get asrModelNotInstalled => '未安装';

  @override
  String get asrModelUse => '使用';

  @override
  String get asrModelRemove => '删除';

  @override
  String get asrServicesTitle => '识别服务';

  @override
  String get asrAddService => '添加 HTTP 服务';

  @override
  String get asrEditService => '编辑服务';

  @override
  String get asrRemoveService => '删除';

  @override
  String get asrServicePrivacy => '仅在你允许后上传提取的音频，不发送视频链接或 NAS 凭据。';

  @override
  String get asrServiceName => '名称';

  @override
  String get asrServiceUrl => '服务地址（https://…）';

  @override
  String get asrServiceToken => '访问令牌';

  @override
  String get asrServiceUrlInvalid => '请输入不含凭据的 https:// 地址（仅在下方允许时可用 http://）。';

  @override
  String get asrServiceInvalid => '请检查模型与语言。';

  @override
  String get asrAllowHttp => '允许未加密 HTTP（仅局域网）';

  @override
  String get asrAllowHttpHint => '音频将以明文传输。HTTPS 证书校验不会被关闭。';

  @override
  String get asrInstallModel => '安装或选择模型';

  @override
  String get asrRecheck => '重新检查';

  @override
  String asrTranscribeBlocked(String reason) {
    return '暂不能识别：$reason';
  }
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
  String get defaultDescription => '預設實例僅用於未明確選擇來源的操作。已有資源始終由原實例解析，不自動切換帳號。';

  @override
  String get defaultBrowse => '預設瀏覽實例';

  @override
  String get defaultResolve => '預設資源解析實例';

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
  String get connectionFailed => '連線失敗。';

  @override
  String get deleteSourceFailed => '刪除來源失敗，請重試。';

  @override
  String get folderEmpty => '此目錄沒有可瀏覽的媒體。';

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
  String disableSourceDescription(int playing, int running) {
    return '目前播放 $playing 個，進行中請求 $running 個。停用後拒絕新請求；目前播放可繼續，結束後釋放連線。設定、收藏和產物保留。';
  }

  @override
  String deleteSourceDescription(int playing, int running) {
    return '僅刪除此實例設定與憑證參照，不刪除原始檔案、收藏或產物。目前播放 $playing 個、進行中請求 $running 個可完成，之後釋放連線。';
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
  String get metadataTokenStatusSaved => '已儲存';

  @override
  String get metadataTokenStatusMissing => '未設定';

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
  String get aiConfigureFirst => '請先在模型設定中填寫 API 網域、模型名稱和 Key。';

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
      '支援 OpenAI 相容介面，例如 DeepSeek。Key 儲存在系統鑰匙圈中。';

  @override
  String get aiEndpoint => 'API 網域';

  @override
  String get aiModel => '模型名稱';

  @override
  String get aiApiKey => 'API Key';

  @override
  String get aiKeyRequired => '填寫 API Key';

  @override
  String get aiKeySaved => '已儲存憑據，留空保留';

  @override
  String get aiSaveFailed => '儲存失敗，請檢查設定及系統憑據儲存權限。';

  @override
  String aiExecuting(String name) {
    return '正在執行 $name…';
  }

  @override
  String get aiAuthenticationFailed => '認證失敗，請檢查 API Key 和 API 基址是否屬於同一服務商。';

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
  String get nameFileSource => '為檔案來源命名';

  @override
  String get fileSourceEnable => '啟用';

  @override
  String get fileSourceDisable => '停用';

  @override
  String get fileSourceDisabled => '已停用';

  @override
  String get noFileSources => '尚無檔案來源，新增一個資料夾開始建立媒體庫';

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
  String get aiNewChat => '新增對話';

  @override
  String get aiChatHistory => '對話紀錄';

  @override
  String get aiShowMedia => '返回首頁內容';

  @override
  String get aiExpandChat => '在首頁展開';

  @override
  String get aiLatest => '回到最新';

  @override
  String get aiDraftNext => '正在回覆，你可以先編輯下一則訊息。';

  @override
  String get aiSuggestMedia => '幫我找一部電影';

  @override
  String get aiSuggestResume => '我上次看到哪裡了？';

  @override
  String get aiToolPreparing => '準備執行';

  @override
  String get aiToolRunning => '執行中';

  @override
  String get aiToolWaiting => '等待確認';

  @override
  String get aiToolSucceeded => '已完成';

  @override
  String get aiToolCancelled => '未執行或已取消';

  @override
  String get aiActionExpired => '此操作已失效，請重新選擇。';

  @override
  String get aiRemoteImageBlocked => '遠端圖片未自動載入';

  @override
  String get aiOpenLink => '開啟外部連結？';

  @override
  String get aiLinkBlocked => '無法開啟此連結';

  @override
  String get aiTaskSubmitted => '已提交工作';

  @override
  String get aiPartialFailure => '部分來源暫時無法使用';

  @override
  String get aiMoreResults => '還有更多結果，可繼續提問查看。';

  @override
  String get aiNoResults => '沒有找到符合的內容';

  @override
  String get aiUntitledChat => '新對話';

  @override
  String get aiHistoryEmpty => '還沒有對話紀錄';

  @override
  String get aiReplying => '正在回覆…';

  @override
  String get aiToolSummary => '操作及結果來自本機服務';

  @override
  String get aiEarlier => '載入較早的訊息';

  @override
  String get diagnosticsTitle => '傳送診斷資訊';

  @override
  String get diagnosticsDescription =>
      '選擇是否向配置的 Sentry 服務傳送應用版本及脫敏錯誤堆疊，不含媒體路徑、憑證或聊天內容。開啟後重啟生效，關閉立即停止所有視窗及背景任務的新上報。暫不收集原生崩潰。';

  @override
  String get anonymousHelp => '匿名存取時，使用者名稱和密碼都留空';

  @override
  String get s3AccessKey => 'Access Key ID';

  @override
  String get s3SecretKey => 'Secret Access Key';

  @override
  String get s3AnonymousHelp => '公開儲存貯體可以不填金鑰';

  @override
  String get s3Region => '區域（選填，預設 us-east-1）';

  @override
  String get s3PathHint => '儲存貯體/選填前綴，例如 media/movies';

  @override
  String get remotePathHint => '例如 media/movies，留空為根目錄';

  @override
  String get dlnaSearch => '搜尋區域網路裝置';

  @override
  String get dlnaSearching => '正在搜尋…';

  @override
  String get dlnaNoDevices => '沒有找到媒體伺服器，可以手動填寫裝置描述位址。';

  @override
  String get dlnaDevice => '裝置';

  @override
  String get dlnaAddress => '裝置描述位址';

  @override
  String get dlnaAddressHelp => '選擇搜尋到的裝置會自動填寫，也可以手動填寫。';

  @override
  String get aiOpenExternal => '開啟連結';

  @override
  String get serverBrowseAll => '全部';

  @override
  String get serverUnavailable => '無法連線此伺服器';

  @override
  String get serverEmpty => '這裡還沒有內容';

  @override
  String get serverLoadMore => '載入更多';

  @override
  String get localLibrary => '本機媒體庫';

  @override
  String get remoteHomeAccess => '家庭遠端存取';

  @override
  String get remoteProxy => '服務（frpc proxy）';

  @override
  String get remoteNoProxies => '還沒有可用的 proxy：請先在 設定 → 遠端存取 匯入 Relay 的 App 設定。';

  @override
  String remoteProxyMissing(String name) {
    return '$name（目前 App 設定中沒有）';
  }

  @override
  String get remoteLanAddress => '已配對的區域網路 HTTPS 位址';

  @override
  String get remoteLanFingerprint => '區域網路服務憑證 SHA-256';

  @override
  String get remoteLanIdentityHelp => '透過可信管道確認的 64 位十六進位指紋；服務憑證還須通過系統信任驗證。';

  @override
  String get remoteAutomatic => '自動：驗證區域網路後使用，否則走遠端';

  @override
  String get remoteLocalOnly => '僅區域網路';

  @override
  String get remoteRemoteOnly => '僅遠端';

  @override
  String get developerMode => '開發偵錯';

  @override
  String get developerModeDescription => '開啟後顯示偵錯入口，例如媒體詳情頁右上角的「影視資訊」按鈕。';

  @override
  String get metadataConfigureInSettings => '請在「設定 → TMDB」中設定讀取存取權杖後再搜尋。';

  @override
  String get scrapeManagement => '刮削管理';

  @override
  String get scrapedCount => '已刮削項目';

  @override
  String scrapedCountValue(int count) {
    return '$count 筆';
  }

  @override
  String get scrapeStorage => '佔用空間';

  @override
  String scrapeStorageDetail(String database, String artwork) {
    return '資料庫 $database · 圖片快取 $artwork';
  }

  @override
  String get scrapeLoading => '正在統計…';

  @override
  String get scrapeClear => '清除全部刮削資訊';

  @override
  String get scrapeClearHint => '刪除從 TMDB 及 NFO 取得的影視資訊與海報快取。';

  @override
  String get scrapeClearTitle => '清除全部刮削資訊？';

  @override
  String get scrapeClearDescription =>
      '將刪除從 TMDB 及 NFO 取得的影視資訊、配對結果與已下載的海報，無法復原。影片檔案、播放進度、媒體伺服器提供的資訊及你手動修改的內容都會保留。若已設定 TMDB，背景會重新開始刮削。';

  @override
  String get scrapeCleared => '已清除全部刮削資訊。';

  @override
  String get scrapeClearFailed => '清除失敗，請稍後再試。';

  @override
  String get metadataProgressDone => '刮削完成';

  @override
  String get edit => '編輯';

  @override
  String get refresh => '重新整理';

  @override
  String get addFileSourceShort => '新增檔案來源';

  @override
  String shelfViewAll(int count) {
    return '全部 · $count';
  }

  @override
  String get recentlyAdded => '最近添加';

  @override
  String get tvShows => '電視劇';

  @override
  String seasonCount(int n) {
    return '共$n季';
  }

  @override
  String seasonEpisodeShort(int season, int episode) {
    return '第$season季 第$episode集';
  }

  @override
  String get detailCastAndCrew => '演職人員';

  @override
  String get detailGenres => '風格';

  @override
  String get detailCollection => '系列電影';

  @override
  String get detailVersions => '版本';

  @override
  String get detailViewAll => '查看全部';

  @override
  String get detailScrollStart => '回到開頭';

  @override
  String get detailScrollEnd => '跳到末尾';

  @override
  String detailEpisodeCount(int n) {
    return '共 $n 集';
  }

  @override
  String detailMovieCount(int n) {
    return '共 $n 部';
  }

  @override
  String detailRuntime(int n) {
    return '$n 分鐘';
  }

  @override
  String get markWatched => '標記為已看';

  @override
  String get markUnwatched => '標記為未看';

  @override
  String get removeFavorite => '取消收藏';

  @override
  String get aiMore => '更多';

  @override
  String get aiGreeting => '有什麼可以幫你？';

  @override
  String get aiSuggestTonight => '推薦一部今晚看的電影';

  @override
  String get aiSuggestContinue => '繼續看上次沒看完的';

  @override
  String get aiSuggestSciFi => '我的片庫裡有哪些科幻片？';

  @override
  String get aiTestConnection => '測試連線';

  @override
  String get aiCheckingConnection => '正在測試連線…';

  @override
  String get aiConnectionOk => '連線成功，可以聊天和使用工具。';

  @override
  String get aiConnectionOkNoTools => '連線成功，但該模型不支援工具呼叫，只能純聊天。';

  @override
  String get aiInvalidSettings => '請填寫有效的 HTTPS API 網域和模型名稱。';

  @override
  String get remoteConnectionMode => '連線方式';

  @override
  String get ffmpegSnapshotDebug => 'FFmpeg 截圖除錯';

  @override
  String get ffmpegSnapshotAgain => '再截一張';

  @override
  String ffmpegSnapshotAt(String time, String duration) {
    return '截圖時間點 $time / $duration';
  }

  @override
  String ffmpegSnapshotFailed(String reason) {
    return '截圖失敗（$reason）。';
  }

  @override
  String get ffmpegUnavailable => '此版本未包含 FFmpeg 媒體處理模組。';

  @override
  String get asrDebugTitle => '音訊與字幕除錯';

  @override
  String get asrChooseEpisode => '選擇單集';

  @override
  String get asrSectionResource => '目前資源';

  @override
  String get asrSectionInput => '輸入選擇';

  @override
  String get asrSectionBackend => '辨識方式';

  @override
  String get asrSectionActions => '操作';

  @override
  String get asrSectionStatus => '執行狀態';

  @override
  String get asrSectionAudio => '音訊結果';

  @override
  String get asrSectionSubtitles => '字幕結果';

  @override
  String get asrSectionDebug => '除錯資訊';

  @override
  String get asrTitle => '劇名';

  @override
  String get asrEpisode => '季/集';

  @override
  String get asrVersion => '媒體版本';

  @override
  String get asrDuration => '時長';

  @override
  String get asrUnknown => '未知';

  @override
  String get asrStart => '開始（秒或 分:秒）';

  @override
  String get asrEnd => '結束（秒或 分:秒）';

  @override
  String get asrWhole => '整集';

  @override
  String get asrRangeHint => '預設處理開頭 60 秒；整集需主動選擇。';

  @override
  String get asrWholeUnavailable => '時長未知，暫不支援整集處理。';

  @override
  String get asrRangeInvalid => '區間無效：結束須晚於開始且在媒體時長內。';

  @override
  String asrChannels(int n) {
    return '$n 聲道';
  }

  @override
  String get asrNotDecodable => '無法解碼';

  @override
  String get asrEmbedded => '本機內嵌';

  @override
  String get asrHttp => 'HTTP 服務';

  @override
  String get asrNoBackends => '未設定辨識後端。';

  @override
  String get asrChecking => '檢查中…';

  @override
  String asrBackendReady(String engine, String revision) {
    return '可用 · $engine · 模型 $revision';
  }

  @override
  String asrBackendUnavailable(String reason) {
    return '無法使用：$reason';
  }

  @override
  String get asrExtractOnly => '僅擷取音訊';

  @override
  String get asrExtractAndTranscribe => '擷取並辨識字幕';

  @override
  String get asrStagePreparing => '資源準備';

  @override
  String get asrStageExtracting => '音訊擷取';

  @override
  String get asrStageUploading => '上傳';

  @override
  String get asrStageQueued => '排隊';

  @override
  String get asrStageTranscribing => '辨識';

  @override
  String get asrStageFormatting => '字幕產生';

  @override
  String get asrCancelling => '取消中…';

  @override
  String get asrCancelled => '已取消';

  @override
  String get asrSucceeded => '已完成';

  @override
  String asrFailed(String reason) {
    return '失敗：$reason';
  }

  @override
  String get asrAudioTrack => '實際音軌';

  @override
  String get asrAudioFormat => '格式';

  @override
  String get asrAudioSize => '大小';

  @override
  String get asrAudioReused => '重用了設定一致的既有擷取結果';

  @override
  String get asrNoSpeech => '此區間未辨識到語音。';

  @override
  String get asrWholeResult => '整集';

  @override
  String asrPartialResult(String start, String end) {
    return '部分區間：$start – $end（非整集）';
  }

  @override
  String get asrSave => '儲存字幕';

  @override
  String get asrExport => '匯出…';

  @override
  String get asrExported => '已匯出。';

  @override
  String get asrSaved => '已儲存為此版本的新字幕。';

  @override
  String get asrSavedPartial => '已儲存為此版本的新字幕（部分區間）。';

  @override
  String get asrSaveHint => '未儲存的結果離開頁面後清除；儲存不會取代既有字幕或影響播放。';

  @override
  String get asrTaskId => '任務 ID';

  @override
  String get asrBackendLabel => '後端';

  @override
  String get asrModel => '模型';

  @override
  String get asrEngine => '引擎';

  @override
  String get asrLanguage => '語言（auto / zh / en …）';

  @override
  String get asrRemoteJob => '遠端任務';

  @override
  String get asrError => '錯誤';

  @override
  String get asrContinue => '繼續';

  @override
  String get asrWholeTitle => '處理整集？';

  @override
  String asrWholeBody(String duration, String size) {
    return '時長 $duration，音訊約 $size。辨識可能耗時較長。';
  }

  @override
  String get asrUploadTitle => '上傳音訊到辨識服務？';

  @override
  String asrUploadBody(String host, String range, String insecure) {
    return '將上傳 $range 的音訊到 $host。$insecure';
  }

  @override
  String get asrUploadInsecure => '此服務使用未加密的 HTTP，音訊傳輸不加密。';

  @override
  String get asrUploadAllow => '允許上傳';

  @override
  String get asrUploadAuthorized => '已授權上傳';

  @override
  String get asrErrorNoAudio => '此資源沒有音軌。';

  @override
  String get asrErrorDurationUnknown => '時長未知。';

  @override
  String get asrErrorModelMissing => '模型未安裝。';

  @override
  String get asrErrorEngineUnavailable => '此版本未包含本機辨識引擎。';

  @override
  String get asrErrorUnreachable => '服務無法連線。';

  @override
  String get asrErrorUnauthorized => '服務拒絕了憑證。';

  @override
  String get asrErrorUploadConsent => '尚未授權上傳到此服務。';

  @override
  String get asrErrorTls => '無法驗證服務憑證。';

  @override
  String get asrErrorRemoteStream => '此來源暫不支援本機讀取。';

  @override
  String get asrErrorTrackChanged => '檔案已變更，請重新選擇音軌。';

  @override
  String get asrSettingsTitle => '語音辨識';

  @override
  String get asrModelFooter => '本機 Whisper 多語言模型。檔案依大小與 SHA-256 驗證後啟用，不會自動下載。';

  @override
  String get asrModelDownload => '下載';

  @override
  String asrModelDownloading(String done, String total) {
    return '下載中 $done / $total';
  }

  @override
  String get asrModelDownloadFailed => '下載失敗或檔案驗證未通過。';

  @override
  String get asrModelImport => '匯入模型檔案…';

  @override
  String get asrModelImportRejected => '不是已知的模型檔案（大小或校驗值不符）。';

  @override
  String get asrModelInstalled => '已安裝';

  @override
  String get asrModelInUse => '已安裝 · 使用中';

  @override
  String get asrModelNotInstalled => '未安裝';

  @override
  String get asrModelUse => '使用';

  @override
  String get asrModelRemove => '刪除';

  @override
  String get asrServicesTitle => '辨識服務';

  @override
  String get asrAddService => '新增 HTTP 服務';

  @override
  String get asrEditService => '編輯服務';

  @override
  String get asrRemoveService => '刪除';

  @override
  String get asrServicePrivacy => '僅在你允許後上傳擷取的音訊，不傳送影片連結或 NAS 憑證。';

  @override
  String get asrServiceName => '名稱';

  @override
  String get asrServiceUrl => '服務位址（https://…）';

  @override
  String get asrServiceToken => '存取權杖';

  @override
  String get asrServiceUrlInvalid => '請輸入不含憑證的 https:// 位址（僅在下方允許時可用 http://）。';

  @override
  String get asrServiceInvalid => '請檢查模型與語言。';

  @override
  String get asrAllowHttp => '允許未加密 HTTP（僅區域網路）';

  @override
  String get asrAllowHttpHint => '音訊將以明文傳輸。HTTPS 憑證驗證不會被關閉。';

  @override
  String get asrInstallModel => '安裝或選擇模型';

  @override
  String get asrRecheck => '重新檢查';

  @override
  String asrTranscribeBlocked(String reason) {
    return '暫不能辨識：$reason';
  }
}
