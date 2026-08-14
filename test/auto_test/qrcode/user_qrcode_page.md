# `page/qrcode/user_qrcode_page.dart`

> 功能点 10 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | ``page/qrcode/user_qrcode_page.dart`` | 名片卡渲染头像昵称地区性别 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/qrcode/user_qrcode_page.dart`` | 二维码内容携带uid与固定后缀 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/qrcode/user_qrcode_page.dart`` | 二维码中心嵌入品牌Logo | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | `page/qrcode/user_qrcode_page.dart` | 保存到相册成功后弹成功提示 | 已通过 | 批次22 | 0 | 0 | 0 | |
| 无待办 | - | `page/qrcode/user_qrcode_page.dart` | 保存到相册失败时给出可见反馈 | 已通过 | 批次66 | 1 | 1 | 0 | BUG#87 失败反馈代码收口核验通过（savePhoto 异常路径 showError+返回false L62-67/L75-78；截图异常 try-catch L52-56）；真机授权后点保存走正常路径不跳转（PhotoManager.saveImage）；新发现：repaint_boundary L29 用 Permission.storage.isGranted 只判不请求，未授权时 openAppSettings 跳系统设置页（属权限请求策略，非BUG#87范畴） |
| 无待办 | - | ``page/qrcode/user_qrcode_page.dart`` | 分享按钮导出二维码图片分享 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | `page/qrcode/user_qrcode_page.dart` | 更多菜单分享入口触发分享 | 已通过 | 批次30 | 0 | 0 | 0 | 实测深链进 /qrcode/user → 右上角更多 (644,98) → CupertinoActionSheet（分享/保存二维码/扫描二维码/取消）→ 点分享 → SharePlus 系统「分享方式」面板弹出（resolver 多目标），未点任何目标 BACK 关闭（_showBottomSheet L241-278 + _shareQrCode L280-290） |
| 无待办 | - | `page/qrcode/user_qrcode_page.dart` | 更多菜单保存入口触发保存 | 已通过 | 批次30 | 0 | 0 | 0 | 实测更多菜单点「保存二维码」→ 相册新增 Pictures/1786148769845.jpg（08:26, 66KB）落盘硬证据（_saveQrCode L292-301 savePhoto + saveSuccess toast；成功提示 EasyLoading 不进语义树） |
| 无待办 | - | `page/qrcode/user_qrcode_page.dart` | 更多菜单扫一扫入口跳扫码页 | 已通过 | 批次30 | 0 | 0 | 0 | 实测更多菜单点「扫描二维码」→ ScannerPage 进入（打开闪光灯/暂停扫描/切换摄像头/从相册选择 结构完整，代码 L260-266 Navigator.push ScannerPage） |
| 无待办 | - | ``page/qrcode/user_qrcode_page.dart`` | 分享卡固定白底黑字不随暗色变 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
