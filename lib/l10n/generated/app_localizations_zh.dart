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
  String get plugins => 'AI';

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
  String get retry => '重试';

  @override
  String get cancel => '取消';

  @override
  String get aiSettingsSaved => '已保存。';

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
  String get saving => '正在保存…';

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
    return '此文件源关联 $count 项内容。删除后，只由它扫描到的文件记录、播放进度和刮削信息会一并删除；其他文件源也扫描到的内容会保留。存储上的原文件不受影响。';
  }

  @override
  String disableSourceDescription(int playing, int running) {
    return '当前播放 $playing 个，进行中请求 $running 个。禁用后拒绝新请求；当前播放可继续，结束后释放连接。配置、收藏和产物保留。';
  }

  @override
  String deleteSourceDescription(int fileSources, int playing, int running) {
    return '删除此连接的配置与凭据，并删除它下面的 $fileSources 个文件源及其扫描到的内容（文件记录、播放进度、刮削信息）。存储上的原文件不受影响。当前播放 $playing 个、进行中请求 $running 个可完成，之后释放连接。';
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
    return '$speed MB/s';
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
  String get detailExtras => '花絮';

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
  String get aiTextToolCall => '模型在重试后仍把工具调用输出为文字，工具未执行。请检查模型及端点是否支持工具调用。';

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
  String get artworkCacheLimit => '图片缓存上限';

  @override
  String get artworkCacheLimitDescription =>
      '海报、背景图和演职人员照片。达到上限时先删除最早下载的图片，已锁定的图片不会删除。';

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
  String get aiConnectionOkNoTools => '连接成功，工具调用测试未通过；实际任务仍会尝试调用已注册的工具。';

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
  String get asrSaved => '已保存，可在播放时的字幕列表中选择（标记为“识别”）。';

  @override
  String get asrSavedPartial => '已保存（部分区间），可在播放时的字幕列表中选择（标记为“识别”）。';

  @override
  String get asrSaveHint => '未保存的结果离开页面后清除；保存会新增一条字幕记录，不替换已有字幕，也不会自动影响播放。';

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
  String get asrServiceUrl => '服务地址';

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

  @override
  String get embeddedSubtitles => '内嵌字幕';

  @override
  String get externalSubtitles => '外部字幕';

  @override
  String get recognizedSubtitles => '识别字幕';

  @override
  String get recognizedSubtitleBadge => '识别';

  @override
  String recognizedSubtitleTitle(String time) {
    return '保存于 $time';
  }

  @override
  String recognizedSubtitlePartial(String start, String end) {
    return '部分 $start–$end';
  }

  @override
  String get recognizedSubtitleFull => '整集';

  @override
  String get addSourceConnection => '添加连接';

  @override
  String get sourcesDescription => '连接你的存储，整理你的媒体。';

  @override
  String sourceActions(String name) {
    return '$name的操作';
  }

  @override
  String get browseSourceFiles => '浏览文件';

  @override
  String get sourceAwaitingVerification => '待验证';

  @override
  String sourceFileCount(int count) {
    return '$count 个文件源';
  }

  @override
  String get sourceRootFolder => '根目录';

  @override
  String get rescanFileSource => '重新扫描';

  @override
  String plAbASet(String time) {
    return '已设置 A 点 $time';
  }

  @override
  String get plAbClear => '清除 A-B 循环';

  @override
  String get plAbCleared => '已清除 A-B 循环';

  @override
  String get plAbLoop => 'A-B 循环';

  @override
  String plAbLooping(String a, String b) {
    return '循环 $a – $b';
  }

  @override
  String get plAbSetA => '设置 A 点';

  @override
  String get plAbSetB => '设置 B 点';

  @override
  String get plAdvancedTools => '高级工具行';

  @override
  String get plAspectDefault => '默认';

  @override
  String get plAspectRatio => '宽高比';

  @override
  String get plAudioDelay => '音频延迟';

  @override
  String plBoosting(String speed) {
    return '$speed 快进中 · 松手恢复';
  }

  @override
  String get plDelayHint => '正值表示声音或字幕延后。';

  @override
  String get plExitFullscreen => '退出全屏';

  @override
  String get plFaster => '加速';

  @override
  String get plFitBest => '最佳适配';

  @override
  String get plFitFill => '填充';

  @override
  String get plFitMode => '画面尺寸';

  @override
  String get plFitOriginal => '原始尺寸';

  @override
  String get plFullscreen => '全屏';

  @override
  String get plGo => '跳转';

  @override
  String get plInfo => '信息';

  @override
  String get plInfoDuration => '时长';

  @override
  String get plInfoResolution => '分辨率';

  @override
  String get plInfoTitle => '标题';

  @override
  String get plJumpBackMedium => '后退 1 分钟';

  @override
  String get plJumpExtraShort => '跳转 3 秒';

  @override
  String get plJumpForwardMedium => '前进 1 分钟';

  @override
  String get plJumpLong => '跳转 5 分钟';

  @override
  String plJumpSeconds(String seconds) {
    return '$seconds 秒';
  }

  @override
  String get plJumpToTime => '跳到时间';

  @override
  String get plJumpToTimeInvalid => '请输入如 1:23:45 或 12:30 的时间。';

  @override
  String get plLoadSubtitle => '加载外部字幕…';

  @override
  String get plLockShort => '锁定';

  @override
  String get plMediaInfo => '媒体信息';

  @override
  String get plMenuAudio => '音频';

  @override
  String get plMenuPlayback => '播放';

  @override
  String get plMenuSubtitle => '字幕';

  @override
  String get plMenuVideo => '视频';

  @override
  String get plMenuView => '视图';

  @override
  String get plMute => '静音';

  @override
  String get plMuted => '已静音';

  @override
  String get plNextAudioTrack => '下一音轨';

  @override
  String get plNextSubtitle => '下一字幕';

  @override
  String get plNormalSpeed => '恢复正常速度';

  @override
  String get plOrientationShort => '方向';

  @override
  String get plPicture => '画面';

  @override
  String get plPictureAndSound => '画面与声音';

  @override
  String get plRepeatMode => '重复模式';

  @override
  String get plRepeatOff => '不重复';

  @override
  String get plRepeatOne => '单项循环';

  @override
  String get plReset => '重置';

  @override
  String get plSettingsAndEffects => '设置与效果';

  @override
  String get plShortcuts => '快捷键';

  @override
  String get plShowPosition => '显示当前位置';

  @override
  String get plSleepEndOfItem => '本集结束后';

  @override
  String get plSleepFinished => '睡眠定时已暂停播放';

  @override
  String plSleepMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get plSleepOff => '关闭';

  @override
  String get plSleepShort => '睡眠';

  @override
  String get plSleepTimer => '睡眠定时';

  @override
  String get plSlideToUnlock => '向右滑动解锁';

  @override
  String get plSlower => '减速';

  @override
  String get plSnapshot => '截图';

  @override
  String get plSnapshotFailed => '截图保存失败';

  @override
  String plSnapshotSaved(String path) {
    return '截图已保存：$path';
  }

  @override
  String get plSpeedShort => '倍速';

  @override
  String get plStatistics => '统计信息';

  @override
  String get plStatsAudio => '音频块 播放/丢失';

  @override
  String get plStatsDemux => '解复用码率';

  @override
  String get plStatsFrames => '帧 显示/丢失';

  @override
  String get plStatsInput => '输入码率';

  @override
  String get plStatsOverlay => '统计浮层';

  @override
  String get plStatsRead => '读取速度';

  @override
  String get plStop => '停止';

  @override
  String get plSubtitleDelay => '字幕延迟';

  @override
  String get plSync => '同步';

  @override
  String get plTimeTooltip => '单击切换剩余时间，双击跳到时间';

  @override
  String get plToggleControls => '显示/隐藏控制层';

  @override
  String get plToggleSubtitles => '字幕开关';

  @override
  String get plTrackAudio => '音频';

  @override
  String get plTracks => '音轨与字幕';

  @override
  String get plTracksShort => '音轨字幕';

  @override
  String get plTrackSubtitle => '字幕';

  @override
  String get plTrackVideo => '视频';

  @override
  String get plUnsupported => '当前播放器不支持';

  @override
  String get plZoom => '缩放';

  @override
  String get plZoomOriginal => '原始';

  @override
  String get plMenuPlaybackControl => '播放控制';

  @override
  String plBoostingShort(String speed) {
    return '$speed 快进中';
  }

  @override
  String get plSwipeUpToLock => '上滑锁定';

  @override
  String plSpeedLocked(String speed) {
    return '已锁定 $speed';
  }

  @override
  String get plExternalSubtitleShort => '+ 外部字幕';

  @override
  String get listSeparator => '、';

  @override
  String get remoteAccess => '远程访问';

  @override
  String get remoteHomeAndRoutes => '家庭与连接线路';

  @override
  String get remoteImportTitle => '导入远程配置';

  @override
  String get remoteImportFooter => '粘贴 Relay 导出的 App 配置，导入后立即生效。';

  @override
  String get remoteImportPlaceholder => 'App 配置 JSON';

  @override
  String get remoteImport => '导入';

  @override
  String get remoteImporting => '正在导入…';

  @override
  String get remoteImported => '已导入并生效。';

  @override
  String get remoteClearConfirmTitle => '清空远程配置？';

  @override
  String get remoteClearConfirmMessage => '清空本机的远程配置与凭据，重新导入后可恢复远程访问。';

  @override
  String get remoteClear => '清空';

  @override
  String get remoteClearing => '正在清空…';

  @override
  String get remoteCleared => '已清空远程配置。';

  @override
  String get remoteNotImported => '尚未导入';

  @override
  String get remoteNotImportedHint => '点击“导入”添加远程配置。';

  @override
  String get remoteServerName => '服务器名称';

  @override
  String get remoteCredentials => '认证凭据';

  @override
  String get remoteCredentialsSecure => '已保存在系统安全存储';

  @override
  String get remoteProxyUnused => '未被来源使用';

  @override
  String remoteProxyUsedBy(String sources) {
    return '来源：$sources';
  }

  @override
  String remoteProxyPort(int port) {
    return '端口 $port';
  }

  @override
  String get remoteRelayServer => '中继服务器';

  @override
  String get remoteRelayFooter => '整个 App 共用此连接；认证凭据保存在系统安全存储。';

  @override
  String get remoteAvailableServices => '可用服务';

  @override
  String get remoteAvailableServicesFooter =>
      '由 Home 注册在 Relay 上。来源在“编辑来源 → 家庭远程访问”中选择其中一个。';

  @override
  String get remoteNeedsAttention => '需要处理';

  @override
  String remoteSourceProxyMissing(String proxy) {
    return '使用的 proxy「$proxy」不在当前配置中，远程连接不可用。';
  }

  @override
  String get statusConfigured => '已配置';

  @override
  String get statusNotConfigured => '未配置';

  @override
  String get statusAvailable => '可用';

  @override
  String get statusUnavailable => '不可用';

  @override
  String get plgGroupModel => '模型';

  @override
  String get plgGroupExternal => '外部能力';

  @override
  String get plgGroupBuiltIn => '内部能力';

  @override
  String get plgGroupModelDescription => '配置 Agent 使用的模型';

  @override
  String get plgGroupExternalDescription => '自部署或云端服务，由你添加';

  @override
  String get plgGroupBuiltInDescription => '随 App 提供，默认全部开放';

  @override
  String plgCount(int count) {
    return '$count 项';
  }

  @override
  String extToolCount(int count) {
    return '$count 个工具';
  }

  @override
  String plgInstanceCount(int count) {
    return '$count 个实例';
  }

  @override
  String get plgExternalHint => '填写地址和令牌，自动识别并配置服务';

  @override
  String get plgExternalEmpty => '还没有配置外部服务';

  @override
  String get extConfigureTitle => '配置外部能力';

  @override
  String plgBuiltInHint(int count) {
    return '随 App 提供 $count 项，默认全部开放，无需逐项启用';
  }

  @override
  String plgGroupEmpty(String group) {
    return '暂无$group';
  }

  @override
  String get plgNoAssistant => '此构建未接入 AI 助手';

  @override
  String get plgSelectForDetail => '选择一项查看详情';

  @override
  String get plgDeviceUnsupported => '当前设备不支持';

  @override
  String get plgTemporarilyUnavailable => '暂不可用';

  @override
  String get plgDisabled => '插件已停用';

  @override
  String plgDisableConfirmTitle(String name) {
    return '停用「$name」？';
  }

  @override
  String get plgImpactIntro => '停用后立即阻止新的调用；实例配置、已生成的字幕和历史记录都会保留。';

  @override
  String plgImpactPlaying(int count) {
    return '$count 个正在播放的会话会继续到播放结束后再释放连接。';
  }

  @override
  String plgImpactRunning(int count) {
    return '$count 个进行中的请求会在完成后释放。';
  }

  @override
  String plgImpactInstances(String instances) {
    return '受影响的实例：$instances。';
  }

  @override
  String get actionFailedRetry => '操作失败，请重试。';

  @override
  String get plgUnavailableReason => '不可用原因';

  @override
  String get plgSwitch => '插件开关';

  @override
  String get plgSwitchOn => '允许承接新的业务调用';

  @override
  String get plgSwitchOff => '已阻止新的调用；实例配置保留';

  @override
  String get settingsCapabilities => '基础能力';

  @override
  String get capabilitySwitchesFooter =>
      '关闭的能力在整个 App 中都不再承接新的调用，AI 也无法使用；已有配置会保留。';

  @override
  String capabilityNeeds(String name) {
    return '需要先开启「$name」';
  }

  @override
  String get plgCapabilitySwitch => '基础能力开关';

  @override
  String get plgCapabilitySwitchHint => '在「设置 → 基础能力」中开关，对整个 App 生效';

  @override
  String get capabilityOn => '已开启';

  @override
  String get capabilityOff => '已关闭';

  @override
  String get plgLocation => '执行位置';

  @override
  String get plgLocationDevice => '在本机运行';

  @override
  String get plgLocationNetwork => 'App 在本机连接你配置的存储服务';

  @override
  String get plgLocationSelfHosted => 'App 在本机运行适配器，实际工作在你配置的服务器上进行';

  @override
  String get plgLocationCloudApi => 'App 在本机调用云端 API';

  @override
  String get plgDependencies => '依赖';

  @override
  String plgDependency(String name, String status) {
    return '$name（$status）';
  }

  @override
  String get plgCapabilities => '能力';

  @override
  String get plgCapabilitiesFooter => '只列出此插件真实实现的方法；未实现的能力不会显示。';

  @override
  String plgInstancesTitle(int count) {
    return '实例（$count 个）';
  }

  @override
  String plgInstanceBusy(int playing, int running) {
    return '使用中：播放 $playing · 请求 $running';
  }

  @override
  String get plgNoInstances => '暂无实例';

  @override
  String get plgOpenSettings => '打开设置';

  @override
  String get plgRuntime => '运行状态与诊断';

  @override
  String plgRevisions(String saved, String applied) {
    return '已保存修订 $saved · 实际生效 $applied';
  }

  @override
  String get plgNotApplied => '尚未生效';

  @override
  String get plgPendingApply => '新配置待生效，旧修订仍在服务进行中的调用';

  @override
  String plgActivity(int playing, int running) {
    return '活动播放 $playing · 进行中请求 $running';
  }

  @override
  String plgLastError(String code) {
    return '最近错误：$code';
  }

  @override
  String get plgRefreshStatus => '刷新状态';

  @override
  String get plgCopyDiagnostics => '复制脱敏诊断信息';

  @override
  String get plgCopyDiagnosticsHint => '不含地址、账号、路径或密钥';

  @override
  String get plgDiagnosticsCopied => '已复制诊断信息';

  @override
  String get extConnectionOk => '连接正常';

  @override
  String extRemoveConfirmTitle(String name) {
    return '移除「$name」？';
  }

  @override
  String get extRemoveConfirmMessage => '只移除 App 中的地址和令牌，不会影响服务器上的数据。';

  @override
  String get extNeedsRecheck => '需要重新检测';

  @override
  String extToolAiUnavailable(String problem) {
    return 'AI 暂不可用：$problem';
  }

  @override
  String get extToolNeedsConfirm => '调用前需要你确认';

  @override
  String get extAiServiceUnavailable => '服务当前不可用，AI 暂时无法调用';

  @override
  String get extAiNeedsRecheck => '请点“重新检测”以获取工具定义';

  @override
  String extAiSummary(int usable, int total) {
    return 'AI 可直接调用 $usable / $total 个工具；会改变状态的操作会先请你确认';
  }

  @override
  String get extRemoved => '这个外部能力已移除';

  @override
  String extVersion(String version) {
    return '版本 $version';
  }

  @override
  String get extAiCalls => 'AI 调用';

  @override
  String extToolsTitle(int count) {
    return '工具（$count 个）';
  }

  @override
  String get extNoTools => '没有工具';

  @override
  String get extRecheck => '重新检测';

  @override
  String get extConnecting => '正在连接并识别…';

  @override
  String extAdded(String name) {
    return '已添加「$name」';
  }

  @override
  String get extConfigureFooter =>
      '填写服务地址和访问令牌，App 会通过 MCP 连接，读取它是什么服务、提供哪些工具。';

  @override
  String get extServiceAddress => '服务地址';

  @override
  String get extAccessToken => '访问令牌';

  @override
  String get extNameOptional => '名称（可选）';

  @override
  String get extDetected => '识别结果';

  @override
  String get extTools => '工具';

  @override
  String get extConnect => '连接并识别';

  @override
  String get scanStatusPending => '待扫描';

  @override
  String get scanStatusScanning => '扫描中';

  @override
  String get scanStatusDone => '扫描完成';

  @override
  String get scanStatusFailed => '扫描失败';

  @override
  String get scanStatusInterrupted => '扫描中断';

  @override
  String get scanRescanHint => '请重新扫描';

  @override
  String get libraryDbTooNew => '媒体库版本较新，请升级应用';

  @override
  String get errConfigUnknownFields => '配置包含未知字段，原始配置必须保留。';

  @override
  String get errRemoteKinds => '当前远程访问支持 Jellyfin、Emby、Plex 和 SMB。';

  @override
  String get errRemoteProtocolMismatch => '远程服务协议不匹配；SMB 当前仅支持远程模式。';

  @override
  String get errConfigVersionNoOverwrite => '配置版本不兼容，不能覆盖保存。';

  @override
  String get errAddressRequired => '请填写地址。';

  @override
  String get errTimeoutConcurrency => '请求超时须为 1–120 秒，并发须为 1–8。';

  @override
  String get errScopeCount => '至少设置一个访问范围，范围和排除项最多各 100 条。';

  @override
  String get errScopeRelative => '访问范围和排除项须为根目录内的相对路径，不允许 .. 或绝对路径。';

  @override
  String get errBrowseModeUnsupported => '此插件不支持该浏览方式。';

  @override
  String get errNoSearchIndex => '此插件尚未提供搜索或后台索引能力。';

  @override
  String get errLibraryNoDirPolicy => '媒体库来源暂不支持文件目录策略。';

  @override
  String get errChooseLocalFolder => '请选择本地文件夹。';

  @override
  String get errAddressRelativeSegments => '地址不能包含相对路径片段。';

  @override
  String get errInvalidServerAddress => '请输入有效的服务器地址，凭据请填在单独字段。';

  @override
  String get errSmbAddressFormat => 'SMB 使用标准 445 端口：smb://主机/共享名/可选目录。';

  @override
  String errUserIdRequired(String kind) {
    return '请填写 $kind 用户 ID。';
  }

  @override
  String get errSftpUsernameRequired => '请填写 SFTP 用户名。';

  @override
  String get errServerAddressRequired => '请填写服务器地址。';

  @override
  String get errInvalidHost => '请输入有效的 IP、主机名或服务器地址。';

  @override
  String get errPortRange => '端口须为 1–65535。';

  @override
  String get errSmbPort => '当前 SMB 连接使用 445 端口。';

  @override
  String get errPathDots => '路径不能包含 . 或 ..。';

  @override
  String get errSignInFailed => '登录失败，请检查账号和密码或重新授权。';

  @override
  String get errAddressRedirected => '地址发生跳转，请填写服务器的实际入口。';

  @override
  String get errCannotConnectService => '无法连接服务，请检查地址和网络。';

  @override
  String get errConnectTimeout => '连接超时，请重试。';

  @override
  String errKindUsernameRequired(String kind) {
    return '请填写 $kind 用户名。';
  }

  @override
  String get errNoValidSignIn => '服务器未返回有效的登录结果。';

  @override
  String get errPlexSessionExpired => '登录已过期，请重新登录 Plex。';

  @override
  String get errPlexServerUnreachable => '无法连接这台 Plex 服务器，请确认服务器在线。';

  @override
  String errDlnaHttp(int status) {
    return 'DLNA 设备请求失败（HTTP $status）。';
  }

  @override
  String get errDlnaForeignHost => 'DLNA 设备返回了其他主机的地址。';

  @override
  String get errDlnaNotMediaServer => '该设备不是媒体服务器（没有内容目录服务）。';

  @override
  String get errChooseFolder => '请选择文件夹。';

  @override
  String get untitled => '未命名';

  @override
  String get errChooseVideoOrAudio => '请选择视频或音频。';

  @override
  String get errNoPlayableAddress => '此项目没有可播放的地址。';

  @override
  String get plexPartMedia => '媒体';

  @override
  String get errPathOutsideRoot => '路径超出配置的根目录。';

  @override
  String get errOutsideScope => '目录不在此实例配置的访问范围内。';

  @override
  String get errAttachmentTooLarge => '附件过大';

  @override
  String errServiceAccessDenied(String service, int status) {
    return '$service 拒绝访问（HTTP $status），请检查用户名和密码。';
  }

  @override
  String get errFileNotFound => '文件或文件夹不存在。';

  @override
  String errServiceRequestFailed(String service, int status) {
    return '$service 请求失败（HTTP $status）。';
  }

  @override
  String get errFtpRefused => 'FTP 服务器拒绝连接。';

  @override
  String get errFtpLogin => 'FTP 登录失败，请检查用户名和密码。';

  @override
  String get errFtpNoBinary => 'FTP 服务器不支持二进制传输。';

  @override
  String get errPathChars => '路径包含不支持的字符。';

  @override
  String get errFtpNoPassive => 'FTP 服务器不支持被动模式。';

  @override
  String get errFolderNotFoundOrDenied => '文件夹不存在或无权访问。';

  @override
  String get errFtpList => 'FTP 无法列出文件夹。';

  @override
  String get errFtpNoResume => 'FTP 服务器不支持断点续传，无法拖动进度。';

  @override
  String get errFtpRead => '无法读取该 FTP 文件。';

  @override
  String get errFtpNoSize => 'FTP 服务器未返回文件大小，无法播放。';

  @override
  String get errSftpLogin => 'SFTP 登录失败，请检查用户名和密码。';

  @override
  String get errSftpDisabled => '服务器未启用 SFTP。';

  @override
  String get errPathDenied => '没有权限访问该路径。';

  @override
  String get errSftpRequest => 'SFTP 请求失败。';

  @override
  String get errSftpConnect => 'SFTP 连接失败。';

  @override
  String get errSftpPlay => '无法播放该 SFTP 文件。';

  @override
  String get errChooseFile => '请选择文件。';

  @override
  String get errConnectionClosed => '连接已关闭。';

  @override
  String get errUnsafeResourceUrl => '媒体服务返回了不安全的资源地址。';

  @override
  String errMediaServerHttp(int status) {
    return '媒体服务请求失败（HTTP $status），请检查地址和凭据。';
  }

  @override
  String get errServerArtworkUnavailable => '服务端图片不可用';

  @override
  String get errImageTooLarge => '图片过大';

  @override
  String get errNoPlayableVersion => '此媒体没有可播放版本。';

  @override
  String get errReselectVersion => '请返回媒体库重新选择一个版本。';

  @override
  String get errServerIdentityMismatch => '服务端对象身份不匹配';

  @override
  String plexPartLabel(int index, String container) {
    return '文件 $index · $container';
  }

  @override
  String get errNoPlayableFile => '此媒体没有可播放文件。';

  @override
  String get errMultiPartUnsupported => '该媒体包含多个版本或分段，暂不支持直接播放。';

  @override
  String get errMetadataNotThisServer => '元数据查询不属于此服务端实例';

  @override
  String get errArtworkNotThisServer => '图片不属于此服务端实例';

  @override
  String get srcFieldFolder => '文件夹';

  @override
  String get srcFieldWorkgroup => '工作组（可选）';

  @override
  String get srcFieldRegion => '区域（可选）';

  @override
  String srcFieldRequired(String field) {
    return '请填写$field。';
  }

  @override
  String get errResourceNotThisSource => '资源不属于此媒体源。';

  @override
  String get errOutsideAuthorizedFolder => '文件超出已授权文件夹。';

  @override
  String get errOutsideSmbShare => '路径超出配置的 SMB 共享。';

  @override
  String get errSmbListShares => '无法读取共享列表，请在“高级”中填写共享文件夹路径后重试。';

  @override
  String get errSmbPlay => '无法播放该 SMB 文件。';

  @override
  String get errAttachmentNotFound => '附件不存在';

  @override
  String get errInvalidFileName => '文件名无效。';

  @override
  String get errUnknownWriteShare => '无法确定要写入的共享。';

  @override
  String get errOpenPlayXFolderBlocked => '共享中已有同名文件，无法创建 OpenPlayX 文件夹。';

  @override
  String get errTooManySameName => '同名文件过多，请先整理 OpenPlayX 文件夹。';

  @override
  String get errTempNameConflict => '临时文件名冲突，请重试。';

  @override
  String get errUploadIncomplete => '上传不完整，已丢弃临时文件。';

  @override
  String get errSmbWrite => '写入 SMB 失败，请确认账号对该共享有写权限。';

  @override
  String get errAttachmentTypeOrLimit => '不支持的附件类型或读取上限';

  @override
  String get errSourceMissing => '媒体源不存在或配置不兼容。';

  @override
  String get errSourceKindChange => '编辑时不能更改源类型。';

  @override
  String get errTokenRequired => '请填写访问令牌。';

  @override
  String get srcStatusDisabled => '已禁用';

  @override
  String get srcStatusReady => '已就绪';

  @override
  String get srcStatusFailed => '连接失败';

  @override
  String get srcStatusInitialized => '已初始化 · 待连接验证';

  @override
  String get srcStatusSaved => '已保存 · 下次访问生效';

  @override
  String get errArtworkCacheLimit => '不支持的图片缓存上限。';

  @override
  String get errExtensions => '文件后缀只能包含字母和数字，最多 100 个。';

  @override
  String get errSourceDisabled => '媒体源已禁用，配置仍保留。';

  @override
  String get errPluginDisabled => '此插件已停用，实例配置仍保留。';

  @override
  String get errTokenExpired => '令牌已到期，请更新凭据。';

  @override
  String get errReselectLocalFolder => '请重新选择本地文件夹以恢复授权。';

  @override
  String get errCredentialsUnavailable => '凭据不可用，请重新登录或更新凭据。';

  @override
  String get errInstanceChanged => '实例配置已改变，请重试。';

  @override
  String get errRequestTimedOut => '请求已超时。';

  @override
  String get errSourceUnreachable => '无法访问媒体源，请检查地址、权限和凭据。';

  @override
  String get errInvalidPaging => '无效的分页参数。';

  @override
  String get errInvalidSearchPaging => '无效搜索或分页';

  @override
  String get errSearchUnsupported => '此来源不支持搜索';

  @override
  String get errMetadataUnsupported => '此来源不支持影视信息查询';

  @override
  String get errAttachmentsUnsupported => '此来源不支持附件读取';

  @override
  String get errWriteUnsupported => '此来源不支持写入。';

  @override
  String get errWriteTimeout => '写入超时，服务器上可能残留以 .openplayx- 开头的临时文件。';

  @override
  String errSourceProxyMissing(String proxy) {
    return '此来源使用远程访问 proxy「$proxy」，但当前 App 没有该 proxy；请在设置 → 远程访问导入 Relay 的 App 配置。';
  }

  @override
  String get errReloadBeforeTest => '请重新加载配置后测试。';

  @override
  String get errTestTimeout => '连接测试超时。';

  @override
  String get errTestFailed => '连接测试失败，请检查地址、权限和凭据。';

  @override
  String get errManualScanDisabled => '此实例未启用手动文件扫描。';

  @override
  String get errScanLimit => '扫描上限须为 1–5000。';

  @override
  String get errScanPageLimit => '扫描达到 1000 次目录分页上限，请缩小访问范围。';

  @override
  String get errScanConfigChanged => '扫描期间实例配置已改变，请重新扫描。';

  @override
  String get errTooManyQueued => '此实例排队请求过多，请稍后重试。';

  @override
  String get credNotRequired => '无需账号凭据';

  @override
  String get credMissing => '缺少凭据';

  @override
  String get credConfigured => '凭据已保存 · 尚未验证';

  @override
  String get credExpiring => '令牌将在 7 天内到期';

  @override
  String get credExpired => '令牌已到期';

  @override
  String get credRejected => '认证失败 · 请更新凭据';

  @override
  String get credVerified => '连接已验证';

  @override
  String get errConfigDbTooNew => '本地配置数据库版本较新，请升级应用。';

  @override
  String get errConfigVersionKept => '配置版本不兼容，原数据已保留。';

  @override
  String get errInstanceMetaMismatch => '实例配置与元数据不一致。';

  @override
  String get errInstanceQuarantined => '实例配置不兼容或损坏，已隔离且保留原数据。';

  @override
  String get errInstanceNoOverwrite => '不能覆盖版本不兼容的实例配置。';

  @override
  String get errConfigChangedElsewhereEdit => '配置已被其他窗口修改，请重新加载后编辑。';

  @override
  String get errConfigChangedDelete => '配置已更新，请重新加载后删除。';

  @override
  String get errDefaultInstanceChanged => '默认实例设置已更新，请重新加载。';

  @override
  String get errSettingsChangedElsewhere => '设置已被其他窗口修改，请重新加载。';

  @override
  String get pickerVideoAudio => '视频和音频';

  @override
  String get pickerAllFiles => '所有文件';

  @override
  String get errSeriesIdentityConflict => '剧集或季的身份存在冲突';

  @override
  String get errInfoChangedReload => '信息已更改，请重新加载后操作';

  @override
  String get errWorkIdConflict => '作品 ID 冲突，需要人工确认';

  @override
  String get errInvalidFieldValue => '字段值无效';

  @override
  String get errPosterNotThisWork => '海报不属于当前作品';

  @override
  String get errRemoteConfigVersion => '远程访问配置版本不兼容或包含未知字段。';

  @override
  String get errRemoteOutboundCredential => 'outbound 与凭据必须同时存在。';

  @override
  String get errRemoteUuidPlacement => 'UUID 只能保存在 credential 中。';

  @override
  String get errRemoteCredentialInvalid => '远程凭据无效。';

  @override
  String get errRemoteProxiesInvalid =>
      'proxies 的 name 不能为空或重复，remotePort 须为有效端口。';

  @override
  String get errRemotePolicyUnsupported => '远程连接策略超出支持范围。';

  @override
  String get errRemoteLanNeedsHttps => '局域网自动访问需要 HTTPS 端点和配对确认的证书 SHA-256。';

  @override
  String get errRemoteUnknownField => '未知远程访问字段。';

  @override
  String get errRemoteChooseProxy => '请选择远程访问使用的 proxy。';

  @override
  String get errRemoteEndpoint => '远程访问需要有效的 HTTP(S) 或 SMB 服务端点。';

  @override
  String get errRemoteProxyRef => 'proxy name、remotePort 或凭据引用无效。';

  @override
  String get errRemoteProxyHost => '代理主机或配置长度无效。';

  @override
  String get errRemoteTlsName => '代理 TLS 服务名称无效。';

  @override
  String get errRemoteNeedsVless => '配对需要开启证书校验的 VLESS TLS/REALITY 出站。';

  @override
  String get errRemoteCaPrivateKey => 'CA 配置不能包含私钥。';

  @override
  String get errRemoteRealityPublic => 'REALITY 客户端只保存公开参数。';

  @override
  String get errRemoteAuthHeader => '传输认证头不能写入公开线路配置。';

  @override
  String get errRemoteTlsField => '不支持的 TLS 配置字段。';

  @override
  String get errRemoteConfigTooLarge => '配置过大。';

  @override
  String get errRemoteInvalidJson => '不是有效的 JSON，请粘贴 Relay 导出的完整 App 配置。';

  @override
  String get errRemoteAppConfigShape =>
      'App 配置须为只含“outbound”（对象）和“proxies”（数组）的 JSON 对象。';

  @override
  String get errRemoteProxyShape =>
      'proxies 每项须只含“name”（字符串）和“remotePort”（端口）。';

  @override
  String get errRemoteProxiesEmpty => 'proxies 不能为空，name 不能重复。';

  @override
  String get errRemoteOutsideEndpoint => '请求超出已授权的服务端点。';

  @override
  String get errRemoteCertMismatch => '服务证书与已配对身份不匹配。';

  @override
  String get errRemoteOutsidePaired => '连接超出已配对服务。';

  @override
  String get errRemoteLanUnreachable => '局域网服务不可达或身份验证失败。';

  @override
  String get errRemoteCellularBlocked => '当前设置禁止蜂窝网络远程访问，或无法确认当前网络。';

  @override
  String get errRemoteCellularUnknown => '无法确认蜂窝网络状态，已阻止远程连接。';

  @override
  String get errRemoteNoCore => '此构建缺少远程连接内核，请安装包含 sing-box 的构建。';

  @override
  String get errRemoteNativeConfigTooLarge => '远程连接配置过大。';

  @override
  String get errRemoteCoreStart => '远程内核启动失败，请检查线路配置。';

  @override
  String get rtDisabled => '已停用';

  @override
  String get rtUnchecked => '未检测';

  @override
  String get rtStarting => '启动中';

  @override
  String get rtBlocked => '需处理';

  @override
  String get rtError => '出错';

  @override
  String get rtDraining => '收尾中';

  @override
  String get healthLastOk => '上次连接成功';

  @override
  String get healthLocal => '本机';

  @override
  String get plgDraining => '已阻止新调用，正在等待播放或任务结束';

  @override
  String plgDependencyBlocked(String name) {
    return '依赖的「$name」已停用或不可用';
  }

  @override
  String get plgNoInstanceAdded => '尚未添加实例';

  @override
  String get plgAllInstancesDisabled => '所有实例均已停用';

  @override
  String get plgInstanceFailing => '有实例连接失败';

  @override
  String get plgSomeInstancesBlocked => '部分实例需处理';

  @override
  String get plgNfoInstance => '邻近文件规则';

  @override
  String get plgNoTmdb => '此构建未接入 TMDB 设置';

  @override
  String get plgTmdbInstance => 'TMDB 配置';

  @override
  String get plgTmdbNoToken => '未配置访问令牌';

  @override
  String get plgNoFfmpeg => '当前平台或构建未包含 FFmpeg 媒体处理';

  @override
  String get plgFfmpegInstance => '设备内处理';

  @override
  String get plgModelNotConfigured => '未配置模型或密钥';

  @override
  String get plgNoSources => '此构建未接入媒体来源';

  @override
  String get plgNoAsr => '此构建未接入语音识别';

  @override
  String plgModelDetail(String model) {
    return '模型 $model';
  }

  @override
  String get plgLocalAsrUnavailable => '本地识别引擎不可用';

  @override
  String get errTmdbTokenRequired => '请配置 TMDB 读取访问令牌';

  @override
  String get errQueryCancelled => '查询已取消';

  @override
  String get errTmdbResponseTooLarge => 'TMDB 响应过大';

  @override
  String get errTmdbAuth => 'TMDB 认证失败，请更新令牌';

  @override
  String get errTmdbNotFound => 'TMDB 对象不存在';

  @override
  String get errTmdbRateLimited => 'TMDB 请求受限，请稍后重试';

  @override
  String get errTmdbUnavailable => 'TMDB 暂时不可用';

  @override
  String get errTmdbRequestFailed => 'TMDB 请求失败';

  @override
  String get errTmdbInvalidResponse => 'TMDB 响应格式无效';

  @override
  String get errTmdbUnreachable => '无法连接 TMDB，请检查网络';

  @override
  String get errTmdbNoAttachments => 'TMDB 不读取来源附件';

  @override
  String get errTmdbInvalidIds => 'TMDB ID 或季集编号无效';

  @override
  String get errIdentifySeriesFirst => '请先识别剧集，再选择季集';

  @override
  String get errTmdbRefRequired => '详情需要 TMDB 引用';

  @override
  String get errTmdbInvalidIdentity => 'TMDB 对象身份或标题无效';

  @override
  String get errNfoRefRequired => 'NFO 详情需要附件引用';

  @override
  String get errNfoParse => 'NFO 解析失败';

  @override
  String get errNfoTooLarge => 'NFO 超过 1 MiB';

  @override
  String get errNfoDtd => 'NFO 不允许 DTD 或实体声明';

  @override
  String get errNfoTooManyNodes => 'NFO 节点过多';

  @override
  String get errNfoTooDeep => 'NFO 嵌套过深';

  @override
  String get errNfoType => '不支持的 NFO 对象类型';

  @override
  String get errNfoFieldTooLong => 'NFO 字段过长';

  @override
  String get errInvalidMetadataQuery => '无效的元数据查询参数';

  @override
  String get errMetadataQueryUnsupported => '此元数据实例不支持该查询';

  @override
  String get errMediaKindUnsupported => '不支持此媒体类型的影视信息';

  @override
  String get errBackgroundIdentify => '后台识别失败';

  @override
  String get errQueryStale => '查询已过期或已取消';

  @override
  String get errTmdbConfigChanged => 'TMDB 配置已改变';

  @override
  String get errRequeryCandidates => '请重新查询候选';

  @override
  String get errChooseEpisodeFirst => '请先选择具体季集';

  @override
  String get errCandidateNotThisQuery => '候选不属于此查询';

  @override
  String get errDetailIdentityMismatch => '详情身份不匹配';

  @override
  String get errReloadCandidates => '请重新加载候选';

  @override
  String get errInvalidLocalCandidate => '无效的本地候选';

  @override
  String get errChooseSeriesFirst => '请先选择剧集';

  @override
  String get errConfirmMatchFirst => '请先确认匹配';

  @override
  String get errCatalogTooLarge => '目录过大，请缩小元数据范围';

  @override
  String get errCursorStuck => '分页游标未前进';

  @override
  String get errEpisodeSeasonMissing => '单集所属季不存在';

  @override
  String get errSourceConfigChanged => '来源配置已改变';

  @override
  String get errInvalidYear => '年份无效';

  @override
  String get catSourceBrowse => '浏览目录';

  @override
  String get catSourceBrowseDesc => '列出该来源的文件夹与文件';

  @override
  String get catSourceResolve => '播放';

  @override
  String get catSourceResolveDesc => '把选中的资源交给播放器；严格绑定资源所属实例';

  @override
  String get catSourceAttachments => '读取附件';

  @override
  String get catSourceAttachmentsDesc => '读取 NFO、外挂字幕等小文件（有大小上限）';

  @override
  String get catSearchMedia => '搜索媒体';

  @override
  String get catSearchMediaDesc => '在服务端搜索影片与剧集';

  @override
  String get catMetadataLookup => '影视信息';

  @override
  String get catMetadataLookupDesc => '读取媒体服务器整理好的影视信息';

  @override
  String get catSourceWrite => '写入新文件';

  @override
  String get catSourceWriteDesc =>
      '把 App 生成的片段写到同一共享的 OpenPlayX 文件夹；不覆盖、不删除，每次需确认';

  @override
  String get catSummaryLocal => '本机或已挂载的文件夹';

  @override
  String get catSummarySmb => 'Windows 共享、NAS 的 SMB 共享目录';

  @override
  String get catSummaryWebdav => 'WebDAV 网盘或 NAS 目录';

  @override
  String get catSummaryFtp => 'FTP 服务器目录';

  @override
  String get catSummarySftp => '通过 SSH 访问的服务器目录';

  @override
  String get catSummaryS3 => 'S3 兼容对象存储桶';

  @override
  String get catSummaryPlex => 'Plex 媒体服务器';

  @override
  String get catSummaryJellyfin => 'Jellyfin 媒体服务器';

  @override
  String get catSummaryEmby => 'Emby 媒体服务器';

  @override
  String get catSummaryDlna => '局域网 DLNA 媒体服务器';

  @override
  String get catDataLocal => '只读取你授权的文件夹。';

  @override
  String get catDataRemote =>
      'App 在本机连接你配置的服务器；文件名和目录名会出现在 AI 对话中（仅当允许 AI 使用时）。';

  @override
  String get catNfoName => 'NFO 元数据';

  @override
  String get catNfoSummary => '读取媒体旁边的 .nfo 文件';

  @override
  String get catNfoToggle => '由“刮削管理”控制是否刮削；后台刮削独立运行，暂不支持单独停用。';

  @override
  String get catNfoCap => '本地元数据';

  @override
  String get catNfoCapDesc => '按邻近文件规则匹配影片信息';

  @override
  String get catTmdbSummary => '从 The Movie Database 查询影片与剧集信息';

  @override
  String get catTmdbToggle => '清除访问令牌即停止使用；后台刮削独立运行，暂不支持单独停用。';

  @override
  String get catTmdbData => '查询时向 TMDB 发送解析出的片名与年份，不发送文件内容。';

  @override
  String get catTmdbCap => '查询元数据';

  @override
  String get catTmdbCapDesc => '搜索、匹配影片与剧集信息；写入由宿主完成';

  @override
  String get catFfmpegName => 'FFmpeg 媒体处理';

  @override
  String get catFfmpegSummary => '截图、探测、转码与音频提取';

  @override
  String get catFfmpegData => '在本机处理媒体，产物保存在应用目录。';

  @override
  String get catProbe => '探测';

  @override
  String get catProbeDesc => '读取时长、编码与音轨';

  @override
  String get catTranscode => '转码';

  @override
  String get catTranscodeDesc => '按预设转码为新文件';

  @override
  String get catExtractAudio => '提取音频';

  @override
  String get catExtractAudioDesc => '导出音轨用于识别或保存';

  @override
  String get catSnapshot => '截图';

  @override
  String get catSnapshotDesc => '截取指定时间的画面';

  @override
  String get catAsrName => '语音识别';

  @override
  String get catAsrSummary => '为视频生成原语言字幕与转录';

  @override
  String get catAsrCapDesc => '生成原语言字幕/转录；不包含翻译';

  @override
  String get catLlmName => '对话模型';

  @override
  String get catLlmSummary => '为 AI 助手提供大语言模型';

  @override
  String get catLlmToggle => '在“AI 与模型”中配置或清除模型；不会生成可递归调用自身的推理工具。';

  @override
  String get catLlmData => '对话内容、页面摘要与工具结果会发送给所配置的模型服务，可能产生费用。';

  @override
  String get catLlmCap => '对话推理';

  @override
  String get catLlmCapDesc => '为 AI 助手生成回复与工具调用';

  @override
  String get catCategorySource => '媒体来源';

  @override
  String get catCategoryMetadata => '元数据';

  @override
  String get catCategoryMediaProcessing => '媒体处理';

  @override
  String get catCategorySpeech => '字幕识别';

  @override
  String get catLocationNetwork => '网络存储';

  @override
  String get catLocationSelfHosted => '自建服务';

  @override
  String get catLocationCloudApi => '云 API';

  @override
  String get webSearchPresetName => '联网搜索';

  @override
  String get errAssistantConfig =>
      '请填写有效的 HTTPS API 基址（本机服务可用 http，例如 http://localhost:11434/v1）、模型和输出上限（128–16384）';

  @override
  String get errExtRootAddress => '请输入服务根地址，例如 https://bt.example.com';

  @override
  String get errExtHttpsRequired => '公网地址必须使用 HTTPS；HTTP 仅允许局域网或本机地址';

  @override
  String get errExtTokenRequired => '请填写访问令牌';

  @override
  String get errExtTimeout => '连接超时';

  @override
  String get errExtUnreachable => '无法连接到这个地址';

  @override
  String get errExtTls => 'TLS 证书校验失败';

  @override
  String get errExtTooLarge => '服务返回的数据过大';

  @override
  String errExtRejected(String reason) {
    return '服务拒绝了请求：$reason';
  }

  @override
  String errExtError(String code) {
    return '服务返回错误（$code）';
  }

  @override
  String get errExtTokenInvalid => '访问令牌无效';

  @override
  String get errExtNoMcp => '这个地址没有提供 MCP 入口';

  @override
  String get errArtworkCancelled => '图片加载已取消';

  @override
  String get errArtworkQuota => '图片缓存额度不足';

  @override
  String get errArtworkUnauthorized => '图片地址未经授权';

  @override
  String get errArtworkTypeSize => '图片类型或大小无效';

  @override
  String get errArtworkEmptyOrLarge => '图片为空或过大';

  @override
  String get errArtworkContentType => '不支持的图片内容类型';

  @override
  String get errArtworkDecodeSize => '图片解码尺寸过大';

  @override
  String get errArtworkWait => '请等待图片加载完成';

  @override
  String get errLibraryClosing => '媒体库正在关闭';

  @override
  String get errNameRequired => '请输入名称';

  @override
  String get errSeasonCycle => '来源返回了循环季集关系';

  @override
  String get errInvalidPagingShort => '无效分页';

  @override
  String get errTitleRequired => '请输入标题';

  @override
  String get errScanRunning => '扫描已在运行';

  @override
  String get errFileSourceMissing => '文件源不存在';

  @override
  String get errFileSourceDisabled => '文件源已停用';

  @override
  String get errSourceScanDisabled => '来源未启用扫描';

  @override
  String get errScanTooLarge => '扫描范围过大，请缩小范围';

  @override
  String get errScanBindingChanged => '来源或绑定已变更，请重新扫描';

  @override
  String get errSourceIdentityMismatch => '来源身份不匹配';

  @override
  String get errSourceCursorStuck => '来源分页游标未前进';

  @override
  String get errScanIncomplete => '扫描未完成，请检查来源后重试';

  @override
  String get aiToolContextGet => '读取当前页面';

  @override
  String get aiToolSourceList => '列出媒体来源';

  @override
  String get aiToolSourceBrowse => '浏览文件夹';

  @override
  String get aiToolLibraryQuery => '查询媒体库';

  @override
  String get aiToolMediaGet => '查看媒体详情';

  @override
  String get aiToolSearchMedia => '搜索媒体';

  @override
  String get aiToolProgressQuery => '查看观看进度';

  @override
  String get aiToolPlaybackGet => '读取播放状态';

  @override
  String get aiToolPlaybackOpen => '打开播放';

  @override
  String get aiToolPlaybackPause => '暂停';

  @override
  String get aiToolPlaybackResume => '继续播放';

  @override
  String get aiToolPlaybackStop => '停止播放';

  @override
  String get aiToolPlaybackSeek => '跳转';

  @override
  String get aiToolPlaybackSetSpeed => '设置倍速';

  @override
  String get aiToolPlaybackSetVolume => '设置音量';

  @override
  String get aiToolPlaybackSetSubtitle => '设置字幕';

  @override
  String get aiToolMediaProcessingCapabilities => '查询媒体处理能力';

  @override
  String get aiToolMediaProbe => '分析媒体';

  @override
  String get aiToolMediaTranscode => '转码 / 截取片段';

  @override
  String get aiToolMediaExtractAudio => '提取音频';

  @override
  String get aiToolMediaSnapshot => '截图';

  @override
  String get aiToolMediaSaveToSource => '存回媒体来源';

  @override
  String get aiToolTaskGet => '查询处理任务';

  @override
  String get aiToolTaskList => '列出处理任务';

  @override
  String get aiToolTaskCancel => '取消处理任务';

  @override
  String get aiToolTaskRetry => '重试处理任务';

  @override
  String get aiToolSpeechRecognitionStatus => '查询语音识别状态';

  @override
  String get aiToolSubtitleGenerate => '识别字幕';

  @override
  String get aiToolTranscriptGenerate => '生成转录';

  @override
  String get aiToolSubtitleTaskGet => '查询字幕任务';

  @override
  String get aiToolSubtitleTaskCancel => '取消字幕任务';

  @override
  String get aiToolSubtitleSave => '保存字幕';

  @override
  String get aiToolPluginStatus => '查看插件状态';

  @override
  String get aiToolMcpTavilyWebSearch => '联网搜索';

  @override
  String get aiToolWebFetch => '读取网页';

  @override
  String get aiArgQuery => '关键词';

  @override
  String get aiArgUrl => '网址';

  @override
  String get aiArgRange => '范围';

  @override
  String get aiArgEnd => '结尾';

  @override
  String get aiArgWholeMedia => '整部';

  @override
  String get aiArgTime => '时间';

  @override
  String get aiArgPosition => '位置';

  @override
  String get aiArgPreset => '预设';

  @override
  String get aiArgLanguage => '语言';

  @override
  String get aiArgFormat => '格式';

  @override
  String get aiArgSpeed => '倍速';

  @override
  String get aiArgVolume => '音量';

  @override
  String get aiArgSwitch => '开关';

  @override
  String get aiArgOff => '关闭';

  @override
  String get aiArgWait => '等待';

  @override
  String get aiToolInput => '输入';

  @override
  String get aiToolOutput => '输出';

  @override
  String get aiActivityThinking => '正在思考';

  @override
  String get aiActivityAnswering => '正在回复';

  @override
  String get aiActivityRunningDefault => '运行中';

  @override
  String get aiReasoningStreaming => '思考中…';

  @override
  String get aiReasoningDone => '已思考';

  @override
  String get aiReasoningUnderSecond => '思考了不到 1 秒';

  @override
  String get aiStillRunning => '等待超时，任务仍在后台运行（未失败、未停止）';

  @override
  String get aiStatusQueued => '排队中';

  @override
  String get aiStatusPreparing => '准备中';

  @override
  String get aiStatusRunning => '处理中';

  @override
  String get aiStatusCancelling => '取消中';

  @override
  String get aiStatusSucceeded => '已完成';

  @override
  String get aiStatusFailed => '失败';

  @override
  String get aiStatusCancelled => '已取消';

  @override
  String get aiStatusInterrupted => '已中断';

  @override
  String get aiStageExtracting => '提取音频';

  @override
  String get aiStageUploading => '上传';

  @override
  String get aiStageQueued => '排队';

  @override
  String get aiStageTranscribing => '识别';

  @override
  String get aiStageFormatting => '整理字幕';

  @override
  String aiArgWaitValue(String seconds) {
    return '最多等 ${seconds}s';
  }

  @override
  String aiStepPreparing(String name) {
    return '准备调用 $name…';
  }

  @override
  String aiStepRunning(String name) {
    return '正在执行 $name…';
  }

  @override
  String aiStepWaiting(String name) {
    return '允许执行 $name？';
  }

  @override
  String aiStepFailed(String name) {
    return '$name 失败';
  }

  @override
  String aiStepCancelled(String name) {
    return '已取消 $name';
  }

  @override
  String aiShowAll(int count) {
    return '显示全部（$count 个字符）';
  }

  @override
  String aiActivityPreparingTool(String name) {
    return '准备调用：$name';
  }

  @override
  String aiActivityTool(String name) {
    return '正在执行：$name';
  }

  @override
  String aiActivityConfirm(String name) {
    return '等待你确认：$name';
  }

  @override
  String aiStepNumber(int step) {
    return '第 $step 步';
  }

  @override
  String aiReasoningSeconds(int seconds) {
    return '思考了 $seconds 秒';
  }

  @override
  String aiReasoningMinutes(int minutes) {
    return '思考了 $minutes 分钟';
  }

  @override
  String get cloudJianguoyun => '坚果云';

  @override
  String get cloud123 => '123 云盘';

  @override
  String get cloudJianguoyunHelp => '使用账号和第三方应用密码，可调整默认 WebDAV 目录。';

  @override
  String get cloud123Help => '先确认 123 账号具备 WebDAV 权益，填写官方后台提供的地址和凭据；可用性取决于套餐。';

  @override
  String get cloudPreset => 'WebDAV 预设';

  @override
  String get cloudCustom => '自定义 WebDAV';

  @override
  String get catSummaryCloudDrive => '浏览和播放云盘文件。';

  @override
  String get cloudSignIn => '使用浏览器登录';

  @override
  String get cloudSignInHelp =>
      '仅读取文件，请在下方选择根目录。断开 OneDrive 后，还需到微软账号权限页面解除应用授权。';

  @override
  String get cloudNotConfigured => '此构建尚未配置云盘登录，需由发布者配置 OAuth 应用。';

  @override
  String get cloudSignInFailed => '云盘授权失败，请重试。';

  @override
  String get cloudCallbackInvalid => '无法验证授权回调。';

  @override
  String get cloudRoot => '已选根目录';

  @override
  String get cloudRootHelp => '打开文件夹即可选为根目录，仅浏览和扫描此目录下的文件。';

  @override
  String get cloudReauthorize => '授权已过期或撤销，请重新登录。';

  @override
  String get cloudPersonalOnly => '目前仅支持个人 OneDrive 账号。';

  @override
  String get cloudDisconnect => '断开账号';

  @override
  String get cloudDisconnectHelp =>
      '清除本地凭据并停止云盘请求。还需在微软或 Dropbox 账号权限页面移除此应用，以解除平台授权。';
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
  String get plugins => 'AI';

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
  String get retry => '重试';

  @override
  String get cancel => '取消';

  @override
  String get aiSettingsSaved => '已保存。';

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
  String get saving => '正在保存…';

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
    return '此文件源关联 $count 项内容。删除后，只由它扫描到的文件记录、播放进度和刮削信息会一并删除；其他文件源也扫描到的内容会保留。存储上的原文件不受影响。';
  }

  @override
  String disableSourceDescription(int playing, int running) {
    return '当前播放 $playing 个，进行中请求 $running 个。禁用后拒绝新请求；当前播放可继续，结束后释放连接。配置、收藏和产物保留。';
  }

  @override
  String deleteSourceDescription(int fileSources, int playing, int running) {
    return '删除此连接的配置与凭据，并删除它下面的 $fileSources 个文件源及其扫描到的内容（文件记录、播放进度、刮削信息）。存储上的原文件不受影响。当前播放 $playing 个、进行中请求 $running 个可完成，之后释放连接。';
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
    return '$speed MB/s';
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
  String get detailExtras => '花絮';

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
  String get aiTextToolCall => '模型在重试后仍把工具调用输出为文字，工具未执行。请检查模型及端点是否支持工具调用。';

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
  String get artworkCacheLimit => '图片缓存上限';

  @override
  String get artworkCacheLimitDescription =>
      '海报、背景图和演职人员照片。达到上限时先删除最早下载的图片，已锁定的图片不会删除。';

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
  String get aiConnectionOkNoTools => '连接成功，工具调用测试未通过；实际任务仍会尝试调用已注册的工具。';

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
  String get asrSaved => '已保存，可在播放时的字幕列表中选择（标记为“识别”）。';

  @override
  String get asrSavedPartial => '已保存（部分区间），可在播放时的字幕列表中选择（标记为“识别”）。';

  @override
  String get asrSaveHint => '未保存的结果离开页面后清除；保存会新增一条字幕记录，不替换已有字幕，也不会自动影响播放。';

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
  String get asrServiceUrl => '服务地址';

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

  @override
  String get embeddedSubtitles => '内嵌字幕';

  @override
  String get externalSubtitles => '外部字幕';

  @override
  String get recognizedSubtitles => '识别字幕';

  @override
  String get recognizedSubtitleBadge => '识别';

  @override
  String recognizedSubtitleTitle(String time) {
    return '保存于 $time';
  }

  @override
  String recognizedSubtitlePartial(String start, String end) {
    return '部分 $start–$end';
  }

  @override
  String get recognizedSubtitleFull => '整集';

  @override
  String get addSourceConnection => '添加连接';

  @override
  String get sourcesDescription => '连接你的存储，整理你的媒体。';

  @override
  String sourceActions(String name) {
    return '$name的操作';
  }

  @override
  String get browseSourceFiles => '浏览文件';

  @override
  String get sourceAwaitingVerification => '待验证';

  @override
  String sourceFileCount(int count) {
    return '$count 个文件源';
  }

  @override
  String get sourceRootFolder => '根目录';

  @override
  String get rescanFileSource => '重新扫描';

  @override
  String plAbASet(String time) {
    return '已设置 A 点 $time';
  }

  @override
  String get plAbClear => '清除 A-B 循环';

  @override
  String get plAbCleared => '已清除 A-B 循环';

  @override
  String get plAbLoop => 'A-B 循环';

  @override
  String plAbLooping(String a, String b) {
    return '循环 $a – $b';
  }

  @override
  String get plAbSetA => '设置 A 点';

  @override
  String get plAbSetB => '设置 B 点';

  @override
  String get plAdvancedTools => '高级工具行';

  @override
  String get plAspectDefault => '默认';

  @override
  String get plAspectRatio => '宽高比';

  @override
  String get plAudioDelay => '音频延迟';

  @override
  String plBoosting(String speed) {
    return '$speed 快进中 · 松手恢复';
  }

  @override
  String get plDelayHint => '正值表示声音或字幕延后。';

  @override
  String get plExitFullscreen => '退出全屏';

  @override
  String get plFaster => '加速';

  @override
  String get plFitBest => '最佳适配';

  @override
  String get plFitFill => '填充';

  @override
  String get plFitMode => '画面尺寸';

  @override
  String get plFitOriginal => '原始尺寸';

  @override
  String get plFullscreen => '全屏';

  @override
  String get plGo => '跳转';

  @override
  String get plInfo => '信息';

  @override
  String get plInfoDuration => '时长';

  @override
  String get plInfoResolution => '分辨率';

  @override
  String get plInfoTitle => '标题';

  @override
  String get plJumpBackMedium => '后退 1 分钟';

  @override
  String get plJumpExtraShort => '跳转 3 秒';

  @override
  String get plJumpForwardMedium => '前进 1 分钟';

  @override
  String get plJumpLong => '跳转 5 分钟';

  @override
  String plJumpSeconds(String seconds) {
    return '$seconds 秒';
  }

  @override
  String get plJumpToTime => '跳到时间';

  @override
  String get plJumpToTimeInvalid => '请输入如 1:23:45 或 12:30 的时间。';

  @override
  String get plLoadSubtitle => '加载外部字幕…';

  @override
  String get plLockShort => '锁定';

  @override
  String get plMediaInfo => '媒体信息';

  @override
  String get plMenuAudio => '音频';

  @override
  String get plMenuPlayback => '播放';

  @override
  String get plMenuSubtitle => '字幕';

  @override
  String get plMenuVideo => '视频';

  @override
  String get plMenuView => '视图';

  @override
  String get plMute => '静音';

  @override
  String get plMuted => '已静音';

  @override
  String get plNextAudioTrack => '下一音轨';

  @override
  String get plNextSubtitle => '下一字幕';

  @override
  String get plNormalSpeed => '恢复正常速度';

  @override
  String get plOrientationShort => '方向';

  @override
  String get plPicture => '画面';

  @override
  String get plPictureAndSound => '画面与声音';

  @override
  String get plRepeatMode => '重复模式';

  @override
  String get plRepeatOff => '不重复';

  @override
  String get plRepeatOne => '单项循环';

  @override
  String get plReset => '重置';

  @override
  String get plSettingsAndEffects => '设置与效果';

  @override
  String get plShortcuts => '快捷键';

  @override
  String get plShowPosition => '显示当前位置';

  @override
  String get plSleepEndOfItem => '本集结束后';

  @override
  String get plSleepFinished => '睡眠定时已暂停播放';

  @override
  String plSleepMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get plSleepOff => '关闭';

  @override
  String get plSleepShort => '睡眠';

  @override
  String get plSleepTimer => '睡眠定时';

  @override
  String get plSlideToUnlock => '向右滑动解锁';

  @override
  String get plSlower => '减速';

  @override
  String get plSnapshot => '截图';

  @override
  String get plSnapshotFailed => '截图保存失败';

  @override
  String plSnapshotSaved(String path) {
    return '截图已保存：$path';
  }

  @override
  String get plSpeedShort => '倍速';

  @override
  String get plStatistics => '统计信息';

  @override
  String get plStatsAudio => '音频块 播放/丢失';

  @override
  String get plStatsDemux => '解复用码率';

  @override
  String get plStatsFrames => '帧 显示/丢失';

  @override
  String get plStatsInput => '输入码率';

  @override
  String get plStatsOverlay => '统计浮层';

  @override
  String get plStatsRead => '读取速度';

  @override
  String get plStop => '停止';

  @override
  String get plSubtitleDelay => '字幕延迟';

  @override
  String get plSync => '同步';

  @override
  String get plTimeTooltip => '单击切换剩余时间，双击跳到时间';

  @override
  String get plToggleControls => '显示/隐藏控制层';

  @override
  String get plToggleSubtitles => '字幕开关';

  @override
  String get plTrackAudio => '音频';

  @override
  String get plTracks => '音轨与字幕';

  @override
  String get plTracksShort => '音轨字幕';

  @override
  String get plTrackSubtitle => '字幕';

  @override
  String get plTrackVideo => '视频';

  @override
  String get plUnsupported => '当前播放器不支持';

  @override
  String get plZoom => '缩放';

  @override
  String get plZoomOriginal => '原始';

  @override
  String get plMenuPlaybackControl => '播放控制';

  @override
  String plBoostingShort(String speed) {
    return '$speed 快进中';
  }

  @override
  String get plSwipeUpToLock => '上滑锁定';

  @override
  String plSpeedLocked(String speed) {
    return '已锁定 $speed';
  }

  @override
  String get plExternalSubtitleShort => '+ 外部字幕';

  @override
  String get listSeparator => '、';

  @override
  String get remoteAccess => '远程访问';

  @override
  String get remoteHomeAndRoutes => '家庭与连接线路';

  @override
  String get remoteImportTitle => '导入远程配置';

  @override
  String get remoteImportFooter => '粘贴 Relay 导出的 App 配置，导入后立即生效。';

  @override
  String get remoteImportPlaceholder => 'App 配置 JSON';

  @override
  String get remoteImport => '导入';

  @override
  String get remoteImporting => '正在导入…';

  @override
  String get remoteImported => '已导入并生效。';

  @override
  String get remoteClearConfirmTitle => '清空远程配置？';

  @override
  String get remoteClearConfirmMessage => '清空本机的远程配置与凭据，重新导入后可恢复远程访问。';

  @override
  String get remoteClear => '清空';

  @override
  String get remoteClearing => '正在清空…';

  @override
  String get remoteCleared => '已清空远程配置。';

  @override
  String get remoteNotImported => '尚未导入';

  @override
  String get remoteNotImportedHint => '点击“导入”添加远程配置。';

  @override
  String get remoteServerName => '服务器名称';

  @override
  String get remoteCredentials => '认证凭据';

  @override
  String get remoteCredentialsSecure => '已保存在系统安全存储';

  @override
  String get remoteProxyUnused => '未被来源使用';

  @override
  String remoteProxyUsedBy(String sources) {
    return '来源：$sources';
  }

  @override
  String remoteProxyPort(int port) {
    return '端口 $port';
  }

  @override
  String get remoteRelayServer => '中继服务器';

  @override
  String get remoteRelayFooter => '整个 App 共用此连接；认证凭据保存在系统安全存储。';

  @override
  String get remoteAvailableServices => '可用服务';

  @override
  String get remoteAvailableServicesFooter =>
      '由 Home 注册在 Relay 上。来源在“编辑来源 → 家庭远程访问”中选择其中一个。';

  @override
  String get remoteNeedsAttention => '需要处理';

  @override
  String remoteSourceProxyMissing(String proxy) {
    return '使用的 proxy「$proxy」不在当前配置中，远程连接不可用。';
  }

  @override
  String get statusConfigured => '已配置';

  @override
  String get statusNotConfigured => '未配置';

  @override
  String get statusAvailable => '可用';

  @override
  String get statusUnavailable => '不可用';

  @override
  String get plgGroupModel => '模型';

  @override
  String get plgGroupExternal => '外部能力';

  @override
  String get plgGroupBuiltIn => '内部能力';

  @override
  String get plgGroupModelDescription => '配置 Agent 使用的模型';

  @override
  String get plgGroupExternalDescription => '自部署或云端服务，由你添加';

  @override
  String get plgGroupBuiltInDescription => '随 App 提供，默认全部开放';

  @override
  String plgCount(int count) {
    return '$count 项';
  }

  @override
  String extToolCount(int count) {
    return '$count 个工具';
  }

  @override
  String plgInstanceCount(int count) {
    return '$count 个实例';
  }

  @override
  String get plgExternalHint => '填写地址和令牌，自动识别并配置服务';

  @override
  String get plgExternalEmpty => '还没有配置外部服务';

  @override
  String get extConfigureTitle => '配置外部能力';

  @override
  String plgBuiltInHint(int count) {
    return '随 App 提供 $count 项，默认全部开放，无需逐项启用';
  }

  @override
  String plgGroupEmpty(String group) {
    return '暂无$group';
  }

  @override
  String get plgNoAssistant => '此构建未接入 AI 助手';

  @override
  String get plgSelectForDetail => '选择一项查看详情';

  @override
  String get plgDeviceUnsupported => '当前设备不支持';

  @override
  String get plgTemporarilyUnavailable => '暂不可用';

  @override
  String get plgDisabled => '插件已停用';

  @override
  String plgDisableConfirmTitle(String name) {
    return '停用「$name」？';
  }

  @override
  String get plgImpactIntro => '停用后立即阻止新的调用；实例配置、已生成的字幕和历史记录都会保留。';

  @override
  String plgImpactPlaying(int count) {
    return '$count 个正在播放的会话会继续到播放结束后再释放连接。';
  }

  @override
  String plgImpactRunning(int count) {
    return '$count 个进行中的请求会在完成后释放。';
  }

  @override
  String plgImpactInstances(String instances) {
    return '受影响的实例：$instances。';
  }

  @override
  String get actionFailedRetry => '操作失败，请重试。';

  @override
  String get plgUnavailableReason => '不可用原因';

  @override
  String get plgSwitch => '插件开关';

  @override
  String get plgSwitchOn => '允许承接新的业务调用';

  @override
  String get plgSwitchOff => '已阻止新的调用；实例配置保留';

  @override
  String get settingsCapabilities => '基础能力';

  @override
  String get capabilitySwitchesFooter =>
      '关闭的能力在整个 App 中都不再承接新的调用，AI 也无法使用；已有配置会保留。';

  @override
  String capabilityNeeds(String name) {
    return '需要先开启「$name」';
  }

  @override
  String get plgCapabilitySwitch => '基础能力开关';

  @override
  String get plgCapabilitySwitchHint => '在「设置 → 基础能力」中开关，对整个 App 生效';

  @override
  String get capabilityOn => '已开启';

  @override
  String get capabilityOff => '已关闭';

  @override
  String get plgLocation => '执行位置';

  @override
  String get plgLocationDevice => '在本机运行';

  @override
  String get plgLocationNetwork => 'App 在本机连接你配置的存储服务';

  @override
  String get plgLocationSelfHosted => 'App 在本机运行适配器，实际工作在你配置的服务器上进行';

  @override
  String get plgLocationCloudApi => 'App 在本机调用云端 API';

  @override
  String get plgDependencies => '依赖';

  @override
  String plgDependency(String name, String status) {
    return '$name（$status）';
  }

  @override
  String get plgCapabilities => '能力';

  @override
  String get plgCapabilitiesFooter => '只列出此插件真实实现的方法；未实现的能力不会显示。';

  @override
  String plgInstancesTitle(int count) {
    return '实例（$count 个）';
  }

  @override
  String plgInstanceBusy(int playing, int running) {
    return '使用中：播放 $playing · 请求 $running';
  }

  @override
  String get plgNoInstances => '暂无实例';

  @override
  String get plgOpenSettings => '打开设置';

  @override
  String get plgRuntime => '运行状态与诊断';

  @override
  String plgRevisions(String saved, String applied) {
    return '已保存修订 $saved · 实际生效 $applied';
  }

  @override
  String get plgNotApplied => '尚未生效';

  @override
  String get plgPendingApply => '新配置待生效，旧修订仍在服务进行中的调用';

  @override
  String plgActivity(int playing, int running) {
    return '活动播放 $playing · 进行中请求 $running';
  }

  @override
  String plgLastError(String code) {
    return '最近错误：$code';
  }

  @override
  String get plgRefreshStatus => '刷新状态';

  @override
  String get plgCopyDiagnostics => '复制脱敏诊断信息';

  @override
  String get plgCopyDiagnosticsHint => '不含地址、账号、路径或密钥';

  @override
  String get plgDiagnosticsCopied => '已复制诊断信息';

  @override
  String get extConnectionOk => '连接正常';

  @override
  String extRemoveConfirmTitle(String name) {
    return '移除「$name」？';
  }

  @override
  String get extRemoveConfirmMessage => '只移除 App 中的地址和令牌，不会影响服务器上的数据。';

  @override
  String get extNeedsRecheck => '需要重新检测';

  @override
  String extToolAiUnavailable(String problem) {
    return 'AI 暂不可用：$problem';
  }

  @override
  String get extToolNeedsConfirm => '调用前需要你确认';

  @override
  String get extAiServiceUnavailable => '服务当前不可用，AI 暂时无法调用';

  @override
  String get extAiNeedsRecheck => '请点“重新检测”以获取工具定义';

  @override
  String extAiSummary(int usable, int total) {
    return 'AI 可直接调用 $usable / $total 个工具；会改变状态的操作会先请你确认';
  }

  @override
  String get extRemoved => '这个外部能力已移除';

  @override
  String extVersion(String version) {
    return '版本 $version';
  }

  @override
  String get extAiCalls => 'AI 调用';

  @override
  String extToolsTitle(int count) {
    return '工具（$count 个）';
  }

  @override
  String get extNoTools => '没有工具';

  @override
  String get extRecheck => '重新检测';

  @override
  String get extConnecting => '正在连接并识别…';

  @override
  String extAdded(String name) {
    return '已添加「$name」';
  }

  @override
  String get extConfigureFooter =>
      '填写服务地址和访问令牌，App 会通过 MCP 连接，读取它是什么服务、提供哪些工具。';

  @override
  String get extServiceAddress => '服务地址';

  @override
  String get extAccessToken => '访问令牌';

  @override
  String get extNameOptional => '名称（可选）';

  @override
  String get extDetected => '识别结果';

  @override
  String get extTools => '工具';

  @override
  String get extConnect => '连接并识别';

  @override
  String get scanStatusPending => '待扫描';

  @override
  String get scanStatusScanning => '扫描中';

  @override
  String get scanStatusDone => '扫描完成';

  @override
  String get scanStatusFailed => '扫描失败';

  @override
  String get scanStatusInterrupted => '扫描中断';

  @override
  String get scanRescanHint => '请重新扫描';

  @override
  String get libraryDbTooNew => '媒体库版本较新，请升级应用';

  @override
  String get errConfigUnknownFields => '配置包含未知字段，原始配置必须保留。';

  @override
  String get errRemoteKinds => '当前远程访问支持 Jellyfin、Emby、Plex 和 SMB。';

  @override
  String get errRemoteProtocolMismatch => '远程服务协议不匹配；SMB 当前仅支持远程模式。';

  @override
  String get errConfigVersionNoOverwrite => '配置版本不兼容，不能覆盖保存。';

  @override
  String get errAddressRequired => '请填写地址。';

  @override
  String get errTimeoutConcurrency => '请求超时须为 1–120 秒，并发须为 1–8。';

  @override
  String get errScopeCount => '至少设置一个访问范围，范围和排除项最多各 100 条。';

  @override
  String get errScopeRelative => '访问范围和排除项须为根目录内的相对路径，不允许 .. 或绝对路径。';

  @override
  String get errBrowseModeUnsupported => '此插件不支持该浏览方式。';

  @override
  String get errNoSearchIndex => '此插件尚未提供搜索或后台索引能力。';

  @override
  String get errLibraryNoDirPolicy => '媒体库来源暂不支持文件目录策略。';

  @override
  String get errChooseLocalFolder => '请选择本地文件夹。';

  @override
  String get errAddressRelativeSegments => '地址不能包含相对路径片段。';

  @override
  String get errInvalidServerAddress => '请输入有效的服务器地址，凭据请填在单独字段。';

  @override
  String get errSmbAddressFormat => 'SMB 使用标准 445 端口：smb://主机/共享名/可选目录。';

  @override
  String errUserIdRequired(String kind) {
    return '请填写 $kind 用户 ID。';
  }

  @override
  String get errSftpUsernameRequired => '请填写 SFTP 用户名。';

  @override
  String get errServerAddressRequired => '请填写服务器地址。';

  @override
  String get errInvalidHost => '请输入有效的 IP、主机名或服务器地址。';

  @override
  String get errPortRange => '端口须为 1–65535。';

  @override
  String get errSmbPort => '当前 SMB 连接使用 445 端口。';

  @override
  String get errPathDots => '路径不能包含 . 或 ..。';

  @override
  String get errSignInFailed => '登录失败，请检查账号和密码或重新授权。';

  @override
  String get errAddressRedirected => '地址发生跳转，请填写服务器的实际入口。';

  @override
  String get errCannotConnectService => '无法连接服务，请检查地址和网络。';

  @override
  String get errConnectTimeout => '连接超时，请重试。';

  @override
  String errKindUsernameRequired(String kind) {
    return '请填写 $kind 用户名。';
  }

  @override
  String get errNoValidSignIn => '服务器未返回有效的登录结果。';

  @override
  String get errPlexSessionExpired => '登录已过期，请重新登录 Plex。';

  @override
  String get errPlexServerUnreachable => '无法连接这台 Plex 服务器，请确认服务器在线。';

  @override
  String errDlnaHttp(int status) {
    return 'DLNA 设备请求失败（HTTP $status）。';
  }

  @override
  String get errDlnaForeignHost => 'DLNA 设备返回了其他主机的地址。';

  @override
  String get errDlnaNotMediaServer => '该设备不是媒体服务器（没有内容目录服务）。';

  @override
  String get errChooseFolder => '请选择文件夹。';

  @override
  String get untitled => '未命名';

  @override
  String get errChooseVideoOrAudio => '请选择视频或音频。';

  @override
  String get errNoPlayableAddress => '此项目没有可播放的地址。';

  @override
  String get plexPartMedia => '媒体';

  @override
  String get errPathOutsideRoot => '路径超出配置的根目录。';

  @override
  String get errOutsideScope => '目录不在此实例配置的访问范围内。';

  @override
  String get errAttachmentTooLarge => '附件过大';

  @override
  String errServiceAccessDenied(String service, int status) {
    return '$service 拒绝访问（HTTP $status），请检查用户名和密码。';
  }

  @override
  String get errFileNotFound => '文件或文件夹不存在。';

  @override
  String errServiceRequestFailed(String service, int status) {
    return '$service 请求失败（HTTP $status）。';
  }

  @override
  String get errFtpRefused => 'FTP 服务器拒绝连接。';

  @override
  String get errFtpLogin => 'FTP 登录失败，请检查用户名和密码。';

  @override
  String get errFtpNoBinary => 'FTP 服务器不支持二进制传输。';

  @override
  String get errPathChars => '路径包含不支持的字符。';

  @override
  String get errFtpNoPassive => 'FTP 服务器不支持被动模式。';

  @override
  String get errFolderNotFoundOrDenied => '文件夹不存在或无权访问。';

  @override
  String get errFtpList => 'FTP 无法列出文件夹。';

  @override
  String get errFtpNoResume => 'FTP 服务器不支持断点续传，无法拖动进度。';

  @override
  String get errFtpRead => '无法读取该 FTP 文件。';

  @override
  String get errFtpNoSize => 'FTP 服务器未返回文件大小，无法播放。';

  @override
  String get errSftpLogin => 'SFTP 登录失败，请检查用户名和密码。';

  @override
  String get errSftpDisabled => '服务器未启用 SFTP。';

  @override
  String get errPathDenied => '没有权限访问该路径。';

  @override
  String get errSftpRequest => 'SFTP 请求失败。';

  @override
  String get errSftpConnect => 'SFTP 连接失败。';

  @override
  String get errSftpPlay => '无法播放该 SFTP 文件。';

  @override
  String get errChooseFile => '请选择文件。';

  @override
  String get errConnectionClosed => '连接已关闭。';

  @override
  String get errUnsafeResourceUrl => '媒体服务返回了不安全的资源地址。';

  @override
  String errMediaServerHttp(int status) {
    return '媒体服务请求失败（HTTP $status），请检查地址和凭据。';
  }

  @override
  String get errServerArtworkUnavailable => '服务端图片不可用';

  @override
  String get errImageTooLarge => '图片过大';

  @override
  String get errNoPlayableVersion => '此媒体没有可播放版本。';

  @override
  String get errReselectVersion => '请返回媒体库重新选择一个版本。';

  @override
  String get errServerIdentityMismatch => '服务端对象身份不匹配';

  @override
  String plexPartLabel(int index, String container) {
    return '文件 $index · $container';
  }

  @override
  String get errNoPlayableFile => '此媒体没有可播放文件。';

  @override
  String get errMultiPartUnsupported => '该媒体包含多个版本或分段，暂不支持直接播放。';

  @override
  String get errMetadataNotThisServer => '元数据查询不属于此服务端实例';

  @override
  String get errArtworkNotThisServer => '图片不属于此服务端实例';

  @override
  String get srcFieldFolder => '文件夹';

  @override
  String get srcFieldWorkgroup => '工作组（可选）';

  @override
  String get srcFieldRegion => '区域（可选）';

  @override
  String srcFieldRequired(String field) {
    return '请填写$field。';
  }

  @override
  String get errResourceNotThisSource => '资源不属于此媒体源。';

  @override
  String get errOutsideAuthorizedFolder => '文件超出已授权文件夹。';

  @override
  String get errOutsideSmbShare => '路径超出配置的 SMB 共享。';

  @override
  String get errSmbListShares => '无法读取共享列表，请在“高级”中填写共享文件夹路径后重试。';

  @override
  String get errSmbPlay => '无法播放该 SMB 文件。';

  @override
  String get errAttachmentNotFound => '附件不存在';

  @override
  String get errInvalidFileName => '文件名无效。';

  @override
  String get errUnknownWriteShare => '无法确定要写入的共享。';

  @override
  String get errOpenPlayXFolderBlocked => '共享中已有同名文件，无法创建 OpenPlayX 文件夹。';

  @override
  String get errTooManySameName => '同名文件过多，请先整理 OpenPlayX 文件夹。';

  @override
  String get errTempNameConflict => '临时文件名冲突，请重试。';

  @override
  String get errUploadIncomplete => '上传不完整，已丢弃临时文件。';

  @override
  String get errSmbWrite => '写入 SMB 失败，请确认账号对该共享有写权限。';

  @override
  String get errAttachmentTypeOrLimit => '不支持的附件类型或读取上限';

  @override
  String get errSourceMissing => '媒体源不存在或配置不兼容。';

  @override
  String get errSourceKindChange => '编辑时不能更改源类型。';

  @override
  String get errTokenRequired => '请填写访问令牌。';

  @override
  String get srcStatusDisabled => '已禁用';

  @override
  String get srcStatusReady => '已就绪';

  @override
  String get srcStatusFailed => '连接失败';

  @override
  String get srcStatusInitialized => '已初始化 · 待连接验证';

  @override
  String get srcStatusSaved => '已保存 · 下次访问生效';

  @override
  String get errArtworkCacheLimit => '不支持的图片缓存上限。';

  @override
  String get errExtensions => '文件后缀只能包含字母和数字，最多 100 个。';

  @override
  String get errSourceDisabled => '媒体源已禁用，配置仍保留。';

  @override
  String get errPluginDisabled => '此插件已停用，实例配置仍保留。';

  @override
  String get errTokenExpired => '令牌已到期，请更新凭据。';

  @override
  String get errReselectLocalFolder => '请重新选择本地文件夹以恢复授权。';

  @override
  String get errCredentialsUnavailable => '凭据不可用，请重新登录或更新凭据。';

  @override
  String get errInstanceChanged => '实例配置已改变，请重试。';

  @override
  String get errRequestTimedOut => '请求已超时。';

  @override
  String get errSourceUnreachable => '无法访问媒体源，请检查地址、权限和凭据。';

  @override
  String get errInvalidPaging => '无效的分页参数。';

  @override
  String get errInvalidSearchPaging => '无效搜索或分页';

  @override
  String get errSearchUnsupported => '此来源不支持搜索';

  @override
  String get errMetadataUnsupported => '此来源不支持影视信息查询';

  @override
  String get errAttachmentsUnsupported => '此来源不支持附件读取';

  @override
  String get errWriteUnsupported => '此来源不支持写入。';

  @override
  String get errWriteTimeout => '写入超时，服务器上可能残留以 .openplayx- 开头的临时文件。';

  @override
  String errSourceProxyMissing(String proxy) {
    return '此来源使用远程访问 proxy「$proxy」，但当前 App 没有该 proxy；请在设置 → 远程访问导入 Relay 的 App 配置。';
  }

  @override
  String get errReloadBeforeTest => '请重新加载配置后测试。';

  @override
  String get errTestTimeout => '连接测试超时。';

  @override
  String get errTestFailed => '连接测试失败，请检查地址、权限和凭据。';

  @override
  String get errManualScanDisabled => '此实例未启用手动文件扫描。';

  @override
  String get errScanLimit => '扫描上限须为 1–5000。';

  @override
  String get errScanPageLimit => '扫描达到 1000 次目录分页上限，请缩小访问范围。';

  @override
  String get errScanConfigChanged => '扫描期间实例配置已改变，请重新扫描。';

  @override
  String get errTooManyQueued => '此实例排队请求过多，请稍后重试。';

  @override
  String get credNotRequired => '无需账号凭据';

  @override
  String get credMissing => '缺少凭据';

  @override
  String get credConfigured => '凭据已保存 · 尚未验证';

  @override
  String get credExpiring => '令牌将在 7 天内到期';

  @override
  String get credExpired => '令牌已到期';

  @override
  String get credRejected => '认证失败 · 请更新凭据';

  @override
  String get credVerified => '连接已验证';

  @override
  String get errConfigDbTooNew => '本地配置数据库版本较新，请升级应用。';

  @override
  String get errConfigVersionKept => '配置版本不兼容，原数据已保留。';

  @override
  String get errInstanceMetaMismatch => '实例配置与元数据不一致。';

  @override
  String get errInstanceQuarantined => '实例配置不兼容或损坏，已隔离且保留原数据。';

  @override
  String get errInstanceNoOverwrite => '不能覆盖版本不兼容的实例配置。';

  @override
  String get errConfigChangedElsewhereEdit => '配置已被其他窗口修改，请重新加载后编辑。';

  @override
  String get errConfigChangedDelete => '配置已更新，请重新加载后删除。';

  @override
  String get errDefaultInstanceChanged => '默认实例设置已更新，请重新加载。';

  @override
  String get errSettingsChangedElsewhere => '设置已被其他窗口修改，请重新加载。';

  @override
  String get pickerVideoAudio => '视频和音频';

  @override
  String get pickerAllFiles => '所有文件';

  @override
  String get errSeriesIdentityConflict => '剧集或季的身份存在冲突';

  @override
  String get errInfoChangedReload => '信息已更改，请重新加载后操作';

  @override
  String get errWorkIdConflict => '作品 ID 冲突，需要人工确认';

  @override
  String get errInvalidFieldValue => '字段值无效';

  @override
  String get errPosterNotThisWork => '海报不属于当前作品';

  @override
  String get errRemoteConfigVersion => '远程访问配置版本不兼容或包含未知字段。';

  @override
  String get errRemoteOutboundCredential => 'outbound 与凭据必须同时存在。';

  @override
  String get errRemoteUuidPlacement => 'UUID 只能保存在 credential 中。';

  @override
  String get errRemoteCredentialInvalid => '远程凭据无效。';

  @override
  String get errRemoteProxiesInvalid =>
      'proxies 的 name 不能为空或重复，remotePort 须为有效端口。';

  @override
  String get errRemotePolicyUnsupported => '远程连接策略超出支持范围。';

  @override
  String get errRemoteLanNeedsHttps => '局域网自动访问需要 HTTPS 端点和配对确认的证书 SHA-256。';

  @override
  String get errRemoteUnknownField => '未知远程访问字段。';

  @override
  String get errRemoteChooseProxy => '请选择远程访问使用的 proxy。';

  @override
  String get errRemoteEndpoint => '远程访问需要有效的 HTTP(S) 或 SMB 服务端点。';

  @override
  String get errRemoteProxyRef => 'proxy name、remotePort 或凭据引用无效。';

  @override
  String get errRemoteProxyHost => '代理主机或配置长度无效。';

  @override
  String get errRemoteTlsName => '代理 TLS 服务名称无效。';

  @override
  String get errRemoteNeedsVless => '配对需要开启证书校验的 VLESS TLS/REALITY 出站。';

  @override
  String get errRemoteCaPrivateKey => 'CA 配置不能包含私钥。';

  @override
  String get errRemoteRealityPublic => 'REALITY 客户端只保存公开参数。';

  @override
  String get errRemoteAuthHeader => '传输认证头不能写入公开线路配置。';

  @override
  String get errRemoteTlsField => '不支持的 TLS 配置字段。';

  @override
  String get errRemoteConfigTooLarge => '配置过大。';

  @override
  String get errRemoteInvalidJson => '不是有效的 JSON，请粘贴 Relay 导出的完整 App 配置。';

  @override
  String get errRemoteAppConfigShape =>
      'App 配置须为只含“outbound”（对象）和“proxies”（数组）的 JSON 对象。';

  @override
  String get errRemoteProxyShape =>
      'proxies 每项须只含“name”（字符串）和“remotePort”（端口）。';

  @override
  String get errRemoteProxiesEmpty => 'proxies 不能为空，name 不能重复。';

  @override
  String get errRemoteOutsideEndpoint => '请求超出已授权的服务端点。';

  @override
  String get errRemoteCertMismatch => '服务证书与已配对身份不匹配。';

  @override
  String get errRemoteOutsidePaired => '连接超出已配对服务。';

  @override
  String get errRemoteLanUnreachable => '局域网服务不可达或身份验证失败。';

  @override
  String get errRemoteCellularBlocked => '当前设置禁止蜂窝网络远程访问，或无法确认当前网络。';

  @override
  String get errRemoteCellularUnknown => '无法确认蜂窝网络状态，已阻止远程连接。';

  @override
  String get errRemoteNoCore => '此构建缺少远程连接内核，请安装包含 sing-box 的构建。';

  @override
  String get errRemoteNativeConfigTooLarge => '远程连接配置过大。';

  @override
  String get errRemoteCoreStart => '远程内核启动失败，请检查线路配置。';

  @override
  String get rtDisabled => '已停用';

  @override
  String get rtUnchecked => '未检测';

  @override
  String get rtStarting => '启动中';

  @override
  String get rtBlocked => '需处理';

  @override
  String get rtError => '出错';

  @override
  String get rtDraining => '收尾中';

  @override
  String get healthLastOk => '上次连接成功';

  @override
  String get healthLocal => '本机';

  @override
  String get plgDraining => '已阻止新调用，正在等待播放或任务结束';

  @override
  String plgDependencyBlocked(String name) {
    return '依赖的「$name」已停用或不可用';
  }

  @override
  String get plgNoInstanceAdded => '尚未添加实例';

  @override
  String get plgAllInstancesDisabled => '所有实例均已停用';

  @override
  String get plgInstanceFailing => '有实例连接失败';

  @override
  String get plgSomeInstancesBlocked => '部分实例需处理';

  @override
  String get plgNfoInstance => '邻近文件规则';

  @override
  String get plgNoTmdb => '此构建未接入 TMDB 设置';

  @override
  String get plgTmdbInstance => 'TMDB 配置';

  @override
  String get plgTmdbNoToken => '未配置访问令牌';

  @override
  String get plgNoFfmpeg => '当前平台或构建未包含 FFmpeg 媒体处理';

  @override
  String get plgFfmpegInstance => '设备内处理';

  @override
  String get plgModelNotConfigured => '未配置模型或密钥';

  @override
  String get plgNoSources => '此构建未接入媒体来源';

  @override
  String get plgNoAsr => '此构建未接入语音识别';

  @override
  String plgModelDetail(String model) {
    return '模型 $model';
  }

  @override
  String get plgLocalAsrUnavailable => '本地识别引擎不可用';

  @override
  String get errTmdbTokenRequired => '请配置 TMDB 读取访问令牌';

  @override
  String get errQueryCancelled => '查询已取消';

  @override
  String get errTmdbResponseTooLarge => 'TMDB 响应过大';

  @override
  String get errTmdbAuth => 'TMDB 认证失败，请更新令牌';

  @override
  String get errTmdbNotFound => 'TMDB 对象不存在';

  @override
  String get errTmdbRateLimited => 'TMDB 请求受限，请稍后重试';

  @override
  String get errTmdbUnavailable => 'TMDB 暂时不可用';

  @override
  String get errTmdbRequestFailed => 'TMDB 请求失败';

  @override
  String get errTmdbInvalidResponse => 'TMDB 响应格式无效';

  @override
  String get errTmdbUnreachable => '无法连接 TMDB，请检查网络';

  @override
  String get errTmdbNoAttachments => 'TMDB 不读取来源附件';

  @override
  String get errTmdbInvalidIds => 'TMDB ID 或季集编号无效';

  @override
  String get errIdentifySeriesFirst => '请先识别剧集，再选择季集';

  @override
  String get errTmdbRefRequired => '详情需要 TMDB 引用';

  @override
  String get errTmdbInvalidIdentity => 'TMDB 对象身份或标题无效';

  @override
  String get errNfoRefRequired => 'NFO 详情需要附件引用';

  @override
  String get errNfoParse => 'NFO 解析失败';

  @override
  String get errNfoTooLarge => 'NFO 超过 1 MiB';

  @override
  String get errNfoDtd => 'NFO 不允许 DTD 或实体声明';

  @override
  String get errNfoTooManyNodes => 'NFO 节点过多';

  @override
  String get errNfoTooDeep => 'NFO 嵌套过深';

  @override
  String get errNfoType => '不支持的 NFO 对象类型';

  @override
  String get errNfoFieldTooLong => 'NFO 字段过长';

  @override
  String get errInvalidMetadataQuery => '无效的元数据查询参数';

  @override
  String get errMetadataQueryUnsupported => '此元数据实例不支持该查询';

  @override
  String get errMediaKindUnsupported => '不支持此媒体类型的影视信息';

  @override
  String get errBackgroundIdentify => '后台识别失败';

  @override
  String get errQueryStale => '查询已过期或已取消';

  @override
  String get errTmdbConfigChanged => 'TMDB 配置已改变';

  @override
  String get errRequeryCandidates => '请重新查询候选';

  @override
  String get errChooseEpisodeFirst => '请先选择具体季集';

  @override
  String get errCandidateNotThisQuery => '候选不属于此查询';

  @override
  String get errDetailIdentityMismatch => '详情身份不匹配';

  @override
  String get errReloadCandidates => '请重新加载候选';

  @override
  String get errInvalidLocalCandidate => '无效的本地候选';

  @override
  String get errChooseSeriesFirst => '请先选择剧集';

  @override
  String get errConfirmMatchFirst => '请先确认匹配';

  @override
  String get errCatalogTooLarge => '目录过大，请缩小元数据范围';

  @override
  String get errCursorStuck => '分页游标未前进';

  @override
  String get errEpisodeSeasonMissing => '单集所属季不存在';

  @override
  String get errSourceConfigChanged => '来源配置已改变';

  @override
  String get errInvalidYear => '年份无效';

  @override
  String get catSourceBrowse => '浏览目录';

  @override
  String get catSourceBrowseDesc => '列出该来源的文件夹与文件';

  @override
  String get catSourceResolve => '播放';

  @override
  String get catSourceResolveDesc => '把选中的资源交给播放器；严格绑定资源所属实例';

  @override
  String get catSourceAttachments => '读取附件';

  @override
  String get catSourceAttachmentsDesc => '读取 NFO、外挂字幕等小文件（有大小上限）';

  @override
  String get catSearchMedia => '搜索媒体';

  @override
  String get catSearchMediaDesc => '在服务端搜索影片与剧集';

  @override
  String get catMetadataLookup => '影视信息';

  @override
  String get catMetadataLookupDesc => '读取媒体服务器整理好的影视信息';

  @override
  String get catSourceWrite => '写入新文件';

  @override
  String get catSourceWriteDesc =>
      '把 App 生成的片段写到同一共享的 OpenPlayX 文件夹；不覆盖、不删除，每次需确认';

  @override
  String get catSummaryLocal => '本机或已挂载的文件夹';

  @override
  String get catSummarySmb => 'Windows 共享、NAS 的 SMB 共享目录';

  @override
  String get catSummaryWebdav => 'WebDAV 网盘或 NAS 目录';

  @override
  String get catSummaryFtp => 'FTP 服务器目录';

  @override
  String get catSummarySftp => '通过 SSH 访问的服务器目录';

  @override
  String get catSummaryS3 => 'S3 兼容对象存储桶';

  @override
  String get catSummaryPlex => 'Plex 媒体服务器';

  @override
  String get catSummaryJellyfin => 'Jellyfin 媒体服务器';

  @override
  String get catSummaryEmby => 'Emby 媒体服务器';

  @override
  String get catSummaryDlna => '局域网 DLNA 媒体服务器';

  @override
  String get catDataLocal => '只读取你授权的文件夹。';

  @override
  String get catDataRemote =>
      'App 在本机连接你配置的服务器；文件名和目录名会出现在 AI 对话中（仅当允许 AI 使用时）。';

  @override
  String get catNfoName => 'NFO 元数据';

  @override
  String get catNfoSummary => '读取媒体旁边的 .nfo 文件';

  @override
  String get catNfoToggle => '由“刮削管理”控制是否刮削；后台刮削独立运行，暂不支持单独停用。';

  @override
  String get catNfoCap => '本地元数据';

  @override
  String get catNfoCapDesc => '按邻近文件规则匹配影片信息';

  @override
  String get catTmdbSummary => '从 The Movie Database 查询影片与剧集信息';

  @override
  String get catTmdbToggle => '清除访问令牌即停止使用；后台刮削独立运行，暂不支持单独停用。';

  @override
  String get catTmdbData => '查询时向 TMDB 发送解析出的片名与年份，不发送文件内容。';

  @override
  String get catTmdbCap => '查询元数据';

  @override
  String get catTmdbCapDesc => '搜索、匹配影片与剧集信息；写入由宿主完成';

  @override
  String get catFfmpegName => 'FFmpeg 媒体处理';

  @override
  String get catFfmpegSummary => '截图、探测、转码与音频提取';

  @override
  String get catFfmpegData => '在本机处理媒体，产物保存在应用目录。';

  @override
  String get catProbe => '探测';

  @override
  String get catProbeDesc => '读取时长、编码与音轨';

  @override
  String get catTranscode => '转码';

  @override
  String get catTranscodeDesc => '按预设转码为新文件';

  @override
  String get catExtractAudio => '提取音频';

  @override
  String get catExtractAudioDesc => '导出音轨用于识别或保存';

  @override
  String get catSnapshot => '截图';

  @override
  String get catSnapshotDesc => '截取指定时间的画面';

  @override
  String get catAsrName => '语音识别';

  @override
  String get catAsrSummary => '为视频生成原语言字幕与转录';

  @override
  String get catAsrCapDesc => '生成原语言字幕/转录；不包含翻译';

  @override
  String get catLlmName => '对话模型';

  @override
  String get catLlmSummary => '为 AI 助手提供大语言模型';

  @override
  String get catLlmToggle => '在“AI 与模型”中配置或清除模型；不会生成可递归调用自身的推理工具。';

  @override
  String get catLlmData => '对话内容、页面摘要与工具结果会发送给所配置的模型服务，可能产生费用。';

  @override
  String get catLlmCap => '对话推理';

  @override
  String get catLlmCapDesc => '为 AI 助手生成回复与工具调用';

  @override
  String get catCategorySource => '媒体来源';

  @override
  String get catCategoryMetadata => '元数据';

  @override
  String get catCategoryMediaProcessing => '媒体处理';

  @override
  String get catCategorySpeech => '字幕识别';

  @override
  String get catLocationNetwork => '网络存储';

  @override
  String get catLocationSelfHosted => '自建服务';

  @override
  String get catLocationCloudApi => '云 API';

  @override
  String get webSearchPresetName => '联网搜索';

  @override
  String get errAssistantConfig =>
      '请填写有效的 HTTPS API 基址（本机服务可用 http，例如 http://localhost:11434/v1）、模型和输出上限（128–16384）';

  @override
  String get errExtRootAddress => '请输入服务根地址，例如 https://bt.example.com';

  @override
  String get errExtHttpsRequired => '公网地址必须使用 HTTPS；HTTP 仅允许局域网或本机地址';

  @override
  String get errExtTokenRequired => '请填写访问令牌';

  @override
  String get errExtTimeout => '连接超时';

  @override
  String get errExtUnreachable => '无法连接到这个地址';

  @override
  String get errExtTls => 'TLS 证书校验失败';

  @override
  String get errExtTooLarge => '服务返回的数据过大';

  @override
  String errExtRejected(String reason) {
    return '服务拒绝了请求：$reason';
  }

  @override
  String errExtError(String code) {
    return '服务返回错误（$code）';
  }

  @override
  String get errExtTokenInvalid => '访问令牌无效';

  @override
  String get errExtNoMcp => '这个地址没有提供 MCP 入口';

  @override
  String get errArtworkCancelled => '图片加载已取消';

  @override
  String get errArtworkQuota => '图片缓存额度不足';

  @override
  String get errArtworkUnauthorized => '图片地址未经授权';

  @override
  String get errArtworkTypeSize => '图片类型或大小无效';

  @override
  String get errArtworkEmptyOrLarge => '图片为空或过大';

  @override
  String get errArtworkContentType => '不支持的图片内容类型';

  @override
  String get errArtworkDecodeSize => '图片解码尺寸过大';

  @override
  String get errArtworkWait => '请等待图片加载完成';

  @override
  String get errLibraryClosing => '媒体库正在关闭';

  @override
  String get errNameRequired => '请输入名称';

  @override
  String get errSeasonCycle => '来源返回了循环季集关系';

  @override
  String get errInvalidPagingShort => '无效分页';

  @override
  String get errTitleRequired => '请输入标题';

  @override
  String get errScanRunning => '扫描已在运行';

  @override
  String get errFileSourceMissing => '文件源不存在';

  @override
  String get errFileSourceDisabled => '文件源已停用';

  @override
  String get errSourceScanDisabled => '来源未启用扫描';

  @override
  String get errScanTooLarge => '扫描范围过大，请缩小范围';

  @override
  String get errScanBindingChanged => '来源或绑定已变更，请重新扫描';

  @override
  String get errSourceIdentityMismatch => '来源身份不匹配';

  @override
  String get errSourceCursorStuck => '来源分页游标未前进';

  @override
  String get errScanIncomplete => '扫描未完成，请检查来源后重试';

  @override
  String get aiToolContextGet => '读取当前页面';

  @override
  String get aiToolSourceList => '列出媒体来源';

  @override
  String get aiToolSourceBrowse => '浏览文件夹';

  @override
  String get aiToolLibraryQuery => '查询媒体库';

  @override
  String get aiToolMediaGet => '查看媒体详情';

  @override
  String get aiToolSearchMedia => '搜索媒体';

  @override
  String get aiToolProgressQuery => '查看观看进度';

  @override
  String get aiToolPlaybackGet => '读取播放状态';

  @override
  String get aiToolPlaybackOpen => '打开播放';

  @override
  String get aiToolPlaybackPause => '暂停';

  @override
  String get aiToolPlaybackResume => '继续播放';

  @override
  String get aiToolPlaybackStop => '停止播放';

  @override
  String get aiToolPlaybackSeek => '跳转';

  @override
  String get aiToolPlaybackSetSpeed => '设置倍速';

  @override
  String get aiToolPlaybackSetVolume => '设置音量';

  @override
  String get aiToolPlaybackSetSubtitle => '设置字幕';

  @override
  String get aiToolMediaProcessingCapabilities => '查询媒体处理能力';

  @override
  String get aiToolMediaProbe => '分析媒体';

  @override
  String get aiToolMediaTranscode => '转码 / 截取片段';

  @override
  String get aiToolMediaExtractAudio => '提取音频';

  @override
  String get aiToolMediaSnapshot => '截图';

  @override
  String get aiToolMediaSaveToSource => '存回媒体来源';

  @override
  String get aiToolTaskGet => '查询处理任务';

  @override
  String get aiToolTaskList => '列出处理任务';

  @override
  String get aiToolTaskCancel => '取消处理任务';

  @override
  String get aiToolTaskRetry => '重试处理任务';

  @override
  String get aiToolSpeechRecognitionStatus => '查询语音识别状态';

  @override
  String get aiToolSubtitleGenerate => '识别字幕';

  @override
  String get aiToolTranscriptGenerate => '生成转录';

  @override
  String get aiToolSubtitleTaskGet => '查询字幕任务';

  @override
  String get aiToolSubtitleTaskCancel => '取消字幕任务';

  @override
  String get aiToolSubtitleSave => '保存字幕';

  @override
  String get aiToolPluginStatus => '查看插件状态';

  @override
  String get aiToolMcpTavilyWebSearch => '联网搜索';

  @override
  String get aiToolWebFetch => '读取网页';

  @override
  String get aiArgQuery => '关键词';

  @override
  String get aiArgUrl => '网址';

  @override
  String get aiArgRange => '范围';

  @override
  String get aiArgEnd => '结尾';

  @override
  String get aiArgWholeMedia => '整部';

  @override
  String get aiArgTime => '时间';

  @override
  String get aiArgPosition => '位置';

  @override
  String get aiArgPreset => '预设';

  @override
  String get aiArgLanguage => '语言';

  @override
  String get aiArgFormat => '格式';

  @override
  String get aiArgSpeed => '倍速';

  @override
  String get aiArgVolume => '音量';

  @override
  String get aiArgSwitch => '开关';

  @override
  String get aiArgOff => '关闭';

  @override
  String get aiArgWait => '等待';

  @override
  String get aiToolInput => '输入';

  @override
  String get aiToolOutput => '输出';

  @override
  String get aiActivityThinking => '正在思考';

  @override
  String get aiActivityAnswering => '正在回复';

  @override
  String get aiActivityRunningDefault => '运行中';

  @override
  String get aiReasoningStreaming => '思考中…';

  @override
  String get aiReasoningDone => '已思考';

  @override
  String get aiReasoningUnderSecond => '思考了不到 1 秒';

  @override
  String get aiStillRunning => '等待超时，任务仍在后台运行（未失败、未停止）';

  @override
  String get aiStatusQueued => '排队中';

  @override
  String get aiStatusPreparing => '准备中';

  @override
  String get aiStatusRunning => '处理中';

  @override
  String get aiStatusCancelling => '取消中';

  @override
  String get aiStatusSucceeded => '已完成';

  @override
  String get aiStatusFailed => '失败';

  @override
  String get aiStatusCancelled => '已取消';

  @override
  String get aiStatusInterrupted => '已中断';

  @override
  String get aiStageExtracting => '提取音频';

  @override
  String get aiStageUploading => '上传';

  @override
  String get aiStageQueued => '排队';

  @override
  String get aiStageTranscribing => '识别';

  @override
  String get aiStageFormatting => '整理字幕';

  @override
  String aiArgWaitValue(String seconds) {
    return '最多等 ${seconds}s';
  }

  @override
  String aiStepPreparing(String name) {
    return '准备调用 $name…';
  }

  @override
  String aiStepRunning(String name) {
    return '正在执行 $name…';
  }

  @override
  String aiStepWaiting(String name) {
    return '允许执行 $name？';
  }

  @override
  String aiStepFailed(String name) {
    return '$name 失败';
  }

  @override
  String aiStepCancelled(String name) {
    return '已取消 $name';
  }

  @override
  String aiShowAll(int count) {
    return '显示全部（$count 个字符）';
  }

  @override
  String aiActivityPreparingTool(String name) {
    return '准备调用：$name';
  }

  @override
  String aiActivityTool(String name) {
    return '正在执行：$name';
  }

  @override
  String aiActivityConfirm(String name) {
    return '等待你确认：$name';
  }

  @override
  String aiStepNumber(int step) {
    return '第 $step 步';
  }

  @override
  String aiReasoningSeconds(int seconds) {
    return '思考了 $seconds 秒';
  }

  @override
  String aiReasoningMinutes(int minutes) {
    return '思考了 $minutes 分钟';
  }

  @override
  String get cloudJianguoyun => '坚果云';

  @override
  String get cloud123 => '123 云盘';

  @override
  String get cloudJianguoyunHelp => '使用账号和第三方应用密码，可调整默认 WebDAV 目录。';

  @override
  String get cloud123Help => '先确认 123 账号具备 WebDAV 权益，填写官方后台提供的地址和凭据；可用性取决于套餐。';

  @override
  String get cloudPreset => 'WebDAV 预设';

  @override
  String get cloudCustom => '自定义 WebDAV';

  @override
  String get catSummaryCloudDrive => '浏览和播放云盘文件。';

  @override
  String get cloudSignIn => '使用浏览器登录';

  @override
  String get cloudSignInHelp =>
      '仅读取文件，请在下方选择根目录。断开 OneDrive 后，还需到微软账号权限页面解除应用授权。';

  @override
  String get cloudNotConfigured => '此构建尚未配置云盘登录，需由发布者配置 OAuth 应用。';

  @override
  String get cloudSignInFailed => '云盘授权失败，请重试。';

  @override
  String get cloudCallbackInvalid => '无法验证授权回调。';

  @override
  String get cloudRoot => '已选根目录';

  @override
  String get cloudRootHelp => '打开文件夹即可选为根目录，仅浏览和扫描此目录下的文件。';

  @override
  String get cloudReauthorize => '授权已过期或撤销，请重新登录。';

  @override
  String get cloudPersonalOnly => '目前仅支持个人 OneDrive 账号。';

  @override
  String get cloudDisconnect => '断开账号';

  @override
  String get cloudDisconnectHelp =>
      '清除本地凭据并停止云盘请求。还需在微软或 Dropbox 账号权限页面移除此应用，以解除平台授权。';
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
  String get plugins => 'AI';

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
  String get retry => '重試';

  @override
  String get cancel => '取消';

  @override
  String get aiSettingsSaved => '已儲存。';

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
  String get saving => '正在儲存…';

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
    return '此檔案來源關聯 $count 項內容。刪除後，只由它掃描到的檔案記錄、播放進度和刮削資訊會一併刪除；其他檔案來源也掃描到的內容會保留。儲存空間上的原始檔案不受影響。';
  }

  @override
  String disableSourceDescription(int playing, int running) {
    return '目前播放 $playing 個，進行中請求 $running 個。停用後拒絕新請求；目前播放可繼續，結束後釋放連線。設定、收藏和產物保留。';
  }

  @override
  String deleteSourceDescription(int fileSources, int playing, int running) {
    return '刪除此連線的設定與憑證，並刪除其下的 $fileSources 個檔案來源及其掃描到的內容（檔案記錄、播放進度、刮削資訊）。儲存空間上的原始檔案不受影響。目前播放 $playing 個、進行中請求 $running 個可完成，之後釋放連線。';
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
    return '$speed MB/s';
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
  String get detailExtras => '花絮';

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
  String get aiTextToolCall => '模型在重試後仍把工具呼叫輸出為文字，工具未執行。請檢查模型及端點是否支援工具呼叫。';

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
  String get artworkCacheLimit => '圖片快取上限';

  @override
  String get artworkCacheLimitDescription =>
      '海報、背景圖和演職人員照片。達到上限時先刪除最早下載的圖片，已鎖定的圖片不會刪除。';

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
  String get aiConnectionOkNoTools => '連線成功，工具呼叫測試未通過；實際任務仍會嘗試呼叫已註冊的工具。';

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
  String get asrSaved => '已儲存，可在播放時的字幕清單中選擇（標記為「辨識」）。';

  @override
  String get asrSavedPartial => '已儲存（部分區間），可在播放時的字幕清單中選擇（標記為「辨識」）。';

  @override
  String get asrSaveHint => '未儲存的結果離開頁面後清除；儲存會新增一筆字幕記錄，不取代既有字幕，也不會自動影響播放。';

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
  String get asrServiceUrl => '服務位址';

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

  @override
  String get embeddedSubtitles => '內嵌字幕';

  @override
  String get externalSubtitles => '外部字幕';

  @override
  String get recognizedSubtitles => '辨識字幕';

  @override
  String get recognizedSubtitleBadge => '辨識';

  @override
  String recognizedSubtitleTitle(String time) {
    return '儲存於 $time';
  }

  @override
  String recognizedSubtitlePartial(String start, String end) {
    return '部分 $start–$end';
  }

  @override
  String get recognizedSubtitleFull => '整集';

  @override
  String get addSourceConnection => '新增連線';

  @override
  String get sourcesDescription => '連接你的儲存空間，整理你的媒體。';

  @override
  String sourceActions(String name) {
    return '$name的操作';
  }

  @override
  String get browseSourceFiles => '瀏覽檔案';

  @override
  String get sourceAwaitingVerification => '待驗證';

  @override
  String sourceFileCount(int count) {
    return '$count 個檔案來源';
  }

  @override
  String get sourceRootFolder => '根目錄';

  @override
  String get rescanFileSource => '重新掃描';

  @override
  String plAbASet(String time) {
    return '已設定 A 點 $time';
  }

  @override
  String get plAbClear => '清除 A-B 循環';

  @override
  String get plAbCleared => '已清除 A-B 循環';

  @override
  String get plAbLoop => 'A-B 循環';

  @override
  String plAbLooping(String a, String b) {
    return '循環 $a – $b';
  }

  @override
  String get plAbSetA => '設定 A 點';

  @override
  String get plAbSetB => '設定 B 點';

  @override
  String get plAdvancedTools => '進階工具列';

  @override
  String get plAspectDefault => '預設';

  @override
  String get plAspectRatio => '長寬比';

  @override
  String get plAudioDelay => '音訊延遲';

  @override
  String plBoosting(String speed) {
    return '$speed 快轉中 · 放開恢復';
  }

  @override
  String get plDelayHint => '正值表示聲音或字幕延後。';

  @override
  String get plExitFullscreen => '結束全螢幕';

  @override
  String get plFaster => '加速';

  @override
  String get plFitBest => '最佳適配';

  @override
  String get plFitFill => '填滿';

  @override
  String get plFitMode => '畫面尺寸';

  @override
  String get plFitOriginal => '原始尺寸';

  @override
  String get plFullscreen => '全螢幕';

  @override
  String get plGo => '跳轉';

  @override
  String get plInfo => '資訊';

  @override
  String get plInfoDuration => '時長';

  @override
  String get plInfoResolution => '解析度';

  @override
  String get plInfoTitle => '標題';

  @override
  String get plJumpBackMedium => '倒退 1 分鐘';

  @override
  String get plJumpExtraShort => '跳轉 3 秒';

  @override
  String get plJumpForwardMedium => '前進 1 分鐘';

  @override
  String get plJumpLong => '跳轉 5 分鐘';

  @override
  String plJumpSeconds(String seconds) {
    return '$seconds 秒';
  }

  @override
  String get plJumpToTime => '跳到時間';

  @override
  String get plJumpToTimeInvalid => '請輸入如 1:23:45 或 12:30 的時間。';

  @override
  String get plLoadSubtitle => '載入外部字幕…';

  @override
  String get plLockShort => '鎖定';

  @override
  String get plMediaInfo => '媒體資訊';

  @override
  String get plMenuAudio => '音訊';

  @override
  String get plMenuPlayback => '播放';

  @override
  String get plMenuSubtitle => '字幕';

  @override
  String get plMenuVideo => '影片';

  @override
  String get plMenuView => '檢視';

  @override
  String get plMute => '靜音';

  @override
  String get plMuted => '已靜音';

  @override
  String get plNextAudioTrack => '下一音軌';

  @override
  String get plNextSubtitle => '下一字幕';

  @override
  String get plNormalSpeed => '恢復正常速度';

  @override
  String get plOrientationShort => '方向';

  @override
  String get plPicture => '畫面';

  @override
  String get plPictureAndSound => '畫面與聲音';

  @override
  String get plRepeatMode => '重複模式';

  @override
  String get plRepeatOff => '不重複';

  @override
  String get plRepeatOne => '單項循環';

  @override
  String get plReset => '重設';

  @override
  String get plSettingsAndEffects => '設定與效果';

  @override
  String get plShortcuts => '快捷鍵';

  @override
  String get plShowPosition => '顯示目前位置';

  @override
  String get plSleepEndOfItem => '本集結束後';

  @override
  String get plSleepFinished => '睡眠定時已暫停播放';

  @override
  String plSleepMinutes(int minutes) {
    return '$minutes 分鐘';
  }

  @override
  String get plSleepOff => '關閉';

  @override
  String get plSleepShort => '睡眠';

  @override
  String get plSleepTimer => '睡眠定時';

  @override
  String get plSlideToUnlock => '向右滑動解鎖';

  @override
  String get plSlower => '減速';

  @override
  String get plSnapshot => '截圖';

  @override
  String get plSnapshotFailed => '截圖儲存失敗';

  @override
  String plSnapshotSaved(String path) {
    return '截圖已儲存：$path';
  }

  @override
  String get plSpeedShort => '倍速';

  @override
  String get plStatistics => '統計資訊';

  @override
  String get plStatsAudio => '音訊區塊 播放/遺失';

  @override
  String get plStatsDemux => '解多工位元率';

  @override
  String get plStatsFrames => '影格 顯示/遺失';

  @override
  String get plStatsInput => '輸入位元率';

  @override
  String get plStatsOverlay => '統計浮層';

  @override
  String get plStatsRead => '讀取速度';

  @override
  String get plStop => '停止';

  @override
  String get plSubtitleDelay => '字幕延遲';

  @override
  String get plSync => '同步';

  @override
  String get plTimeTooltip => '按一下切換剩餘時間，按兩下跳到時間';

  @override
  String get plToggleControls => '顯示/隱藏控制層';

  @override
  String get plToggleSubtitles => '字幕開關';

  @override
  String get plTrackAudio => '音訊';

  @override
  String get plTracks => '音軌與字幕';

  @override
  String get plTracksShort => '音軌字幕';

  @override
  String get plTrackSubtitle => '字幕';

  @override
  String get plTrackVideo => '影片';

  @override
  String get plUnsupported => '目前播放器不支援';

  @override
  String get plZoom => '縮放';

  @override
  String get plZoomOriginal => '原始';

  @override
  String get plMenuPlaybackControl => '播放控制';

  @override
  String plBoostingShort(String speed) {
    return '$speed 快轉中';
  }

  @override
  String get plSwipeUpToLock => '上滑鎖定';

  @override
  String plSpeedLocked(String speed) {
    return '已鎖定 $speed';
  }

  @override
  String get plExternalSubtitleShort => '+ 外部字幕';

  @override
  String get listSeparator => '、';

  @override
  String get remoteAccess => '遠端存取';

  @override
  String get remoteHomeAndRoutes => '家庭與連線路線';

  @override
  String get remoteImportTitle => '匯入遠端設定';

  @override
  String get remoteImportFooter => '貼上 Relay 匯出的 App 設定，匯入後立即生效。';

  @override
  String get remoteImportPlaceholder => 'App 設定 JSON';

  @override
  String get remoteImport => '匯入';

  @override
  String get remoteImporting => '正在匯入…';

  @override
  String get remoteImported => '已匯入並生效。';

  @override
  String get remoteClearConfirmTitle => '清除遠端設定？';

  @override
  String get remoteClearConfirmMessage => '清除本機的遠端設定與憑證，重新匯入後可恢復遠端存取。';

  @override
  String get remoteClear => '清除';

  @override
  String get remoteClearing => '正在清除…';

  @override
  String get remoteCleared => '已清除遠端設定。';

  @override
  String get remoteNotImported => '尚未匯入';

  @override
  String get remoteNotImportedHint => '點選「匯入」新增遠端設定。';

  @override
  String get remoteServerName => '伺服器名稱';

  @override
  String get remoteCredentials => '認證憑證';

  @override
  String get remoteCredentialsSecure => '已儲存在系統安全儲存區';

  @override
  String get remoteProxyUnused => '未被來源使用';

  @override
  String remoteProxyUsedBy(String sources) {
    return '來源：$sources';
  }

  @override
  String remoteProxyPort(int port) {
    return '連接埠 $port';
  }

  @override
  String get remoteRelayServer => '中繼伺服器';

  @override
  String get remoteRelayFooter => '整個 App 共用此連線；認證憑證儲存在系統安全儲存區。';

  @override
  String get remoteAvailableServices => '可用服務';

  @override
  String get remoteAvailableServicesFooter =>
      '由 Home 註冊在 Relay 上。來源在「編輯來源 → 家庭遠端存取」中選擇其中一個。';

  @override
  String get remoteNeedsAttention => '需要處理';

  @override
  String remoteSourceProxyMissing(String proxy) {
    return '使用的 proxy「$proxy」不在目前設定中，遠端連線無法使用。';
  }

  @override
  String get statusConfigured => '已設定';

  @override
  String get statusNotConfigured => '未設定';

  @override
  String get statusAvailable => '可用';

  @override
  String get statusUnavailable => '無法使用';

  @override
  String get plgGroupModel => '模型';

  @override
  String get plgGroupExternal => '外部能力';

  @override
  String get plgGroupBuiltIn => '內部能力';

  @override
  String get plgGroupModelDescription => '設定 Agent 使用的模型';

  @override
  String get plgGroupExternalDescription => '自架或雲端服務，由你新增';

  @override
  String get plgGroupBuiltInDescription => '隨 App 提供，預設全部開放';

  @override
  String plgCount(int count) {
    return '$count 項';
  }

  @override
  String extToolCount(int count) {
    return '$count 個工具';
  }

  @override
  String plgInstanceCount(int count) {
    return '$count 個實例';
  }

  @override
  String get plgExternalHint => '填寫位址和權杖，自動識別並設定服務';

  @override
  String get plgExternalEmpty => '還沒有設定外部服務';

  @override
  String get extConfigureTitle => '設定外部能力';

  @override
  String plgBuiltInHint(int count) {
    return '隨 App 提供 $count 項，預設全部開放，無需逐項啟用';
  }

  @override
  String plgGroupEmpty(String group) {
    return '暫無$group';
  }

  @override
  String get plgNoAssistant => '此版本未接入 AI 助理';

  @override
  String get plgSelectForDetail => '選擇一項檢視詳細資訊';

  @override
  String get plgDeviceUnsupported => '目前裝置不支援';

  @override
  String get plgTemporarilyUnavailable => '暫時無法使用';

  @override
  String get plgDisabled => '外掛已停用';

  @override
  String plgDisableConfirmTitle(String name) {
    return '停用「$name」？';
  }

  @override
  String get plgImpactIntro => '停用後立即阻止新的呼叫；實例設定、已產生的字幕和歷史記錄都會保留。';

  @override
  String plgImpactPlaying(int count) {
    return '$count 個正在播放的工作階段會持續到播放結束後再釋放連線。';
  }

  @override
  String plgImpactRunning(int count) {
    return '$count 個進行中的請求會在完成後釋放。';
  }

  @override
  String plgImpactInstances(String instances) {
    return '受影響的實例：$instances。';
  }

  @override
  String get actionFailedRetry => '操作失敗，請重試。';

  @override
  String get plgUnavailableReason => '無法使用的原因';

  @override
  String get plgSwitch => '外掛開關';

  @override
  String get plgSwitchOn => '允許承接新的業務呼叫';

  @override
  String get plgSwitchOff => '已阻止新的呼叫；實例設定保留';

  @override
  String get settingsCapabilities => '基礎能力';

  @override
  String get capabilitySwitchesFooter =>
      '關閉的能力在整個 App 中都不再承接新的呼叫，AI 也無法使用；既有設定會保留。';

  @override
  String capabilityNeeds(String name) {
    return '需要先開啟「$name」';
  }

  @override
  String get plgCapabilitySwitch => '基礎能力開關';

  @override
  String get plgCapabilitySwitchHint => '在「設定 → 基礎能力」中開關，對整個 App 生效';

  @override
  String get capabilityOn => '已開啟';

  @override
  String get capabilityOff => '已關閉';

  @override
  String get plgLocation => '執行位置';

  @override
  String get plgLocationDevice => '在本機執行';

  @override
  String get plgLocationNetwork => 'App 在本機連線你設定的儲存服務';

  @override
  String get plgLocationSelfHosted => 'App 在本機執行轉接器，實際工作在你設定的伺服器上進行';

  @override
  String get plgLocationCloudApi => 'App 在本機呼叫雲端 API';

  @override
  String get plgDependencies => '相依項目';

  @override
  String plgDependency(String name, String status) {
    return '$name（$status）';
  }

  @override
  String get plgCapabilities => '能力';

  @override
  String get plgCapabilitiesFooter => '只列出此外掛實際實作的方法；未實作的能力不會顯示。';

  @override
  String plgInstancesTitle(int count) {
    return '實例（$count 個）';
  }

  @override
  String plgInstanceBusy(int playing, int running) {
    return '使用中：播放 $playing · 請求 $running';
  }

  @override
  String get plgNoInstances => '暫無實例';

  @override
  String get plgOpenSettings => '開啟設定';

  @override
  String get plgRuntime => '執行狀態與診斷';

  @override
  String plgRevisions(String saved, String applied) {
    return '已儲存修訂 $saved · 實際生效 $applied';
  }

  @override
  String get plgNotApplied => '尚未生效';

  @override
  String get plgPendingApply => '新設定待生效，舊修訂仍在服務進行中的呼叫';

  @override
  String plgActivity(int playing, int running) {
    return '活動播放 $playing · 進行中請求 $running';
  }

  @override
  String plgLastError(String code) {
    return '最近錯誤：$code';
  }

  @override
  String get plgRefreshStatus => '重新整理狀態';

  @override
  String get plgCopyDiagnostics => '複製去識別化診斷資訊';

  @override
  String get plgCopyDiagnosticsHint => '不含位址、帳號、路徑或金鑰';

  @override
  String get plgDiagnosticsCopied => '已複製診斷資訊';

  @override
  String get extConnectionOk => '連線正常';

  @override
  String extRemoveConfirmTitle(String name) {
    return '移除「$name」？';
  }

  @override
  String get extRemoveConfirmMessage => '只移除 App 中的位址和權杖，不會影響伺服器上的資料。';

  @override
  String get extNeedsRecheck => '需要重新偵測';

  @override
  String extToolAiUnavailable(String problem) {
    return 'AI 暫時無法使用：$problem';
  }

  @override
  String get extToolNeedsConfirm => '呼叫前需要你確認';

  @override
  String get extAiServiceUnavailable => '服務目前無法使用，AI 暫時無法呼叫';

  @override
  String get extAiNeedsRecheck => '請點「重新偵測」以取得工具定義';

  @override
  String extAiSummary(int usable, int total) {
    return 'AI 可直接呼叫 $usable / $total 個工具；會改變狀態的操作會先請你確認';
  }

  @override
  String get extRemoved => '這個外部能力已移除';

  @override
  String extVersion(String version) {
    return '版本 $version';
  }

  @override
  String get extAiCalls => 'AI 呼叫';

  @override
  String extToolsTitle(int count) {
    return '工具（$count 個）';
  }

  @override
  String get extNoTools => '沒有工具';

  @override
  String get extRecheck => '重新偵測';

  @override
  String get extConnecting => '正在連線並識別…';

  @override
  String extAdded(String name) {
    return '已新增「$name」';
  }

  @override
  String get extConfigureFooter =>
      '填寫服務位址和存取權杖，App 會透過 MCP 連線，讀取它是什麼服務、提供哪些工具。';

  @override
  String get extServiceAddress => '服務位址';

  @override
  String get extAccessToken => '存取權杖';

  @override
  String get extNameOptional => '名稱（選填）';

  @override
  String get extDetected => '識別結果';

  @override
  String get extTools => '工具';

  @override
  String get extConnect => '連線並識別';

  @override
  String get scanStatusPending => '待掃描';

  @override
  String get scanStatusScanning => '掃描中';

  @override
  String get scanStatusDone => '掃描完成';

  @override
  String get scanStatusFailed => '掃描失敗';

  @override
  String get scanStatusInterrupted => '掃描中斷';

  @override
  String get scanRescanHint => '請重新掃描';

  @override
  String get libraryDbTooNew => '媒體庫版本較新，請更新 App';

  @override
  String get errConfigUnknownFields => '設定包含未知欄位，原始設定必須保留。';

  @override
  String get errRemoteKinds => '目前遠端存取支援 Jellyfin、Emby、Plex 和 SMB。';

  @override
  String get errRemoteProtocolMismatch => '遠端服務協定不相符；SMB 目前僅支援遠端模式。';

  @override
  String get errConfigVersionNoOverwrite => '設定版本不相容，無法覆寫儲存。';

  @override
  String get errAddressRequired => '請填寫位址。';

  @override
  String get errTimeoutConcurrency => '請求逾時須為 1–120 秒，並行數須為 1–8。';

  @override
  String get errScopeCount => '至少設定一個存取範圍，範圍和排除項最多各 100 條。';

  @override
  String get errScopeRelative => '存取範圍和排除項須為根目錄內的相對路徑，不允許 .. 或絕對路徑。';

  @override
  String get errBrowseModeUnsupported => '此外掛不支援該瀏覽方式。';

  @override
  String get errNoSearchIndex => '此外掛尚未提供搜尋或背景索引能力。';

  @override
  String get errLibraryNoDirPolicy => '媒體庫來源暫不支援檔案目錄策略。';

  @override
  String get errChooseLocalFolder => '請選擇本機資料夾。';

  @override
  String get errAddressRelativeSegments => '位址不能包含相對路徑片段。';

  @override
  String get errInvalidServerAddress => '請輸入有效的伺服器位址，憑證請填在獨立欄位。';

  @override
  String get errSmbAddressFormat => 'SMB 使用標準 445 連接埠：smb://主機/共用名稱/選用目錄。';

  @override
  String errUserIdRequired(String kind) {
    return '請填寫 $kind 使用者 ID。';
  }

  @override
  String get errSftpUsernameRequired => '請填寫 SFTP 使用者名稱。';

  @override
  String get errServerAddressRequired => '請填寫伺服器位址。';

  @override
  String get errInvalidHost => '請輸入有效的 IP、主機名稱或伺服器位址。';

  @override
  String get errPortRange => '連接埠須為 1–65535。';

  @override
  String get errSmbPort => '目前 SMB 連線使用 445 連接埠。';

  @override
  String get errPathDots => '路徑不能包含 . 或 ..。';

  @override
  String get errSignInFailed => '登入失敗，請檢查帳號和密碼或重新授權。';

  @override
  String get errAddressRedirected => '位址發生跳轉，請填寫伺服器的實際入口。';

  @override
  String get errCannotConnectService => '無法連線服務，請檢查位址和網路。';

  @override
  String get errConnectTimeout => '連線逾時，請重試。';

  @override
  String errKindUsernameRequired(String kind) {
    return '請填寫 $kind 使用者名稱。';
  }

  @override
  String get errNoValidSignIn => '伺服器未傳回有效的登入結果。';

  @override
  String get errPlexSessionExpired => '登入已過期，請重新登入 Plex。';

  @override
  String get errPlexServerUnreachable => '無法連線這台 Plex 伺服器，請確認伺服器在線上。';

  @override
  String errDlnaHttp(int status) {
    return 'DLNA 裝置請求失敗（HTTP $status）。';
  }

  @override
  String get errDlnaForeignHost => 'DLNA 裝置傳回了其他主機的位址。';

  @override
  String get errDlnaNotMediaServer => '該裝置不是媒體伺服器（沒有內容目錄服務）。';

  @override
  String get errChooseFolder => '請選擇資料夾。';

  @override
  String get untitled => '未命名';

  @override
  String get errChooseVideoOrAudio => '請選擇影片或音訊。';

  @override
  String get errNoPlayableAddress => '此項目沒有可播放的位址。';

  @override
  String get plexPartMedia => '媒體';

  @override
  String get errPathOutsideRoot => '路徑超出設定的根目錄。';

  @override
  String get errOutsideScope => '目錄不在此實例設定的存取範圍內。';

  @override
  String get errAttachmentTooLarge => '附件過大';

  @override
  String errServiceAccessDenied(String service, int status) {
    return '$service 拒絕存取（HTTP $status），請檢查使用者名稱和密碼。';
  }

  @override
  String get errFileNotFound => '檔案或資料夾不存在。';

  @override
  String errServiceRequestFailed(String service, int status) {
    return '$service 請求失敗（HTTP $status）。';
  }

  @override
  String get errFtpRefused => 'FTP 伺服器拒絕連線。';

  @override
  String get errFtpLogin => 'FTP 登入失敗，請檢查使用者名稱和密碼。';

  @override
  String get errFtpNoBinary => 'FTP 伺服器不支援二進位傳輸。';

  @override
  String get errPathChars => '路徑包含不支援的字元。';

  @override
  String get errFtpNoPassive => 'FTP 伺服器不支援被動模式。';

  @override
  String get errFolderNotFoundOrDenied => '資料夾不存在或無權存取。';

  @override
  String get errFtpList => 'FTP 無法列出資料夾。';

  @override
  String get errFtpNoResume => 'FTP 伺服器不支援續傳，無法拖曳進度。';

  @override
  String get errFtpRead => '無法讀取該 FTP 檔案。';

  @override
  String get errFtpNoSize => 'FTP 伺服器未傳回檔案大小，無法播放。';

  @override
  String get errSftpLogin => 'SFTP 登入失敗，請檢查使用者名稱和密碼。';

  @override
  String get errSftpDisabled => '伺服器未啟用 SFTP。';

  @override
  String get errPathDenied => '沒有權限存取該路徑。';

  @override
  String get errSftpRequest => 'SFTP 請求失敗。';

  @override
  String get errSftpConnect => 'SFTP 連線失敗。';

  @override
  String get errSftpPlay => '無法播放該 SFTP 檔案。';

  @override
  String get errChooseFile => '請選擇檔案。';

  @override
  String get errConnectionClosed => '連線已關閉。';

  @override
  String get errUnsafeResourceUrl => '媒體服務傳回了不安全的資源位址。';

  @override
  String errMediaServerHttp(int status) {
    return '媒體服務請求失敗（HTTP $status），請檢查位址和憑證。';
  }

  @override
  String get errServerArtworkUnavailable => '伺服器圖片無法使用';

  @override
  String get errImageTooLarge => '圖片過大';

  @override
  String get errNoPlayableVersion => '此媒體沒有可播放版本。';

  @override
  String get errReselectVersion => '請返回媒體庫重新選擇一個版本。';

  @override
  String get errServerIdentityMismatch => '伺服器物件身分不相符';

  @override
  String plexPartLabel(int index, String container) {
    return '檔案 $index · $container';
  }

  @override
  String get errNoPlayableFile => '此媒體沒有可播放檔案。';

  @override
  String get errMultiPartUnsupported => '該媒體包含多個版本或分段，暫不支援直接播放。';

  @override
  String get errMetadataNotThisServer => '中繼資料查詢不屬於此伺服器實例';

  @override
  String get errArtworkNotThisServer => '圖片不屬於此伺服器實例';

  @override
  String get srcFieldFolder => '資料夾';

  @override
  String get srcFieldWorkgroup => '工作群組（選填）';

  @override
  String get srcFieldRegion => '區域（選填）';

  @override
  String srcFieldRequired(String field) {
    return '請填寫$field。';
  }

  @override
  String get errResourceNotThisSource => '資源不屬於此媒體來源。';

  @override
  String get errOutsideAuthorizedFolder => '檔案超出已授權資料夾。';

  @override
  String get errOutsideSmbShare => '路徑超出設定的 SMB 共用。';

  @override
  String get errSmbListShares => '無法讀取共用清單，請在「進階」中填寫共用資料夾路徑後重試。';

  @override
  String get errSmbPlay => '無法播放該 SMB 檔案。';

  @override
  String get errAttachmentNotFound => '附件不存在';

  @override
  String get errInvalidFileName => '檔案名稱無效。';

  @override
  String get errUnknownWriteShare => '無法確定要寫入的共用。';

  @override
  String get errOpenPlayXFolderBlocked => '共用中已有同名檔案，無法建立 OpenPlayX 資料夾。';

  @override
  String get errTooManySameName => '同名檔案過多，請先整理 OpenPlayX 資料夾。';

  @override
  String get errTempNameConflict => '暫存檔名衝突，請重試。';

  @override
  String get errUploadIncomplete => '上傳不完整，已捨棄暫存檔。';

  @override
  String get errSmbWrite => '寫入 SMB 失敗，請確認帳號對該共用有寫入權限。';

  @override
  String get errAttachmentTypeOrLimit => '不支援的附件類型或讀取上限';

  @override
  String get errSourceMissing => '媒體來源不存在或設定不相容。';

  @override
  String get errSourceKindChange => '編輯時不能變更來源類型。';

  @override
  String get errTokenRequired => '請填寫存取權杖。';

  @override
  String get srcStatusDisabled => '已停用';

  @override
  String get srcStatusReady => '已就緒';

  @override
  String get srcStatusFailed => '連線失敗';

  @override
  String get srcStatusInitialized => '已初始化 · 待連線驗證';

  @override
  String get srcStatusSaved => '已儲存 · 下次存取生效';

  @override
  String get errArtworkCacheLimit => '不支援的圖片快取上限。';

  @override
  String get errExtensions => '副檔名只能包含字母和數字，最多 100 個。';

  @override
  String get errSourceDisabled => '媒體來源已停用，設定仍保留。';

  @override
  String get errPluginDisabled => '此外掛已停用，實例設定仍保留。';

  @override
  String get errTokenExpired => '權杖已到期，請更新憑證。';

  @override
  String get errReselectLocalFolder => '請重新選擇本機資料夾以恢復授權。';

  @override
  String get errCredentialsUnavailable => '憑證無法使用，請重新登入或更新憑證。';

  @override
  String get errInstanceChanged => '實例設定已變更，請重試。';

  @override
  String get errRequestTimedOut => '請求已逾時。';

  @override
  String get errSourceUnreachable => '無法存取媒體來源，請檢查位址、權限和憑證。';

  @override
  String get errInvalidPaging => '無效的分頁參數。';

  @override
  String get errInvalidSearchPaging => '無效的搜尋或分頁';

  @override
  String get errSearchUnsupported => '此來源不支援搜尋';

  @override
  String get errMetadataUnsupported => '此來源不支援影視資訊查詢';

  @override
  String get errAttachmentsUnsupported => '此來源不支援附件讀取';

  @override
  String get errWriteUnsupported => '此來源不支援寫入。';

  @override
  String get errWriteTimeout => '寫入逾時，伺服器上可能殘留以 .openplayx- 開頭的暫存檔。';

  @override
  String errSourceProxyMissing(String proxy) {
    return '此來源使用遠端存取 proxy「$proxy」，但目前 App 沒有該 proxy；請在 設定 → 遠端存取 匯入 Relay 的 App 設定。';
  }

  @override
  String get errReloadBeforeTest => '請重新載入設定後再測試。';

  @override
  String get errTestTimeout => '連線測試逾時。';

  @override
  String get errTestFailed => '連線測試失敗，請檢查位址、權限和憑證。';

  @override
  String get errManualScanDisabled => '此實例未啟用手動檔案掃描。';

  @override
  String get errScanLimit => '掃描上限須為 1–5000。';

  @override
  String get errScanPageLimit => '掃描達到 1000 次目錄分頁上限，請縮小存取範圍。';

  @override
  String get errScanConfigChanged => '掃描期間實例設定已變更，請重新掃描。';

  @override
  String get errTooManyQueued => '此實例排隊請求過多，請稍後重試。';

  @override
  String get credNotRequired => '無需帳號憑證';

  @override
  String get credMissing => '缺少憑證';

  @override
  String get credConfigured => '憑證已儲存 · 尚未驗證';

  @override
  String get credExpiring => '權杖將在 7 天內到期';

  @override
  String get credExpired => '權杖已到期';

  @override
  String get credRejected => '認證失敗 · 請更新憑證';

  @override
  String get credVerified => '連線已驗證';

  @override
  String get errConfigDbTooNew => '本機設定資料庫版本較新，請更新 App。';

  @override
  String get errConfigVersionKept => '設定版本不相容，原資料已保留。';

  @override
  String get errInstanceMetaMismatch => '實例設定與中繼資料不一致。';

  @override
  String get errInstanceQuarantined => '實例設定不相容或損毀，已隔離並保留原資料。';

  @override
  String get errInstanceNoOverwrite => '無法覆寫版本不相容的實例設定。';

  @override
  String get errConfigChangedElsewhereEdit => '設定已被其他視窗修改，請重新載入後編輯。';

  @override
  String get errConfigChangedDelete => '設定已更新，請重新載入後刪除。';

  @override
  String get errDefaultInstanceChanged => '預設實例設定已更新，請重新載入。';

  @override
  String get errSettingsChangedElsewhere => '設定已被其他視窗修改，請重新載入。';

  @override
  String get pickerVideoAudio => '影片和音訊';

  @override
  String get pickerAllFiles => '所有檔案';

  @override
  String get errSeriesIdentityConflict => '劇集或季的身分存在衝突';

  @override
  String get errInfoChangedReload => '資訊已變更，請重新載入後操作';

  @override
  String get errWorkIdConflict => '作品 ID 衝突，需要人工確認';

  @override
  String get errInvalidFieldValue => '欄位值無效';

  @override
  String get errPosterNotThisWork => '海報不屬於目前作品';

  @override
  String get errRemoteConfigVersion => '遠端存取設定版本不相容或包含未知欄位。';

  @override
  String get errRemoteOutboundCredential => 'outbound 與憑證必須同時存在。';

  @override
  String get errRemoteUuidPlacement => 'UUID 只能儲存在 credential 中。';

  @override
  String get errRemoteCredentialInvalid => '遠端憑證無效。';

  @override
  String get errRemoteProxiesInvalid =>
      'proxies 的 name 不能為空或重複，remotePort 須為有效連接埠。';

  @override
  String get errRemotePolicyUnsupported => '遠端連線策略超出支援範圍。';

  @override
  String get errRemoteLanNeedsHttps => '區域網路自動存取需要 HTTPS 端點和配對確認的憑證 SHA-256。';

  @override
  String get errRemoteUnknownField => '未知的遠端存取欄位。';

  @override
  String get errRemoteChooseProxy => '請選擇遠端存取使用的 proxy。';

  @override
  String get errRemoteEndpoint => '遠端存取需要有效的 HTTP(S) 或 SMB 服務端點。';

  @override
  String get errRemoteProxyRef => 'proxy name、remotePort 或憑證參照無效。';

  @override
  String get errRemoteProxyHost => '代理主機或設定長度無效。';

  @override
  String get errRemoteTlsName => '代理 TLS 伺服器名稱無效。';

  @override
  String get errRemoteNeedsVless => '配對需要開啟憑證驗證的 VLESS TLS/REALITY 出站。';

  @override
  String get errRemoteCaPrivateKey => 'CA 設定不能包含私密金鑰。';

  @override
  String get errRemoteRealityPublic => 'REALITY 用戶端只儲存公開參數。';

  @override
  String get errRemoteAuthHeader => '傳輸認證標頭不能寫入公開線路設定。';

  @override
  String get errRemoteTlsField => '不支援的 TLS 設定欄位。';

  @override
  String get errRemoteConfigTooLarge => '設定過大。';

  @override
  String get errRemoteInvalidJson => '不是有效的 JSON，請貼上 Relay 匯出的完整 App 設定。';

  @override
  String get errRemoteAppConfigShape =>
      'App 設定須為只含「outbound」（物件）和「proxies」（陣列）的 JSON 物件。';

  @override
  String get errRemoteProxyShape =>
      'proxies 每項須只含「name」（字串）和「remotePort」（連接埠）。';

  @override
  String get errRemoteProxiesEmpty => 'proxies 不能為空，name 不能重複。';

  @override
  String get errRemoteOutsideEndpoint => '請求超出已授權的服務端點。';

  @override
  String get errRemoteCertMismatch => '服務憑證與已配對身分不相符。';

  @override
  String get errRemoteOutsidePaired => '連線超出已配對服務。';

  @override
  String get errRemoteLanUnreachable => '區域網路服務無法連線或身分驗證失敗。';

  @override
  String get errRemoteCellularBlocked => '目前設定禁止行動網路遠端存取，或無法確認目前網路。';

  @override
  String get errRemoteCellularUnknown => '無法確認行動網路狀態，已阻止遠端連線。';

  @override
  String get errRemoteNoCore => '此版本缺少遠端連線核心，請安裝包含 sing-box 的版本。';

  @override
  String get errRemoteNativeConfigTooLarge => '遠端連線設定過大。';

  @override
  String get errRemoteCoreStart => '遠端核心啟動失敗，請檢查線路設定。';

  @override
  String get rtDisabled => '已停用';

  @override
  String get rtUnchecked => '未偵測';

  @override
  String get rtStarting => '啟動中';

  @override
  String get rtBlocked => '需處理';

  @override
  String get rtError => '出錯';

  @override
  String get rtDraining => '收尾中';

  @override
  String get healthLastOk => '上次連線成功';

  @override
  String get healthLocal => '本機';

  @override
  String get plgDraining => '已阻止新呼叫，正在等待播放或工作結束';

  @override
  String plgDependencyBlocked(String name) {
    return '相依的「$name」已停用或無法使用';
  }

  @override
  String get plgNoInstanceAdded => '尚未新增實例';

  @override
  String get plgAllInstancesDisabled => '所有實例均已停用';

  @override
  String get plgInstanceFailing => '有實例連線失敗';

  @override
  String get plgSomeInstancesBlocked => '部分實例需處理';

  @override
  String get plgNfoInstance => '鄰近檔案規則';

  @override
  String get plgNoTmdb => '此版本未接入 TMDB 設定';

  @override
  String get plgTmdbInstance => 'TMDB 設定';

  @override
  String get plgTmdbNoToken => '未設定存取權杖';

  @override
  String get plgNoFfmpeg => '目前平台或版本未包含 FFmpeg 媒體處理';

  @override
  String get plgFfmpegInstance => '裝置內處理';

  @override
  String get plgModelNotConfigured => '未設定模型或金鑰';

  @override
  String get plgNoSources => '此版本未接入媒體來源';

  @override
  String get plgNoAsr => '此版本未接入語音辨識';

  @override
  String plgModelDetail(String model) {
    return '模型 $model';
  }

  @override
  String get plgLocalAsrUnavailable => '本機辨識引擎無法使用';

  @override
  String get errTmdbTokenRequired => '請設定 TMDB 讀取存取權杖';

  @override
  String get errQueryCancelled => '查詢已取消';

  @override
  String get errTmdbResponseTooLarge => 'TMDB 回應過大';

  @override
  String get errTmdbAuth => 'TMDB 認證失敗，請更新權杖';

  @override
  String get errTmdbNotFound => 'TMDB 物件不存在';

  @override
  String get errTmdbRateLimited => 'TMDB 請求受限，請稍後重試';

  @override
  String get errTmdbUnavailable => 'TMDB 暫時無法使用';

  @override
  String get errTmdbRequestFailed => 'TMDB 請求失敗';

  @override
  String get errTmdbInvalidResponse => 'TMDB 回應格式無效';

  @override
  String get errTmdbUnreachable => '無法連線 TMDB，請檢查網路';

  @override
  String get errTmdbNoAttachments => 'TMDB 不讀取來源附件';

  @override
  String get errTmdbInvalidIds => 'TMDB ID 或季集編號無效';

  @override
  String get errIdentifySeriesFirst => '請先識別劇集，再選擇季集';

  @override
  String get errTmdbRefRequired => '詳細資訊需要 TMDB 參照';

  @override
  String get errTmdbInvalidIdentity => 'TMDB 物件身分或標題無效';

  @override
  String get errNfoRefRequired => 'NFO 詳細資訊需要附件參照';

  @override
  String get errNfoParse => 'NFO 解析失敗';

  @override
  String get errNfoTooLarge => 'NFO 超過 1 MiB';

  @override
  String get errNfoDtd => 'NFO 不允許 DTD 或實體宣告';

  @override
  String get errNfoTooManyNodes => 'NFO 節點過多';

  @override
  String get errNfoTooDeep => 'NFO 巢狀過深';

  @override
  String get errNfoType => '不支援的 NFO 物件類型';

  @override
  String get errNfoFieldTooLong => 'NFO 欄位過長';

  @override
  String get errInvalidMetadataQuery => '無效的中繼資料查詢參數';

  @override
  String get errMetadataQueryUnsupported => '此中繼資料實例不支援該查詢';

  @override
  String get errMediaKindUnsupported => '不支援此媒體類型的影視資訊';

  @override
  String get errBackgroundIdentify => '背景識別失敗';

  @override
  String get errQueryStale => '查詢已過期或已取消';

  @override
  String get errTmdbConfigChanged => 'TMDB 設定已變更';

  @override
  String get errRequeryCandidates => '請重新查詢候選';

  @override
  String get errChooseEpisodeFirst => '請先選擇具體季集';

  @override
  String get errCandidateNotThisQuery => '候選不屬於此查詢';

  @override
  String get errDetailIdentityMismatch => '詳細資訊身分不相符';

  @override
  String get errReloadCandidates => '請重新載入候選';

  @override
  String get errInvalidLocalCandidate => '無效的本機候選';

  @override
  String get errChooseSeriesFirst => '請先選擇劇集';

  @override
  String get errConfirmMatchFirst => '請先確認比對';

  @override
  String get errCatalogTooLarge => '目錄過大，請縮小中繼資料範圍';

  @override
  String get errCursorStuck => '分頁游標未前進';

  @override
  String get errEpisodeSeasonMissing => '單集所屬季不存在';

  @override
  String get errSourceConfigChanged => '來源設定已變更';

  @override
  String get errInvalidYear => '年份無效';

  @override
  String get catSourceBrowse => '瀏覽目錄';

  @override
  String get catSourceBrowseDesc => '列出該來源的資料夾與檔案';

  @override
  String get catSourceResolve => '播放';

  @override
  String get catSourceResolveDesc => '把選中的資源交給播放器；嚴格綁定資源所屬實例';

  @override
  String get catSourceAttachments => '讀取附件';

  @override
  String get catSourceAttachmentsDesc => '讀取 NFO、外掛字幕等小檔案（有大小上限）';

  @override
  String get catSearchMedia => '搜尋媒體';

  @override
  String get catSearchMediaDesc => '在伺服器端搜尋影片與劇集';

  @override
  String get catMetadataLookup => '影視資訊';

  @override
  String get catMetadataLookupDesc => '讀取媒體伺服器整理好的影視資訊';

  @override
  String get catSourceWrite => '寫入新檔案';

  @override
  String get catSourceWriteDesc =>
      '把 App 產生的片段寫到同一共用的 OpenPlayX 資料夾；不覆寫、不刪除，每次需確認';

  @override
  String get catSummaryLocal => '本機或已掛載的資料夾';

  @override
  String get catSummarySmb => 'Windows 共用、NAS 的 SMB 共用目錄';

  @override
  String get catSummaryWebdav => 'WebDAV 雲端硬碟或 NAS 目錄';

  @override
  String get catSummaryFtp => 'FTP 伺服器目錄';

  @override
  String get catSummarySftp => '透過 SSH 存取的伺服器目錄';

  @override
  String get catSummaryS3 => 'S3 相容物件儲存貯體';

  @override
  String get catSummaryPlex => 'Plex 媒體伺服器';

  @override
  String get catSummaryJellyfin => 'Jellyfin 媒體伺服器';

  @override
  String get catSummaryEmby => 'Emby 媒體伺服器';

  @override
  String get catSummaryDlna => '區域網路 DLNA 媒體伺服器';

  @override
  String get catDataLocal => '只讀取你授權的資料夾。';

  @override
  String get catDataRemote =>
      'App 在本機連線你設定的伺服器；檔名和目錄名稱會出現在 AI 對話中（僅當允許 AI 使用時）。';

  @override
  String get catNfoName => 'NFO 中繼資料';

  @override
  String get catNfoSummary => '讀取媒體旁邊的 .nfo 檔案';

  @override
  String get catNfoToggle => '由「刮削管理」控制是否刮削；背景刮削獨立執行，暫不支援單獨停用。';

  @override
  String get catNfoCap => '本機中繼資料';

  @override
  String get catNfoCapDesc => '依鄰近檔案規則比對影片資訊';

  @override
  String get catTmdbSummary => '從 The Movie Database 查詢影片與劇集資訊';

  @override
  String get catTmdbToggle => '清除存取權杖即停止使用；背景刮削獨立執行，暫不支援單獨停用。';

  @override
  String get catTmdbData => '查詢時向 TMDB 傳送解析出的片名與年份，不傳送檔案內容。';

  @override
  String get catTmdbCap => '查詢中繼資料';

  @override
  String get catTmdbCapDesc => '搜尋、比對影片與劇集資訊；寫入由主程式完成';

  @override
  String get catFfmpegName => 'FFmpeg 媒體處理';

  @override
  String get catFfmpegSummary => '截圖、探測、轉碼與音訊擷取';

  @override
  String get catFfmpegData => '在本機處理媒體，產物儲存在應用程式目錄。';

  @override
  String get catProbe => '探測';

  @override
  String get catProbeDesc => '讀取時長、編碼與音軌';

  @override
  String get catTranscode => '轉碼';

  @override
  String get catTranscodeDesc => '依預設轉碼為新檔案';

  @override
  String get catExtractAudio => '擷取音訊';

  @override
  String get catExtractAudioDesc => '匯出音軌用於辨識或儲存';

  @override
  String get catSnapshot => '截圖';

  @override
  String get catSnapshotDesc => '擷取指定時間的畫面';

  @override
  String get catAsrName => '語音辨識';

  @override
  String get catAsrSummary => '為影片產生原語言字幕與逐字稿';

  @override
  String get catAsrCapDesc => '產生原語言字幕／逐字稿；不包含翻譯';

  @override
  String get catLlmName => '對話模型';

  @override
  String get catLlmSummary => '為 AI 助理提供大型語言模型';

  @override
  String get catLlmToggle => '在「AI 與模型」中設定或清除模型；不會產生可遞迴呼叫自身的推理工具。';

  @override
  String get catLlmData => '對話內容、頁面摘要與工具結果會傳送給所設定的模型服務，可能產生費用。';

  @override
  String get catLlmCap => '對話推理';

  @override
  String get catLlmCapDesc => '為 AI 助理產生回覆與工具呼叫';

  @override
  String get catCategorySource => '媒體來源';

  @override
  String get catCategoryMetadata => '中繼資料';

  @override
  String get catCategoryMediaProcessing => '媒體處理';

  @override
  String get catCategorySpeech => '字幕辨識';

  @override
  String get catLocationNetwork => '網路儲存';

  @override
  String get catLocationSelfHosted => '自架服務';

  @override
  String get catLocationCloudApi => '雲端 API';

  @override
  String get webSearchPresetName => '聯網搜尋';

  @override
  String get errAssistantConfig =>
      '請填寫有效的 HTTPS API 基礎位址（本機服務可用 http，例如 http://localhost:11434/v1）、模型和輸出上限（128–16384）';

  @override
  String get errExtRootAddress => '請輸入服務根位址，例如 https://bt.example.com';

  @override
  String get errExtHttpsRequired => '公開網路位址必須使用 HTTPS；HTTP 僅允許區域網路或本機位址';

  @override
  String get errExtTokenRequired => '請填寫存取權杖';

  @override
  String get errExtTimeout => '連線逾時';

  @override
  String get errExtUnreachable => '無法連線到這個位址';

  @override
  String get errExtTls => 'TLS 憑證驗證失敗';

  @override
  String get errExtTooLarge => '服務傳回的資料過大';

  @override
  String errExtRejected(String reason) {
    return '服務拒絕了請求：$reason';
  }

  @override
  String errExtError(String code) {
    return '服務傳回錯誤（$code）';
  }

  @override
  String get errExtTokenInvalid => '存取權杖無效';

  @override
  String get errExtNoMcp => '這個位址沒有提供 MCP 入口';

  @override
  String get errArtworkCancelled => '圖片載入已取消';

  @override
  String get errArtworkQuota => '圖片快取額度不足';

  @override
  String get errArtworkUnauthorized => '圖片位址未經授權';

  @override
  String get errArtworkTypeSize => '圖片類型或大小無效';

  @override
  String get errArtworkEmptyOrLarge => '圖片為空或過大';

  @override
  String get errArtworkContentType => '不支援的圖片內容類型';

  @override
  String get errArtworkDecodeSize => '圖片解碼尺寸過大';

  @override
  String get errArtworkWait => '請等待圖片載入完成';

  @override
  String get errLibraryClosing => '媒體庫正在關閉';

  @override
  String get errNameRequired => '請輸入名稱';

  @override
  String get errSeasonCycle => '來源傳回了循環季集關係';

  @override
  String get errInvalidPagingShort => '無效分頁';

  @override
  String get errTitleRequired => '請輸入標題';

  @override
  String get errScanRunning => '掃描已在執行';

  @override
  String get errFileSourceMissing => '檔案來源不存在';

  @override
  String get errFileSourceDisabled => '檔案來源已停用';

  @override
  String get errSourceScanDisabled => '來源未啟用掃描';

  @override
  String get errScanTooLarge => '掃描範圍過大，請縮小範圍';

  @override
  String get errScanBindingChanged => '來源或綁定已變更，請重新掃描';

  @override
  String get errSourceIdentityMismatch => '來源身分不相符';

  @override
  String get errSourceCursorStuck => '來源分頁游標未前進';

  @override
  String get errScanIncomplete => '掃描未完成，請檢查來源後重試';

  @override
  String get aiToolContextGet => '讀取目前頁面';

  @override
  String get aiToolSourceList => '列出媒體來源';

  @override
  String get aiToolSourceBrowse => '瀏覽資料夾';

  @override
  String get aiToolLibraryQuery => '查詢媒體庫';

  @override
  String get aiToolMediaGet => '檢視媒體詳細資訊';

  @override
  String get aiToolSearchMedia => '搜尋媒體';

  @override
  String get aiToolProgressQuery => '檢視觀看進度';

  @override
  String get aiToolPlaybackGet => '讀取播放狀態';

  @override
  String get aiToolPlaybackOpen => '開啟播放';

  @override
  String get aiToolPlaybackPause => '暫停';

  @override
  String get aiToolPlaybackResume => '繼續播放';

  @override
  String get aiToolPlaybackStop => '停止播放';

  @override
  String get aiToolPlaybackSeek => '跳轉';

  @override
  String get aiToolPlaybackSetSpeed => '設定倍速';

  @override
  String get aiToolPlaybackSetVolume => '設定音量';

  @override
  String get aiToolPlaybackSetSubtitle => '設定字幕';

  @override
  String get aiToolMediaProcessingCapabilities => '查詢媒體處理能力';

  @override
  String get aiToolMediaProbe => '分析媒體';

  @override
  String get aiToolMediaTranscode => '轉碼 / 擷取片段';

  @override
  String get aiToolMediaExtractAudio => '擷取音訊';

  @override
  String get aiToolMediaSnapshot => '截圖';

  @override
  String get aiToolMediaSaveToSource => '存回媒體來源';

  @override
  String get aiToolTaskGet => '查詢處理工作';

  @override
  String get aiToolTaskList => '列出處理工作';

  @override
  String get aiToolTaskCancel => '取消處理工作';

  @override
  String get aiToolTaskRetry => '重試處理工作';

  @override
  String get aiToolSpeechRecognitionStatus => '查詢語音辨識狀態';

  @override
  String get aiToolSubtitleGenerate => '辨識字幕';

  @override
  String get aiToolTranscriptGenerate => '產生逐字稿';

  @override
  String get aiToolSubtitleTaskGet => '查詢字幕工作';

  @override
  String get aiToolSubtitleTaskCancel => '取消字幕工作';

  @override
  String get aiToolSubtitleSave => '儲存字幕';

  @override
  String get aiToolPluginStatus => '檢視外掛狀態';

  @override
  String get aiToolMcpTavilyWebSearch => '聯網搜尋';

  @override
  String get aiToolWebFetch => '讀取網頁';

  @override
  String get aiArgQuery => '關鍵字';

  @override
  String get aiArgUrl => '網址';

  @override
  String get aiArgRange => '範圍';

  @override
  String get aiArgEnd => '結尾';

  @override
  String get aiArgWholeMedia => '整部';

  @override
  String get aiArgTime => '時間';

  @override
  String get aiArgPosition => '位置';

  @override
  String get aiArgPreset => '預設';

  @override
  String get aiArgLanguage => '語言';

  @override
  String get aiArgFormat => '格式';

  @override
  String get aiArgSpeed => '倍速';

  @override
  String get aiArgVolume => '音量';

  @override
  String get aiArgSwitch => '開關';

  @override
  String get aiArgOff => '關閉';

  @override
  String get aiArgWait => '等待';

  @override
  String get aiToolInput => '輸入';

  @override
  String get aiToolOutput => '輸出';

  @override
  String get aiActivityThinking => '正在思考';

  @override
  String get aiActivityAnswering => '正在回覆';

  @override
  String get aiActivityRunningDefault => '執行中';

  @override
  String get aiReasoningStreaming => '思考中…';

  @override
  String get aiReasoningDone => '已思考';

  @override
  String get aiReasoningUnderSecond => '思考了不到 1 秒';

  @override
  String get aiStillRunning => '等待逾時，工作仍在背景執行（未失敗、未停止）';

  @override
  String get aiStatusQueued => '排隊中';

  @override
  String get aiStatusPreparing => '準備中';

  @override
  String get aiStatusRunning => '處理中';

  @override
  String get aiStatusCancelling => '取消中';

  @override
  String get aiStatusSucceeded => '已完成';

  @override
  String get aiStatusFailed => '失敗';

  @override
  String get aiStatusCancelled => '已取消';

  @override
  String get aiStatusInterrupted => '已中斷';

  @override
  String get aiStageExtracting => '擷取音訊';

  @override
  String get aiStageUploading => '上傳';

  @override
  String get aiStageQueued => '排隊';

  @override
  String get aiStageTranscribing => '辨識';

  @override
  String get aiStageFormatting => '整理字幕';

  @override
  String aiArgWaitValue(String seconds) {
    return '最多等 ${seconds}s';
  }

  @override
  String aiStepPreparing(String name) {
    return '準備呼叫 $name…';
  }

  @override
  String aiStepRunning(String name) {
    return '正在執行 $name…';
  }

  @override
  String aiStepWaiting(String name) {
    return '允許執行 $name？';
  }

  @override
  String aiStepFailed(String name) {
    return '$name 失敗';
  }

  @override
  String aiStepCancelled(String name) {
    return '已取消 $name';
  }

  @override
  String aiShowAll(int count) {
    return '顯示全部（$count 個字元）';
  }

  @override
  String aiActivityPreparingTool(String name) {
    return '準備呼叫：$name';
  }

  @override
  String aiActivityTool(String name) {
    return '正在執行：$name';
  }

  @override
  String aiActivityConfirm(String name) {
    return '等待你確認：$name';
  }

  @override
  String aiStepNumber(int step) {
    return '第 $step 步';
  }

  @override
  String aiReasoningSeconds(int seconds) {
    return '思考了 $seconds 秒';
  }

  @override
  String aiReasoningMinutes(int minutes) {
    return '思考了 $minutes 分鐘';
  }

  @override
  String get cloudJianguoyun => '堅果雲';

  @override
  String get cloud123 => '123 雲端硬碟';

  @override
  String get cloudJianguoyunHelp => '使用帳號和第三方應用程式密碼，可調整預設 WebDAV 目錄。';

  @override
  String get cloud123Help => '先確認 123 帳號具備 WebDAV 權益，填寫官方後台提供的位址和憑證；可用性取決於方案。';

  @override
  String get cloudPreset => 'WebDAV 預設';

  @override
  String get cloudCustom => '自訂 WebDAV';

  @override
  String get catSummaryCloudDrive => '瀏覽和播放雲端硬碟檔案。';

  @override
  String get cloudSignIn => '使用瀏覽器登入';

  @override
  String get cloudSignInHelp =>
      '僅讀取檔案，請在下方選擇根目錄。中斷 OneDrive 後，還需到微軟帳號權限頁面解除應用程式授權。';

  @override
  String get cloudNotConfigured => '此組建尚未設定雲端硬碟登入，需由發行者設定 OAuth 應用程式。';

  @override
  String get cloudSignInFailed => '雲端硬碟授權失敗，請重試。';

  @override
  String get cloudCallbackInvalid => '無法驗證授權回呼。';

  @override
  String get cloudRoot => '已選根目錄';

  @override
  String get cloudRootHelp => '開啟資料夾即可選為根目錄，僅瀏覽和掃描此目錄下的檔案。';

  @override
  String get cloudReauthorize => '授權已過期或撤銷，請重新登入。';

  @override
  String get cloudPersonalOnly => '目前僅支援個人 OneDrive 帳號。';

  @override
  String get cloudDisconnect => '中斷帳號連線';

  @override
  String get cloudDisconnectHelp =>
      '清除本機憑證並停止雲端硬碟請求。還需在微軟或 Dropbox 帳號權限頁面移除此應用程式，以解除平台授權。';
}
