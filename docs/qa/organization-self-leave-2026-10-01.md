# App 本人退出企业（2026-10-01）

状态：受影响 App 路径验证通过；OA 会话退出和设备验收未完成。源码基于 `22d812eb70a03a62e423d7b02bc69023c8406eea`，后端本人退出语义已由 `e68c6a4c` 实现。

## 行为

企业详情新增「退出企业」：复用现有危险动作确认和 POST offboard 命令；目标 UID 取登录账号，不要求员工抄 ID。Owner 显示移交提示，后端仍是权限与依赖最终裁决。确认取消不请求；409/网络失败保留现有指针与工作区。

成功后清除该账号该企业的展示缓存、当前企业偏好和工作区关系，失效工作区数据与企业入口列表，返回企业列表重新选择。其他企业及个人工作区保留。延迟 mine/default-workspace 响应不能把退出关系重新写回；详情延迟刷新不再播种已退出企业缓存。退出期间换账号或离开页面时仍清理原账号偏好，避免误清新账号界面。

偏好清理采用内存先撤去、持久化再清理；持久化失败不恢复已被服务端撤权的企业，向用户显示清理失败提示。不把该方法用于普通空间切换的失败补偿。

中文与其余九个语言补齐退出、后果、失败与负责人提示文案，生成物由 `dart run slang` 产生；没有手改生成物或新建消息/认证模型。自动测试台账新增一个退出功能点，汇总按现有生成器重算，设备状态明确为待重验。

## 检查

- 本轮 7 个源码/测试文件静态检查：No issues found。
- `organization_leave_widget_test`、`current_organization_store_test`、`organization_detail_hub_widget_test`、`workspace_organization_selection_test`、`workspace_restore_test`：35 PASS，exit 0。日志 `/tmp/gz-app-leave-test.log`。
- 4 个新 Widget 场景：取消；精确本人 POST URL / 409 留在原空间；成功清除指针、缓存、工作区并回企业列表；Owner 不发退出请求。
- 新 Provider 场景：退出前 mine 延迟响应、默认指针延迟响应、退出另一企业保留当前企业。
- HTTP 为本地测试替身、SharedPreferences 为内存后端，未连接真实账号、OA 或生产系统；不能替代真实设备和跨三端接口验收。

## 仍需完成

OA WebView 仍未监听企业退出：需接通会话失效、计时器/签发结果作废、WebView 停止及受控会话退出，不能用隐藏 Tab 或清全站 Cookie 宣称完成。归档/暂停企业详情的本人可达性、资源负责人完整交接 UI、已签名文件链接撤权、客服投产及全部 Internal API 的完整目标仍需继续验证。
