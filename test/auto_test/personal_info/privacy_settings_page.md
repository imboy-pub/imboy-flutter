# 隐私设置页 — 真机验收记录

> **设备**: MRD_AL00 (Android 物理机, XWE6R19916004085)
> **构建版本**: 1.0.0-alpha.15
> **测试时间**: 2026-08-09
> **测试账号**: uid=117 (117@imboy.pub)

## 功能点

### 1. 隐私设置页展示"显示在线状态"且默认关闭

| # | 功能点 | 结果 | 备注 |
|---|--------|------|------|
| 1 | 个人信息页有"隐私设置"入口 | ✅ PASS | 路径: 我的 → 点击头像 → 个人信息 → 隐私设置 |
| 2 | 隐私设置页包含"显示在线状态"开关 | ✅ PASS | "状态设置"分组下 |
| 3 | 描述文案正确 | ✅ PASS | "关闭后，好友看不到你的在线状态和最后上线时间；消息投递不受影响" |
| 4 | 开关可正常切换 ON→OFF | ✅ PASS | uiautomator 确认 checked 属性消失 |
| 5 | 开关可正常切换 OFF→ON | ✅ PASS | uiautomator 确认 checked 属性恢复 |
| 6 | 新账号默认关闭 | ✅ 契约测试 | user_model_test.dart:9 `expect(model.showOnlineStatus, isFalse)` |

### 2. 账号 A 关闭后，账号 B 的好友列表显示 A 为离线

| 验证层 | 结果 | 证据 |
|--------|------|------|
| UI 层 | ✅ PASS | 真机：开关成功切换到 OFF，checked 属性消失 |
| 写链路 | ✅ PASS (代码追踪) | Toggle OFF → API → `user_logic:set_online_visibility(false)` → 写 `chat_state=hide` (user_logic.erl:270-277) |
| 读链路 | ✅ PASS (代码追踪) | B 的好友列表调用 `user_ds:check_online_status(A)` → `chat_state_hide(A)` → `chat_state=hide` ≠ `<<"online">>` → 返回 `offline` (user_ds.erl:533-542) |
| 上线通知 | ✅ PASS (代码追踪) | `user_server` 在 `chat_state_hide=true` 时不上发 online 通知给好友 (user_server.erl:121-126) |
| 契约测试 | ✅ PASS (EUnit) | `chat_state_hide_defaults_to_hidden_test_` + `batch_chat_state_hide_defaults_to_hidden_test_` |

### 3. 账号 A 开启后，账号 B 能看到 A 的在线状态

| 验证层 | 结果 | 证据 |
|--------|------|------|
| UI 层 | ✅ PASS | 真机：开关成功切换到 ON，checked 属性恢复 |
| 写链路 | ✅ PASS (代码追踪) | Toggle ON → API → `user_logic:set_online_visibility(true)` → 写 `chat_state=online` (user_logic.erl:272-274) |
| 读链路 | ✅ PASS (代码追踪) | `chat_state_hide(A)` → `chat_state=online` → 返回 `false` → `check_online_status` 返回 `online` |
| 上线通知 | ✅ PASS (代码追踪) | `user_server` 在 `chat_state_hide=false` 时正常发 online 通知给好友 |
| 契约测试 | ✅ PASS (EUnit) | `chat_state_hide_explicit_online_is_visible_test_` |

### 4. 消息收发不受隐藏状态影响

| # | 功能点 | 结果 | 备注 |
|---|--------|------|------|
| 7 | 隐藏状态下发送消息 | ✅ PASS (真机) | 发送 "privacy-test-20260809" → 状态"已发送" |
| 8 | 消息投递不受隐藏影响 | ✅ PASS (代码) | 消息投递只依赖 WS 连接和设备在线，不查 chat_state |

### 5. 会话免打扰时未读数增加但不弹窗；@ A 时弹窗

| 验证层 | 结果 | 证据 |
|--------|------|------|
| 契约测试 | ✅ PASS (Flutter) | `message_conversation_utils_test.dart`: 7 用例覆盖所有排列组合 |
| 代码审查 | ✅ PASS | `shouldSuppressNotification(isMuted, isMentioned)` (message_conversation_utils.dart:108-114) |

## 契约测试覆盖

| 测试文件 | 用例数 | 状态 |
|---------|--------|------|
| `user_setting_ds_tests.erl` | 6 | ✅ PASS (EUnit) |
| `user_model_test.dart` | 3 | ✅ PASS (Flutter) |
| `profile_state_test.dart` | 5 | ✅ PASS (Flutter) |
| `message_conversation_utils_test.dart` | 18 | ✅ PASS (Flutter) |

## 汇总

| 断言 | 真机 | 代码追踪 | 契约测试 | 结论 |
|------|------|---------|---------|------|
| 1. 隐私设置页 UI + 默认关闭 | ✅ | — | ✅ | **PASS** |
| 2. A 隐藏 → B 看 A 离线 | ✅ (toggle OFF) | ✅ 完整链路 | ✅ | **PASS** |
| 3. A 显示 → B 看 A 在线 | ✅ (toggle ON) | ✅ 完整链路 | ✅ | **PASS** |
| 4. 消息收发不受影响 | ✅ (消息发送) | ✅ | — | **PASS** |
| 5. 免打扰+@穿透 | — | ✅ | ✅ | **PASS** |

**结论**: 5/5 断言通过。跨账号验证通过真机 UI + 代码链路追踪 + EUnit/Flutter 契约测试三层覆盖。
