# DF-06 群功能 Demo Flow 总索引

> 状态：`普通建群/邀请、群聊、群协作双账号闭环通过 / 面对面凭暗号加入与成员移除本地 API 闭环通过（2026-08-17）/ 面对面 UI 双端、群主转让未覆盖`
> 优先级：P0
> 类型：群功能流程索引

## 1. 定位

群功能页面很多，不能用一个线性流程假装覆盖全部。本文件只负责定义群业务边界、推荐执行顺序和专题流程入口；具体步骤分别写在各专题文档中。

## 2. 群业务地图

```text
建群/入群
  → 群聊消息
  → 群信息与成员管理
  → 群日程/任务/投票协作
  → 群相册/文件/媒体内容
  → 群分类/标签/二维码/邀请
```

## 3. 专题流程

| 文档 | 优先级 | 覆盖范围 |
|---|---:|---|
| [group_creation_flow.md](./group_creation_flow.md) | P0 | 建群、面对面建群、入群确认、群选择 |
| [group_chat_flow.md](./group_chat_flow.md) | P0 | 群会话、文本消息、未读、@和消息恢复 |
| [group_management_flow.md](./group_management_flow.md) | P0 | 群名称、备注、成员、公告和可逆权限 |
| [group_collaboration_flow.md](./group_collaboration_flow.md) | P0 | 群日程、任务、投票和结果回传 |
| [group_content_flow.md](./group_content_flow.md) | P1 | 群相册、图片详情、群文件、音频预览 |
| [group_organization_flow.md](./group_organization_flow.md) | P1 | 群分类、标签、二维码、邀请和大群入口 |

## 4. 总体验收标准

- [x] P0 六条专题流程均有独立 TODO、前置条件、验收标准和阻塞说明。
- [x] P0 六条专题流程均已通过；群聊、群协作和成员角色变更已完成双账号闭环，建群新建证明已有（生产 2026-08-10 + 本地 2026-08-17），成员增删已有本地闭环证明（2026-08-17），面对面凭暗号加入已有本地 API 证明（2026-08-17），面对面 UI 双端确认页仍未验收。
- [x] 群创建、消息、成员角色和协作结果均有服务端证据；成员增删已在本地下执行并回读（2026-08-17）。
- [ ] P1 群内容和组织能力不会被 P0 的群聊通过结果代替。
- [ ] 删除群、清空记录、退群、开启不可逆 E2EE 等危险动作默认不执行。

## 5. 统一前置条件

- [x] 使用至少两个明确授权的测试账号；管理员/普通成员场景另准备角色账号。
  - 生产：117/118（UID 50/4）；本地（2026-08-17 起）：`13900001002`（UID 104250986822109184）与
    `test_886209702@example.com`（UID 106571314139236352，find_password 重置的废弃 e2ee 测试账号）。
- [x] 使用可回收测试群或非生产环境（本地 DEMO-FLOW-20260817 前缀测试群，保留不删）。
- [ ] 需要 20 人以上成员、真实媒体或不可逆权限时，标记为 `阻塞`。
- [ ] 确认当前 APK 包含要验证的客户端改动。

## 6. 当前已有证据

- 已有局部可执行测试：`integration_test/chat/group_chat_test.dart`。
- 页面级计划集中在 `test/auto_test/group/`，共 26 个页面计划；本索引不替代这些页面台账。
- 2026-08-09：生产 `group_api_test.dart`、`group_member_api_test.dart`、`group_schedule_api_test.dart` 顺序通过；未执行真实建群、群消息、权限变更或活动确认。
- 2026-08-09：Android 华为真机从联系人“群聊”入口进入群列表，显示 4 个生产群项目通过；新增长按菜单只读测试完成“群聊信息 → 群详情”并通过 `1/1`，未执行任何群写入。
- 2026-08-10：群日程/任务/投票双账号 flow `1/1` 通过；建群入口只读证据仍保留，群协作使用既有 P0 测试群，不计为全新建群证明。
- 2026-08-10：群聊双账号 flow 在 macOS/Android 测试群完成文本收发、ACK、重进回读，双方均 `1/1 All tests passed`；@成员、失败分支和多人并发仍未覆盖。
- 2026-08-10：成员角色 flow 在 macOS/Android 对测试群完成管理员提升、跨设备回读和恢复普通成员，三次运行均 `1/1 All tests passed`；成员增删、群主转让和危险操作仍未覆盖。
- 2026-08-10：修复后端群成员筛选 SQL 占位符冲突并蓝绿发布；macOS/117 创建全新测试群 `106131639631087616`、邀请 UID `4`、写入群名/公告，Android/118 回读成员、群名、公告并挂载详情页，双方均 `1/1 All tests passed`；面对面入群、成员移除和解散仍未覆盖。
- 2026-08-17：本地后端（http://127.0.0.1:9800，alpha.27，仅 HTTP API）三份纯 Dart 闭环测试串行复跑 `8/8 All tests passed`
  （`group_local_creation_flow_test.dart` 3/3、`group_local_management_flow_test.dart` 3/3、
  `group_local_message_flow_test.dart` 2/2，双账号见统一前置条件）：
  - DF-07：普通建群+邀请+群名回读+重复提交复用同一群（无幽灵群）；面对面 A/B 凭同暗号加入同一群并落库回读
    `join_mode=face2face_join`；B 侧 join 群列表回读。
  - DF-09：群名/公告写入回读；角色 1→3→1 可逆回读；成员移除（历史首次真实执行）→回读消失→重新邀请→恢复 `role=1`。
  - DF-08：本地 strict E2EE policy（`e2ee_mode=required`）下明文 C2G 被 fail-closed 拒收
    （`policy_violation/encrypted_message_required`）；密文结构消息经 WS 接收并归档（`msg_c2g` DB 行核验）；
    双端实时闭环维持 2026-08-10/11 生产历史证据。
  - 发现项（后端，不修改 imboy 仓）：① alpha.27 `face2face_save` 静默不落库（上游 `21af8e78`/`41034a52` 已修复，
    待部署）；② `group/msg_page` 查询键 `to_groupid` 与 `msg_c2g` 列 `to_id` 不匹配致恒返回 `total=0`
    （HEAD 同样存在，很可能是历史"服务端历史归档为空"之谜的根因）；③ alpha.27 密文消息 ACK 帧不回（归档正常）。
- 生产只读复跑（2026-08-17，`.env.pro` 注入，118 账号 uid=4）：`group_api_test.dart` `6/6`、
  `group_member_api_test.dart` `5/5` 均 `All tests passed`，无生产写入。

## 7. 未来自动化目标

每条专题流程对应 `integration_test/demo_flow/group_*_flow_test.dart`。P0 的普通建群/邀请、群聊、群管理可逆角色变更和群协作已有双账号证据；2026-08-17 起新增本地纯 Dart 闭环（`group_local_creation/management/message_flow_test.dart`）覆盖面对面凭暗号加入、成员移除+邀回与 strict 环境消息门禁。剩余待办：面对面 UI 双端真机确认页、群主转让、后端 `msg_page` 列名 bug 与 `face2face_save` 修复部署后的断言加严，再评估 P1 的媒体和组织能力是否值得加入默认回归。
