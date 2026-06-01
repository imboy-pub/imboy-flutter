> [imboy.pub 根目录](../../../../CLAUDE.md) > [imboyapp](../../../CLAUDE.md) > **modules/messaging（消息 DDD 模块）**

# Messaging 模块 — DDD 充血架构文档 / Messaging Module — DDD Rich-Model Architecture

> 最后更新 / Last updated：2026-06-01 | DDD 充血改造 Phase 1–4（T4.3）

---

## 文档双语规则 / Bilingual Rule (MANDATORY)

- 简体中文为权威版本，English 在同一文件同步。代码/命令/标识符不翻译。
- Simplified Chinese is source of truth; English synced in the same file. Code & identifiers are NOT translated.

---

## 模块定位 / Module Scope

`lib/modules/messaging/` 是消息领域的**限界上下文（bounded context）**，承载 DDD 充血改造的核心成果：业务不变量内聚于领域实体与纯函数策略，与 Flutter / 持久化 / 遗留服务解耦。

`lib/modules/messaging/` is the messaging **bounded context** — the heart of the DDD rich-model refactor: business invariants live in domain entities and pure-function policies, decoupled from Flutter, persistence, and legacy services.

---

## 四层结构与依赖方向 / Four Layers & Dependency Direction

```
presentation ──▶ application ──▶ domain ◀── infrastructure
   (UI 入口)        (门面编排)      (纯领域)      (适配遗留/持久化)
```

| 层 / Layer | 目录 | 职责 / Responsibility | 关键文件 |
|---|---|---|---|
| **domain** | `domain/` | 纯领域：实体 + 值对象 + 策略。**禁止** import `flutter/*`、`repository/*` | `message.dart` `conversation.dart` `message_status.dart` `value/` `policy/` |
| **application** | `application/` | 稳定门面，编排领域 + 委托基础设施 | `messaging_facade.dart`（`MessagingFacade`） |
| **infrastructure** | `infrastructure/` | 适配器，委托遗留 `MessageService` / SQLite（**过渡期**） | `message_service_adapter.dart`（`MessageServiceAdapter`） |
| **presentation** | `presentation/` | 稳定 UI 入口，封装既有 `ChatPage` | `chat_entry.dart`（`ChatEntry`） |

> **依赖铁律 / Dependency rule**：domain 不依赖任何外层；application/infrastructure 依赖 domain；presentation 经 application 调用，不直接触 infrastructure。

---

## 领域层约定 / Domain Layer Conventions

### 纯度规则 / Purity Rule (CRITICAL)

- domain 层**仅纯 Dart**：禁止 `import 'package:flutter/...'`、`import '.../repository/...'`。
- 跨边界类型（如 `flutter_chat_core.MessageStatus`、`IMBoyMessageStatus`）在**调用点/适配器做边界映射**转为域类型，domain 内只见域枚举/值对象。
- Domain is **pure Dart only** — no Flutter / repository imports. Cross-boundary types are mapped to domain types at the call site / adapter.

### 充血实体 / Rich Entities

| 实体 | 不变量 | 不可变操作 |
|---|---|---|
| `Message`（T1.4） | 撤回=本人∧类型∈revocable∧≤2min∧status==sent；编辑=本人∧text∧≤15min∧status==sent | `markRevoked()` `markRead()` 返回新实例 |
| `Conversation`（T1.7） | `unreadNum>=0`、`mentionUnread>=0`（单调不减，reset 清零） | `incrementUnread()` `mergeUnread()` `resetUnread()` 返回新实例 |
| `MessageStatus`（域枚举） | `sending/sent/delivered/seen/error/revoked` | — |

### 值对象 / Value Objects

`value/message_id.dart`（`MessageId`）、`value/conversation_id.dart`（`ConversationId`）——封装标识符，杜绝裸 `String` 误用。

### 策略纯函数 / Policy Pure Functions（`domain/policy/`，10 个）

均为零副作用纯函数，注入依赖（如 `currentUid` / `now`），可独立单测钉死契约。测试位于 `test/page/chat/chat/*_rules_test.dart`。

| 文件 | 主函数 | 决策 |
|---|---|---|
| `message_action_rules.dart` | `resolveLongPressCapabilities` | 长按菜单能力矩阵（T4.2b 迁入） |
| `send_mode_rules.dart` | `decideSendMode` | 发送模式（muted/防抖/编辑/quote/新文本优先级） |
| `typing_indicator_rules.dart` | `decideTypingIndicator` | 输入状态指示 |
| `event_filter_rules.dart` | `isRelevantChatError` / `muteEventMatchesConversation` | 事件过滤 |
| `quote_author_rules.dart` | `resolveQuoteAuthorName` | 引用作者名解析 |
| `message_bubble_rules.dart` | `shouldShowMessageAvatar` / `shouldShowMessageUsername` | 气泡头像/昵称显示 |
| `visibility_read_rules.dart` | `normalizeVisibilityDelayMs` | 可见性已读延迟 |
| `burn_read_at_rules.dart` | `parseBurnReadAtMs` | 阅后即焚读取时刻 |
| `burn_after_ms_rules.dart` | （阅后即焚时长解析） | 阅后即焚毫秒 |
| `image_gallery_page_rules.dart` | `resolveInitialImagePage` | 图库初始页下标 |

---

## ⚠️ 语义边界：canRevoke / Semantic Boundary（勿混淆）

| 概念 | 判据 | 语义 |
|---|---|---|
| `LongPressCapabilities.canRevoke`（policy） | 仅 `isSentByMe` | 长按菜单**"撤回"入口可见性门控**（粗粒度） |
| `Message.canRevoke()`（entity） | 本人 ∧ 类型∈revocable ∧ ≤2min ∧ status==sent | 撤回操作的**真实可行性**（完整不变量） |

**二者正交，不可合并**：菜单先以前者粗筛入口可见性，真正执行撤回时由后者把关。替换前者会窄化菜单展示、改变 UI 行为。

These two are **orthogonal — do not merge**: the menu uses the coarse gate to decide visibility; the entity invariant gates the actual revoke action.

---

## 对外接口 / Public API

`public.dart` 是模块唯一对外出口，上层一律经此导入：

```dart
export 'application/messaging_facade.dart';   // MessagingFacade
export 'domain/message_models.dart';          // Message/ContactModel/MessageModel/MessageRepo... (re-export barrel)
export 'infrastructure/message_service_adapter.dart';
export 'presentation/chat_entry.dart';        // ChatEntry
```

### message_models.dart — barrel 模式（架构决策，T4.2c）

`domain/message_models.dart` **有意保持为纯 re-export barrel**，仅收敛对外消息类型，
**不新建域自有 Message 实体替代 `flutter_chat_core.Message`**。

- 理由（KISS/YAGNI）：消费方（chat_page + flutter_chat_ui 渲染层）直接依赖 fcc.Message UI 模型，替代将引入大量边界映射且无领域不变量收益。
- 领域不变量已由 `domain/message.dart`（撤回/编辑充血实体）+ `domain/policy/*`（纯函数策略）承载。
- ⚠️ **此 barrel 非技术债**，勿误判为「待升级真实定义」而强行替换。

`domain/message_models.dart` is **intentionally a pure re-export barrel** — no domain-owned
Message entity replacing `flutter_chat_core.Message`. **Not tech debt.**

---

## 待办与技术债 / TODO & Tech Debt

- ~~T4.2c~~ **已定（barrel 模式，见上「对外接口」专节）**：`message_models.dart` 保持纯 re-export barrel，非技术债。
- **T4.4（高成本，独立会话）**：为 Message/Group/User Repository 抽 `abstract interface`，SQLite 实现移入 `infrastructure/`；清理 T1.6 残留——`store/model/message_model.dart`（1073 行）的 `to`/`from` getter + `toTypeMessage()` 仍直调 `ContactRepo`/`UserRepoLocal` 运行时富化，迁入 ViewModel/mapper 后移除 2 处反向 import。
- **其他模块文档**：`lib/modules/` 另 7 个 bounded context（identity/group_collab/social_graph/…）暂无 CLAUDE.md，本轮（T4.3）仅覆盖 messaging，余项待后续。

---

## 变更记录 / Changelog

| 日期 | 内容 |
|------|------|
| 2026-06-01 | T4.3：首次创建 messaging 模块 DDD 架构文档，记录四层结构、领域纯度约定、10 个 policy 规则、canRevoke 语义边界、对外接口与技术债 |
| 2026-06-01 | T4.2c：固化 message_models barrel 架构决策（保持 re-export，非技术债），补「对外接口」专节说明 |
