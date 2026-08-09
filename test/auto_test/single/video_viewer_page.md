# `page/single/video_viewer_page.dart`

> 功能点 11 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 加载前展示带鉴权头的缩略图 | 未测 | 批次24 | 0 | 0 | 0 | 聊天路径不走本页 |
| 无待办 | - | `page/single/video_viewer_page.dart` | 初始化完成后自动播放并循环 | 已通过 | 批次72 | 1 | 1 | 0 | 真机：deep link `/video_viewer?url=<u50 c2c mp4>` 打开后自动进入播放态（控制层显示「28%, 播放」），无需手点 |
| 无待办 | - | `page/single/video_viewer_page.dart` | 点击按钮切换播放与暂停 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：点「播放」→ 控制层变「28%, 播放」；再点控制层 → 回到大播放按钮，状态双向切换正常（控制层由 VideoControllerOverlay 提供） |
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 播放到结尾后重播回到起点 | 未测 | 批次24 | 0 | 0 | 0 | — |
| 无待办 | - | `page/single/video_viewer_page.dart` | 控制层显示进度条与时长 | 已通过 | 批次72 | 1 | 1 | 0 | 真机：控制层语义「28%, 播放 00:00 00:03」——进度百分比+当前时间+总时长齐全，SizedBox.expand（#68）与 Stack（#75）修复生效 |
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 点击按钮切换全屏与还原 | 未测 | 批次24 | 0 | 0 | 0 | — |
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 缓存下载期间显示加载进度圈 | 未测 | 批次24 | 0 | 0 | 0 | — |
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 初始化失败展示空态并点击重试 | 未测 | 批次24 | 0 | 0 | 0 | — |
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 缩略图加载失败展示错误图标 | 未测 | 批次24 | 0 | 0 | 0 | — |
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 加载阶段点击关闭按钮返回上页 | 未测 | 批次24 | 0 | 0 | 0 | — |
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 退出页面释放控制器停止播放 | 未测 | 批次24 | 0 | 0 | 0 | — |
