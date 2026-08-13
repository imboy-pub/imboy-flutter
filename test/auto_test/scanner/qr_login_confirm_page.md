# `page/scanner/qr_login_confirm_page.dart`

> 功能点 9 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/scanner/qr_login_confirm_page.dart` | 进页自动上报扫码状态 | 已通过 | 批次78 | 1 | 1 | 0 | BUG#批次78-1 已修+复验：扫码→push 本页→initState addPostFrameCallback 调 scan(qrToken)→/qr_login/scan。修复后真机扫 qr_login_fake.png：scan 被调用、后端解析 Uid=4、parse_qr_token(FAKE) 失败、返回 5200、parseScanResponse→Failed、UI 渲染错误态（详见 row8） |
| 阻塞 | 修复后到达 AwaitingConfirm 态需真实 Web 端二维码（双端闭环） | `page/scanner/qr_login_confirm_page.dart` | 上报期间展示加载态 | 未测 | - | 0 | 0 | 0 | fake token 直接进 Failed 态，跳过 Scanning→AwaitingConfirm；要测 loading 需真实 Web 端 create 出的 qr_token（双端闭环） |
| 阻塞 | 修复后到达 AwaitingConfirm 需真实 Web 端二维码 | `page/scanner/qr_login_confirm_page.dart` | 点确认登录提交确认请求 | 未测 | - | 0 | 0 | 0 | confirm 在 scan=scanned 之后才可达；fake token 流程在 scan 阶段就 Failed，confirm 不可达 |
| 回归复测 | 2026-08-13 | `page/scanner/qr_login_confirm_page.dart` | 点取消登录上报本机取消 | 待重验 | 批次78 | 0 | 0 | 0 | 修复后页面可达，下轮补测 cancelByMe（不调后端，单机可测） |
| 回归复测 | 2026-08-13 | `page/scanner/qr_login_confirm_page.dart` | 点关闭按钮直接退出本页 | 待重验 | 批次78 | 0 | 0 | 0 | 修复后页面可达，「关闭」按钮已可见（centerX=360 centerY=932），下轮补测点按 pop |
| 阻塞 | 真实 Web 端二维码（双端闭环） | `page/scanner/qr_login_confirm_page.dart` | 登录成功后延时自动退栈 | 未测 | - | 0 | 0 | 0 | Success 态需真实成功 confirm，双端闭环 |
| 回归复测 | 2026-08-13 | `page/scanner/qr_login_confirm_page.dart` | 本机取消后延时自动退栈 | 待重验 | 批次78 | 0 | 0 | 0 | 修复后页面可达，下轮补测 cancelByMe→800ms pop |
| 无待办 | - | `page/scanner/qr_login_confirm_page.dart` | 令牌过期或失效时展示错误态 | 已通过 | 批次78 | 0 | 0 | 0 | 修复后真机扫 qr_login_fake.png：scan 返回 5200「无效的二维码」→ parseScanResponse 映射 QrLoginConfirmFailed(errorMessage) → QrLoginConfirmContent 渲染错误态：get_ui a11y 读取居中文本「无效的二维码」（centerX=360 centerY=781）+「关闭」按钮（centerX=360 centerY=932）。错误态完整可达，文案透传正确 |
| 阻塞 | 断网构造 | `page/scanner/qr_login_confirm_page.dart` | 网络失败时展示错误与重试入口 | 未测 | - | 0 | 0 | 0 | 需断网构造 scan 网络异常，单机可测但需切网络 |
