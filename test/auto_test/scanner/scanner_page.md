# `page/scanner/scanner_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/scanner/scanner_page.dart` | 进页延迟启动相机并渲染取景框 | 待重验 | - | 0 | 0 | 0 | |
| 阻塞 | 手动拒绝相机权限后 | `page/scanner/scanner_page.dart` | 权限被拒时显示去设置引导 | 未测 | - | 0 | 0 | 0 | 需构造权限拒绝场景 |
| 阻塞 | 可构造相机启动失败场景后 | `page/scanner/scanner_page.dart` | 启动失败时显示重试按钮 | 未测 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/scanner/scanner_page.dart` | 闪光灯按钮开关并切换图标 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/scanner/scanner_page.dart` | 暂停与继续扫描切换 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/scanner/scanner_page.dart` | 前后摄像头切换 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/scanner/scanner_page.dart` | 相册识图成功提示用二维码口径 | 已通过 | §三十六 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/scanner/scanner_page.dart` | 相册图片未识别出码时红色提示 | 待重验 | - | 0 | 0 | 0 | |
| 阻塞 | 第二台设备出示Web登录码后 | `page/scanner/scanner_page.dart` | 扫到登录码跳转登录确认页 | 未测 | - | 0 | 0 | 0 | 无第二设备，从未实扫 |
| 阻塞 | 第二台设备出示个人二维码后 | `page/scanner/scanner_page.dart` | 扫到用户名片跳转个人资料页 | 未测 | - | 0 | 0 | 0 | 无第二设备，从未实扫 |
| 阻塞 | 第二台设备出示群二维码后 | `page/scanner/scanner_page.dart` | 扫到群码入群并进入群聊页 | 未测 | - | 0 | 0 | 0 | 无第二设备，从未实扫 |
| 阻塞 | 第二台设备出示任意二维码后 | `page/scanner/scanner_page.dart` | 扫到非站内内容跳扫描结果页 | 未测 | - | 0 | 0 | 0 | 无第二设备，从未实扫 |
