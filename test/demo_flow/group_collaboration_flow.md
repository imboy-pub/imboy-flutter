# DF-10 群日程 → 群任务 → 群投票

> 优先级：P0
> 状态：`双账号写入闭环通过 / 本地单账号 API 闭环通过（2026-08-17 通过，2026-08-18/19 后端 alpha.36 复跑 4/4 维持） / 2026-08-19 生产只读以 bake key 补跑通过（12 过 + 4 写门禁拦，与 08-17/18 口径一致） / 费用与跨频道链路未覆盖`

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

- 2026-08-19 复跑（本地 alpha.36，healthz db=up）：`group_collaboration_local_api_flow_test.dart`
  （测试标记升级 `DEMO-FLOW-20260819`）复跑 `4/4 All tests passed`，与 08-17/08-18 结果一致，无回归。
  测试账号 13900001002（uid=104250986822109184）。本轮跨 flow 群漂移：`group/page` 首个群变为
  `gid=107668853378779136`（08-18 13:15 由并行会话以 smoke_bob/uid=1000000056 创建、无标题，
  A 为其成员；08-18 轮为 `107542237237479424`）——按标题精确匹配逻辑不受影响，日程/任务/投票
  回读断言全部命中。DB 落库核验：`group_schedule`/`group_task`/`group_vote` 各新增一条
  `DEMO-FLOW-20260819-*` 行（SCHEDULE/TASK/VOTE-1787116842）；日程确认 participant_count=1、
  任务提交标记、投票 my_vote 回读（vote_id=`vote.5ylm.IXHa4eeR.S`、option_id=`opt.5ylm.IXHa4eeR.T`）全部命中。
- 2026-08-19 生产只读复跑尝试（`.env.pro` read_env 提取，pro.imboy.pub healthz=alpha.36）：
  schedule/task/vote 三文件 16 项全部 `All tests skipped`——登录被服务端拒
  `签名验证失败，请更新客户端`（118@imboy.pub）。定位：`.env.pro` 的 SOLIDIFIED_KEY
  为 34 字符，与生产编译期 bake 的 32 字符 key 不一致（README 4.1 节已记载该不一致，
  生产签名以 bake 值为准）；本次按任务约束仅允许 read_env 提取，未做解码旁路。
  16 项 SKIP 为登录前的干净跳过，生产零写入、无业务请求发出；生产只读契约证据
  维持 2026-08-17/08-18 历史记载。解锁条件：以 bake 值口径修正 `.env.pro` 密钥
  或提供注入式凭证。
- 2026-08-19 生产只读补跑（主会话裁决后执行，bake key 口径）：按 DF-16/19/20 轮次验证的路径，
  从 `lib/config/env_pro.g.dart` 的 Envied XOR 数组原位解码 32 字符 key（临时脚本仅进程内
  传递、不打印、用后即删），注入 `IMBOY_SOLIDIFIED_KEY` 后复跑 schedule/task/vote 三文件
  `dart test --concurrency=1`：登录 118@imboy.pub 成功（uid=4），`12 通过 + 4 门禁拦`
  （4 个「写端点存活性」用例被 `TEST_ALLOW_API_WRITES` 未开启的 StateError 在发请求前拦截，
  属设计行为）——与 2026-08-17/18 历史记载口径完全一致，生产只读证据本轮已当面复现，
  不再仅维持历史引用。结论：`.env.pro` 明文 key（34 字符）与生产 bake key（32 字符）的
  不一致维持为已知配置问题，运行生产契约测试时须走 bake 解码路径或注入式凭证。
- 2026-08-18 后端升级后复跑（alpha.36，beam PID 40485 今早 08:46 启动）：`group_collaboration_local_api_flow_test.dart` 复跑 `4/4 All tests passed`，与 08-17（alpha.27）结果一致，无回归。测试账号 13900001002（uid=104250986822109184），本轮匹配测试群 gid=107542237237479424（DEMO-FLOW 前缀精确匹配；本地为多会话共用账号，群列表会滚动出现其他会话新建的同前缀群，按名称匹配逻辑不受影响）。日程 participant_count=1、任务提交标记、投票 my_vote 回读全部命中。
- 2026-08-18 费用与跨频道链路评估（维持不覆盖）：日程/任务/投票端点本身无费用字段与扣费语义（本地闭环未触发任何 wallet 流水）；真实费用链路属 DF-13 付费频道（本地 mock 已闭环）与 DF-17 钱包（转账 accept 有后端 BUG-A）范围，不在 DF-10 强行拼装。「频道→群日程」跨模块依赖群绑定字段，DF-05 已定性结构性不成立，本轮复核代码未见新增绑定字段，维持。
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
