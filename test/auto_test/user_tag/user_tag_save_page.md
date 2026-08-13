# `page/user_tag/user_tag_save/user_tag_save_page.dart`

> 功能点 11 个 | bug 发现 3 / 解决 2 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/user_tag/user_tag_save/user_tag_save_page.dart` | 新增模式标题显示添加标签 | 已通过 | 批次32 | 0 | 0 | 0 | 真机确认标题「添加标签」 |
| 无待办 | - | `page/user_tag/user_tag_save/user_tag_save_page.dart` | 编辑模式回填原标签名称 | 已通过 | 批次32 | 0 | 0 | 0 | 修改标签面板自动回填 qa0804（同入口） |
| 无待办 | - | `page/user_tag/user_tag_save/user_tag_save_page.dart` | 输入框自动聚焦并随键盘避让 | 已通过 | 批次32 | 0 | 0 | 0 | autofocus 生效（get_ui focused）；键盘弹出后完成按钮仍可点（resizeToAvoidBottomInset） |
| 无待办 | - | `page/user_tag/user_tag_save/user_tag_save_page.dart` | 输入变化驱动完成按钮高亮 | 已通过 | 批次32 | 0 | 0 | 0 | 代码路径确认（_valueChanged → highlighted） |
| 无待办 | - | `page/user_tag/user_tag_save/user_tag_save_page.dart` | 空白名称点完成不提交请求 | 已通过 | 批次32 | 0 | 0 | 0 | 空名点完成零网络请求、面板不关 |
| 无待办 | - | `page/user_tag/user_tag_save/user_tag_save_page.dart` | 新增标签成功写入列表并关闭 | 已通过 | 批次75 | 1 | 1 | 0 | 真机复验通过：联系人标签→添加→输入 tag75→完成→`/api/v1/user_tag/add` 200 无 not_null_violation（9586c7dd TSID 修复在 alpha.24+ 已生效），列表出现「tag75 (0)」，页面自动关闭 |
| 无待办 | - | `page/user_tag/user_tag_save/user_tag_save_page.dart` | 新增标签失败弹出错误提示 | 已通过 | 批次32 | 0 | 0 | 0 | API 报错→tipFailed 提示+面板不关闭（代码路径+行为确认） |
| 无待办 | - | `page/user_tag/user_tag_save/user_tag_save_page.dart` | 重命名后同步替换关联对象标签 | 已通过 | 批次72 | 1 | 1 | 0 | 真机实证残留 "qqqa-rn-10c," → 代码三处修复（change_scene_tag 事务连接/空标签更新/regexp 边界替换）；批次73 生产复验 delete 完整序列（add 3 → 删中/头/尾）friend.tag 归零且无拼接（alpha.24 已发布） |
| 无待办 | - | `page/user_tag/user_tag_save/user_tag_save_page.dart` | 重命名成功弹提示并关闭面板 | 已通过 | 批次72 | 1 | 1 | 0 | 重命名成功 tip 弹出且面板关闭；随后列表同步刷新为新名 |
| 无待办 | - | `page/user_tag/user_tag_save/user_tag_save_page.dart` | 保存中防抖禁用完成按钮 | 已通过 | 批次32 | 0 | 0 | 0 | 代码路径确认（_isSaving 期间 onPressed null）；保存瞬间无法目视 |
| 无待办 | - | `page/user_tag/user_tag_save/user_tag_save_page.dart` | 点关闭图标退出保存面板 | 已通过 | 批次32 | 0 | 0 | 0 | xmark 退出回标签列表，不保存 |
