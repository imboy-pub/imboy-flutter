# DF-10 群日程 → 群任务 → 群投票

> 优先级：P0
> 状态：`列表只读通过 / 写入闭环阻塞`

## 1. 目标

验证群成员可以围绕一个活动创建日程、分配/查看任务并通过投票形成协作结果。

## 2. 前置条件

- [ ] 使用授权测试账号和可回收测试群。
- [ ] 准备唯一测试标题、未来时间和非敏感地点。
- [ ] 不把群日程描述为预约系统，不把投票描述为费用结算。

## 3. TODO 步骤

- [ ] 创建群日程并进入详情。
  - 预期：标题、时间、地点和描述保存成功。
  - 页面计划：[group_schedule_page.md](../auto_test/group/group_schedule_page.md)、[group_schedule_detail_page.md](../auto_test/group/group_schedule_detail_page.md)
- [ ] 普通成员确认参加。
  - 预期：参与状态、人数和群内卡片同步刷新。
- [ ] 创建测试群任务，成员打开任务详情。
  - 预期：任务列表、标题、状态和详情加载正确。
  - 页面计划：[group_task_page.md](../auto_test/group/group_task_page.md)、[group_task_detail_page.md](../auto_test/group/group_task_detail_page.md)
- [ ] 创建测试投票并由成员提交选项。
  - 预期：投票列表、已选项和结果统计正确。
  - 页面计划：[group_vote_page.md](../auto_test/group/group_vote_page.md)、[group_vote_detail_page.md](../auto_test/group/group_vote_detail_page.md)

## 4. 验收标准

- [ ] 日程、任务、投票均能创建/查看/回传结果。
- [ ] 刷新和重新进入后结果不丢失。
- [ ] 活动费用 AA、托管、退款和预约排班不在现有验收范围内。

## 5. 当前覆盖与阻塞

- 日程已有创建和确认参加证据，但列表、详情刷新等仍有回归复测项。
- 任务和投票需要确认当前群应用入口和测试账号权限。
- 2026-08-09：生产 `group_schedule_api_test.dart` 5/5 顺序通过，覆盖我的日程、群日程、详情和无效群组写端点可达；没有在生产创建/确认真实活动。
- 2026-08-09：Android 华为真机 `group/group_collaboration_readonly_test.dart` 通过 `1/1`；动态读取已有群后，群日程、群任务、群投票三个列表页均成功挂载并完成列表读取，未执行任何写入。
- 该测试通过直接导航到现有路由验证列表页，尚不等于从群详情九宫格点击进入，也不等于创建、确认参加、任务回传或投票提交闭环。
- 2026-08-09：创建日程、确认参加、创建任务、创建投票和提交选项均因生产业务写入受控 `SKIP`；现有证据仅覆盖已有群应用列表只读。

## 6. 未来自动化目标

现有 `group/group_collaboration_readonly_test.dart` 已覆盖日程、任务、投票列表只读入口；暂不新增包装测试。创建、确认参加和结果回传需隔离测试群及显式写入授权。
