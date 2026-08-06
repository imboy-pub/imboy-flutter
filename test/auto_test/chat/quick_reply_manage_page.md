# `page/chat/widget/quick_reply_manage_page.dart`

> 功能点 11 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 待复验 | 2026-08-06 | `page/chat/widget/quick_reply_manage_page.dart` | 从快捷回复面板进入管理页 | BUG已修待验 | 批次26 | 1 | 0 | 1 | 已修待真机复验：管理键在 ListView 末尾且懒构建，屏幕外根本没被建；改 Row+Expanded+固定尾部，测试用 getRect 断言在 viewport 内并做了 A/B 反证 |
| 阻塞 | 解阻塞条件：BUG#101 修复后管理页可达 | `page/chat/widget/quick_reply_manage_page.dart` | 加载快捷回复列表与空态 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：BUG#101 修复后管理页可达 | `page/chat/widget/quick_reply_manage_page.dart` | 点 FAB 新增快捷回复短语 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：BUG#101 修复后管理页可达 | `page/chat/widget/quick_reply_manage_page.dart` | 超出条数上限时提示拒绝 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：BUG#101 修复后管理页可达 | `page/chat/widget/quick_reply_manage_page.dart` | 重复内容校验并提示 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：BUG#101 修复后管理页可达 | `page/chat/widget/quick_reply_manage_page.dart` | 点击条目进入编辑弹窗 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：BUG#101 修复后管理页可达 | `page/chat/widget/quick_reply_manage_page.dart` | 点铅笔按钮编辑短语 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：BUG#101 修复后管理页可达 | `page/chat/widget/quick_reply_manage_page.dart` | 左划删除单条快捷回复 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：BUG#101 修复后管理页可达 | `page/chat/widget/quick_reply_manage_page.dart` | 拖拽手柄调整条目顺序 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：BUG#101 修复后管理页可达 | `page/chat/widget/quick_reply_manage_page.dart` | 未登录态隐藏新增按钮 | 未测 | - | 0 | 0 | 0 | 需退登账号构造 |
| 阻塞 | 解阻塞条件：BUG#101 修复后管理页可达 | `page/chat/widget/quick_reply_manage_page.dart` | 输入框最大长度限制生效 | 未测 | - | 0 | 0 | 0 | |
