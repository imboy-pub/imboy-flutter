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

- 第二轮已补齐冷启动恢复、账号切换清理和分页，见下节。本地检查未替代真机验收。
- 正式个人三栏/企业四栏、组织架构展示、OA 工作台、客服和文件归属仍在整体实施范围内。
- 未执行 Android/iOS 真机、真实 OA、真实数据库或生产验收。

## 第二轮：恢复、账号隔离与分页 / Restore and account isolation

基线：第一轮本地候选提交 `4812555a`，仍在独立工作副本实施。

- 壳状态复用 `currentUserProvider` 的 UID 监听。换号或登出清空工作区状态；
  冷启动先恢复该账号的企业展示偏好，再从后端已加入工作区选择默认项。
- 壳保持挂载时，账号变化会重新初始化；重新进入壳保留仍有效的手动选择。
- 读取后端分页，每页 100 条（服务端上限）。完整结果到齐才提交列表；
  中途失败保留既有列表并显示错误，不把第一页伪装为全部工作区。
- 新请求替代旧请求；每次异步结果回写前还核对当前账号，防止同一企业内
  两个账号之间串用成员列表。品牌和默认工作区响应遵守同一账号约束。

新增 6 项检查：冷启动与第二页默认项、重进保持选择、分页失败、同企业换号
竞态、登出清理、并发刷新、以及壳保持挂载时的换号接线（部分合并在一项）。
扩展检查结果：上述完整命令 **88 项通过、退出码 0**；所改文件静态检查无问题。
换号竞态检查最初复现旧请求回写，加入即时账号核验后通过。

当前企业仍是展示偏好；服务端 membership 和授权继续是数据访问真源。
尚未覆盖真实服务端分页中的并发成员变更或 Android/iOS 设备旅程。
