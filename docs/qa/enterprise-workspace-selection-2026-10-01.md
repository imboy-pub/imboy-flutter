# 企业切换工作区本地验收 / Local verification

状态：**LOCAL_FOCUSED_PASS / 三端改版未完成 / RELEASE=NO_GO**。

基线：imboyapp `54576b776f4691c88f4c42726c1b9aa20d9ede26` 的独立工作副本。
未修改主工作区既有改动，未推送、部署或使用真实外部账号。

## 行为

- 企业选择器和通讯录切换共用 `WorkspaceShellNotifier.selectOrganization`。
- 指针提交后立即过滤已加载工作区：仅目标企业可见、可选；无匹配显示空态。
- 默认指针未配置、读取失败、未加入或归属错误时，使用同企业列表首项。
- 连续企业切换、同企业往返和手动选择后，迟到的默认响应不能覆盖新选择。
- 刷新继续遵守已选择企业；隐藏的已加入工作区保留在内部缓存，切回可用。
- 企业范围过滤只控制展示，不替代服务端成员关系与权限检查。

## 检查 / Checks

```sh
flutter test --no-pub test/unit_test/page/workspace_shell \
  test/organization/organization_picker_page_widget_test.dart \
  test/organization/human_directory_page_widget_test.dart \
  test/organization/human_directory_controller_test.dart --reporter expanded

dart analyze lib/page/workspace_shell/workspace_shell_provider.dart \
  lib/modules/organization/presentation/organization_picker_page.dart \
  lib/modules/organization/presentation/human_directory_page.dart \
  test/organization/organization_picker_page_widget_test.dart \
  test/unit_test/page/workspace_shell/workspace_organization_selection_test.dart
```

结果：82 项通过，退出码 0；所改文件静态检查无问题，退出码 0；差异检查通过。
新增 5 个回归测试覆盖失败回退、无效默认指针、空企业与刷新、往返竞态、手动选择。
按 `ecc:flutter-dart-code-review` 做人工检查，未进行独立代理审查。

隔离副本先按锁定提交恢复本地子模块，再使用缓存依赖；缺失环境文件使用
纯 loopback 测试配置生成，没有读取主工作区生产配置或复制秘密。
初次检查因缺失环境文件未能加载套件，环境补齐后上述检查通过。

## 后续验收 / Remaining

- 冷启动恢复企业指针、账号切换时清理壳状态，还需单独接线和验证。
- `mine` 目前只加载一页；超出该页的企业工作区需要分页或企业筛选接口。
- 正式个人三栏/企业四栏、组织架构展示、OA 工作台、客服和文件归属仍在整体实施范围内。
- 未执行 Android/iOS 真机、真实 OA、真实数据库或生产验收。
