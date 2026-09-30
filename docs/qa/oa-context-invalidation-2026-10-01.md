# OA 宿主上下文失效保护 / OA context invalidation

日期：2026-10-01。基线：`2b773da0c2a4915d74343b29c6d4231854a2eb5e`。

## 本地行为

App 主导航监听当前账号与企业选择。账号、企业、应用 key、重定向地址或允许 origin 变化时，旧 OA 页面进入退出状态，清除签发 URL 与倒计时；旧签发结果和旧页面回调不再打开内容。明确没有账号或企业时不签发 code。签发异常转为可恢复网络错误。

原生 WebView 卸载后拒绝导航与状态回调，并尝试停止页面加载。没有清除全部站点 Cookie，也没有冒充 OA 服务端退出。

## 验证

- `flutter test test/enterprise_oa`：129 项通过，包含新增加的 5 项上下文 / 异常检查。
- `flutter analyze lib/modules/enterprise_oa lib/modules/organization/public.dart lib/page/bottom_navigation/bottom_navigation_page.dart test/enterprise_oa`：无问题。
- `git diff --check`：通过。
- 日志：`/tmp/gz-oa-context-test.log`、`/tmp/gz-oa-context-analyze.log`。

人工检查生产调用入口、结果消费顺序、卸载与倒计时清理、状态机终态。没有独立审计或真机验收。

## 尚未完成

这是宿主失效保护。当前页失效后锁住重新登录，需要后续接入当前企业的服务端应用选择与合法恢复流程；构建时配置尚不能证明属于所选企业。真实 WebView 停止、Cookie / 存储隔离、同源不同企业登录和 OA 服务端退出协议需要真机及端到端验证。本报告不证明完整 OA 协议、全部 Internal API、客服或整体目标可投产。
