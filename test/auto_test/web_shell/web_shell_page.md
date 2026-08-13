# `page/web_shell/web_shell_page.dart`

> 功能点 11 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/web_shell/web_shell_page.dart` | 窄屏时降级渲染移动端入口 | 已通过 | 批次78 | 0 | 0 | 0 | 通过 web_shell_page_test 验证 320px 与 899px 边界下的 mobileFallback 降级渲染 |
| 无待办 | - | `page/web_shell/web_shell_page.dart` | 宽屏时渲染左中右三栏布局 | 已通过 | 批次78 | 0 | 0 | 0 | 通过 web_shell_page_test 验证 >=900px 下渲染 NavRail + MiddlePanel + MainPanel 三栏结构 |
| 无待办 | - | `page/web_shell/web_shell_page.dart` | 点击左栏导航项切换当前标签 | 已通过 | 批次78 | 0 | 0 | 0 | 通过 web_shell_page_test 验证 NavRail 点击切换 Tab 1 (contactTab) 和 Tab 2 等联动行为 |
| 无待办 | - | `page/web_shell/web_shell_page.dart` | 中栏切换标签时保留各页状态 | 已通过 | 批次78 | 0 | 0 | 0 | 通过 web_shell_page_test IndexedStack 保持验证 |
| 无待办 | - | `page/web_shell/web_shell_page.dart` | 消息导航项展示未读数角标 | 已通过 | 批次78 | 0 | 0 | 0 | 通过 web_shell_page_test 验证 messageBadgeCount 渲染 |
| 无待办 | - | `page/web_shell/web_shell_page.dart` | 联系人导航项展示待处理角标 | 已通过 | 批次78 | 0 | 0 | 0 | 通过 web_shell_page_test 验证 |
| 无待办 | - | `page/web_shell/web_shell_page.dart` | 频道导航项展示未读数角标 | 已通过 | 批次78 | 0 | 0 | 0 | 通过 web_shell_page_test 验证 |
| 无待办 | - | `page/web_shell/web_shell_page.dart` | 未选中条目时右栏展示欢迎屏 | 已通过 | 批次78 | 0 | 0 | 0 | 通过 web_shell_page_test 验证 selection=null 时右栏展示 welcomePanel |
| 无待办 | - | `page/web_shell/web_shell_page.dart` | 选中会话时右栏渲染聊天视图 | 已通过 | 批次78 | 0 | 0 | 0 | 通过 web_shell_page_test 验证 ChatSelection 渲染 chatBuilder 视图 |
| 无待办 | - | `page/web_shell/web_shell_page.dart` | 选中联系人频道或我的分发对应视图 | 已通过 | 批次78 | 0 | 0 | 0 | 通过 web_shell_page_test 验证 ContactSelection 等切换行为 |
| 无待办 | 2026-08-09 | `page/web_shell/web_shell_page.dart` | 页面背景色随主题明暗切换 | 已通过 | 批次65 | 1 | 1 | 0 | widget 测试覆盖（web_shell_page_test.dart「Scaffold 背景色随主题明暗切换」）：实现即 `Scaffold(backgroundColor: colorScheme.surface)`，M3 surface 随 brightness 自动切换，代码正确；曾疑似 bug 实为测试陷阱——MaterialApp 默认 themeAnimationDuration=200ms，主题切换经 AnimatedTheme lerp，未等动画完成就读 Scaffold 会拿到过渡中间值（伪失败），测试补 `pump(300ms)` 后两主题断言全绿 |
