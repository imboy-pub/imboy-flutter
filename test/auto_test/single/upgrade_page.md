# `page/single/upgrade_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 待复验 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 弹出升级卡片展示版本与更新说明 | 待重验 | - | 0 | 0 | 0 | 服务端已就绪：生产已下发1.0.1(recommend)+dl链接+sha256(端到端已验)；待真机弹卡验证。原备注：非死页面：`app_upgrade_service.dart:222` 直接 Navigator.push，不走 `/upgrade` 路由 |
| 待复验 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 点击立即更新申请存储权限 | 待重验 | - | 0 | 0 | 0 | 服务端已就绪：生产已下发1.0.1(recommend)+dl链接+sha256(端到端已验)；待真机弹卡验证。原备注：Android 13+ 走私有目录跳过权限 |
| 待复验 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 权限被拒时提示获取失败 | 待重验 | - | 0 | 0 | 0 | 服务端已就绪：生产已下发1.0.1(recommend)+dl链接+sha256(端到端已验)；待真机弹卡验证。 |
| 待复验 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 下载中展示进度条与百分比 | 待重验 | - | 0 | 0 | 0 | 服务端已就绪：生产已下发1.0.1(recommend)+dl链接+sha256(端到端已验)；待真机弹卡验证。 |
| 待复验 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 下载中展示速度剩余时间与包大小 | 待重验 | - | 0 | 0 | 0 | 服务端已就绪：生产已下发1.0.1(recommend)+dl链接+sha256(端到端已验)；待真机弹卡验证。 |
| 待复验 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 点击暂停下载中止当前任务 | 待重验 | - | 0 | 0 | 0 | 服务端已就绪：生产已下发1.0.1(recommend)+dl链接+sha256(端到端已验)；待真机弹卡验证。 |
| 待复验 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 点击继续下载恢复断点任务 | 待重验 | - | 0 | 0 | 0 | 服务端已就绪：生产已下发1.0.1(recommend)+dl链接+sha256(端到端已验)；待真机弹卡验证。 |
| 待复验 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 下载失败后可重新发起下载 | 待重验 | - | 0 | 0 | 0 | 服务端已就绪：生产已下发1.0.1(recommend)+dl链接+sha256(端到端已验)；待真机弹卡验证。 |
| 待复验 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 下载完成校验哈希后触发安装 | 待重验 | - | 0 | 0 | 0 | 服务端已就绪：生产已下发1.0.1(recommend)+dl链接+sha256(端到端已验)；待真机弹卡验证。原备注：fileHash 为空时直接安装 |
| 待复验 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 校验失败删除文件并重试两次 | 待重验 | - | 0 | 0 | 0 | 服务端已就绪：生产已下发1.0.1(recommend)+dl链接+sha256(端到端已验)；待真机弹卡验证。原备注：超限提示失败并复位计数 |
| 待复验 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 点击稍后提醒关闭并取消下载 | 待重验 | - | 0 | 0 | 0 | 服务端已就绪：生产已下发1.0.1(recommend)+dl链接+sha256(端到端已验)；待真机弹卡验证。 |
| 待复验 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 强制更新时禁止返回键关闭弹窗 | 待重验 | - | 0 | 0 | 0 | 服务端已就绪：测此条时UPDATE id=9001 SET force_update=true（或min_supported_vsn=1.0.1）即可构造强制场景。原备注：PopScope canPop=false |
