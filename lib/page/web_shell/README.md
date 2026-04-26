# Web Shell 模块 / Web Shell Module

> **状态 / Status**：Phase 1.1 foundation 批次完成（12 commits, 226 测全绿）/ Phase 1.1 foundation batch complete (12 commits, 226 tests green)
> **下游 / Downstream**：1.1.h.3 i18n wrapper + 1.1.i 路由整合 / 1.1.h.3 i18n wrapper + 1.1.i route integration

---

## 中文

### 模块职责

为 ImBoy Flutter 客户端的 **Web 平台**提供桌面 IM 的「三栏壳」（Telegram Web 风格）：

```
┌────┬────────────┬────────────────────────┐
│ ◇  │            │                        │
│    │  会话列表   │                        │
│ ◇  │  / 联系人   │      聊天面板 /        │
│    │  / 频道     │      联系人详情 /      │
│ ◇  │  / 我的    │      欢迎屏（默认）    │
│    │            │                        │
│ ◇  │            │                        │
└────┴────────────┴────────────────────────┘
 72px    360px            flex: 1
```

响应式：
- `< 900px` → 回退到移动端 BottomNavigationPage（mobile fallback）
- `>= 900px` → 三栏布局（threeColumn）

### 文件清单（12 文件）

| 文件 | 职责 |
|------|------|
| `web_shell.dart` | ⭐ **barrel export** — 单一对外入口 |
| `web_shell_page.dart` | ⭐ **三栏整合主 widget**（参数注入 i18n） |
| `web_shell_breakpoint.dart` | 响应式断点决策（纯函数） |
| `web_shell_state.dart` | 不可变 state + WebSelection sealed (4 变体) |
| `web_shell_provider.dart` | Riverpod 3 NotifierProvider |
| `web_welcome_panel.dart` | 默认欢迎屏 widget |
| `web_nav_rail.dart` | 左侧 NavigationRail widget + WebNavItem |
| `web_middle_panel.dart` | 中间 IndexedStack 面板（保持各 tab state） |
| `web_main_panel.dart` | 右侧 sealed switch 分发面板 |
| `web_nav_items_factory.dart` | NavItems 工厂（i18n + badge 与 widget 解耦） |
| `web_shell_route_params.dart` | URL ↔ state 双向编解码（深链支持） |
| `web_shell_keyboard_intent.dart` | 桌面快捷键映射（Cmd/Ctrl + K/N/, + Esc） |

### 使用示例（1.1.h.3 wrapper 应该这样写）

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/page/web_shell/web_shell.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/contact/contact/contact_page.dart';
import 'package:imboy/page/channel/channel_list_page.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';

class WebShellBootstrap extends ConsumerWidget {
  const WebShellBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);

    return WebShellPage(
      // i18n labels（用 slang 解析）
      tabMessageLabel: t.titleMessage,
      tabContactLabel: t.titleContact,
      tabChannelLabel: t.channel.title,
      tabMineLabel: t.titleMine,
      welcomeTitle: t.appName,
      welcomeSubtitle: t.webShell?.welcomeSubtitle, // 1.1.h.3 时新增

      // Tab 中栏内容（直接复用现有 page）
      messageTab: const ConversationPage(),
      contactTab: ContactPage(),
      channelTab: const ChannelListPage(),
      mineTab: MinePage(),

      // 右栏 sealed selection builder
      chatBuilder: (sel) => ChatPanel(peerId: sel.peerId, type: sel.chatType),
      contactBuilder: (sel) => ContactDetailPanel(uid: sel.uid),
      channelBuilder: (sel) => ChannelDetailPanel(channelId: sel.channelId),
      mineBuilder: (sel) => MineDetailPanel(section: sel.section),

      // mobile fallback（< 900px 回退）
      mobileFallback: const BottomNavigationPage(),

      // 角标计数（从其他 provider 读）
      messageBadgeCount: ref.watch(unreadMessageCountProvider),
      contactBadgeCount: ref.watch(newFriendRequestCountProvider),
      channelBadgeCount: ref.watch(channelUnreadCountProvider),
    );
  }
}
```

### 路由集成（1.1.i 应该这样写）

```dart
// lib/config/router/app_router.dart 新增
GoRoute(
  path: '/web_shell',
  name: 'web_shell',
  builder: (context, state) {
    // 从 URL query 恢复 shell state
    final params = state.uri.queryParameters;
    if (params.isNotEmpty) {
      // 用 1.1.m 提供的纯函数
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(webShellProvider.notifier).replaceState(
          parseShellRouteParams(params),
        );
      });
    }
    return const WebShellBootstrap();
  },
),

// 修改 WebLoginPage 登录成功跳转：
// 旧：context.go('/bottom_navigation')
// 新：context.go(kIsWeb ? '/web_shell' : '/bottom_navigation')
```

### 设计原则

1. **无 i18n 依赖**：所有 widget 接收 String label 入参，由调用方用 slang `t.xxx` 解析
2. **无业务依赖**：tab 内容 widget + selection builder 由调用方注入
3. **类型安全分发**：`WebSelection` sealed + switch expression 强制穷尽，新增变体编译期失败
4. **响应式断点**：纯函数 `resolveShellLayout(width)` 三档分段（< 900 / 900-1200 / >= 1200）
5. **状态短路**：Riverpod Notifier 同 tab + null sel / 同 sel / null clear 短路（避免无效 rebuild）
6. **深链编解码 round-trip 不变性**：`parseShellRouteParams(toParams(state)) == state`

### 测试统计

| Slice | 测 | 类型 |
|-------|-----|------|
| 1.1.a breakpoint | 14 | 单元 |
| 1.1.b state + sealed | 25 | 单元 |
| 1.1.c provider | 20 | 单元 (ProviderContainer) |
| 1.1.d welcome | 14 | widget |
| 1.1.e nav rail | 23 | widget |
| 1.1.f middle | 13 | widget |
| 1.1.g main | 16 | widget |
| 1.1.h.0 factory | 18 | 单元 |
| 1.1.h.2 page integration | 15 | widget |
| 1.1.j barrel | 12 | 单元 |
| 1.1.l keyboard intent | 22 | 单元 |
| 1.1.m route params | 34 | 单元（含 9 case round-trip） |
| **合计** | **226** | **全绿** |

### 测试技术要点（教训沉淀）

1. **MediaQuery 测试**：用 `tester.view.physicalSize = size` + `tester.view.devicePixelRatio = 1.0`，**不要**用 `setSurfaceSize`（不影响 MediaQuery）
2. **Riverpod 3 测试保活**：`container.listen(provider, (_, _) {})` 避免 auto-dispose 提前清空 state
3. **IndexedStack 隐藏子节点 finder**：用 `find.byKey(key, skipOffstage: false)` 才能找到非当前 tab 的 widget
4. **Mobile fallback widget**：用 `Material+Center+Text`，不要用 `SizedBox`（0×0 不渲染 child）
5. **stage 防污染**：每个 commit 前 `git diff --cached --name-only` 二次校验仅 expected 文件

---

## English

### Module Responsibility

Provides a **desktop IM "tri-pane shell"** (Telegram Web style) for the **Web platform** of the ImBoy Flutter client.

```
┌────┬────────────┬────────────────────────┐
│ ◇  │            │                        │
│    │ conv list  │                        │
│ ◇  │ / contact  │   chat panel /         │
│    │ / channel  │   contact detail /     │
│ ◇  │ / mine     │   welcome (default)    │
│    │            │                        │
│ ◇  │            │                        │
└────┴────────────┴────────────────────────┘
 72px    360px            flex: 1
```

Responsive:
- `< 900px` → fallback to mobile `BottomNavigationPage`
- `>= 900px` → tri-pane layout

### Design Principles

1. **No i18n coupling**: all widgets receive `String label` props, callers resolve via slang `t.xxx`
2. **No business coupling**: tab content widgets + selection builders injected by caller
3. **Type-safe dispatch**: `WebSelection` sealed + switch expression forces exhaustiveness — new variants fail at compile time
4. **Responsive breakpoint**: pure function `resolveShellLayout(width)` with 3-bucket segmentation
5. **State short-circuiting**: Riverpod Notifier short-circuits same-tab+null-sel / same-sel / null-clear transitions
6. **Round-trip invariance for deep-linking**: `parseShellRouteParams(toParams(state)) == state`

### Files (12 total)

See Chinese section above for full file list. The barrel export `web_shell.dart` is the single import entry; `web_shell_page.dart` is the integration widget that callers consume.

### Test Stats

**226 tests across all slices, all green.** Full regression: 3070/3070.

### Next Steps (post Phase 1.1)

- **1.1.h.3** wrapper: build `WebShellBootstrap` ConsumerWidget that resolves slang i18n + wires actual page widgets, then instantiates `WebShellPage`
- **1.1.i** route integration: register `/web_shell` route in `app_router.dart`, redirect `WebLoginPage` success to `/web_shell` on `kIsWeb`
- **Phase 2-5**: chat panel Web adaptation / WebRTC / desktop notifications / multi-tab sync / deployment optimization (see `~/.claude/plans/gentle-beaming-treehouse.md`)
