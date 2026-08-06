# `page/single/video_viewer_page.dart`

> 功能点 11 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 加载前展示带鉴权头的缩略图 | 未测 | 批次24 | 0 | 0 | 0 | 聊天路径不走本页 |
| 待复验 | 2026-08-06 | `page/single/video_viewer_page.dart` | 初始化完成后自动播放并循环 | BUG已修待验 | 批次24 | 1 | 1 | 0 | BUG#69 已改代码，本页两条路径无素材未真机验 |
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 点击按钮切换播放与暂停 | 未测 | 批次24 | 0 | 0 | 0 | 控制层由 VideoControllerOverlay 提供 |
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 播放到结尾后重播回到起点 | 未测 | 批次24 | 0 | 0 | 0 | — |
| 待复验 | 2026-08-06 | `page/single/video_viewer_page.dart` | 控制层显示进度条与时长 | BUG已修待验 | 批次24 | 1 | 1 | 0 | BUG#68 SizedBox.expand 已修；BUG#75 真根因在 vendored 插件 _VideoPlayerPage（d3da71ae 另修） |
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 点击按钮切换全屏与还原 | 未测 | 批次24 | 0 | 0 | 0 | — |
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 缓存下载期间显示加载进度圈 | 未测 | 批次24 | 0 | 0 | 0 | — |
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 初始化失败展示空态并点击重试 | 未测 | 批次24 | 0 | 0 | 0 | — |
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 缩略图加载失败展示错误图标 | 未测 | 批次24 | 0 | 0 | 0 | — |
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 加载阶段点击关闭按钮返回上页 | 未测 | 批次24 | 0 | 0 | 0 | — |
| 阻塞 | 需群文件或收藏里有视频素材 | `page/single/video_viewer_page.dart` | 退出页面释放控制器停止播放 | 未测 | 批次24 | 0 | 0 | 0 | — |
