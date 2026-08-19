# DF-09 群信息 → 成员 → 公告 → 可逆管理

> 优先级：P0
> 状态：`通过（2026-08-19 本地 alpha.36 复跑 4/4 维持：群名/公告、角色提升/恢复、成员移除+邀回、群主转让，数据标记更新为 DEMO-FLOW-20260819）；群主转让在专用一次性群单向执行并回读（立即转回被 per_hour_once 限流拒绝）；退群/解散/清空记录等危险操作仍默认不执行`

## 1. 目标

验证管理员能修改群信息、查看成员和发布/查看公告，普通成员只能执行被授权的操作。

## 2. 前置条件

- [x] 准备管理员 A、普通成员 B 两个测试账号；生产测试账号 UID 为 50/4，本地测试账号 UID 为
  104250986822109184（A=`13900001002`）/1000000056（B=`smoke_bob`，2026-08-18 起；原 886209702 密码不可考据弃用）。
- [x] 使用可回收测试群，不执行解散、清空记录、退群和不可逆 E2EE 开启。
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
  - 2026-08-17：本地 API 级 `group/edit introduction` 公告写入+detail 回读一致。
- [x] 在可回收测试群添加或移除测试成员。
  - 预期：成员数和列表权威刷新；没有授权时跳过写操作。
  - 页面计划：[add_member_page.md](../auto_test/group/add_member_page.md)、[remove_member_page.md](../auto_test/group/remove_member_page.md)
  - 2026-08-17：本地 API 级闭环——A `group_member/leave` 移除 B → 成员分页回读 B 消失 →
    A `group_member/join` 重新邀请 → 回读恢复且 B `role=1`。测试群保留（不解散），成员集合恢复原状。
- [x] A 将 B 从普通成员提升为管理员，B 在 Android 真机回读后由 A 恢复为普通成员。
  - 预期：服务端角色从 `role=1` 变为 `role=3`，跨设备可读，恢复后回到 `role=1`。
  - 自动化：[group_member_role_flow_test.dart](../../integration_test/demo_flow/group_member_role_flow_test.dart)
  - 2026-08-17 补充：本地 API 级同样验证 1→3 提升回读、3→1 恢复回读。
- [x] A 将群主转让给 B 并回读（2026-08-18 新覆盖，本地 API 级）。
  - 预期：`group/transfer` 后 `owner_uid` 变更为 B，新群主 `role=4`、原群主降为 `role=1`，写入 `group_log type=9`。
  - 自动化：[group_local_management_flow_test.dart](../../integration_test/demo_flow/group_local_management_flow_test.dart) DF-09-4。
  - 说明：转让接口 `per_hour_once` 按 gid 限流，转回同一群一小时内不可行；本用例在专用一次性面对面群上
    单向执行（A→B），立即转回的负向断言验证限流生效；转让后的群保留为可回收数据，不影响主测试群。

## 4. 验收标准

- [x] 管理员和普通成员的角色变更可逆，服务端与 Android 真机回读一致。
- [x] 群名、成员和公告重新加载后与服务端一致。
- [x] 成员移除后成员列表权威刷新，重新邀请可恢复（本地 API 级，2026-08-17）；群主转让已在本地 API 级验证
  （2026-08-18：owner_uid/角色回读 + group_log 转让日志；因 per_hour_once 限流为单向执行，非立即可逆）。
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
- 2026-08-17：本地后端（alpha.27）新增纯 Dart 闭环测试
  `integration_test/demo_flow/group_local_management_flow_test.dart`，双账号 A=`13900001002`（uid 104250986822109184，
  群主）、B=`test_886209702@example.com`（uid 106571314139236352，普通成员），在 `DEMO-FLOW-20260817` 前缀
  测试群（gid `107539649576306688`，`group/add` 对相同成员集合去重复用）上执行，最终 `3/3 All tests passed`：
  1. 群名+公告：`group/edit {title: DEMO-FLOW-20260817-MGMT-*, introduction: DEMO-FLOW-20260817-NOTICE-*}` →
     `group/detail` 回读两字段与写入一致。
  2. 角色可逆：`group_member/role {user_id:B, role:3}` → `group_member/page` 回读 B `role=3` →
     恢复 `role=1` → 回读 `role=1`。
  3. 成员移除+邀回（历史首次真实执行）：`group_member/leave {member_uids:[B]}` → 成员分页回读 B 消失 →
     `group_member/join` 重新邀请 → 回读 B 恢复在场且 `role=1`。未执行解散、群主转让或退群。
- 2026-08-18：本地后端升级 alpha.36 后复跑 `group_local_management_flow_test.dart` `4/4 All tests passed`
  （A=`13900001002` 群主、B=`smoke_bob` uid `1000000056`，B 账号切换原因见 group_creation_flow.md 第 5 节）：
  1. 群名+公告、角色 1→3→1、成员移除+邀回三项闭环全部复现（与 08-17 一致；A+smoke_bob 成员集合的
     去重主测试群为 `107668232984594432`，群名 `DEMO-FLOW-*-MGMT-*` 回读一致）。
  2. 新增 DF-09-4 群主转让（历史未覆盖项，本轮首次真实执行）：在专用一次性面对面群 `107668853378779136`
     上（B 登记暗号、A/B 凭暗号加入、A `face2face_save` 建行成为 owner）执行 `group/transfer {gid, new_owner_uid:B}`：
     - 转让前 `group/detail` 回读 `owner_uid=A`；
     - 转让后回读 `owner_uid=B`，成员分页回读 B `role=4`（ROLE_OWNER）、A 降为 `role=1`；
     - `group_log` 落 `type=9` 转让日志（body 含 from/to_owner_uid，DB 只读核验）；
     - 负向断言：B 立即转回同群被 `per_hour_once {group_transfer, gid}` 限流拒绝（“在处理中，请稍后重试”），
       证明该操作一小时内不可回收，故只在专用群单向执行。
- 2026-08-19：本地后端（healthz `1.0.0-alpha.36`，db=up，未干预进程）复跑
  `group_local_management_flow_test.dart` `4/4 All tests passed`（A=`13900001002` uid 104250986822109184
  群主、B=`smoke_bob` uid 1000000056）：
  1. 群名+公告、角色 1→3→1、成员移除+邀回三项闭环全部复现，仍落在 A+B 去重主测试群
     `107668232984594432`（群主保持为 A）。本轮数据标记更新为 `DEMO-FLOW-20260819`
     （测试常量 `_groupPrefix`）；DB 只读核验：title=`DEMO-FLOW-20260819-MGMT-1787117018219`、
     introduction=`DEMO-FLOW-20260819-NOTICE-1787117018219`、owner_uid=104250986822109184 落库一致。
  2. DF-09-4 群主转让在新建专用面对面群 `107851155283118080` 上单向执行（B 登记暗号、A/B 凭暗号
     加入、A face2face_save 建行为 owner），DB 只读核验：
     - `group_log` 新增 type=9 日志 `107851163854178304`（body：from_owner_uid=A、to_owner_uid=B、
       changed_by=A、remark=群转让，created_at 2026-08-19 13:24:02）；
     - 转让后 group 行 owner_uid=B（1000000056），成员回读 B `role=4`（ROLE_OWNER）、A 降为 `role=1`，
       双方 join_mode=face2face_join；
     - 负向断言通过：B 立即转回同群被 `per_hour_once` 限流拒绝（该群保留为可回收数据，不解散）。
  3. 上轮（08-18）转让群 `107668853378779136` 未再触碰；本轮转让群为新 gid，不受上轮限流影响。
  4. 与 DF-07 同日串行执行（add/face2face 共用 uid 维度 three_second_once 限流桶），无跨用例限流冲突。
- 危险操作（退群 owner leave、解散、清空记录、不可逆 E2EE）本轮仍默认不执行。

## 6. 未来自动化目标

现有 `group_management_readonly_test.dart`、`group_management_longpress_readonly_test.dart` 和 `group_detail_readonly_test.dart` 已覆盖群列表、详情和成员只读入口；`integration_test/demo_flow/group_creation_management_flow_test.dart` 覆盖群名/公告写入，`group_member_readback_flow_test.dart` 覆盖普通成员跨设备回读，`group_member_role_flow_test.dart` 覆盖管理员→普通成员的可逆角色变更，`group_local_management_flow_test.dart` 覆盖本地群名/公告/角色/成员移除+邀回闭环，2026-08-18 起新增 DF-09-4 覆盖群主转让（单向 + 限流负向断言）。退群、解散和危险操作仍独立受控（默认阻塞）。
