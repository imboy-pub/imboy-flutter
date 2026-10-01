# 企业切换补偿失败的一致性

状态：本地专项 PASS；完整 UX-01 和六项目标仍为 PARTIAL。

原选择器在布局偏好保存失败后尝试恢复旧企业指针，但忽略恢复保存失败，随后把工作区壳强行恢复为旧企业。新增平台接口检查复现：实际企业指针是 7002，壳却是 7001；恢复返回 false 和抛异常均存在此问题。

现在补偿失败会返回明确错误，并按 CurrentOrganizationStore 实际保留的指针对齐企业与工作区，保持选择器错误提示供重试。补偿成功则恢复旧状态；失败不再声称恢复了旧企业。未知保存错误使用已有本地化重试提示。没有跨越服务器成员权限边界。

另一处通讯录内切换也存在忽略补偿错误的代码。该流程没有后续布局保存步骤，改为先失效展示缓存、最后保存指针；保存失败不发布新指针，删除原来的二次补偿写。这部分通过既有通讯录组件检查及静态检查，本轮未新增通讯录内保存故障的完整点击旅程。

52 项相关测试通过，三个改动文件静态检查无问题。新增选择器检查使用已安装 SharedPreferences 平台接口：目标企业保存成功、布局选择首次失败、恢复旧企业返回 false／抛异常；验证指针、缓存中的持久值、企业工作区及错误状态一致，再点击同一企业成功进入工作区首页。不是操作系统存储故障或真机证明。

```sh
flutter test --no-pub test/organization/organization_picker_page_widget_test.dart test/organization/human_directory_page_widget_test.dart test/organization/current_organization_store_test.dart test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart
flutter analyze --no-pub lib/modules/organization/presentation/organization_picker_page.dart lib/modules/organization/presentation/human_directory_page.dart test/organization/organization_picker_page_widget_test.dart
```

证据目录：`evidence/organization-compensation-2026-10-01`。这是失败后按实际状态恢复一致性的检查，不代表多个偏好键具有存储事务。页面退出或账号变化期间的完整持久状态恢复、真实设备、OA 及整体投产证明仍未完成。
