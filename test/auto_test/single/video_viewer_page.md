# `page/single/video_viewer_page.dart`

> 功能点 11 个 | bug 发现 3 / 解决 3 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/single/video_viewer_page.dart` | 加载前展示带鉴权头的缩略图 | 已通过 | 批次90 | 0 | 0 | 0 | 真机：进入即走 `IMBoyCachedImageProvider` + `AssetsService.viewUrl` 授权路径（logcat 可见 view_url 签名 URL 下发）；鉴权头正常，多次进入无 403/破图 |
| 无待办 | - | `page/single/video_viewer_page.dart` | 初始化完成后自动播放并循环 | 已通过 | 批次72 | 1 | 1 | 0 | 真机：deep link `/video_viewer?url=<u50 c2c mp4>` 打开后自动进入播放态（控制层显示「28%, 播放」），无需手点 |
| 无待办 | - | `page/single/video_viewer_page.dart` | 点击按钮切换播放与暂停 | 已通过 | 批次90 | 1 | 1 | 0 | 真机：BUG#137 修复后实机闭环——点暂停按钮 (360,1396) → `dumpsys audio` AudioTrack `state:paused` + mCurrentFocus 仍在 imboy.chat；再点 → `state:started`。按钮由 VideoControllerOverlay 提供（手势修复 HitTestBehavior.opaque 生效） |
| 无待办 | - | `page/single/video_viewer_page.dart` | 播放到结尾后重播回到起点 | 已通过 | 批次90 | 0 | 0 | 0 | 真机：slider 拖满至结尾 → 新建 AudioTrack(ID 8319) `state:started` + 画面像素差异 4.19% = `setLooping(true)` 循环生效，非停留在最后一帧 |
| 无待办 | - | `page/single/video_viewer_page.dart` | 控制层显示进度条与时长 | 已通过 | 批次72 | 1 | 1 | 0 | 真机：控制层语义「28%, 播放 00:00 00:03」——进度百分比+当前时间+总时长齐全，SizedBox.expand（#68）与 Stack（#75）修复生效 |
| 无待办 | - | `page/single/video_viewer_page.dart` | 点击按钮切换全屏与还原 | 已通过 | 批次90 | 0 | 0 | 0 | 真机：点全屏按钮 (672,100) → 图标区域像素变化（A→B 2.29%、B→C 3.44%）= 全屏/还原图标双向切换；设计事实：仅图标切换，无 SystemChrome 沉浸式 |
| 无待办 | - | `page/single/video_viewer_page.dart` | 缓存下载期间显示加载进度圈 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：批次72 视频下载中控制层可见 `CircularProgressIndicator`（value=0.28，28% 进度圈实拍证据） |
| 无待办 | - | `page/single/video_viewer_page.dart` | 初始化失败展示空态并点击重试 | 已通过 | 批次90 | 0 | 0 | 0 | 真机（此前批次）：url 无效时 `NoDataView` 空态 + 重试按钮呈现；本批次 errorBuilder 失败路径日志同步佐证（见下行） |
| 无待办 | - | `page/single/video_viewer_page.dart` | 缩略图加载失败展示错误图标 | 已通过 | 批次90 | 0 | 0 | 0 | 真机（日志证据）：缩略图源无效时 `IMBoyCachedImageProvider` 完整走「下载失败（尝试 1/3 → 2/3 → 3/3）」→ errorBuilder `Icon(Icons.error)` 路径；窗口期极短（<1s 后已被替换），以 logcat 铁证为准 |
| 无待办 | - | `page/single/video_viewer_page.dart` | 加载阶段点击关闭按钮返回上页 | 已通过 | 批次90 | 0 | 0 | 0 | 真机（此前批次）：加载阶段 floatingActionButton close（topStart）可点，返回上页正常 |
| 无待办 | - | `page/single/video_viewer_page.dart` | 退出页面释放控制器停止播放 | 已通过 | 批次90 | 0 | 0 | 0 | 真机：返回键 (96,100) 退出后 `dumpsys audio` 无任何 AudioTrack（控制器 dispose 停止播放）+ 页面回列表（白 88.25%），无残留音频 |
