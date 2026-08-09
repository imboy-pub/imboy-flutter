# `page/qrcode/qrcode_page.dart`

> 功能点 11 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/qrcode/qrcode_page.dart` | 导出个人二维码页供外部引用 | 已通过 | 批次22 | 0 | 0 | 0 | 本文件仅三行 barrel，无独立 UI，功能点落在被导出的三页 |
| 回归复测 | 2026-08-07 | `page/qrcode/qrcode_page.dart` | 导出群二维码页供外部引用 | 已通过 | 批次64 | 0 | 0 | 0 | 代码确认 L2 `export 'group_qrcode_page.dart'` barrel 引用存在 |
| 回归复测 | 2026-08-07 | `page/qrcode/qrcode_page.dart` | 导出频道二维码页供外部引用 | 已通过 | 批次64 | 0 | 0 | 0 | 代码确认 L3 `export 'channel_qrcode_page.dart'` barrel 引用存在 |
| 回归复测 | 2026-08-07 | `page/qrcode/qrcode_page.dart` | 群二维码卡渲染群头像与群名 | 已通过 | 批次64 | 0 | 0 | 0 | 批次30 真机群二维码页「群聊: 群名」渲染（group_qrcode_page.dart L76-93 SmartGroupAvatar+displayTitle 标题）；九宫格合成见 group_qrcode_page L11 |
| 无待办 | - | `page/qrcode/qrcode_page.dart` | 群二维码携带七天有效期与签名 | 已通过 | 批次30 | 0 | 0 | 0 | 实测群二维码页 footer「该二维码7天内（2026-08-15前）有效」真机目击 + 签名代码证实 qrcodeData = `${apiBaseUrl}/group/qrcode?id=...&exp=now+7d&tk=md5(exp_solidifiedKey)`（group_qrcode_page.dart L48-49） |
| 回归复测 | 2026-08-07 | `page/qrcode/qrcode_page.dart` | 群二维码底部显示到期日期文案 | 已通过 | 批次64 | 0 | 0 | 0 | 批次30 真机目击「该二维码7天内（2026-08-15前）有效」+ group_qrcode_page.dart L96-101 footerText=groupQrcodeTips(days,date) |
| 无待办 | - | `page/qrcode/qrcode_page.dart` | 群二维码保存到相册 | 已通过 | 批次30 | 0 | 0 | 0 | 实测群二维码页点「保存二维码」→ 相册新增 Pictures/1786148309046.jpg（08:18, 79KB）；首次保存触发系统「应用信息」页权限引导 → adb pm grant imboy.chat WRITE/READ_EXTERNAL_STORAGE 后重试成功（repaint_boundary.dart L45-67 savePhoto → PhotoManager.editor.saveImage 落盘） |
| 无待办 | - | `page/qrcode/qrcode_page.dart` | 群二维码导出图片并分享 | 已通过 | 批次30 | 0 | 0 | 0 | 实测群二维码页点「分享」→ 系统「分享方式」面板弹出（保存到QQ收藏/电子邮件/发送到我的电脑/发送给好友/发送给朋友/蓝牙/面对面快传/添加到微信收藏/Huawei Share/WLAN直连/WPS Office 等 resolver 列表），未点任何目标 BACK 关闭（SharePlus 唤起 share sheet，代码 group_qrcode_page.dart L285-291） |
| 无待办 | - | `page/qrcode/qrcode_page.dart` | 频道二维码卡渲染频道名与占位图 | 已通过 | 批次30 | 0 | 0 | 0 | 实测频道 tab→「干饭」详情→显示菜单→分享 sheet→「我的二维码」→ 频道二维码页（标题「频道二维码」+ 频道名「干饭」渲染 @(360,440) + qr code + footer「二维码7天内（2026-08-15前）有效」+ 保存/分享按钮）；频道无头像占位图=新增 widget 测试 CQ-3 断言（channel_qrcode_page.dart 无头像显示 CupertinoIcons.antenna_radiowaves_left_right 天线图标） |
| 无待办 | - | `page/qrcode/qrcode_page.dart` | 频道二维码保存与分享 | 已通过 | 批次30 | 0 | 0 | 0 | 实测频道二维码页点「保存二维码」→ 相册新增 Pictures/1786148509279.jpg（08:21, 38KB）；点「分享」→ 系统「分享方式」面板弹出（resolver 多目标），未点目标 BACK 关闭；同群侧 savePhoto/SharePlus 机制（channel_qrcode_page.dart 同 repaint_boundary_helper + share_plus） |
| 无待办 | - | `page/qrcode/qrcode_page.dart` | 三个二维码页更多菜单含扫一扫 | 已通过 | 批次30 | 0 | 0 | 0 | 实测群二维码页更多菜单（分享/保存二维码/扫描二维码/取消）→ 点「扫描二维码」→ 相机权限弹窗「始终允许」→ ScannerPage（闪光灯/暂停扫描/切换摄像头/从相册选择 结构完整）；代码证实 group_qrcode_page.dart L262-271 菜单项跳转 ScannerPage，用户/频道侧菜单同构 |
