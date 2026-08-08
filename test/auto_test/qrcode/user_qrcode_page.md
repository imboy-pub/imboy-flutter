# `page/qrcode/user_qrcode_page.dart`

> 功能点 10 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/qrcode/user_qrcode_page.dart` | 名片卡渲染头像昵称地区性别 | 已通过 | 批次64 | 0 | 0 | 0 | 真机「我的二维码」页：头像+昵称 117+地区「北京 朝阳」渲染；性别 117 未设置不显示（L89 gender>0 才渲染，条件正确） |
| 回归复测 | 2026-08-07 | `page/qrcode/user_qrcode_page.dart` | 二维码内容携带uid与固定后缀 | 已通过 | 批次64 | 1 | 1 | 0 | BUG#143：URL 漏 /api/v1 段（apiBaseUrl 裸域名 + 直接拼 /user/qrcode），双真机首次扫码实锤——iPhone 16e 扫 Android 二维码报「错误」（裸路径 404 → errorFailedConnectServer=common.error）；已修 375a8f29（user/channel/group 三处拼接收敛 qrcode_url.dart 补 /api/v1 + 3 单测，analyze 零 issues），待新 APK 真机复验 |
| 回归复测 | 2026-08-07 | `page/qrcode/user_qrcode_page.dart` | 二维码中心嵌入品牌Logo | 已通过 | 批次64 | 0 | 0 | 0 | 代码确认 L142-156 二维码内嵌 assets/images/imboy_logo0.png 品牌 Logo；真机二维码中心可见 Logo 位 |
| 无待办 | - | `page/qrcode/user_qrcode_page.dart` | 保存到相册成功后弹成功提示 | 已通过 | 批次22 | 0 | 0 | 0 | |
| 待复验 | 2026-08-06 | `page/qrcode/user_qrcode_page.dart` | 保存到相册失败时给出可见反馈 | BUG已修待验 | 批次22 | 1 | 1 | 0 | BUG#87 已收口进 savePhoto，失败路径尚无真机证据 |
| 回归复测 | 2026-08-07 | `page/qrcode/user_qrcode_page.dart` | 分享按钮导出二维码图片分享 | 已通过 | 批次64 | 0 | 0 | 0 | 真机点页面底部「分享」→ 系统「分享方式」面板弹出（保存到QQ收藏/电子邮件/发送到我的电脑/发送给好友/蓝牙/面对面快传/添加到微信收藏/Huawei Share/WLAN直连/WPS Office），未点目标 BACK 关闭 |
| 无待办 | - | `page/qrcode/user_qrcode_page.dart` | 更多菜单分享入口触发分享 | 已通过 | 批次30 | 0 | 0 | 0 | 实测深链进 /qrcode/user → 右上角更多 (644,98) → CupertinoActionSheet（分享/保存二维码/扫描二维码/取消）→ 点分享 → SharePlus 系统「分享方式」面板弹出（resolver 多目标），未点任何目标 BACK 关闭（_showBottomSheet L241-278 + _shareQrCode L280-290） |
| 无待办 | - | `page/qrcode/user_qrcode_page.dart` | 更多菜单保存入口触发保存 | 已通过 | 批次30 | 0 | 0 | 0 | 实测更多菜单点「保存二维码」→ 相册新增 Pictures/1786148769845.jpg（08:26, 66KB）落盘硬证据（_saveQrCode L292-301 savePhoto + saveSuccess toast；成功提示 EasyLoading 不进语义树） |
| 无待办 | - | `page/qrcode/user_qrcode_page.dart` | 更多菜单扫一扫入口跳扫码页 | 已通过 | 批次30 | 0 | 0 | 0 | 实测更多菜单点「扫描二维码」→ ScannerPage 进入（打开闪光灯/暂停扫描/切换摄像头/从相册选择 结构完整，代码 L260-266 Navigator.push ScannerPage） |
| 回归复测 | 2026-08-07 | `page/qrcode/user_qrcode_page.dart` | 分享卡固定白底黑字不随暗色变 | 已通过 | 批次64 | 0 | 0 | 0 | 代码确认 L73/L117-118 分享卡恒白底黑字（意图注释：导出/分享为固定外观图片，刻意不随明暗主题切换）；亮色主题下目击分享卡白底 |
