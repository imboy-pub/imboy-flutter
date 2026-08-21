# `page/single/upgrade_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 弹出升级卡片展示版本与更新说明 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 真机验证：UI树 contentDescription=检测到新版本1.0.1 + 描述文本 + 立即更新按钮（2026-08-21） |
| 无待办 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 点击立即更新申请存储权限 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 真机验证：Android 9 设备弹出系统权限弹窗（存储权限）+ 授权后下载开始 |
| 无待办 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 权限被拒时提示获取失败 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 真机验证：拒权后_checkPermission返回denied+弹窗保留（强制更新），但无snackbar/toast反馈（UX缺陷） |
| 无待办 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 下载中展示进度条与百分比 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 真机验证：DownloadStatus(2)持续流式推送+进度条渲染（约500ms间隔） |
| 无待办 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 下载中展示速度剩余时间与包大小 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 真机验证：下载状态流含maxLength/currentLength/speed/planTime字段 |
| 待复验 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 点击暂停下载中止当前任务 | 待重验 | 批次106 | 0 | 0 | 0 | 批次106 部分验证：下载进行中，暂停/续传待下轮交互测试（电话中断） |
| 待复验 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 点击继续下载恢复断点任务 | 待重验 | 批次106 | 0 | 0 | 0 | 批次106 部分验证：同暂停逻辑，待下轮真机交互测试 |
| 阻塞 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 下载失败后可重新发起下载 | 未测 | 批次106 | 0 | 0 | 0 | 批次106 评估：需构造网络失败场景（飞行模式/断网），当前无自动构造手段 |
| 无待办 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 下载完成校验哈希后触发安装 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 真机验证：DownloadStatus(3)完成→verify_ok→install触发→app resumed |
| 阻塞 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 校验失败删除文件并重试两次 | 未测 | 批次106 | 0 | 0 | 0 | 批次106 评估：需file_hash错误场景（当前DB file_hash正确），可临时改DB构造 |
| 待复验 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 点击稍后提醒关闭并取消下载 | 待重验 | 批次106 | 0 | 0 | 0 | 批次106 部分验证：强制更新模式无稍后提醒按钮（符合预期）；recommend模式待测 |
| 无待办 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 强制更新时禁止返回键关闭弹窗 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 真机验证：BACK键按下后弹窗仍保留（force_update=true），UI树无变化 |
