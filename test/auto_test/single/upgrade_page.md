# `page/single/upgrade_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 需服务端下发更高版本号 | `page/single/upgrade_page.dart` | 弹出升级卡片展示版本与更新说明 | 未测 | - | 0 | 0 | 0 | 非死页面：`app_upgrade_service.dart:222` 直接 Navigator.push，不走 `/upgrade` 路由 |
| 阻塞 | 需服务端下发更高版本号 | `page/single/upgrade_page.dart` | 点击立即更新申请存储权限 | 未测 | - | 0 | 0 | 0 | Android 13+ 走私有目录跳过权限 |
| 阻塞 | 需服务端下发更高版本号 | `page/single/upgrade_page.dart` | 权限被拒时提示获取失败 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需服务端下发更高版本号 | `page/single/upgrade_page.dart` | 下载中展示进度条与百分比 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需服务端下发更高版本号 | `page/single/upgrade_page.dart` | 下载中展示速度剩余时间与包大小 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需服务端下发更高版本号 | `page/single/upgrade_page.dart` | 点击暂停下载中止当前任务 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需服务端下发更高版本号 | `page/single/upgrade_page.dart` | 点击继续下载恢复断点任务 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需服务端下发更高版本号 | `page/single/upgrade_page.dart` | 下载失败后可重新发起下载 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需服务端下发更高版本号 | `page/single/upgrade_page.dart` | 下载完成校验哈希后触发安装 | 未测 | - | 0 | 0 | 0 | fileHash 为空时直接安装 |
| 阻塞 | 需服务端下发更高版本号 | `page/single/upgrade_page.dart` | 校验失败删除文件并重试两次 | 未测 | - | 0 | 0 | 0 | 超限提示失败并复位计数 |
| 阻塞 | 需服务端下发更高版本号 | `page/single/upgrade_page.dart` | 点击稍后提醒关闭并取消下载 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需服务端下发强制更新版本 | `page/single/upgrade_page.dart` | 强制更新时禁止返回键关闭弹窗 | 未测 | - | 0 | 0 | 0 | PopScope canPop=false |
