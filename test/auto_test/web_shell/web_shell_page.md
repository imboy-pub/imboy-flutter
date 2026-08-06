# `page/web_shell/web_shell_page.dart`

> 功能点 11 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 需 Web 环境运行（移动端刻意不可达） | `page/web_shell/web_shell_page.dart` | 窄屏时降级渲染移动端入口 | 未测 | - | 0 | 0 | 0 | `README.md:124` 明写移动端走 bottom_navigation，非缺陷 |
| 阻塞 | 需 Web 环境运行 | `page/web_shell/web_shell_page.dart` | 宽屏时渲染左中右三栏布局 | 未测 | - | 0 | 0 | 0 | 900 像素为分界 |
| 阻塞 | 需 Web 环境运行 | `page/web_shell/web_shell_page.dart` | 点击左栏导航项切换当前标签 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需 Web 环境运行 | `page/web_shell/web_shell_page.dart` | 中栏切换标签时保留各页状态 | 未测 | - | 0 | 0 | 0 | IndexedStack 四个标签 |
| 阻塞 | 需 Web 环境运行 | `page/web_shell/web_shell_page.dart` | 消息导航项展示未读数角标 | 未测 | - | 0 | 0 | 0 | 计数为零时不显示 |
| 阻塞 | 需 Web 环境运行 | `page/web_shell/web_shell_page.dart` | 联系人导航项展示待处理角标 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需 Web 环境运行 | `page/web_shell/web_shell_page.dart` | 频道导航项展示未读数角标 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需 Web 环境运行 | `page/web_shell/web_shell_page.dart` | 未选中条目时右栏展示欢迎屏 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需 Web 环境运行 | `page/web_shell/web_shell_page.dart` | 选中会话时右栏渲染聊天视图 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需 Web 环境运行 | `page/web_shell/web_shell_page.dart` | 选中联系人频道或我的分发对应视图 | 未测 | - | 0 | 0 | 0 | sealed switch 三个分支 |
| 阻塞 | 需 Web 环境运行 | `page/web_shell/web_shell_page.dart` | 页面背景色随主题明暗切换 | 未测 | - | 0 | 0 | 0 | — |
