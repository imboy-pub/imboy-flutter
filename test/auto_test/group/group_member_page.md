# `page/group/group_member/group_member_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/group/group_member/group_member_page.dart` | 首屏加载本地与服务端成员列表 | 已通过 | 批次113 | 0 | 0 | 0 | 批次113 macOS 沙箱：22 人群（GMSmoke大群验收，本地 PG 造数）第一页 20 条实证；配方见 integration_test/group/group_member_acceptance_test.dart |
| 无待办 | - | `page/group/group_member/group_member_page.dart` | 下拉刷新重载第一页成员 | 已通过 | 批次113 | 0 | 0 | 0 | 批次113 沙箱：overscroll 下拉触发 onRefresh，标题 22→20（重载第一页语义） |
| 无待办 | - | `page/group/group_member/group_member_page.dart` | 上拉加载更多分页成员 | 已通过 | 批次113 | 0 | 0 | 0 | 批次113 沙箱：触底 onLoad 20→22（第 2 页含群主+管理员） |
| 无待办 | - | `page/group/group_member/group_member_page.dart` | 分页失败回滚页码避免漏页 | 已通过 | 批次113 | 2 | 2 | 0 | 批次113 故障注入实证。双真 bug：服务端 handler 把 ds 错误吞成 total=0 空列表 success（客户端停 20 条且 hasMore=false 静默丢第 2 页）+客户端业务失败（ok=false）不回滚页码。双侧修复（imboy handler error 化+客户端 else 分支回滚）；adapterForTest 注入验证恢复后重试命中第 2 页 20→22。eunit 失败路径用例+integration_test/group/gm_pagination_failover_test.dart |
| 无待办 | - | `page/group/group_member/group_member_page.dart` | 搜索框按昵称群昵称过滤 | 已通过 | 批次113 | 0 | 0 | 0 | 批次113 沙箱：即时过滤命中唯一行 |
| 无待办 | - | `page/group/group_member/group_member_page.dart` | 角色筛选「全部」展示所有成员 | 已通过 | 批次113 | 0 | 0 | 0 | 批次113 沙箱：全量 22 条渲染 |
| 无待办 | - | `page/group/group_member/group_member_page.dart` | 角色筛选群主管理员成员三档 | 已通过 | 批次113 | 0 | 0 | 0 | 批次113 沙箱：三档各命中（成员档 role<=2 含嘉宾；服务端 m.id desc 序，非 role 序） |
| 无待办 | - | `page/group/group_member/group_member_page.dart` | 群主与管理员角色徽章渲染 | 已通过 | 批次113 | 0 | 0 | 0 | 批次113 沙箱：行内徽章与 segment 标签同文共存（findsAtLeastNWidgets(2)） |
| 无待办 | - | `page/group/group_member/group_member_page.dart` | 禁言剩余时间徽章展示 | 已通过 | 批次113 | 0 | 0 | 0 | 批次113 沙箱：禁言 1 天/禁言 2 小时双徽章；RFC3339 mute_until 解析链完好 |
| 无待办 | - | `page/group/group_member/group_member_page.dart` | 禁言解禁事件实时更新列表 | 已通过 | 批次113 | 0 | 0 | 0 | 批次113 沙箱：GroupMemberUnmuteEvent 注入（AppEventBus 驱动真实订阅路径）徽章 2→1 |
| 无待办 | - | `page/group/group_member/group_member_page.dart` | 点成员进详情并回传刷新 | 已通过 | 批次113 | 0 | 0 | 0 | 批次113 沙箱：GroupMemberDetailPage 挂载+返回列表保留（回传 result=true 场景需移除/转让操作，未见回归） |
| 无待办 | - | `page/group/group_member/group_member_page.dart` | 筛选无结果区分两类空态 | 已通过 | 批次113 | 0 | 0 | 0 | 批次113 沙箱：搜索空态「无搜索结果」与角色空态「暂无管理员」（bob 独群）双实证 |
