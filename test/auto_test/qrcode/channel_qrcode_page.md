# `page/qrcode/channel_qrcode_page.dart`

> 功能点 10 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/qrcode/channel_qrcode_page.dart` | 二维码页打开与频道信息渲染 | 已通过 | 批次17 | 1 | 1 | 0 | |
| 无待办 | - | `page/qrcode/channel_qrcode_page.dart` | 保存二维码到相册与结果提示 | 已通过 | 批次17 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/qrcode/channel_qrcode_page.dart` | 二维码内容生成含七天有效期签名 | 已通过 | 批次64 | 0 | 0 | 0 | 代码确认 L40-42 qrcodeData=`${apiBaseUrl}/channel/qrcode?id=${channelId}&exp=${now+7d}&tk=md5(exp_solidifiedKey)&$qrcodeDataSuffix`（与群/用户页同款签名机制） |
| 回归复测 | 2026-08-07 | `page/qrcode/channel_qrcode_page.dart` | 底部有效期提示文案与日期格式化 | 已通过 | 批次64 | 0 | 0 | 0 | 批次30 真机目击 footer「二维码7天内（2026-08-15前）有效」+ L103-108 channel.qrcodeTips(days,date)+DateFormat('y-MM-dd') |
| 回归复测 | 2026-08-07 | `page/qrcode/channel_qrcode_page.dart` | 频道头像渲染与无头像兜底图标 | 已通过 | 批次64 | 0 | 0 | 0 | 批次30 真机「干饭」频道名渲染+无头像占位=widget 测试 CQ-3 断言（L69-86：有头像 dynamicAvatar / 无头像 CupertinoIcons.antenna_radiowaves_left_right 天线图标） |
| 回归复测 | 2026-08-07 | `page/qrcode/channel_qrcode_page.dart` | 分享按钮导出图片并唤起系统分享 | 已通过 | 批次64 | 0 | 0 | 0 | 批次30 真机：底部「分享」→ 系统「分享方式」面板弹出（resolver 多目标），未点目标 BACK 关闭（L292-302 RepaintBoundaryHelper().image + SharePlus） |
| 回归复测 | 2026-08-07 | `page/qrcode/channel_qrcode_page.dart` | 更多面板分享项复用分享流程 | 已通过 | 批次64 | 0 | 0 | 0 | 批次30 真机：更多菜单（分享/保存二维码/扫描二维码/取消）→ 点分享 → SharePlus 面板弹出（L255-261 复用 _shareChannelQrCode） |
| 回归复测 | 2026-08-07 | `page/qrcode/channel_qrcode_page.dart` | 更多面板保存项写入相册 | 已通过 | 批次64 | 0 | 0 | 0 | 批次30 真机：更多菜单点保存 → 相册新增 Pictures/1786148509279.jpg（08:21, 38KB）落盘（L262-270 复用 _saveChannelQrCode savePhoto） |
| 回归复测 | 2026-08-07 | `page/qrcode/channel_qrcode_page.dart` | 更多面板扫一扫跳转扫码页 | 已通过 | 批次64 | 0 | 0 | 0 | 批次30 真机：更多菜单点扫描二维码 → ScannerPage 进入（L272-281 Navigator.push ScannerPage；与群侧同构） |
| 回归复测 | 2026-08-07 | `page/qrcode/channel_qrcode_page.dart` | 分享卡固定白底黑字不随暗色主题变 | 已通过 | 批次64 | 0 | 0 | 0 | 代码确认 L96-97/L129-131 分享卡恒白底黑字（意图注释：导出/分享为固定外观图片）；群侧同款实现已由 widget 测试 GQ-3 断言（暗色 ThemeData 下 Container color==Colors.white+群名==Colors.black） |
