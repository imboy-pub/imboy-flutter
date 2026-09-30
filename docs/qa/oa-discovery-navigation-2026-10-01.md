# 企业 OA 配置与导航 / OA discovery and navigation

日期：2026-10-01。App 基线：`fa291ff0`；后端依赖：`1b0ba8a4`。

App 以 Human 认证读取 `GET /api/v1/workbench/entries?organization_id=...`，严格消费当前企业条目。复用既有 OA 配置模型与 HTTPS origin 策略，拒绝其他企业、userinfo、fragment、非 HTTPS 与非法配置，上限 20。配置 provider 使用账号与企业复合键，未登录 / 账号不匹配不查询，旧 scope 的迟到响应不能覆盖当前 scope。

手机主导航根据服务端配置显示 OA 入口，标准构建也可使用；白标配置仅在当前企业返回的应用 key 与 redirect 精确匹配时优先选择，不绕过成员授权。单应用直接进入，多应用先展示原生选择列表，不自动取第一项。无配置隐藏入口，读取失败提示重试；macOS / Web 不读取及展示 OA。配置增减时处理「我」与 OA 的下标变化。

页面 key 绑定账号、企业、应用和 redirect。新企业验证成功后创建新 OA 页面重新签发；旧页卸载仍使用先前的结果 / 回调失效保护。同一页面在 PageView 中保活，切到远端 Tab 再返回不重新签发。

## 本地检查

- `flutter test test/enterprise_oa test/unit_test/page/bottom_navigation/bottom_navigation_page_test.dart`：155 项通过（OA 138、原导航 17），0 跳过。
- `flutter analyze lib/modules/enterprise_oa lib/page/bottom_navigation/bottom_navigation_page.dart test/enterprise_oa`：无问题。
- `git diff --check`：通过。
- 日志：`/tmp/gz-oa-discovery-test.log`、`/tmp/gz-oa-discovery-analyze.log`。

新增检查覆盖真实请求路径 / 企业 query（adapter 合成响应）、跨企业响应过滤、错误 URL 拒绝、配置上限、迟到响应、未登录、OA 保活；导航注册另有源码接线检查。原导航用例是下标纯函数检查，不证明新增整个主导航旅程已经端到端运行。

## 未完成

没有真实 OA 或真机验证。OA Cookie / 存储隔离、服务端退出、服务器主动撤权后的会话收敛仍需闭环；完整主导航的异步刷新、错误重试、多应用选择与实际 WebView 旅程需要端到端验证。不能据此宣称整体客服、企业治理及全部 Internal API 已投产。
