# `page/user_tag/contact_tag_list/contact_tag_list_page.dart`

> 功能点 12 个 | bug 发现 3 / 解决 3 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 进页加载并展示标签列表 | 已通过 | 批次28 | 1 | 1 | 0 | 批次28 真机复验通过：`qa0804 (2)` 有成员→不渲染副标题（不再谎报「暂无数据」）；`qa0806empty (0)` 真零成员→显示「暂无数据」。标题 (N) 与副标题不再自相矛盾。原修复记录： 批次27 真机发现副标题恒显示「暂无数据」（qa0804 标题算出 (2)、详情页确有 2 名成员）。根因：`refererTime` 由服务端下发，`subtitle` 却是本机进过详情页才写入的派生列，`user_tag/page` 从不返回它。已改为 `buildListSubtitle`：有预览显示预览、有成员但无预览不渲染副标题、确为零成员才显示空态（不补拉成员，那是 N+1 请求）。补 3 条单测并反证通过，待装机复验 |
| 待首测 | 2026-08-07 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 加载中显示居中菊花 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | 2026-08-07 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 无标签时显示空数据视图 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | 2026-08-07 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 搜索框输入实时过滤标签 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | 2026-08-07 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 滚动触底自动加载更多标签 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | 2026-08-07 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 拖拽手柄重排标签顺序 | 未测 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 加号打开新建标签面板并生效 | 已通过 | §三十一 | 1 | 1 | 0 | |
| 无待办 | - | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 新建标签后列表立即刷新 | 已通过 | §三十一 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 左滑打开重命名标签面板 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 左滑删除标签弹出二次确认 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 删除成功与失败分别弹提示 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 详情页返回后重读副标题与计数 | 待重验 | - | 0 | 0 | 0 | |
