# `page/user_tag/contact_tag_list/contact_tag_list_page.dart`

> 功能点 12 个 | bug 发现 3 / 解决 3 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 进页加载并展示标签列表 | 已通过 | 批次28 | 1 | 1 | 0 | 批次28 真机复验通过：`qa0804 (2)` 有成员→不渲染副标题（不再谎报「暂无数据」）；`qa0806empty (0)` 真零成员→显示「暂无数据」。标题 (N) 与副标题不再自相矛盾。原修复记录： 批次27 真机发现副标题恒显示「暂无数据」（qa0804 标题算出 (2)、详情页确有 2 名成员）。根因：`refererTime` 由服务端下发，`subtitle` 却是本机进过详情页才写入的派生列，`user_tag/page` 从不返回它。已改为 `buildListSubtitle`：有预览显示预览、有成员但无预览不渲染副标题、确为零成员才显示空态（不补拉成员，那是 N+1 请求）。补 3 条单测并反证通过，待装机复验 |
| 无待办 | - | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 加载中显示居中菊花 | 已通过 | 批次33 | 0 | 0 | 0 | 代码确认：L83 isLoading→SliverFillRemaining(Center(CupertinoActivityIndicator))；真机请求过快抓不到 loading 帧 |
| 无待办 | - | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 无标签时显示空数据视图 | 已通过 | 批次33 | 0 | 0 | 0 | 真机确认：当前账号标签列表为空时显示「暂无数据」；上轮删 qa0806empty 后同款验证 |
| 阻塞 | 生产 user_tag TSID 缺失修复中 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 搜索框输入实时过滤标签 | 未测 | - | 0 | 0 | 0 | 需 ≥2 标签数据，新建被后端阻断 |
| 阻塞 | 生产 user_tag TSID 缺失修复中 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 滚动触底自动加载更多标签 | 未测 | - | 0 | 0 | 0 | 需分页数据量 |
| 阻塞 | 生产 user_tag TSID 缺失修复中 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 拖拽手柄重排标签顺序 | 未测 | - | 0 | 0 | 0 | 需 ≥2 标签 |
| 无待办 | - | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 加号打开新建标签面板并生效 | 已通过 | §三十一 | 1 | 1 | 0 | |
| 无待办 | - | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 新建标签后列表立即刷新 | 已通过 | §三十一 | 1 | 1 | 0 | |
| 阻塞 | 后端 user_tag 发布 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 左滑打开重命名标签面板 | 未测 | 批次34 | 0 | 0 | 0 | 真机 logcat 实测 /api/v1/user_tag/add 返回 23502 not_null_violation（生产缺 TSID 修复）；修复已在 imboy 工作区落盘未提交（并发 10:00:50），发布后解阻塞 |
| 阻塞 | 后端 user_tag 发布 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 左滑删除标签弹出二次确认 | 未测 | 批次34 | 0 | 0 | 0 | 真机 logcat 实测 /api/v1/user_tag/add 返回 23502 not_null_violation（生产缺 TSID 修复）；修复已在 imboy 工作区落盘未提交（并发 10:00:50），发布后解阻塞 |
| 阻塞 | 后端 user_tag 发布 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 删除成功与失败分别弹提示 | 未测 | 批次34 | 0 | 0 | 0 | 真机 logcat 实测 /api/v1/user_tag/add 返回 23502 not_null_violation（生产缺 TSID 修复）；修复已在 imboy 工作区落盘未提交（并发 10:00:50），发布后解阻塞 |
| 阻塞 | 后端 user_tag 发布 | `page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 详情页返回后重读副标题与计数 | 未测 | 批次34 | 0 | 0 | 0 | 真机 logcat 实测 /api/v1/user_tag/add 返回 23502 not_null_violation（生产缺 TSID 修复）；修复已在 imboy 工作区落盘未提交（并发 10:00:50），发布后解阻塞 |
