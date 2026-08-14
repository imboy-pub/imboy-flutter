# `page/mine/language/language_page.dart`

> 功能点 9 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/mine/language/language_page.dart` | 渲染十个语言的自称名称列表 | 已通过 | §二十九 | 0 | 0 | 0 | |
| 无待办 | - | `page/mine/language/language_page.dart` | 当前语言项显示对勾标记 | 已通过 | §二十九 | 0 | 0 | 0 | |
| 无待办 | - | `page/mine/language/language_page.dart` | 点击语言项全局即时生效 | 已通过 | §二十九 | 0 | 0 | 0 | |
| 无待办 | - | ``page/mine/language/language_page.dart`` | 持久化所选语言到本地存储 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/mine/language/language_page.dart`` | 选完立刻返回不触发未挂载异常 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/mine/language/language_page.dart`` | 渲染选择语言分组标题 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | `page/mine/language/language_page.dart` | 提供跟随系统语言选项 | 已通过 | 批次28 | 1 | 1 | 0 | 批次28 真机复验三条全过：①列表首项是「跟随系统」②选中后勾唯一移到该项③改系统语言 zh-Hans-US→en-US 重启 App，界面跟随变英文；改回 zh-Hans-US 后跟随变回中文（双向）。⚠️「默认选中跟随系统」只对**新装**成立，本机是升级安装保留原有 zh-CN 选择，未覆盖新装路径。原修复记录： 已加「跟随系统」置顶项并作为新装默认。存哨兵值 `Keys.systemLanguageCode` 而非具体枚举名（存具体值就退化成普通选择，改系统语言不再跟随）；判定收敛到 `Keys.isFollowSystemLanguage`，run.dart 启动恢复与本页共用一份防漂移 —— 哨兵值若落进 `firstWhere` 会被 orElse 兜成简体中文，重启即失效。补 4 条单测并反证。待真机验：①列表首项有「跟随系统」且默认选中 ②切换系统语言后 App 跟随 ③选具体语言后勾只出现一个 |
| 无待办 | - | ``page/mine/language/language_page.dart`` | 切换阿拉伯语后 RTL 布局表现 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/mine/language/language_page.dart`` | 存储值非法时回落简体中文 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
