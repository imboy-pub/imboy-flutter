# 企业导航恢复与 OA 配置刷新

状态：本地专项 PASS；六项目标仍为 PARTIAL。

企业首页原把当前标签及群／频道选择存放在页面 State，离开页面或换工作区后就丢失。现在在既有 WorkspaceShellState 内只保存导航选择，按企业 ID 与工作区 ID 区分；账号 UID 变化仍由原 build 链路整体重置。退出企业时删除该企业的所有导航记录。不缓存页面实例、目录数据、WebView、SSO 会话或新持久化文件。

重新进入企业时从当前范围恢复选择。工作台需等待重新读取的 OA 配置；旧授权列表不能作为恢复依据。首帧先屏蔽旧配置，帧结束后刷新已有 Provider，再显示当前可用导航。未配置、读取失败或撤权时显示消息页，消息列表仍激活；不会因为记住工作台而恢复旧 SSO 页面。

52 项相关测试通过，三个改动文件静态检查无问题。新增证据包括企业页销毁后重新挂载恢复通讯录、同企业另一工作区默认消息并独立恢复、另一企业频道选择独立、退出企业删除记录、换账号清空记录，以及重新进入时旧 OA 应用隐藏、重新读取配置后撤权不保留工作台且消息列表正常激活。原有旧响应隔离、无工作区首页、企业选择器和个人顶部入口检查一并通过。

OA 恢复新增检查首先发现快速重挂载仍命中旧配置；这是本次检查揭示的真实问题。初次将刷新放入 initState，在父页面重建时引起状态修改错误；改为首帧结束后刷新，并在首帧屏蔽旧配置。切换企业测试相应等待刷新帧后再完成目标响应。失败日志保留为问题证据，不作为通过记录。

```sh
flutter test --no-pub test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart test/unit_test/page/workspace_shell/workspace_organization_selection_test.dart test/unit_test/page/workspace_shell/workspace_dispatch_test.dart test/organization/organization_picker_page_widget_test.dart test/unit_test/page/chat_shell/chat_shell_page_test.dart
flutter analyze --no-pub lib/page/workspace_shell/workspace_shell_provider.dart lib/page/workspace_shell/enterprise_shell_page.dart test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart
```

运行证据与源码摘要：`evidence/enterprise-navigation-restore-2026-10-01`。本轮使用真实组件、Riverpod 与合成 API；没有真实 OA、真机往返或完整投产证明。目录层级、滚动位置、切换补偿失败及其他整体验收项仍未完成。
