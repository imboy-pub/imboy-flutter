# `page/personal_info/profile/widgets/privacy_settings.dart`

> 功能点 10 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)
>
> 本页原为独立验收记录（2026-08-09，真机 MRD_AL00 / alpha.15 / uid=117），
> 已收编进标准状态机。单设备真机证据 → `无待办`；仅代码追踪/契约测试、
> 缺真机单独验证的 → `回归复测`（§3.4 补单独验证）。

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/personal_info/profile/widgets/privacy_settings.dart` | 个人信息页隐私设置入口可达 | 已通过 | 08-09验收 | 0 | 0 | 0 | 真机：我的→头像→个人信息→隐私设置 路径走通 |
| 无待办 | - | `page/personal_info/profile/widgets/privacy_settings.dart` | 渲染"显示在线状态"开关 | 已通过 | 08-09验收 | 0 | 0 | 0 | 真机：「状态设置」分组下开关渲染 |
| 无待办 | - | `page/personal_info/profile/widgets/privacy_settings.dart` | 描述文案正确 | 已通过 | 08-09验收 | 0 | 0 | 0 | 真机："关闭后，好友看不到你的在线状态和最后上线时间；消息投递不受影响" |
| 无待办 | - | `page/personal_info/profile/widgets/privacy_settings.dart` | 开关 ON→OFF 切换 | 已通过 | 08-09验收 | 0 | 0 | 0 | 真机：uiautomator 确认 checked 属性消失 |
| 无待办 | - | `page/personal_info/profile/widgets/privacy_settings.dart` | 开关 OFF→ON 切换 | 已通过 | 08-09验收 | 0 | 0 | 0 | 真机：uiautomator 确认 checked 属性恢复 |
| 无待办 | - | `page/personal_info/profile/widgets/privacy_settings.dart` | 新账号默认关闭在线状态 | 已通过 | 08-09验收 | 0 | 0 | 0 | 契约测试 user_model_test.dart:9 expect(showOnlineStatus, isFalse) |
| 无待办 | - | `page/personal_info/profile/widgets/privacy_settings.dart` | 隐藏状态下发送消息不受影响 | 已通过 | 08-09验收 | 0 | 0 | 0 | 真机：发送 privacy-test-20260809 → 状态「已发送」 |
| 回归复测 | 2026-08-09 | `page/personal_info/profile/widgets/privacy_settings.dart` | A 关闭后 B 好友列表显示 A 离线 | 待重验 | 08-09验收 | 0 | 0 | 0 | 仅代码追踪+EUnit（user_logic.erl:270-277 / user_ds.erl:533-542 / user_server.erl:121-126），缺第二台设备真机验证 |
| 回归复测 | 2026-08-09 | `page/personal_info/profile/widgets/privacy_settings.dart` | A 开启后 B 看到 A 在线 | 待重验 | 08-09验收 | 0 | 0 | 0 | 仅代码追踪+EUnit（chat_state_hide_explicit_online_is_visible_test_），缺第二台设备真机验证 |
| 回归复测 | 2026-08-09 | `page/personal_info/profile/widgets/privacy_settings.dart` | 会话免打扰不弹窗、@ 时弹窗 | 待重验 | 08-09验收 | 0 | 0 | 0 | 仅契约测试（message_conversation_utils_test.dart 7 用例）+代码审查（shouldSuppressNotification），无真机证据 |
