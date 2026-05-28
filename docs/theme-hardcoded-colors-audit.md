# 深色主题硬编码颜色审计报告

> 生成时间：2026-05-27
> 扫描范围：`lib/`（排除 `lib/theme/default/app_colors.dart` 本身）
> 工具：`grep -rn --include="*.dart"`

---

## 审计说明

本报告列出所有直接在组件/页面代码中写死 `Color(0x...)` 或 `Colors.xxx` 而非引用 `AppColors` token 的位置，并给出对应的迁移建议。

**判定标准**

- `Colors.transparent`、`Colors.white`（用于 `onPrimary` 等对比色）在部分场景属于语义明确的常量，标为 **LOW**。
- 带暗色分支 `isDark ? Color(x) : Color(y)` 已有适配意图但仍需迁移为 token，标为 **MEDIUM**。
- 完全无暗色分支的颜色硬编码，标为 **HIGH**。
- 高频组件（聊天页、会话页）硬编码，标为 **CRITICAL**，优先修复。

---

## 优先级 CRITICAL — 高频核心组件

### `lib/page/chat/chat/chat_provider.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 1512 | `Color(0xffc5c5c5)` | `AppColors.iosGray2` (`#AEAEB2`) 或 `AppColors.iosGray3` |
| 1532 | `Color(0xffc5c5c5)` | `AppColors.iosGray2` |
| 1533 | `Color(0xffc5c5c5)` | `AppColors.iosGray2` |
| 1545 | `Color(0xffc5c5c5)` | `AppColors.iosGray2` |
| 1549 | `Color(0xffc5c5c5)` | `AppColors.iosGray2` |
| 1570 | `Color(0xffc5c5c5)` | `AppColors.iosGray2` |
| 1571 | `Color(0xffc5c5c5)` | `AppColors.iosGray2` |
| 1582 | `Color(0xffc5c5c5)` | `AppColors.iosGray2` |
| 1594 | `Color(0xffc5c5c5)` | `AppColors.iosGray2` |
| 1598 | `Color(0xffc5c5c5)` | `AppColors.iosGray2` |
| 1609 | `Color(0xffc5c5c5)` | `AppColors.iosGray2` |
| 1613 | `Color(0xffc5c5c5)` | `AppColors.iosGray2` |

> 说明：`0xffc5c5c5` ≈ `#C5C5C5`，与 `AppColors.iosGray2`（`#AEAEB2`）接近，语义为「禁用/次要图标色」。建议抽取为 `AppColors.iosGray3`（`#C7C7CC`）或在 `AppColors` 中补充 `iconDisabled` token。

### `lib/page/chat/widget/chat_message_list.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 222 | `Color(0xFF4CAF50)` (static) | `AppColors.onlineIndicator` (`#4CAF50`) — 该值已在 `AppColors` 中定义，直接替换 |

### `lib/page/chat/widget/chat_background_manager.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 450 | `Color(0xFF64B5F6)`, `Color(0xFF42A5F5)` | `AppColors.splashGradientStart` + `AppColors.tagAccent`（渐变蓝系）|
| 458 | `Color(0xFFBA68C8)`, `Color(0xFFAB47BC)` | 无直接 token；建议在 `AppColors` 补充 `chatBgGradientPurpleStart/End` |

---

## 优先级 HIGH — 功能页面无暗色分支

### `lib/page/settings/e2ee_key_recovery_page.dart`（48 处）

该文件是硬编码颜色最密集的文件，全部使用 `Colors.green/blue/orange/red/grey` 等 Material 颜色。

| 色彩语义 | 使用的硬编码值 | 建议迁移 |
|---------|--------------|---------|
| 成功/已激活 | `Colors.green`, `Colors.green.shade100/700` | `AppColors.iosGreen` / `AppColors.success` |
| 进行中/信息 | `Colors.blue`, `Colors.blue.shade50/100/200/700` | `AppColors.iosBlue` / `AppColors.infoBlue` |
| 警告 | `Colors.orange`, `Colors.orange.shade50/100/200` | `AppColors.iosOrange` |
| 错误/危险 | `Colors.red` | `AppColors.iosRed` |
| 禁用/次要文字 | `Colors.grey.shade200/400/600`, `Colors.black54`, `Colors.white60` | `AppColors.iosGray` / `AppColors.getTextColor(brightness, isSecondary: true)` |
| 紫色（特殊状态） | `Colors.purple`, `Colors.purple.shade100/700` | 建议在 `AppColors` 补充 `recoveryStateActive`（紫）|
| 琥珀色 | `Colors.amber` | `AppColors.iosYellow` |

### `lib/page/settings/e2ee_social_manage_page.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 181 | `Colors.purple.shade100` | 新增 `AppColors.socialShardBackground` |
| 187 | `Colors.purple.shade700` | 新增 `AppColors.socialShardForeground` |
| 212 | `Colors.green.shade100` | `AppColors.iosGreen.withValues(alpha: 0.15)` |
| 213 | `Colors.grey.shade200` | `AppColors.lightSurfaceContainer` |
| 223 | `Colors.green.shade700` | `AppColors.iosGreen` |
| 224 | `Colors.grey.shade600` | `AppColors.iosGray` |
| 268 | `Colors.purple` | 新增 token 或 `AppColors.secondary` |
| 297, 306 | `Colors.green` / `Colors.grey` | `AppColors.iosGreen` / `AppColors.iosGray` |
| 327 | `Colors.grey` | `AppColors.iosGray` |

### `lib/page/settings/e2ee_proxy_selector_page.dart`（19 处）

| 色彩语义 | 使用的硬编码值 | 建议迁移 |
|---------|--------------|---------|
| 已选中/确认 | `Colors.green`, `Colors.green.shade50/100/700` | `AppColors.iosGreen` |
| 未选中/信息 | `Colors.blue`, `Colors.blue.shade50/100/700` | `AppColors.iosBlue` |
| 次要文字 | `Colors.white70`, `Colors.black54`, `Colors.white60` | `AppColors.getTextColor(brightness, isSecondary: true)` |

### `lib/page/mine/mine/mine_page.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 69 | `Color(0xFFFFCC00)` | `AppColors.iosYellow` |
| 77 | `Color(0xFF5AC8FA)` | 无直接 token；建议补充 `AppColors.iosSkyBlue` 或用 `AppColors.iosBlue` |
| 85 | `Color(0xFF5856D6)` | `AppColors.secondary`（`#5C6BC0` 接近）|
| 102 | `Color(0xFF8E8E93)` | `AppColors.iosGray` |
| 110 | `Color(0xFF34C759)` | `AppColors.iosGreen` |
| 235 | `Color(0xFFFF9500)` | `AppColors.iosOrange` |
| 248 | `Color(0xFFFF3B30)` | `AppColors.iosRed` |

### `lib/page/contact/new_friend/add_friend_page.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 37 | `Color(0xFF007AFF)` | `AppColors.iosBlue` |
| 50 | `Color(0xFF34C759)` | `AppColors.iosGreen` |
| 61 | `Color(0xFF5856D6)` | `AppColors.secondary` |
| 72 | `Color(0xFFFF9500)` | `AppColors.iosOrange` |

### `lib/page/contact/contact_setting/contact_setting_page.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 102 | `Color(0xFF5856D6)` | `AppColors.secondary` |

### `lib/page/wallet/wallet_page.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 184–185 | `Color(0xFF1E3A8A)`, `Color(0xFF1E1B4B)`, `Color(0xFF1E40AF)` | `AppColors.primaryDark`；深色渐变建议补充 `AppColors.walletGradientDark` |
| 247 | `Color(0xFF5856D6)` | `AppColors.secondary` |
| 255, 325 | `Color(0xFFFF9500)` | `AppColors.iosOrange` |
| 264, 340 | `Color(0xFF007AFF)` | `AppColors.iosBlue` |
| 315 | `Color(0xFF34C759)` | `AppColors.iosGreen` |
| 320 | `Color(0xFF5AC8FA)` | 新增 `AppColors.iosSkyBlue` |
| 330 | `Color(0xFFFFCC00)` | `AppColors.iosYellow` |
| 335 | `Color(0xFFFF2D55)` | `AppColors.iosRed`（`#FF3B30` 极接近）|

---

## 优先级 MEDIUM — 有暗色分支但仍未使用 Token

### `lib/page/passport/login_page.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 242 | `isDark ? Color(0xFF2C2C2E) : Color(0xFFF2F2F7)` | `AppColors.getSurfaceGrouped(brightness)` |

### `lib/page/group/face_to_face/face_to_face_confirm_page.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 136–137 | `isDark ? Color(0xFF1C1C1E) : Color(0xFFF2F2F7)` | `AppColors.getSurfaceGrouped(brightness)` |

### `lib/page/channel/channel_detail_page.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 293–294 | `isDark ? Color(0xFF545458) : Color(0xFFC6C6C8)` | `AppColors.getIosSeparator(brightness)` |
| 328 | `isDark ? Color(0xFF38383A)` | `AppColors.iosSeparatorDark` |
| 1461 | `isDark ? Color(0xFF1C1C1E) : AppColors.lightSurface` | `AppColors.getSurfaceColor(brightness)` |
| 1465 | `Color(0xFFE5E5EA)` | `AppColors.lightBorder` |

### `lib/page/search/web_search_page.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 626, 632 | `isDark ? Color(0xFFE53935) : Colors.red` | `AppColors.getIosRed(brightness)` |

### `lib/page/personal_info/update/update_page.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 248 | `isDark ? Colors.white : Color(0xFF1A1A1A)` | `AppColors.getTextColor(brightness)` |
| 257 | `Color(0xFFCCCCCC)` | `AppColors.iosGray3` |
| 267 | `Color(0xFF999999)` | `AppColors.iosGray` |

### `lib/page/moment/moment_feed_page.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 374 | `Color(0xFF576B95)` | 无直接 token；建议新增 `AppColors.momentLinkColor` 或用 `AppColors.iosBlue` |

### `lib/page/mine/user_device/user_device_detail_page.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 113 | `Color(0xFFE8F5E9)` | `AppColors.iosGreen.withValues(alpha: 0.12)` |

### `lib/page/mine/user_collect/user_collect_detail_page.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 522 | `Color(0xFF01579B)` | `AppColors.infoBlue` |

---

## 优先级 LOW — 使用语义明确的全局色或透明色

### `lib/page/user_tag/user_tag_relation/user_tag_relation_page.dart`

| 行号 | 原始值 | 说明 |
|------|--------|------|
| 130 | `Colors.white` | 亮色背景对比色，暗色已有分支；建议 `AppColors.lightSurface` |
| 165 | `Colors.white10` | 半透明覆盖层，可接受；建议 `Colors.white.withValues(alpha: 0.1)` |
| 219 | `isDark ? Colors.white10 : Colors.white` | 见上 |

### `lib/page/user_tag/contact_tag_detail/contact_tag_detail_page.dart`

| 行号 | 原始值 | 说明 |
|------|--------|------|
| 90 | `Colors.grey` | 建议 `AppColors.iosGray` |
| 111 | `Colors.grey[800] / grey[200]` | 建议 `AppColors.getTextColor(brightness, isSecondary: true)` |
| 116 | `Colors.white / Colors.black87` | 建议 `AppColors.getTextColor(brightness)` |
| 254, 503 | `Colors.red` | `AppColors.iosRed` |
| 563, 849 | `Colors.white` | `AppColors.lightSurface` 或 `onPrimary` |
| 567, 853 | `Colors.green` | `AppColors.iosGreen` |
| 711 | `Colors.green / Colors.grey` | `AppColors.iosGreen / AppColors.iosGray` |

### `lib/component/ui/tag.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 17 | `Color(0xfff8f8f8)` | `AppColors.lightSurfaceContainerLow`（`#F9FAFB`，接近）|

### `lib/page/user_tag/user_tag_relation/tag_relation_page.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 421 | `Color(0xFFE8F5E9)` | `AppColors.iosGreen.withValues(alpha: 0.12)` |

### `lib/theme/default/config/component_theme_manager.dart`

| 行号 | 原始值 | 建议 Token |
|------|--------|-----------|
| 71–72 | `isDark ? Color(0xFF2C2C2E) : Color(0xFFE5E5EA).withValues(alpha: 0.5)` | `AppColors.darkSurfaceGroupedTertiary` / `AppColors.lightBorder` |

---

## 需要在 AppColors 补充的新 Token（建议）

以下颜色在现有 `AppColors` 中无精确对应，建议补充：

| 建议 Token 名 | 颜色值 | 使用场景 |
|--------------|--------|---------|
| `iosSkyBlue` | `#5AC8FA` | mine 页功能图标、钱包页 |
| `socialShardBackground` | 对应 `Colors.purple.shade100` | E2EE 社交碎片状态背景 |
| `socialShardForeground` | 对应 `Colors.purple.shade700` | E2EE 社交碎片状态前景 |
| `momentLinkColor` | `#576B95` | 朋友圈链接文字色 |
| `walletGradientStart` | `#1E3A8A` | 钱包卡片渐变起点（暗色模式）|
| `walletGradientEnd` | `#1E40AF` | 钱包卡片渐变终点（亮色模式）|
| `iconDisabled` | `#C5C5C5` | 聊天工具栏禁用图标（当前用 `0xffc5c5c5`）|

---

## 迁移优先级汇总

| 优先级 | 文件数 | 近似修改行数 | 推荐时间 |
|--------|--------|------------|---------|
| CRITICAL | 3 | ~25 | Sprint 内完成 |
| HIGH | 8 | ~90 | 下一 Sprint |
| MEDIUM | 8 | ~20 | Backlog |
| LOW | 5 | ~30 | 可随 PR 顺手修复 |

---

## 快速修复命令参考

```bash
# 定位所有 Colors.xxx 硬编码（排除 transparent）
grep -rn --include="*.dart" "Colors\." lib/ \
  | grep -v "Colors\.transparent" \
  | grep -v "lib/theme/default/app_colors\.dart"

# 定位所有 Color(0x...) 硬编码（排除 app_colors.dart）
grep -rn --include="*.dart" "Color(0x" lib/ \
  | grep -v "lib/theme/default/app_colors\.dart"
```
