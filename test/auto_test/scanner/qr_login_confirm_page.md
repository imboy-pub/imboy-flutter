# `page/scanner/qr_login_confirm_page.dart`

> 功能点 9 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 待修复 | 2026-08-13（解阻塞条件：BUG#批次78-1 已发布+装新APK） | `page/scanner/qr_login_confirm_page.dart` | 进页自动上报扫码状态 | 有BUG待修 | 批次78 | 1 | 0 | 1 | 真机扫 qr_login_fake.png 替代第二台设备，push 本页成功，initState 调 scan(qrToken)；scan API 返回 401「未登录」（后端 BUG#批次78-1：scan 误在 router.open 白名单 → handler Uid 恒 0）。前端 _checkAuthExpired 触发 quitLogin → 删本地 pro_4.db；本页 9 行依赖 scan 成功才能验证，待修后整体复验 |
| 阻塞 | 同上 row1 解阻塞条件 | `page/scanner/qr_login_confirm_page.dart` | 上报期间展示加载态 | 未测 | - | 0 | 0 | 0 | 依赖 row1 修后可达 Scanning 态 |
| 阻塞 | 同上 row1 解阻塞条件 | `page/scanner/qr_login_confirm_page.dart` | 点确认登录提交确认请求 | 未测 | - | 0 | 0 | 0 | 依赖 row1 修后到达 AwaitingConfirm |
| 阻塞 | 同上 row1 解阻塞条件 | `page/scanner/qr_login_confirm_page.dart` | 点取消登录上报本机取消 | 未测 | - | 0 | 0 | 0 | 依赖 row1 修后页面可达；cancelByMe 不调后端，单机可测 |
| 阻塞 | 同上 row1 解阻塞条件 | `page/scanner/qr_login_confirm_page.dart` | 点关闭按钮直接退出本页 | 未测 | - | 0 | 0 | 0 | 依赖 row1 修后页面可达 |
| 阻塞 | 同上 row1 解阻塞条件 | `page/scanner/qr_login_confirm_page.dart` | 登录成功后延时自动退栈 | 未测 | - | 0 | 0 | 0 | 依赖 row1+真实 Web 端二维码（需双端闭环） |
| 阻塞 | 同上 row1 解阻塞条件 | `page/scanner/qr_login_confirm_page.dart` | 本机取消后延时自动退栈 | 未测 | - | 0 | 0 | 0 | 依赖 row1 修后页面可达；cancelByMe 后 800ms pop，单机可测 |
| 阻塞 | 同上 row1 解阻塞条件 | `page/scanner/qr_login_confirm_page.dart` | 令牌过期或失效时展示错误态 | 未测 | - | 0 | 0 | 0 | 修后用 fake token 可触发 Expired/Failed 态 |
| 阻塞 | 同上 row1 解阻塞条件 | `page/scanner/qr_login_confirm_page.dart` | 网络失败时展示错误与重试入口 | 未测 | - | 0 | 0 | 0 | 依赖 row1 修后页面可达，断网构造 |
