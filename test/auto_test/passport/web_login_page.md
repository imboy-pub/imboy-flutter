# `page/passport/web_login_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | 需 Web 平台运行（移动端 isWide+kIsWeb 双重门刻意不可达，非双机依赖） | `page/passport/web_login_page.dart` | 进页自动生成登录二维码 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 Web 实测：qr_login/create 200 + UI 渲染（生产 web 已部署 2026-08-17） |
| 无待办 | 需 Web 平台运行（移动端 isWide+kIsWeb 双重门刻意不可达，非双机依赖） | `page/passport/web_login_page.dart` | 倒计时递减并切换过期态 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 Web 实测：39s 时刻显示「43 秒后过期」递减→91s 过期覆盖层「二维码已过期」 |
| 无待办 | - | `page/passport/web_login_page.dart` | 过期或失败时刷新二维码 | 已通过 | 批次126 | 0 | 0 | 0 | AT-WL07 macOS 集成测试：真 60s 过期→刷新→新码回 waiting；Playwright 合成点击无效的定性翻案——tester.tap 是真实 Flutter 命中事件 |
| 无待办 | - | `page/passport/web_login_page.dart` | 展示已扫码待手机确认态 | 已通过 | 批次126 | 0 | 0 | 0 | AT-WL06 FlowApiClient 登录 51730 充当手机端 POST scan，Web 端 2s 轮询感知切 scanned 态；「需手机配合」定性翻案 |
| 无待办 | - | `page/passport/web_login_page.dart` | 确认后完成登录跳 Web Shell | 已通过 | 批次126 | 1 | 1 | 0 | AT-WL06 confirm→轮询拿一次性 login_token+uid→落地登录态→跳 /web_shell；挖出并修复 QR 登录只写 token 不写 currentUid 的真 bug（守卫弹回登录页），服务端 status 响应补 uid+客户端透传落地 |
| 无待办 | 需 Web 平台运行（移动端 isWide+kIsWeb 双重门刻意不可达，非双机依赖） | `page/passport/web_login_page.dart` | SSE 不可用时降级为轮询 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 Web 实测：subscribe 失败后自动转 status 2s 间隔轮询（headless 天然构造 SSE 不可用） |
| 无待办 | - | `page/passport/web_login_page.dart` | 切到密码登录并停止轮询 | 已通过 | 批次125 | 0 | 0 | 0 | AT-WL01 切换成功+密码区渲染；停止轮询为内部 timer 行为未直测（状态机活性由 WL06 反向覆盖） |
| 无待办 | - | `page/passport/web_login_page.dart` | 切回扫码登录并重新生成码 | 已通过 | 批次126 | 0 | 0 | 0 | AT-WL01 切回调 generateQRCode，qr_login/create 真请求新码 |
| 无待办 | - | `page/passport/web_login_page.dart` | 拦截账号或密码为空并提示 | 已通过 | 批次126 | 1 | 1 | 0 | AT-WL03 挖出并修复提示缺失真 bug：setError 写 state.error 但密码区无渲染位；补 error 文本渲染 |
| 无待办 | - | `page/passport/web_login_page.dart` | 提交密码登录并跳 Web Shell | 已通过 | 批次126 | 0 | 0 | 0 | AT-WL04 真登录 51730→/web_shell |
| 无待办 | - | `page/passport/web_login_page.dart` | 切换密码框明文与密文 | 已通过 | 批次126 | 0 | 0 | 0 | AT-WL02 eye/eye_slash obscureText 切换 |
| 无待办 | - | `page/passport/web_login_page.dart` | 跳转忘记密码页 | 已通过 | 批次126 | 0 | 0 | 0 | AT-WL05 ForgotPasswordPage |
