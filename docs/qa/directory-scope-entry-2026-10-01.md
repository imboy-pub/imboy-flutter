# 企业通讯录空间入口收敛

状态：本地组件验证；整体目标仍为 PARTIAL，未作真机或投产结论。

原企业壳在通讯录隐藏 WorkspaceSwitcherChip，目录另设只列企业的弹层。复现测试要求通讯录仍有全局入口时失败：找到 0 个切换按钮。原企业选择器也没有个人入口，空企业列表检查同样失败。

企业主界面现在所有栏目共用同一顶部入口。嵌入式目录根级移除重复导航栏，进入部门后保留显式逐级返回；独立目录深链保持兼容。现有企业选择器复用 ProductExperienceNotifier 提供个人入口；个人入口、加入企业和切换错误放在列表状态组件外，企业列表为空、读取失败或加载中不遮住这些动作。返回个人只是修改既有首页偏好，保留企业指针，不执行退企操作。

验证覆盖企业底栏、OA 条件入口、企业变更旧响应隔离、目录搜索/分页/逐级返回、大小屏/暗色/双倍字号、邀请加入与选择器。新增检查验证：嵌入根级无第二个标题栏；部门返回重拉正确根范围；空列表仍有个人和加入入口；选择个人后偏好变为 chat 并返回路由、原企业指针保留；读取企业列表和保存偏好均失败时保留 workspace 并显示错误。

测试使用既有 Widget/Dio/Provider 合成数据，不是服务端真实旅程或设备验收。全局顶部与选择器分别验证，尚未证明真机从目录切个人后 Cookie、缓存和草稿等完整旅程。本次未调整企业三/四栏结构，个人四栏继续为「消息、通讯录、频道、我」。

运行记录和源码摘要位于 `evidence/directory-scope-entry-2026-10-01`。已有主分支账户面板滚动修复 06a43c2e 纳入候选后重新验证；保留主目录中无关的暂存修改。

```sh
flutter test --no-pub test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart test/organization/organization_picker_page_widget_test.dart test/organization/human_directory_page_widget_test.dart test/unit_test/page/chat_shell/experience_provider_test.dart test/unit_test/page/workspace_shell/workspace_account_menu_scroll_test.dart test/unit_test/page/workspace_shell/workspace_account_menu_logout_test.dart
flutter analyze --no-pub lib/modules/organization/presentation/human_directory_page.dart lib/modules/organization/presentation/organization_picker_page.dart lib/page/workspace_shell/enterprise_shell_page.dart test/organization/human_directory_page_widget_test.dart test/organization/organization_picker_page_widget_test.dart test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart
```
