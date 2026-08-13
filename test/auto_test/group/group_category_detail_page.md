# `page/group/category/group_category_detail_page.dart`

> 功能点 10 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 待复验 | - | `page/group/category/group_category_detail_page.dart` | 重命名分组并同步父页列表 | 待重验 | 批次79 | 2 | 0 | 2 | 批次79：alpha.27 已发布；迁移00000060删6个误挂 updated_at 触发器已在生产迁移版本66执行（BUG-3 触发器根因 DB 层面已消除）；前端 BUG-A(3f877d1e pop null)在当前 APK；待真机构造分组场景完整验证重命名+父页同步闭环后解决 bug |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 名称未变更时跳过重命名请求 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 删除分组并二次确认拦截 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 删除成功后回传刷新并退出 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 右上角弹出更多操作动作面板 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 未分类桶隐藏重命名删除入口 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 列表项直接触发重命名与删除 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 渲染分组用途说明提示卡片 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 重命名与删除失败的错误提示 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/category/group_category_detail_page.dart` | 标题栏实时反映当前分组名 | 待重验 | - | 0 | 0 | 0 | |
