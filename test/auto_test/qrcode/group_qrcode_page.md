# `page/qrcode/group_qrcode_page.dart`

> 功能点 11 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/qrcode/group_qrcode_page.dart` | 无名群名走 displayTitle 兜底 | 已通过 | 批次22 | 1 | 1 | 0 | |
| 无待办 | - | `page/qrcode/group_qrcode_page.dart` | 保存二维码到相册并提示结果 | 已通过 | 批次22 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/qrcode/group_qrcode_page.dart` | 生成带有效期与签名的二维码 | 已通过 | 批次64 | 0 | 0 | 0 | 代码确认 L47-49 qrcodeData=`${apiBaseUrl}/group/qrcode?id=${groupId}&exp=${now+7d}&tk=md5(exp_solidifiedKey)&$qrcodeDataSuffix`（7 天有效+签名）；批次30 真机群二维码页二维码渲染 |
| 回归复测 | 2026-08-07 | `page/qrcode/group_qrcode_page.dart` | 展示群头像合成九宫格图 | 已通过 | 批次64 | 0 | 0 | 0 | 代码确认 L76-81 SmartGroupAvatar(avatarLoader:_loadGroupMemberAvatars L34-41 取前9个成员头像合成九宫格)；批次30 真机群二维码页头像位渲染 |
| 回归复测 | 2026-08-07 | `page/qrcode/group_qrcode_page.dart` | 展示七天有效期与到期日期 | 已通过 | 批次64 | 0 | 0 | 0 | 批次30 真机目击 footer「该二维码7天内（2026-08-15前）有效」+ L96-101 footerText=groupQrcodeTips(days,date)+DateFormat('y-MM-dd') |
| 回归复测 | 2026-08-07 | `page/qrcode/group_qrcode_page.dart` | 点分享按钮唤起系统分享面板 | 已通过 | 批次64 | 0 | 0 | 0 | 批次30 真机：底部「分享」→ 系统「分享方式」面板弹出（resolver 多目标），未点目标 BACK 关闭（L282-292 _shareGroupQrCode：RepaintBoundaryHelper().image + SharePlus） |
| 回归复测 | 2026-08-07 | `page/qrcode/group_qrcode_page.dart` | 点右上更多弹出操作表 | 已通过 | 批次64 | 0 | 0 | 0 | 批次30 真机：右上角更多 (644,98) → CupertinoActionSheet（分享/保存二维码/扫描二维码/取消）（L55-63 ellipsis_circle + L243-280 _showGroupBottomSheet） |
| 回归复测 | 2026-08-07 | `page/qrcode/group_qrcode_page.dart` | 操作表内分享二维码 | 已通过 | 批次64 | 0 | 0 | 0 | 批次30 真机：操作表点分享 → SharePlus 系统分享面板弹出（L248-254 复用 _shareGroupQrCode） |
| 回归复测 | 2026-08-07 | `page/qrcode/group_qrcode_page.dart` | 操作表内保存二维码 | 已通过 | 批次64 | 0 | 0 | 0 | 批次30 真机：操作表点保存二维码 → 相册新增 Pictures/1786148309046.jpg（08:18, 79KB）落盘（L255-261 复用 _saveGroupQrCode savePhoto） |
| 回归复测 | 2026-08-07 | `page/qrcode/group_qrcode_page.dart` | 操作表内跳转扫一扫页面 | 已通过 | 批次64 | 0 | 0 | 0 | 批次30 真机：操作表点扫描二维码 → 相机权限弹窗 → ScannerPage 进入（L262-271 Navigator.push ScannerPage） |
| 无待办 | - | `page/qrcode/group_qrcode_page.dart` | 分享卡固定白底黑字不随主题 | 已通过 | 批次30 | 0 | 0 | 0 | 实测切深色模式（设置→深色模式→已开启）后群二维码页正常渲染（标题/群名/二维码/有效期/保存分享按钮结构完整）；颜色不随主题=新增 widget 测试 GQ-3 断言（暗色 ThemeData 下分享卡 Container color==Colors.white + 群名 color==Colors.black）+ 代码证实 L90/L124 写死 Colors.black/white（注释：分享二维码为固定外观白底黑字，刻意不随明暗主题切换）；测试后已切回浅色模式 |
