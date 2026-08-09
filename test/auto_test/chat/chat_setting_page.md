# `page/chat/chat_setting/chat_setting_page.dart`

> 功能点 10 个 | bug 发现 2 / 解决 1 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/chat/chat_setting/chat_setting_page.dart` | 展示当前会话加密模式与说明 | 已通过 | 批次35 | 0 | 0 | 0 | 真机：leeyi 会话显示「标准模式 消息未加密传输」 |
| 无待办 | — | `page/chat/chat_setting/chat_setting_page.dart` | 切换消息免打扰并持久化 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 无待办 | — | `page/chat/chat_setting/chat_setting_page.dart` | 切换阅后即焚开关并持久化 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-08 | `page/chat/chat_setting/chat_setting_page.dart` | 选择阅后即焚销毁时长 | 已通过 | 批次61 | 1 | 1 | 0 | BUG#122 已修：根因=选中索引 tempIndex 写在 showModalBottomSheet builder 闭包局部变量，真机因 MediaQuery/键盘变化重建 builder 每次新建变量致确认恒读旧值；改 State 字段 _burnPickerIndex 跨 rebuild 存活+controller 提升 builder 外。测试 chat_setting_burn_picker_test 全绿+反证通过；真机复验需新 APK |
| 无待办 | — | `page/chat/chat_setting/chat_setting_page.dart` | 跳转查找聊天记录页 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 无待办 | — | `page/chat/chat_setting/chat_setting_page.dart` | 跳转聊天背景设置页 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 无待办 | - | `page/chat/chat_setting/chat_setting_page.dart` | 确认并清空本会话聊天记录 | 已通过 | 批次26 | 1 | 1 | 0 | 真机复验通过：图标已变 iosRed |
| 无待办 | - | `page/chat/chat_setting/chat_setting_page.dart` | 返回时回传刷新标记给聊天页 | 已通过 | 批次35 | 0 | 0 | 0 | 返回后聊天页正常渲染无异常 |
| 无待办 | - | `page/chat/chat_setting/chat_setting_page.dart` | 开关操作后弹出成功/失败提示 | 已通过 | 批次35 | 0 | 0 | 0 | 代码确认 L376 showToast(enabled/disabled)；真机免打扰开关状态 checked 往返正确 |
| 无待办 | — | `page/chat/chat_setting/chat_setting_page.dart` | 切换系统语言后页面实时刷新 | 已通过 | 批次26 | 0 | 0 | 0 | 集成测试通过：chat_setting_locale_test.dart。切换 zh-CN 标题为"聊天设置"，切换 en-US 标题为"Chat settings"。 |
