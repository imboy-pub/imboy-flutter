# DF-07 建群 → 面对面建群 → 入群确认

> 优先级：P0
> 状态：`通过（2026-08-18 本地 alpha.36 复跑 3/3，face2face_save 落库修复已实测验证并落实加严断言）；后端无独立入群确认端点（邀请直接生效）；面对面 UI 双端确认页仍未验收`

## 1. 目标

验证用户可以从联系人选择成员创建群，也可以使用面对面暗号建群，并能完成入群确认和群会话出现。

## 2. 前置条件

- [x] 准备 A、B 两个授权测试账号；面对面流程按需准备第二设备。
  - 2026-08-17 起本地 A/B 双账号可用（API 级，无需第二设备）。
  - 2026-08-18 起 B 账号为 `smoke_bob`（uid `1000000056`，account 型登录，凭证见 moments/wallet/red_packet
    flow 文档）；原 `test_886209702@example.com` 密码不可考据，弃用（见第 5 节）。
- [x] 使用可回收测试群或非生产环境。
- [x] 不删除真实群、不清空聊天记录、不强制移除第三方成员。

## 3. TODO 步骤

- [x] A 打开发起群聊页，选择 B 并确认创建。
  - 预期：成员选择、预览、完成按钮和创建结果正确。
  - 页面计划：[launch_chat_page.md](../auto_test/group/launch_chat_page.md)
  - 2026-08-17：本地 API 级闭环（group/add 邀请 B、群名写入、详情/成员回读、重复提交复用同一群）；UI 级仍引用 2026-08-09 入口挂载与 2026-08-10 双端证据。
- [x] A 从群列表或会话列表进入新群。
  - 预期：群标题、成员数和群会话正确。
  - 页面计划：[group_list_page.md](../auto_test/group/group_list_page.md)、[group_select_page.md](../auto_test/group/group_select_page.md)
  - 2026-08-17：B 侧 `group/page attr=join` 回读包含普通建群创建的群。
- [x] 在两台授权设备上输入同一面对面暗号。
  - 预期：暗号输入、确认页、进群结果和群名兜底正确。
  - 页面计划：[face_to_face_page.md](../auto_test/group/face_to_face_page.md)、[face_to_face_confirm_page.md](../auto_test/group/face_to_face_confirm_page.md)
  - 2026-08-17：本地 API 级闭环——A `face2face` 登记暗号后，A/B 凭同暗号+同位置（50m 内）加入同一群，
    `group_member` 落库回读双方 `join_mode=face2face_join`；纯 API 注入位置，无需物理第二设备。
  - 2026-08-18：本地后端升级 alpha.36（含 `21af8e78`/`41034a52` 修复）后复跑 3/3 通过；
    `face2face_save` 落库修复实测生效——响应携带完整 group map（id=gid）与 member_list（双方），
    group 行随后可 `group/detail` 回读，面对面群进入非群主成员的 `attr=join` 群列表（详见第 5 节）。
- [x] B 重新加载群列表确认群关系。
  - 预期：双方看到一致的成员关系。
  - 2026-08-17：成员关系以 `group_member/page` 服务端回读为准，双方一致。

## 4. 验收标准

- [x] 普通建群和授权成员邀请有独立证据；面对面建群已有本地 API 级凭暗号加入证据（UI 双端仍未验收）。
- [x] 创建失败、暗号错误和重复提交不会产生幽灵群（后端 `find_by_creator_and_sum` 对相同创建者+成员集合去重，重复 add 返回同一 gid 已断言）。
- [x] 不以本地列表出现作为唯一成功证据（全部断言基于服务端响应与回读）。

## 5. 当前覆盖与阻塞

- 面对面 UI 确认页双端真机流程仍未验收（本地 API 级已闭环）。
- 真实建群会产生服务端数据；本轮使用唯一标题创建了可追踪测试群，未删除前序失败探针产生的测试群。
- 2026-08-09：生产 `group_api_test.dart` 与 `group_member_api_test.dart` 顺序通过，覆盖群列表、详情、成员分页和无效 gid；未创建真实群、未执行入群确认。
- 2026-08-09：Android 华为真机 `group/group_creation_readonly_test.dart` 通过 `1/1`；发起群聊、选择群聊、面对面建群三个入口页面均成功挂载，未选择成员、未输入暗号、未点击完成，因此没有生产建群写入。
- 该结果只覆盖入口和页面挂载，不等于普通建群、面对面确认、入群关系或新群会话闭环通过。
- 2026-08-09：普通建群、面对面暗号确认、入群关系和新群会话均因生产写入/第二设备前置条件受控 `SKIP`，没有把入口挂载误记为建群通过。
- 2026-08-09：受控双账号 flow 在 macOS 管理员端调用建群入口后，服务端按相同成员集合复用了已有测试群 `104603643803863040`（成员 UID `50/4`），随后完成群名和公告写入；因此证明了可回收测试群上的管理写入，不证明“全新建群”或面对面入群。
- 2026-08-10：Android/118 只读回读同一测试群，群名、成员 UID `50/4`、公告标记和 `GroupDetailPage` 均通过 `1/1`；新群会话和入群确认仍未验收。
- 2026-08-10：修复后端 `group_member_ds:list_member/2` 的 SQL 占位符冲突（成员参数从 `$2` 开始），并以蓝绿方式发布到生产绿色节点；macOS/117 创建全新测试群 `106131639631087616`，邀请 UID `4` 返回 `ok=true`，写入群名和公告后服务端成员/详情回读、`GroupDetailPage` 挂载均通过，最终 `1/1 All tests passed`。
- 2026-08-10：Android/118 使用成员账号只读回读上述全新测试群的群名、成员 UID `50/4`、公告标记并挂载 `GroupDetailPage`，最终 `1/1 All tests passed`。
- 2026-08-17：本地后端（`http://127.0.0.1:9800`，alpha.27，仅 HTTP API 不干预进程）新增纯 Dart 闭环测试
  `integration_test/demo_flow/group_local_creation_flow_test.dart`，双账号 A=`13900001002`（uid 104250986822109184）、
  B=`test_886209702@example.com`（uid 106571314139236352，find_password 重置的废弃 e2ee 测试账号），
  最终 `3/3 All tests passed`：
  1. 普通建群：`group/add {member_uids:[B]}` → 复用探针群 gid `107539649576306688`（同成员集合去重）→ `group/edit` 写入群名
     `DEMO-FLOW-20260817-CREATE-*` → `group/detail` 回读一致；`group_member/page` 回读成员含 A/B；
     重复 add 相同成员集合返回同一 gid（无幽灵群断言通过）。
  2. 面对面：A `face2face`（暗号+经纬度）登记 → A 同暗号二次 `face2face` 落库入群 → B 同暗号加入同一 gid →
     B `face2face_save` 幂等成功 → `group_member/page` 回读双方在场且 B `join_mode=face2face_join`。
  3. B 侧 `group/page attr=join` 回读包含普通建群创建的群。
- 2026-08-17 发现项（后端，不修改 imboy 仓）：本地 alpha.27 的 `group/face2face_save` 静默不落库——
  返回 `code=0` 但 payload 为空 `{group:{}, member_list:[]}` 且 `group`/`group_member` 表无写入；根因是建群链路
  `parse_result` 形态错（上游提交 `21af8e78`/`41034a52` 已修复，alpha.28+ 部署后生效）。当前测试改走“同暗号再次
  face2face”的 join 路径完成落库（与凭暗号加入的产品语义一致）。
- 2026-08-18：本地后端升级到 alpha.36 release（beam 2026-08-17 02:50 构建，`21af8e78`/`41034a52` 均为
  alpha.36 版本提交的祖先，进程 08:46 启动）后，`group_local_creation_flow_test.dart` 复跑 `3/3 All tests passed`，
  并按上轮计划落实「断言加严」：
  1. `face2face_save` 落库修复实测生效：此时 group 表仍无该群行（face2face 登记只写 `group_random_code`
     +内存缓存，join 路径只写 `group_member`），save 响应携带完整 group map（id=gid）与 member_list（含双方），
     group 行由 save 创建（`group_ds:face2face_save/3` 事务内 `create_group` + 幂等入群）。
  2. 新增独立回读断言：`group/detail` 回读群行 id 一致；面对面群出现在非群主成员的 `group/page attr=join`
     列表（修复前 group 无行、LEFT JOIN 查不到）。
  3. B 账号切换为 `smoke_bob`（uid `1000000056`，account 型登录，凭证见 moments/wallet/red_packet flow 文档，
     08-17 有本地成功记录）：原 `test_886209702@example.com`（uid `106571314139236352`）密码在仓库/文档/
     会话记录中均不可考据（只有占位符），不猜测凭证，改用已记载账号。A+smoke_bod 成员集合的去重群为新群
     `107668232984594432`（不影响历史 A+886209702 群的证据）。
  4. 观察到的语义（记录，不作为验收断言）：face2face 群的 group 行 owner_uid 是 `face2face_save` 的调用方
     （非暗号登记人）；`page_joined` 排除自己是群主的群，因此 f2f 群要在非群主一侧断言 join 列表；
     f2f 群 `member_count` 停留在 1（建行前的 join 不回填统计）、title 为空（UI 端兜底）。
- 入群确认：后端路由无独立 invite/confirm 端点，`group_member/join` 对邀请直接生效（被邀请方无确认页），
  `face2face` join_mode 为 `face2face_join`；“确认后入群”的二段式链路在当前后端实现中不存在，UI 确认页仅为保存动作。

## 6. 未来自动化目标

现有 `integration_test/group/group_creation_readonly_test.dart` 已覆盖三个入口只读挂载；
`integration_test/demo_flow/group_local_creation_flow_test.dart` 覆盖本地 API 级建群/邀请/面对面闭环，
2026-08-18 起已按 face2face_save 修复落实加严断言（响应 group/member_list 非空、group/detail 回读、
面对面群进入 join 列表），可作为本地回归默认用例（双账号 13900001002 + smoke_bob）。
面对面 UI 双端真机确认页流程仍需第二设备。
