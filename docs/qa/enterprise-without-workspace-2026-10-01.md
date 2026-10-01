# 无工作区企业首页

状态：本地专项验证；六项目标仍为 PARTIAL，未作真机或投产认定。

已加入企业但未加入任何工作区时，旧首页先显示工作区空态，屏蔽了企业通讯录及 OA 入口。企业成员资格与工作区成员资格独立，组织架构读取并不需要工作区成员资格。

现在有账号及企业上下文时，复用已有企业首页。工作区加载中或读取失败只影响消息区域，企业通讯录仍可进入；组织架构仍经现有组织 API 获取，由服务端检查权限。没有账号或企业上下文时保留原入口。在没有选中工作区时隐藏“我”页的工作区成员、群组、项目入口，企业详情入口保留。

新增三种真实组件场景：无工作区正常、加载中、读取失败。每个场景从首页点击通讯录，经过既有 HttpClient 与 OrganizationApi 的合成响应，验证部门实际显示以及空间切换入口保留。失败场景同时验证消息区域错误提示，加载场景验证进度指示。

基线首页检查失败：没有企业导航。测试中的安全存储、Dio 出口均使用现有测试注入能力，没有访问真实企业或 OA。早期测试缺少安全存储替身，导致后续场景进入退出登录流程；补齐后重新验证，失败轮次不作为通过证据。

```sh
flutter test --no-pub test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart test/unit_test/page/workspace_shell/workspace_dispatch_test.dart test/organization/human_directory_page_widget_test.dart test/organization/organization_picker_page_widget_test.dart
flutter analyze --no-pub lib/page/workspace_shell/enterprise_shell_page.dart lib/page/workspace_shell/workspace_shell_bootstrap.dart test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart
```

日志及源码摘要在 `evidence/enterprise-without-workspace-2026-10-01`。这是本地组件及合成 API 验证，不能证明真机成员生命周期、真实 OA 交互或整体投产条件。
