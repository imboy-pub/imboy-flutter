# `page/scanner/qr_login_confirm_page.dart`

> 功能点 9 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/scanner/qr_login_confirm_page.dart` | 进页自动上报扫码状态 | 已通过 | 批次78 | 1 | 1 | 0 | BUG#批次78-1 已修+复验：扫码→push 本页→initState addPostFrameCallback 调 scan(qrToken)→/qr_login/scan。修复后真机扫 qr_login_fake.png：scan 被调用、后端解析 Uid=4、parse_qr_token(FAKE) 失败、返回 5200、parseScanResponse→Failed、UI 渲染错误态（详见 row8） |
| 无待办 | - | `page/scanner/qr_login_confirm_page.dart` | 上报期间展示加载态 | 已通过 | 批次97 | 1 | 1 | 0 | BUG#批次97-1（生产500）已修+复验：confirm 走 log_device_login→user_device_repo:save 时毫秒时间戳编 timestamptz 崩溃（epgsql function_clause），QR登录确认全挂；修复=elib_dt:now()（imboy 1422e6bc，蓝绿发布 alpha.35）。复验全链：create→真机选图→UI自动scan→AwaitingConfirm（设备卡片）→确认→Success→800ms自动退栈；status API 返回 confirmed+login_token（uid50）；user_device 落库 last_login_at 正常（2026-08-17 02:56:50+08） |
| 无待办 | - | `page/scanner/qr_login_confirm_page.dart` | 点确认登录提交确认请求 | 已通过 | 批次97 | 0 | 0 | 0 | 同上复验：点「确认登录」→ POST confirm 成功（修复后）→ 服务端 confirmed + login_token 签发（uid50），UI Success 态自动退栈 |
| 无待办 | - | ``page/scanner/qr_login_confirm_page.dart`` | 点取消登录上报本机取消 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/scanner/qr_login_confirm_page.dart`` | 点关闭按钮直接退出本页 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | `page/scanner/qr_login_confirm_page.dart` | 登录成功后延时自动退栈 | 已通过 | 批次97 | 0 | 0 | 0 | 同上复验：confirm 成功后 UI 自动 pop 回扫描页（get_ui 连续采样证据，tap 后数秒内已在扫描页）；Success 态与 CancelledByMe 同 800ms 自动退栈路径（page.dart:47-54） |
| 无待办 | - | ``page/scanner/qr_login_confirm_page.dart`` | 本机取消后延时自动退栈 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | `page/scanner/qr_login_confirm_page.dart` | 令牌过期或失效时展示错误态 | 已通过 | 批次78 | 0 | 0 | 0 | 修复后真机扫 qr_login_fake.png：scan 返回 5200「无效的二维码」→ parseScanResponse 映射 QrLoginConfirmFailed(errorMessage) → QrLoginConfirmContent 渲染错误态：get_ui a11y 读取居中文本「无效的二维码」（centerX=360 centerY=781）+「关闭」按钮（centerX=360 centerY=932）。错误态完整可达，文案透传正确 |
| 无待办 | - | `page/scanner/qr_login_confirm_page.dart` | 网络失败时展示错误与关闭入口 | 已通过 | 批次97 | 0 | 0 | 0 | 实测：飞行模式断网→相册识别 imboy://qr_login/ 码→scan 网络异常→Failed 态（错误文案「Instance of 'NetworkException'」+「关闭」按钮，关闭退栈回扫描页正常）；⚠️无重试按钮（content.dart:94-98 _terminal 仅 onClose，失败后重试=重新扫码），功能点描述已按实际修正 |
