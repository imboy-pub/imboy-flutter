# 个人首页空间切换入口

状态：本地专项验证；整体六项目标仍为 PARTIAL。

个人首页既有底部顺序为消息、通讯录、频道、我，但手机和桌面都缺少常驻的顶部空间切换入口。现在业务接线层注入已有 WorkspaceSwitcherChip 的个人模式，共用企业选择器路由；按钮固定显示“个人”，不会因之前保留的企业指针显示企业名称，也不订阅或加载工作区。

ChatShellPage 只增加可选顶部入口，默认调用保持原来的直接分发。入口使用现有字号、间距和主题，保留按钮 44pt 热区，顶部安全区只计算一次。个人四项导航及企业选择器的既有加入、切换、错误重试流程均复用。

新增 430px、1440px 两种真实组件检查：个人文案、响应布局、真实点击后路由打开企业选择器、个人模式不得读取工作区、子页不重复计算顶部安全区。选择器目的页为路由标记，现有企业选择器测试独立覆盖个人入口和企业切换；本证据不等同于完整真机往返旅程。未完成跨空间浏览位置恢复、真实 OA、设备端验证或整体投产证明。

```sh
flutter test --no-pub test/unit_test/page/chat_shell/chat_shell_page_test.dart test/unit_test/page/chat_shell/chat_shell_bootstrap_test.dart test/unit_test/page/workspace_shell/workspace_account_menu_scroll_test.dart test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart test/organization/organization_picker_page_widget_test.dart
flutter analyze --no-pub lib/page/chat_shell/chat_shell_page.dart lib/page/chat_shell/chat_shell_bootstrap.dart lib/page/workspace_shell/workspace_account_menu.dart test/unit_test/page/chat_shell/chat_shell_page_test.dart
```

运行记录与源码摘要：`evidence/personal-scope-entry-2026-10-01`。没有新增依赖、访问真实企业、发布或部署。
