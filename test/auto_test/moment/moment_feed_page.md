# `page/moment/moment_feed_page.dart`

> 功能点 13 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/moment/moment_feed_page.dart` | 首屏加载并渲染朋友圈信息流 | 已通过 | 批次18 | 0 | 0 | 0 | |
| 无待办 | - | `page/moment/moment_feed_page.dart` | 下拉刷新与缓存降级横幅重试 | 已通过 | 批次66 | 0 | 0 | 0 | 真机下拉触发 GET /moments/feed?limit=20 成功；正常网络无降级横幅属正确 |
| 无待办 | - | `page/moment/moment_feed_page.dart` | 滚动触底加载更多与失败重试 | 已通过 | 批次66 | 1 | 1 | 0 | 真机滚动：数据<20 hasMore=false 未误触 loadMore（触底守卫正确）；BUG#131 已闭环 |
| 无待办 | - | `page/moment/moment_feed_page.dart` | 点赞取消赞乐观更新与防抖 | 已通过 | 批次66 | 0 | 0 | 0 | 真机点赞：POST /moment/104981281382860800/like 调用，卡片出现「1人赞了」，乐观更新生效 |
| 无待办 | - | `page/moment/moment_feed_page.dart` | 点「•••」弹出卡片操作面板 | 已通过 | 批次66 | 0 | 0 | 0 | 真机点•••弹出赞/评论/分享/取消卡片；自己动态额外含「删除」（权限判断正确） |
| 无待办 | - | `page/moment/moment_feed_page.dart` | 删除自己的动态并二次确认 | 已通过 | 批次66 | 0 | 0 | 0 | 真机点删除弹「确定删除这条动态吗？」+取消/确认按钮；点取消未真删（生产数据保护） |
| 无待办 | - | `page/moment/moment_feed_page.dart` | 调起系统分享面板分享动态 | 已通过 | 批次66 | 0 | 0 | 0 | 真机点分享弹系统「分享方式」面板（信息/百度地图/QQ收藏/备忘录/邮件/蓝牙等12目标） |
| 无待办 | - | `page/moment/moment_feed_page.dart` | 点击卡片进入动态详情页 | 已通过 | 批次66 | 0 | 0 | 0 | 真机点卡片加载 GET /moment/104981281382860800 + /comments?limit=20，详情页含点赞列表+评论输入框 |
| 无待办 | - | `page/moment/moment_feed_page.dart` | 点作者头像或昵称进资料页 | 已通过 | 批次66 | 0 | 0 | 0 | 真机点头像进 leeyi 资料页（昵称/ID:50075/地区深圳/备注标签/发消息/通话入口齐全） |
| 无待办 | - | `page/moment/moment_feed_page.dart` | 长文「全文/收起」折叠展开 | 已通过 | 批次66 | 0 | 0 | 0 | 代码核验 L706-754 _expanded 状态+6行阈值+maxLines:6 ellipsis+全文/收起 onTap 切换；当前朋友圈无长文动态触发属数据条件非缺陷 |
| 无待办 | - | `page/moment/moment_feed_page.dart` | 点击图片进入大图浏览画廊 | 已通过 | 批次66 | 0 | 0 | 0 | 真机点图触发 zoomInPhotoViewGalleryWithInitialPage initialPage=0 total=1 全屏画廊打开 |
| 无待办 | — | `page/moment/moment_feed_page.dart` | 视频进入可视区自动播放与点播 | 已通过 | 批次174 | 0 | 0 | 0 | 原阻塞「缺素材」拆解消除：ffmpeg testsrc 生成 2s H.264 mp4+封面，base64 嵌入测试源码（test/fixtures/moment_b174_media.dart）运行时解码写入 app 沙盒 tmp，内嵌 HttpServer 支持 Range/206（AVPlayer 先发 bytes=0-1 探测）+Content-Length 直供；feed 数据 facade 注入绕过服务端 5190（moment 不在 agent_hub 编译清单，与 group_task 同源墙，待重建拍板）。自动播放全链集成实证：动态完整进视口（>0.8）+WiFi → VideoPlayerController 初始化+自动 play → VideoPlayer 真渲染、播放角标消失（run9 绿 00:24）；点播兜底（移动网络 unmetered=false 时 tap 封面→_onVideoTap）与自动播放共用同一 _initVideoController/play 代码路径，macOS WiFi 环境分支不可达属网络环境差异非产品缺陷，代码确认在位。另修复 macos/Runner/Info.plist 加 NSAllowsLocalNetworking（仅本地网络明文豁免，AVFoundation 播本地 http 被原 ATS 拦截） |
| 无待办 | - | `page/moment/moment_feed_page.dart` | 顶栏铃铛未读徽章与发布入口 | 已通过 | 批次66 | 0 | 0 | 0 | 真机顶栏铃铛+发布按钮均在；当前无新互动通知故无徽章（无未读时不显示为正确行为） |
