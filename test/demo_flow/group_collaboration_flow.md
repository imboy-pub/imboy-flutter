# DF-10 群日程 → 群任务 → 群投票

> 优先级：P0
> 状态：`双账号写入闭环通过 / 本地单账号 API 闭环通过（2026-08-17） / 费用与跨频道链路未覆盖`

## 1. 目标

验证群成员可以围绕一个活动创建日程、分配/查看任务并通过投票形成协作结果。

## 2. 前置条件

- [x] 使用授权测试账号和既有 P0 测试群。
- [x] 准备唯一测试标题、未来时间和非敏感地点。
- [x] 不把群日程描述为预约系统，不把投票描述为费用结算。

## 3. TODO 步骤

- [x] 117 创建/定位群日程并进入详情。
  - 预期：标题、时间、地点和描述保存成功。
  - 页面计划：[group_schedule_page.md](../auto_test/group/group_schedule_page.md)、[group_schedule_detail_page.md](../auto_test/group/group_schedule_detail_page.md)
- [x] 118 普通成员确认参加。
  - 预期：参与状态、人数和群内卡片同步刷新。
- [x] 117 创建/定位测试群任务，118 打开任务详情并提交内容。
  - 预期：任务列表、标题、状态和详情加载正确。
  - 页面计划：[group_task_page.md](../auto_test/group/group_task_page.md)、[group_task_detail_page.md](../auto_test/group/group_task_detail_page.md)
- [x] 117 创建/定位测试投票，118 提交选项并回读已选项。
  - 预期：投票列表、已选项和结果统计正确。
  - 页面计划：[group_vote_page.md](../auto_test/group/group_vote_page.md)、[group_vote_detail_page.md](../auto_test/group/group_vote_detail_page.md)

## 4. 验收标准

- [x] 日程、任务、投票均能创建/查看/回传结果。
- [x] 双端重新请求详情并挂载详情页后结果仍可回读。
- [ ] 活动费用 AA、托管、退款和预约排班不在现有验收范围内。

## 5. 当前覆盖与阻塞

- 2026-08-17 本地单账号 API 闭环（新增 `integration_test/demo_flow/group_collaboration_local_api_flow_test.dart`，纯 Dart 无设备）：`dart test --concurrency=1` 最终 `4/4 All tests passed`。本地后端 `1.0.0-alpha.27`（healthz db=up），测试账号 13900001002（uid=104250986822109184），测试群 `DEMO-FLOW-20260817-COLLAB`（gid=107539326623287296，member_count=1，建群/命名均为 API 写入并回读）。
  - 日程：创建 code=0 → 列表回读命中 → 确认参加 code=0 → 详情回读 `participant_count=1` 且 participants 含自己。
  - 任务：创建 code=0 → 分配给自己 code=0 → 列表回读命中 → 提交 code=0 → 详情回读包含提交标记。
  - 投票：创建 code=0 → 列表回读命中（vote_id=`vote.*`）→ 投票 code=0（option_id=`opt.*`）→ my_vote 回读包含已投选项。
  - 覆盖范围说明：本地为单账号闭环（创建者本人确认/提交/投票）；本地无第二可登录账号（smoke_alice/smoke_bob 密码为空），双账号互补证据仍为 2026-08-10 生产 117/118 闭环。
- 2026-08-17 生产只读复跑（`.env.pro` 注入，pro.imboy.pub alpha.36，118@imboy.pub uid=4，逐文件 `dart test --concurrency=1`）：`group_schedule_api_test.dart` 4 通过、1 失败（写探活被 `TEST_ALLOW_API_WRITES` 门禁在请求发出前 StateError 拦截，无生产写入）；`group_task_api_test.dart` 5 通过、1 失败（同门禁拦截）；`group_vote_api_test.dart` 3 通过、2 失败（同门禁拦截）。只读端点全部通过，门禁拦截为设计行为非回归。
- 2026-08-10：117 macOS 群主端与 118 Android 华为真机完成同一测试群的日程、任务、投票双账号闭环，测试 `1/1 All tests passed`。
- 证据覆盖：日程创建/确认参加、任务创建/分配/提交、投票创建/投票/我的投票回读，以及双方列表页和详情页挂载。
- 任务接口兼容修复：deadline 发送 RFC3339；任务详情使用数值 `id`，提交使用 `task_id`；投票“您还未投票”业务响应按空列表处理，其他失败仍抛错。
- 2026-08-09：生产 `group_schedule_api_test.dart` 5/5 顺序通过，覆盖我的日程、群日程、详情和无效群组写端点可达；没有在生产创建/确认真实活动。
- 2026-08-09：Android 华为真机 `group/group_collaboration_readonly_test.dart` 通过 `1/1`；该只读证据保留，另由双账号 flow 补齐写入与结果回传。
- 双账号 flow 直接调用现有 API 并挂载现有页面路由，不等于新增预约、收费或 AA 能力；这些不在当前验收范围。

## 6. 未来自动化目标

现有 `group/group_collaboration_readonly_test.dart` 保留为低风险只读回归；`integration_test/demo_flow/group_collaboration_flow_test.dart` 负责显式授权后的双账号闭环；`integration_test/demo_flow/group_collaboration_local_api_flow_test.dart` 负责本地后端的纯 API 闭环回归（需 `TEST_ALLOW_API_WRITES=true` + 本地 URL + `IMBOY_SOLIDIFIED_KEY`）。测试使用既有测试群，不执行取消日程、删除任务、撤销投票或费用结算。
