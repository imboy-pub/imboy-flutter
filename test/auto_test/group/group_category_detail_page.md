# `page/group/category/group_category_detail_page.dart`

> 功能点 10 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 待发布生效+真机复验 | `page/group/category/group_category_detail_page.dart` | 重命名分组并同步父页列表 | 待重验 | 批次26+31 | 2 | 0 | 2 | BUG-A（08-06 已修 3f877d1e，pop null 问题）：前端已修但 14:53 后构建需新 APK。BUG-3（08-08 真机新发现）：重命名确认后停留详情页且父页列表旧名；根因=00000009 给无 updated_at 列的表挂 set_updated_at() 触发器，UPDATE user_group_category 必抛 "record new has no field updated_at"；迁移 00000060 已删 6 个误挂触发器（提交 4729a409 未 push），待发布后复验重命名/删除/排序 |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 名称未变更时跳过重命名请求 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 删除分组并二次确认拦截 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 删除成功后回传刷新并退出 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 右上角弹出更多操作动作面板 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 未分类桶隐藏重命名删除入口 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 列表项直接触发重命名与删除 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 渲染分组用途说明提示卡片 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 重命名与删除失败的错误提示 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 标题栏实时反映当前分组名 | 待重验 | - | 0 | 0 | 0 | |
