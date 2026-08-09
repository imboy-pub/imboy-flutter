# `page/mine/dark_model/dark_model_page.dart`

> 功能点 9 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/mine/dark_model/dark_model_page.dart` | 切换跟随系统主题开关 | 已通过 | §十七 | 0 | 0 | 0 | | 批次51 真机开关开→checked+主题组整个隐藏；关→主题组回落；shared_prefs theme_follow_system 同步翻转
| 无待办 | — | `page/mine/dark_model/dark_model_page.dart` | 开启跟随系统时隐藏主题选项组 | 已通过 | 批次27 | 1 | 1 | 0 | 预存红灯已定性：**测试写错，页面一直是对的**。selectIndex=2 走 tapDarkItem(2)→强制浅色，页面早按 QA#56 把文案从「系统默认」改为「浅色模式」，只有这条断言没跟着改。修断言后 8/8 全绿 |
| 无待办 | - | `page/mine/dark_model/dark_model_page.dart` | 选择强制浅色主题并即时生效 | 已通过 | §十七 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/dark_model/dark_model_page.dart` | 选择强制深色主题并即时生效 | 已通过 | §十七 | 0 | 0 | 0 | | 批次51 真机点深色模式→shared_prefs theme_is_dark_mode=true 实锤即时生效；切回浅色恢复 false；代码 L84-89 toggleTheme(isDark:true)
| 回归复测 | 2026-08-07 | `page/mine/dark_model/dark_model_page.dart` | 当前选中项显示对勾标记 | 已通过 | §十七 | 0 | 0 | 0 | | 批次51 代码确认 L96-97/L106-107 selectIndex==2/3→CupertinoIcons.check_mark 18px iosBlue；语义树无法看 Icon 视觉
| 回归复测 | 2026-08-07 | `page/mine/dark_model/dark_model_page.dart` | 重复点击已选项时不重复切换 | 已通过 | §十七 | 0 | 0 | 0 | | 批次51 真机重复点浅色模式 theme_is_dark_mode 保持 false 无重复切换；代码 L83 同值提前 return
| 回归复测 | 2026-08-07 | `page/mine/dark_model/dark_model_page.dart` | 进入页面时回显当前主题状态 | 已通过 | §十七 | 0 | 0 | 0 | | 批次51 真机设置页入口「已关闭」+页内跟随系统开关未 checked+主题组可见，回显一致；代码 L41-47 按 themeMode 派生
| 回归复测 | 2026-08-07 | `page/mine/dark_model/dark_model_page.dart` | 关闭跟随系统后回落实际亮暗 | 已通过 | §十七 | 0 | 0 | 0 | | 批次51 真机关闭后主题组重新显示（configLocalTheme 按当前亮暗设 selectIndex）；代码 L72-74
| 回归复测 | 2026-08-07 | `page/mine/dark_model/dark_model_page.dart` | 渲染显示与主题分组标题 | 已通过 | §十七 | 0 | 0 | 0 | | 批次51 真机「显示」「主题」分组标题；代码 sectionDisplay/sectionTheme 大写化
