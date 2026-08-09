# DF-09 群信息 → 成员 → 公告 → 可逆管理

> 优先级：P0
> 状态：`详情只读通过 / 管理写入待授权`

## 1. 目标

验证管理员能修改群信息、查看成员和发布/查看公告，普通成员只能执行被授权的操作。

## 2. 前置条件

- [ ] 准备管理员 A、普通成员 B 两个测试账号。
- [ ] 使用可回收测试群，不执行解散、清空记录、退群和不可逆 E2EE 开启。
- [ ] 需要 20 人以上成员的入口单独标记阻塞。

## 3. TODO 步骤

- [ ] A 打开群详情，修改群名或群备注并重新加载。
  - 预期：保存成功，服务端刷新后仍保持。
  - 页面计划：[group_detail_page.md](../auto_test/group/group_detail_page.md)、[change_info_page.md](../auto_test/group/change_info_page.md)
- [ ] A 打开成员列表和成员详情。
  - 预期：成员身份、群昵称和成员数正确。
  - 页面计划：[group_member_page.md](../auto_test/group/group_member_page.md)、[group_member_detail_page.md](../auto_test/group/group_member_detail_page.md)
- [ ] A 发布/查看群公告，B 查看公告。
  - 预期：管理员入口和普通成员入口符合权限，公告服务端保存成功。
  - 页面计划：[group_announcement_page.md](../auto_test/group/group_announcement_page.md)
- [ ] 在可回收测试群添加或移除测试成员。
  - 预期：成员数和列表权威刷新；没有授权时跳过写操作。
  - 页面计划：[add_member_page.md](../auto_test/group/add_member_page.md)、[remove_member_page.md](../auto_test/group/remove_member_page.md)

## 4. 验收标准

- [ ] 管理员和普通成员权限差异清晰。
- [ ] 群名、成员和公告重新加载后与服务端一致。
- [ ] 删除群、清空记录、退群和开启不可逆 E2EE 默认阻塞。

## 5. 当前覆盖与阻塞

- 2026-08-09：Android 华为真机生产只读测试 `integration_test/group/group_management_readonly_test.dart` 通过；从联系人“群聊”入口进入 `GroupListPage`，生产群列表显示 4 项。
- 2026-08-09：Android 华为真机 `integration_test/group/group_management_longpress_readonly_test.dart` 通过 `1/1`，完成群列表长按、选择“群聊信息”、详情/成员只读加载，并显式关闭 GoRouter 详情路由；此前的 SemanticsHandle 泄漏不再复现。
- 2026-08-09：Android 华为真机 `integration_test/group/group_detail_readonly_test.dart` 直接挂载已有群详情页通过 `1/1`，详情和成员只读加载完成。
- 群成员、公告和权限 UI 仍有回归复测项。
- 20 人以上成员入口、真实成员增删和危险操作需要专门授权。
- 2026-08-09：生产 `group_member_api_test.dart` 5/5 通过，覆盖成员分页和结构；群名、公告、权限变更和成员增删未执行。
- 2026-08-09：已有群详情、成员只读、群列表长按入口已形成 Android 真机通过证据；改群名、公告、权限和成员增删因生产写入受控 `SKIP`。

## 6. 未来自动化目标

现有 `group_management_readonly_test.dart`、`group_management_longpress_readonly_test.dart` 和 `group_detail_readonly_test.dart` 已覆盖群列表、详情和成员只读入口；暂不新增包装测试。管理写入独立受控。
