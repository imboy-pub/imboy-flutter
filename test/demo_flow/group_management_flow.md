# DF-09 群信息 → 成员 → 公告 → 可逆管理

> 优先级：P0
> 状态：`群名/公告与成员角色可逆写入、双端回读通过 / 成员增删与危险权限未覆盖`

## 1. 目标

验证管理员能修改群信息、查看成员和发布/查看公告，普通成员只能执行被授权的操作。

## 2. 前置条件

- [x] 准备管理员 A、普通成员 B 两个测试账号；测试账号 UID 为 50/4。
- [ ] 使用可回收测试群，不执行解散、清空记录、退群和不可逆 E2EE 开启。
- [ ] 需要 20 人以上成员的入口单独标记阻塞。

## 3. TODO 步骤

- [x] A 打开群详情，修改群名或群备注并重新加载。
  - 预期：保存成功，服务端刷新后仍保持。
  - 页面计划：[group_detail_page.md](../auto_test/group/group_detail_page.md)、[change_info_page.md](../auto_test/group/change_info_page.md)
- [x] A 打开成员列表和成员详情。
  - 预期：成员身份、群昵称和成员数正确。
  - 页面计划：[group_member_page.md](../auto_test/group/group_member_page.md)、[group_member_detail_page.md](../auto_test/group/group_member_detail_page.md)
- [x] A 发布/查看群公告，B 查看公告。
  - 预期：管理员入口和普通成员入口符合权限，公告服务端保存成功。
  - 页面计划：[group_announcement_page.md](../auto_test/group/group_announcement_page.md)
- [ ] 在可回收测试群添加或移除测试成员。
  - 预期：成员数和列表权威刷新；没有授权时跳过写操作。
  - 页面计划：[add_member_page.md](../auto_test/group/add_member_page.md)、[remove_member_page.md](../auto_test/group/remove_member_page.md)
- [x] A 将 B 从普通成员提升为管理员，B 在 Android 真机回读后由 A 恢复为普通成员。
  - 预期：服务端角色从 `role=1` 变为 `role=3`，跨设备可读，恢复后回到 `role=1`。
  - 自动化：[group_member_role_flow_test.dart](../../integration_test/demo_flow/group_member_role_flow_test.dart)

## 4. 验收标准

- [x] 管理员和普通成员的角色变更可逆，服务端与 Android 真机回读一致。
- [x] 群名、成员和公告重新加载后与服务端一致。
- [ ] 成员增删、群主转让等高影响权限仍未验证。
- [ ] 删除群、清空记录、退群和开启不可逆 E2EE 默认阻塞。

## 5. 当前覆盖与阻塞

- 2026-08-09：Android 华为真机生产只读测试 `integration_test/group/group_management_readonly_test.dart` 通过；从联系人“群聊”入口进入 `GroupListPage`，生产群列表显示 4 项。
- 2026-08-09：Android 华为真机 `integration_test/group/group_management_longpress_readonly_test.dart` 通过 `1/1`，完成群列表长按、选择“群聊信息”、详情/成员只读加载，并显式关闭 GoRouter 详情路由；此前的 SemanticsHandle 泄漏不再复现。
- 2026-08-09：Android 华为真机 `integration_test/group/group_detail_readonly_test.dart` 直接挂载已有群详情页通过 `1/1`，详情和成员只读加载完成。
- 群成员、公告和权限 UI 仍有回归复测项。
- 20 人以上成员入口、真实成员增删和危险操作需要专门授权。
- 2026-08-09：生产 `group_member_api_test.dart` 5/5 通过，覆盖成员分页和结构；群名、公告、权限变更和成员增删未执行。
- 2026-08-09：已有群详情、成员只读、群列表长按入口已形成 Android 真机通过证据；改群名、公告、权限和成员增删因生产写入受控 `SKIP`。
- 2026-08-09：受控 macOS/117 flow 对测试群 `104603643803863040` 完成群名 `P0-TEST-GROUP-20260809-235926` 与公告标记 `P0-GROUP-20260809-235926` 写入，随后通过群详情、成员页和公告接口回读；没有执行成员增删、权限修改、退群、解散或 E2EE 开启。
- 2026-08-10：Android/118 跨设备只读回读同一群，服务端确认群名、成员 UID `50/4` 和公告标记，`GroupDetailPage` 挂载成功，最终 `1/1 All tests passed`。
- 2026-08-10：macOS/117 将测试群成员 118 从 `role=1` 提升为 `role=3`，Android/118 真机从服务端回读管理员角色并挂载 `GroupDetailPage`，随后 macOS/117 将角色恢复为 `role=1`；提升、回读、恢复均 `1/1 All tests passed`，未执行成员增删、群主转让或解散。
- 2026-08-10：macOS/117 在生产绿色节点创建全新测试群 `106131639631087616`，邀请 UID `4`、写入群名和公告；Android/118 真机服务端回读成员 UID `50/4`、群名和公告并挂载 `GroupDetailPage`，双方均 `1/1 All tests passed`。后端修复为 `group_member_ds:list_member/2` 成员占位符从 `$2` 开始，未执行成员移除、群主转让或解散。

## 6. 未来自动化目标

现有 `group_management_readonly_test.dart`、`group_management_longpress_readonly_test.dart` 和 `group_detail_readonly_test.dart` 已覆盖群列表、详情和成员只读入口；`integration_test/demo_flow/group_creation_management_flow_test.dart` 覆盖群名/公告写入，`group_member_readback_flow_test.dart` 覆盖普通成员跨设备回读，`group_member_role_flow_test.dart` 覆盖管理员→普通成员的可逆角色变更。成员增删、群主转让和危险操作仍独立受控。
