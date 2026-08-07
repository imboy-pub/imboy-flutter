# `page/personal_info/set_nickname/set_nickname_page.dart`

> 功能点 11 个 | bug 发现 2 / 解决 1 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 输入框自动聚焦并回填当前昵称 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/personal_info/set_nickname/set_nickname_page.dart` | 底部展示昵称字符规则说明 | 已通过 | 批次19 | 0 | 0 | 0 | |
| 待复验 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_provider.dart` | 进页面时剩余字数初始值 | BUG已修待验 | 批次28 | 1 | 0 | 1 | 批次28 真机新发现：同一个昵称「117👩‍👩‍👧」，**进页面显示 13、敲一下键盘跳成 20**。上轮只改了 `updateNickname`（onChange）的口径，`build()` 的 `remainingChars: 24 - originalNickname.length` 仍是 UTF-16。两处各写一遍就是根因，已收敛成唯一入口 `SetNicknameNotifier.remainingCharsFor()`，初始化与 onChange 共用。补 2 条单测（SN-4/SN-5）并反证通过 —— 把口径退回 `String.length` 后 SN-4 精确变红且 Actual 恰为 13，与真机现象一致。⚠️修完已重装但**未再进昵称页真机确认**（当前昵称已改回纯 ASCII「117」，两种口径下都是 21，真机区分不出来；要复验需再次把昵称改成含 emoji，会对好友可见）
| 无待办 | - | `page/personal_info/set_nickname/set_nickname_page.dart` | 右侧剩余字数计数实时更新 | 已通过 | 批次28 | 1 | 1 | 0 | 批次28 真机复验通过：输入 ZWJ 家庭 emoji「117👩‍👩‍👧」（5 码位 / 8 个 UTF-16 code unit）计数为 20，即该 emoji 计 1 个字素簇（修前 UTF-16 口径会显示 13）。保存后**用服务端搜索自己**（`user_search` 58628）回读到「117👩‍👩‍👧」—— 排除乐观更新的落库硬证据。测试后已把昵称改回 117。原修复记录： 核实后修正定性：后端**根本不校验**昵称（在 user_agg 的透传白名单里，注释写明「无校验原样落库」），客户端是唯一防线，且客户端内部两个口径就在打架 —— 输入框 `maxLength:24` 走 LengthLimitingTextInputFormatter 按字素簇截断，provider 却用 `String.length`（UTF-16 code unit，一个 👨‍👩‍👧‍👦 占 11），输入框放行的内容被判超长、存不下去。已双端统一到字素簇：客户端改 `.characters.length`；后端把 nickname 移出透传白名单并按 `string:length/1`（grapheme 口径）校验 2~24，非法 UTF-8 走 `unicode:characters_to_list` 返回错误而非抛 badarg 变 500。后端补 6 条 eunit（含 ZWJ emoji 计 1、非法 UTF-8、非 binary），反证通过。待真机验：输入 emoji 时计数与保存行为 |
| 回归复测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 超出长度时计数变红警示 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 非法输入展示校验错误提示行 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 保存按钮按可保存态启用或置灰 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 点保存收起键盘并提交昵称 | 待重验 | - | 0 | 0 | 0 | |
| 待首测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 保存中显示菊花并禁止重复点击 | 未测 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 保存成功退栈并回传刷新标志 | 待重验 | - | 0 | 0 | 0 | |
| 待首测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 保存失败弹出更新失败提示 | 未测 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 输入达24字符时硬截断 | 待重验 | - | 0 | 0 | 0 | |
