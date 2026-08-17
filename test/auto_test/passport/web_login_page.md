# `page/passport/web_login_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | 需 Web 平台运行（移动端 isWide+kIsWeb 双重门刻意不可达，非双机依赖） | `page/passport/web_login_page.dart` | 进页自动生成登录二维码 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 Web 实测：qr_login/create 200 + UI 渲染（生产 web 已部署 2026-08-17） |
| 无待办 | 需 Web 平台运行（移动端 isWide+kIsWeb 双重门刻意不可达，非双机依赖） | `page/passport/web_login_page.dart` | 倒计时递减并切换过期态 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 Web 实测：39s 时刻显示「43 秒后过期」递减→91s 过期覆盖层「二维码已过期」 |
| 阻塞 | 需 Web 平台运行（移动端 isWide+kIsWeb 双重门刻意不可达，非双机依赖） | `page/passport/web_login_page.dart` | 过期或失败时刷新二维码 | 未测 | 批次106 | 0 | 0 | 0 | 批次106 部分验证：过期态+「刷新二维码」按钮渲染确认；点击刷新行为待真机/可交互环境（Playwright 合成点击对 Flutter Web 无效） |
| 阻塞 | 需 Web 平台运行（移动端 isWide+kIsWeb 双重门刻意不可达，非双机依赖） | `page/passport/web_login_page.dart` | 展示已扫码待手机确认态 | 未测 | 批次106 | 0 | 0 | 0 | 批次106 Web 已部署；此点需手机 App 扫码配合 |
| 阻塞 | 需 Web 平台运行（移动端 isWide+kIsWeb 双重门刻意不可达，非双机依赖） | `page/passport/web_login_page.dart` | 确认后完成登录跳 Web Shell | 未测 | 批次106 | 0 | 0 | 0 | 批次106 Web 已部署；此点需手机 App 扫码配合 |
| 无待办 | 需 Web 平台运行（移动端 isWide+kIsWeb 双重门刻意不可达，非双机依赖） | `page/passport/web_login_page.dart` | SSE 不可用时降级为轮询 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 Web 实测：subscribe 失败后自动转 status 2s 间隔轮询（headless 天然构造 SSE 不可用） |
| 阻塞 | 需 Web 平台运行（移动端 isWide+kIsWeb 双重门刻意不可达，非双机依赖） | `page/passport/web_login_page.dart` | 切到密码登录并停止轮询 | 未测 | 批次106 | 0 | 0 | 0 | 批次106 Web 部署后 UI 入口可见（过期态见「使用账号密码登录」链接）；交互验证待真机（合成输入失效） |
| 阻塞 | 需 Web 平台运行（移动端 isWide+kIsWeb 双重门刻意不可达，非双机依赖） | `page/passport/web_login_page.dart` | 切回扫码登录并重新生成码 | 未测 | 批次106 | 0 | 0 | 0 | 批次106 Web 部署后 UI 入口可见（过期态见「使用账号密码登录」链接）；交互验证待真机（合成输入失效） |
| 阻塞 | 需 Web 平台运行（移动端 isWide+kIsWeb 双重门刻意不可达，非双机依赖） | `page/passport/web_login_page.dart` | 拦截账号或密码为空并提示 | 未测 | 批次106 | 0 | 0 | 0 | 批次106 Web 部署后 UI 入口可见（过期态见「使用账号密码登录」链接）；交互验证待真机（合成输入失效） |
| 阻塞 | 需 Web 平台运行（移动端 isWide+kIsWeb 双重门刻意不可达，非双机依赖） | `page/passport/web_login_page.dart` | 提交密码登录并跳 Web Shell | 未测 | 批次106 | 0 | 0 | 0 | 批次106 Web 已部署；此点需手机 App 扫码配合 |
| 阻塞 | 需 Web 平台运行（移动端 isWide+kIsWeb 双重门刻意不可达，非双机依赖） | `page/passport/web_login_page.dart` | 切换密码框明文与密文 | 未测 | 批次106 | 0 | 0 | 0 | 批次106 Web 部署后 UI 入口可见（过期态见「使用账号密码登录」链接）；交互验证待真机（合成输入失效） |
| 阻塞 | 需 Web 平台运行（移动端 isWide+kIsWeb 双重门刻意不可达，非双机依赖） | `page/passport/web_login_page.dart` | 跳转忘记密码页 | 未测 | 批次106 | 0 | 0 | 0 | 批次106 Web 部署后 UI 入口可见（过期态见「使用账号密码登录」链接）；交互验证待真机（合成输入失效） |
