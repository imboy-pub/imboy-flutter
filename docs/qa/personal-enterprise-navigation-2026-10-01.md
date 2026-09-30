# 个人与企业主导航 / Personal and enterprise navigation

## 实现范围 / Scope

基线：`c67bdbcccbfbc92e9aa04d0dd9274fa3803b89d8`。

- 个人移动端及桌面标签统一为「消息、通讯录、频道、我」。OA 不再因为本地记住企业而插入个人底栏。频道入口继续遵循产品能力开关，页面与导航采用相同可用性条件。
- 已选择企业的工作区壳使用「消息、通讯录、我」；仅 Android/iOS 当前企业服务器授权有效 OA 时插入「工作台」。普通非企业工作区保持既有导航。
- 企业消息页内切换群聊/频道；通讯录复用组织部门与成员浏览。企业「我」保留个人设置，并提供企业详情、工作区成员、群组及已启用项目入口；权限由现有服务端及治理页面验证。
- 账号、企业、工作区切换重建企业壳；目的地具备稳定 Key。页面按需挂载，只有点击工作台应用后才创建 OA SSO/WebView。配置重新加载或失败撤下旧入口，有显式重试按钮。
- 工作区数据 Provider 依赖当前账号；退出账号不读取组织资源。消息页隐藏时停止主动重拉，恢复时在当前帧之后刷新，避免构建中修改 Provider。

English summary: Personal navigation has four product destinations and no OA tab. Enterprise navigation has three destinations, or four when mobile OA discovery authorizes valid entries. The existing directory and workspace resource pages are reused. OA starts only after an explicit application selection. Account and scope changes discard old page state; unavailable OA configurations do not remain navigable.

## 本地验证 / Local verification

```
flutter test --no-pub --concurrency=1 \
  test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart \
  test/unit_test/page/workspace_shell/workspace_shell_page_test.dart \
  test/unit_test/page/workspace/workspace_conversations_page_test.dart \
  test/unit_test/page/bottom_navigation/bottom_navigation_page_test.dart \
  test/unit_test/page/chat_shell/chat_shell_nav_items_test.dart \
  test/enterprise_oa/oa_workbench_provider_test.dart \
  test/enterprise_oa/oa_workbench_api_test.dart
```

53 tests passed. 新增用例使用实际壳组件及合成 API 响应，验证三/四项导航、默认消息、按需通讯录、工作台未选应用不启动 SSO、切换企业后迟到响应、配置错误撤下入口、频道次级入口、桌面无 OA 请求、换账号频道隔离及登出资源清空。

受影响源码和新增测试 `dart analyze`：No issues found。`git diff --check` 通过。翻译由项目已有 slang generator 生成；未改动依赖文件。手动审查了调用方、异步刷新、模块导出和账号作用域；没有独立审查代理结果。

## 未关闭的交付门 / Remaining gates

这份证据仅覆盖本地导航组件和相关状态回归。个人完整四子页的运行截图、Android/iOS 真机视觉/触达验证、真实 OA SSO/WebView 联调、全目标六项的冻结候选验收和生产投产均未完成。企业专用「我」的更精简内容、统一个人/企业空间选择器及企业消息/资料治理闭环仍需继续收敛，不以这轮导航变更宣称可投产。

English: Local tests are not device, external OA or production evidence. The complete six-part delivery remains active.
