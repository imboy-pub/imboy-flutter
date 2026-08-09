# `page/mine/denylist/denylist_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/mine/denylist/denylist_page.dart` | 展示顶部黑名单风险说明卡片 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测「黑名单说明」标题+「被拉黑的用户无法给你发送消息，也无法查看你的动态。点击用户可...」（L128-176 警告卡片） |
| 无待办 | - | `page/mine/denylist/denylist_page.dart` | 进入页面自动加载黑名单列表 | 已通过 | 批次29 | 0 | 0 | 0 | deep link 进入 → logcat GET /api/v1/friend/denylist/page?page=1&size=1000 发出并返回（L39 loadData） |
| 无待办 | - | `page/mine/denylist/denylist_page.dart` | 首次加载展示加载中状态 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 L70 AsyncStateView(isLoading: isLoading && items.isEmpty)（加载瞬态不可实测） |
| 无待办 | - | `page/mine/denylist/denylist_page.dart` | 加载失败展示错误与重试按钮 | 已通过 | 批次29 | 0 | 0 | 0 | 飞行模式进入 →「加载失败，请重试」+重试按钮（get_ui 实测）→ 恢复网络点重试 → 空态恢复，闭环通过（onRetry=_load L73） |
| 无待办 | - | `page/mine/denylist/denylist_page.dart` | 无数据时展示黑名单为空态 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测「黑名单为空」（emptyText t.contact.denylistEmpty L74） |
| 无待办 | - | `page/mine/denylist/denylist_page.dart` | 渲染右侧字母索引栏 | 已通过 | 批次29 | 0 | 0 | 0 | 有数据时 get_ui 实测右侧索引栏 desc="↑\n#"（indexBarData: ['↑', ...currIndexBarData] L103，uid7 归 "#" 组） |
| 无待办 | - | `page/mine/denylist/denylist_page.dart` | 渲染悬浮字母分组标题 | 已通过 | 批次29 | 0 | 0 | 0 | 有数据时 get_ui 实测悬浮标题 "#"（susItemBuilder L87-102；uid7 无拼音标题归 "#" 组 L54-64） |
| 无待办 | - | `page/mine/denylist/denylist_page.dart` | 展示头像昵称并在昵称空时回落账号 | 已通过 | 批次29 | 0 | 0 | 0 | 条目渲染实测（Avatar 36x36+clickable 条目+「已拉黑」副标题 L209-226）；title 回落逻辑代码证实 L204-205（nickname.isEmpty ? account : nickname） |
| 无待办 | - | `page/mine/denylist/denylist_page.dart` | 点击条目进入对方资料页 | 已通过 | 批次29 | 0 | 0 | 0 | 实测点击条目 → uid7 资料页（PeopleInfoPage scene='denylist'），页面含「已添加至黑名单，你将不再收到对方的消息」警告（L184-196 + L305-306） |
| 无待办 | - | `page/mine/denylist/denylist_page.dart` | 从资料页返回后自动刷新列表 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 L193-195 push().then(loadData)；返回后列表数据保留（本地 SQLite 命中不发网络请求是 provider L96-102 设计） |
| 无待办 | - | `page/mine/denylist/denylist_page.dart` | 左滑条目显示移除操作背景 | 已通过 | 批次29 | 0 | 0 | 0 | 实测左滑后「移出」红色背景持续显示（get_ui desc 含「移出」，Dismissible endToStart L229-251+secondaryBackground L233-251）；移除闭环见下行 |
| 无待办 | - | `page/mine/denylist/denylist_page.dart` | 滑动移除成功或失败弹出提示 | 已通过 | 批次29 | 0 | 0 | 0 | 实测快速左滑（input swipe 120ms）→ POST /api/v1/friend/denylist/remove 发出+返回 →「清除缓存: user_denylist」成功链 → 条目消失列表恢复空态；成功提示 AppLoading.showSuccess（EasyLoading 不进语义树），失败分支 L261 showError 代码证实；黑名单关系已还原（测试期间拉黑 uid7 后移除，结束=初始空状态） |
