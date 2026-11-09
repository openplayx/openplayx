# 播放器基础控制

实现日期：2026-11-09。分支：`feature/basic-player`。

## 操作

- 播放/暂停，前后各跳 10 秒；跳转限制在 0 与总时长之间。媒体不可定位或总时长未知时禁用跳转。
- 进度条显示当前时间与总时长，并显示剩余时间；拖动过程中预览时间，松手提交一次定位。
- 倍速菜单：0.5、0.75、1、1.25、1.5、2 倍；更换文件保留页面内的选择，不写入全局设置。
- 播放时长按视频画面，临时使用 2 倍速；松手、手势取消、暂停、结束、锁定、更换文件或应用失去焦点时恢复原倍率。原生倍速命令串行执行，避免较慢的加速命令覆盖恢复命令。
- 播放器音量范围 0–100%；与系统音量独立。
- 画面亮度滑块通过黑色遮罩调暗视频，最低保留 15% 画面；不修改系统亮度，也不调暗控制面板。
- 音轨菜单按当前媒体向底层实时获取，选择时传递原始音轨 ID；无可选音轨时显示提示。底层未暴露当前选中轨道查询，因此首次打开不猜测默认选中项，仅标记用户成功选择的轨道。
- 锁定后隐藏顶部入口与底部控制栏，视频画面禁用长按加速，仅保留解锁按钮。
- 控制层叠加在视频上，视频始终铺满可用区域；顶部文件名及入口、底部时间和进度/操作行都不挤占画面高度。
- 音量/亮度改为点击图标展开滑块；窄屏将亮度、音轨、锁定放进“更多播放设置”。
- 播放时静止 3 秒淡出控制层，鼠标移动或点击画面重新显示；暂停、出错、拖动进度和展开菜单时保留控制。锁定后仅显示解锁入口。
- 控制条保持约 100 逻辑像素，适配窄屏和短横屏；不再常驻多排滑块和提示文字。

## 结构

`packages/playback/lib/playback.dart` 增加 `PlayerAudioTrack`、倍速/音量快照，以及设置倍速、音量、发现与选择音轨的接口。VLC 类型仍封装在播放包内。

`lib/features/player/player_page.dart` 负责界面、持续倍率与临时倍率的区分、触控锁定和画面调暗。音量和倍速的原生快照由 VLC 事件提供；调整失败会提示，避免把未执行的选项标记为已选择。

## 验证范围

播放器 Widget 测试覆盖原有文件选择/失败恢复/定位，以及跳转边界、剩余时间、持续倍率恢复、手势取消、后台暂停、触控锁定、音量与音轨 ID、画面调暗、窄屏与横屏布局。

macOS 原生集成测试使用仓库无声视频，验证倍速 1.5→1、音量 40→100 的原生状态反馈和无声媒体的音轨发现，并继续验证解码、暂停、定位、重新打开和结束后重播。

多音轨真实文件的听感切换及其他平台仍需实机验证；Widget 测试确认了音轨菜单传递正确 ID，但不替代真实多音轨音频验证。

## 紧凑布局参考

参考射手影音现代版 `chiflix/splayerx` 的 `develop` 分支布局与交互结构，在 Flutter 中重新实现，没有移植其 Vue/SCSS 源码或图标素材。

- [TheVideoController.vue](https://github.com/chiflix/splayerx/blob/develop/src/renderer/containers/TheVideoController.vue)：控制器覆盖整个视频；底部渐变衬底、右侧功能入口、3 秒无移动隐藏；展开附属菜单时保留控制层。
- [TheProgressBar.vue](https://github.com/chiflix/splayerx/blob/develop/src/renderer/containers/TheProgressBar.vue)：进度条绝对定位在底边，常态较细（4px），悬停时加粗，命中范围大于可见线条。
- [TheTimeCodes.vue](https://github.com/chiflix/splayerx/blob/develop/src/renderer/components/PlayingView/TheTimeCodes.vue)：时间靠左，并把倍率状态与时间组织在同一控制区域。
- [AdvanceControl.vue](https://github.com/chiflix/splayerx/blob/develop/src/renderer/components/PlayingView/AdvanceControl.vue)：按钮与按需展开面板分离，而非所有选项常驻。

OpenPlayX 保留自身前后 10 秒和触控锁定功能，底部使用一排操作与独立细进度条；窄屏通过更多菜单保持完整功能可达。
