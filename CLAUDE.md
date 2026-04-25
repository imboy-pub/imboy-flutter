# ImBoy App - 架构文档 / Architecture Document

> 本文档由 init-architect 自动生成和维护
> This document is auto-generated and maintained by init-architect
> 最后更新 / Last updated：2026-04-11 CST

---

## 📘 文档双语强制规则 / Bilingual Documentation Rule (MANDATORY)

> **适用范围 / Scope**：本项目（imboyapp Flutter 客户端）所有新增 / 修改的 Markdown 文档（README、CHANGELOG、DESIGN.md、doc/**、lib/**/CLAUDE.md、release notes 等）必须遵守本规则。
> All new or modified Markdown docs in this project (imboyapp Flutter client) — README, CHANGELOG, DESIGN.md, doc/**, lib/**/CLAUDE.md, release notes, etc. — MUST follow this rule.

### 1. 强制双语 / Bilingual mandatory

- 面向用户 / 贡献者 / 测试 / 上架审核的文档必须同时提供 **简体中文 + English** 两种语言。
- User / contributor / QA / store-review-facing docs MUST provide both **Simplified Chinese** and **English**.

### 2. 组织方式（二选一）/ Organization (pick one)

- **方式 A — 单文件并排 / Pattern A — Side-by-side**
  每个小节按 `中文 / English` 同节并排或上下段落对照。适合短文档（README hero、CHANGELOG 条目、Play Store / App Store 文案、release notes、issue 模板）。
  Each section uses `中文 / English` side-by-side or stacked paragraphs. Use for short docs (README hero, CHANGELOG entries, Play Store / App Store listings, release notes, issue templates).

- **方式 B — 文件后缀分离 / Pattern B — Separate files by suffix**
  `README.md`（中文权威）+ `README.en.md`（英文镜像）；两个文件顶部互加语言切换链接 `[English](README.en.md) | 简体中文`。适合长文档（DESIGN.md、architecture、测试指南、Mixin 规则手册）。
  `README.md` (Chinese authoritative) + `README.en.md` (English mirror); both have a language switcher at the top. Use for long docs (DESIGN.md, architecture, test guides, Mixin rules handbook).

### 3. 权威语言 / Source of truth

- **简体中文为权威版本**；英文版基于中文翻译。**中文先改，英文在同一次 PR 内同步跟进**，禁止出现只改中文不改英文或反之。
- **Simplified Chinese is the source of truth**; English mirrors Chinese. **Update Chinese first, sync English in the same PR**. Never ship one language without the other.

### 4. 代码块与命令行原样保留 / Code and CLI verbatim

- Dart 代码、Flutter 命令、`pubspec.yaml` 片段、iOS / Android 配置、错误堆栈不翻译。
- Dart code, Flutter commands, `pubspec.yaml` snippets, iOS / Android configs, error stacks are NOT translated.

### 5. 术语一致性 / Terminology consistency

- 关键术语首次出现时给出对照：`会话 (Conversation)`、`消息气泡 (Message Bubble)`、`首启向导 (First-run Setup Wizard)`、`本地数据库 (Local DB)`、`端到端加密 (E2EE)`、`推送通知 (Push Notification)`、`暗色模式 (Dark Mode)`、`资源授权 URL (Authorized Asset URL)`。
- Key terms come with a translation pair on first occurrence.

### 6. i18n 与 slang 的协作 / Coordination with slang i18n

- 本规则约束的是**开发 / 运维 Markdown 文档**的双语；应用内文案仍由 `lib/i18n/*.i18n.yaml` + slang 负责，二者互不替代。
- This rule covers **developer / ops Markdown docs**; in-app strings remain driven by `lib/i18n/*.i18n.yaml` + slang. The two do not replace each other.

### 7. 例外（可仅保留中文）/ Exceptions (Chinese-only allowed)

- `.claude/plan/*`、`.claude/memory/*`、内部会议纪要、个人研发笔记、`lib/**/*_REPORT.md` 类内部迁移报告
- `.claude/plan/*`, `.claude/memory/*`, internal meeting notes, personal dev notes, `lib/**/*_REPORT.md` internal migration reports

### 8. AI 编码代理契约 / AI Coding Agent Contract

当 AI 代理（Claude Code / Cursor / Copilot）收到「写文档 / 改文档 / 新建 .md」类任务时：
1. **默认双语输出**，无需用户额外提示。
2. 修改已有单语文档时，**主动补齐**缺失的语言。
3. 新建文档时，短文档走方式 A，长文档走方式 B。
4. Commit message 前缀 `docs(bilingual):` 或 PR 描述勾选 "docs bilingual check"。

When an AI agent (Claude Code / Cursor / Copilot) is asked to write, modify, or create Markdown docs:
1. **Default to bilingual output**, no extra user prompt needed.
2. When editing an existing single-language doc, **proactively add** the missing language.
3. For new docs, use Pattern A (short) or Pattern B (long) as appropriate.
4. Use `docs(bilingual):` commit prefix or tick "docs bilingual check" in the PR description.

---

## ⭐ 必读设计规范（Design Reference）

**所有 UI 相关代码（新增 / 修改）必须先阅读并遵守：**

- 📘 **[`./DESIGN.md`](./DESIGN.md)** — ImBoy App 视觉与交互设计规范（iOS 原生感 / Material 3 + iOS HIG 美学）

**核心约束速查：**

1. **品牌色策略**：品牌蓝 `#2474E5`（`AppColors.primary`）用于 Logo、Tab 选中、主按钮、发送气泡；iOS 系统蓝 `#007AFF`（`AppColors.iosBlue`，待新增）用于链接、Nav 文字按钮、取消按钮等系统语义位置。
2. **最小触达区域**：所有可点击元素 ≥ 44×44pt。
3. **页面水平 padding**：统一 16pt。
4. **聊天气泡**：圆角 20pt，发送用 `brand`，接收用 `surface`。
5. **破坏性操作**：必须用 `iosRed` (`#FF3B30`)。
6. **禁止硬编码**：颜色、间距、字号必须通过 `AppColors` / `AppSpacing` / `FontSizeType` Token 使用。
7. **暗色模式**：查 DESIGN.md 第 10.2 节的浅→暗映射表。

**AI Coding Agent 请直接阅读 `DESIGN.md` 第 13 章（For Coding Agents）获取决策树与模板代码。**

---

## 变更记录 (Changelog)

### 2026-04-25
- **#20 C2C 发送方本地 msg_c2c 表缺行修复（根因：MessageModel.id 类型与 Xid 不兼容）** / **#20 C2C sender-side missing local msg_c2c row fix (root cause: MessageModel.id type incompatible with Xid)**：
  - **根因**：`MessageModel.id` 字段为 `int`，与客户端 `Xid().toString()` 生成的 base32hex 字符串 ID 不兼容；`chat_provider._getMsgFromTMsg` 用 `int.tryParse(message.id) ?? 0` 强转必然回退 0 → 触发 `_validateMessageData` 的 `if (msg.id == 0)` 拦截 → `ArgumentError` 被外层 `try/catch` 静默吞掉 / Root: `int.tryParse(xid)` always returns null, falls to 0, then guarded out and silently swallowed
  - **接收侧无 bug**：Bob 接收方走 `batchInsertOfflineMessages` 另一路径，未碰 `int.tryParse` 强转
  - **修复（commit `a0ff7f12`，20 文件 +288/-90）**：
    - `MessageModel.id` 字段 `int` → `String`，对齐后端 `binary()` msg_id 契约
    - `_validateMessageData` 守卫语义升级：`id == 0` → `id.isEmpty`
    - SQLite `INTEGER NOT NULL` 列通过 type affinity 直接接收字符串（SQLite 弱类型存储）
    - 9 个 `lib/*` 文件（chat_provider / send_to_provider / user_collect_provider / message.dart / message_actions / message_retry / message_model / message_repo_sqlite / fts_api）+ 11 个 `test/*` fixture 同步迁移
  - **新增回归测试** `test/store/repository/message_c2c_send_side_test.dart`（4 测全绿）：
    - Xid 字符串通过 type affinity 落库验证 / Verify Xid string lands via SQLite type affinity
    - UNIQUE 索引拦截重复 ID / Verify UNIQUE index blocks duplicates
    - 反例钉死旧 bug（`int.tryParse(xid)` 必然 null → 回退 0）/ Counter-example pins old bug
    - 空字符串 ID 业务层拦截 / Empty string ID business-layer guard
  - **回归**：`flutter analyze` 零警告；`flutter test` 2718/2718 绿（11 skip + 4 新）；保留区 `ios/*` + `plugin/r_upgrade` 未动 / Regression: analyzer clean, 2718/2718 tests green (+4 new), preservation zones untouched
- **R-3-token-expansion 6 hex → AppColors Token（lib/page 26 文件大面积收编）** / **R-3-token-expansion: 6 hex literals folded into AppColors Tokens across 26 files in lib/page**：
  - **新增 6 个 Token**（`lib/theme/default/app_colors.dart` +35 行）/ Add 6 new Tokens：
    - `lightPageBackground (#F5F5F5)` — iOS Settings 风格页面级 Scaffold 背景，21 处使用 / iOS-Settings-style page-level Scaffold bg, 21 sites
    - `darkSurfaceGroupedTertiary (#2C2C2E)` — iOS HIG `tertiarySystemGroupedBackground dark`，7 处；docstring 标注与 `darkSurfaceVariant (#2C2C2C)` 仅 1 hex 之差但语义不同（Material 3 surface variant vs Apple HIG 严格值）
    - `iosGray3Dark (#48484A)` — iOS Gray 3 暗色自适应版（Apple HIG 官方），5 处
    - `chatWebSecondaryLight (#667781)` — Chat Web 风格次级文本（亮色），21 处
    - `chatWebSecondaryDark (#8696A0)` — Chat Web 风格次级文本（暗色），21 处
    - `chatWebBrand (#00A884)` — Chat Web 风格品牌强调色（WhatsApp 绿），8 处
  - **范围**：26 文件 +112/-67 / Scope: 26 files +112/-67：
    - `lib/theme/default/app_colors.dart`：+35 行 Token 定义（含 docstring）
    - `lib/page/` 25 文件 hex 字面量 → `AppColors.xxx`（covering update / more / add_friend / people_info / face_to_face / group_detail / personal_info / search_chat / group_list / tag_relation / launch_chat / group_select / change_info / privacy_settings / set_region / e2ee_proxy_selector / e2ee_key_recovery / set_nickname / web_search / web_conversation 等）
    - 10 文件追加 `import 'package:imboy/theme/default/app_colors.dart'`
    - **保留区零动**：`ios/*` / `plugin/r_upgrade` / `lib/page/passport/**`
  - **回归**：`flutter analyze lib/` 零警告；`grep` 兜底 `lib/page/` 6 hex 0 命中（仅 app_colors.dart Token 源头保留）/ Regression: analyzer clean, 0 hex residue in `lib/page/`
- **A-2 code-reviewer HIGH 回归保护测试落地（NULL 折叠语义钉死）** / **A-2 code-reviewer HIGH regression-protection test for NULL-fold semantics**：
  - `d8b18048` 新增 `test/store/repository/moment_notify_dedup_index_test.dart`（8 个测试，SQLite ffi in-memory）/ add 8 in-memory SQLite tests
    - **正向 7 测**：复用 v21 `uq_moment_notify_dedup` 索引 DDL，钉死 NULL 折叠后重复拦截 / action 区分 / 不同 from_uid / moment_id / user_id 可共存 / 显式空串 `""` 与 NULL 在 COALESCE 下等价
    - **反例 1 测**：用 v20 直接 `comment_id` 索引复现 bug（`NULL != NULL` 允许两行 moment_like 都落库）→ 证明 v21 修复的语义差异真实存在，避免回归测试成为"自证循环"
  - **查实 SQL 修复已在位**：`assets/migrations/upgrade.sql:1245-1270` v21 migration `COALESCE(comment_id, '')` + `lib/service/sqlite.dart:38` `_dbVersion=21` 已就位（原 code-reviewer HIGH 指向的 SQL 层修复此前已完成，仅缺回归保护测试）
  - 全量回归 2686/2686 绿（+8 新）；`flutter analyze` 零警告 / Full regression 2686/2686 green (+8 new); analyzer clean
- **A-2 code-reviewer MEDIUM 3 项代码层确认已修**（在位证据 + 无需额外 commit）/ **A-2 code-reviewer MEDIUM 3 items already fixed in code**：
  - **① `_onScroll` 快速滚动竞态守卫**：`lib/page/moment/moment_notify/moment_notify_page.dart:66-68` 已有 `final snapshot = ref.read(momentNotifyProvider); if (snapshot.isLoading || !snapshot.hasMore) return;` 早退守卫，`loadMore` 内部二次守卫 → 双保险
  - **② `_ensureTagUids` / `_loadTags` 魔数常量化**：`lib/page/moment/moment_friend_picker/moment_friend_picker_page.dart:31-41` 已抽出顶层 `const int kFriendPickerTagPageSize = 200` + `kFriendPickerTagUidsPageSize = 1000`，含 docstring 解释取值依据（标签总数 <50 / 单标签成员数 <1000）
  - **③ `FutureBuilder._resolveContact` rebuild 重建 Future**：`lib/page/moment/moment_notify/moment_notify_page.dart:42-43 + 74-83` 已用 `final Map<String, Future<ContactModel?>> _contactFutureCache` + `putIfAbsent`，同一 uid 每次 rebuild 返回同一 Future 实例，FutureBuilder 不再误入 waiting 态闪骨架
- **Track A 进度修订：9/10 → 10/10** / **Track A progress revision: 9/10 → 10/10**：
  - 2026-04-18 条目 "Track A 进度 9/10，仅 A-10 channel regression 待做" 过时 / 2026-04-18 entry stale
  - 实际 **#25 A-10 channel 模块全链路回归已 completed**：24 个测试覆盖列表/详情/消息 repo/规则/服务/运营 / 24 tests across list/detail/message-repo/rules/service/ops
    - 纯函数测 7：`channel_detail_rules` / `channel_edit_rules` / `channel_admin_add_rules` / `channel_invitation_rules` / `channel_load_more_guard` 等
    - 仓储测 6：`channel_repo_unread_atomic` / `channel_message_repo_{view_count,pinned_limit,query_contract}` / `channel_repo_last_message_id` 等
    - 服务/S2C 测 3：`channel_service_operations` / `channel_service_unread_summary_sync` / `channel_s2c_sync`
    - Widget / Provider 测 4：`channel_list_state_sync` / `channel_provider_state` / `channel_detail_actions` / `channel_detail_event`
    - 模型测 4：`channel_model` / `channel_message_model` / `channel_subscription_model` / `channel_stats_model` 等
  - **关键修复已登记**：2026-04-18 条目 "F4 pre-existing 测试失败修复" 详细记录 `channel_list_state_sync_test` 4 测修复（Riverpod 3 auto-dispose 语义陷阱）
- **静态债务剩余面**：pending 任务 #19/#20/#26/#28/#33/#35 全为真机/运行时依赖项 → sequential-safe 循环再度进入暂停态，等待真机联调机会 / Sequential-safe loop stalled again; remaining pending tasks are device/runtime-dependent

### 2026-04-24
- **docs(stale-todo) 三片收尾清理**（静态文档债务审计批次，零代码影响）/ **Three-slice stale-todo cleanup batch (doc-debt audit, zero code impact)**：
  - `552ffb22` 清理 2 处过时 TODO 注释 / Clean 2 stale TODO comments：
    - `lib/store/api/group_member_api.dart:104` 原"TODO：后端提供 unmute 后开放独立方法"→ 改为"请用独立方法 [unmute]（slice-9a/9b 已落地）"
    - `lib/service/group_member_mute_service.dart:65` 原"TODO(slice-2) Repo 支持注入后接入"→ 改为"已由 MessageS2CService._handleGroupMemberMute 通过 S2C 广播统一落库"
  - `ace09ad2` 修正 4 处伪 `@Deprecated` 文档注释 / Fix 4 pseudo-`@Deprecated` doc comments：
    - `lib/theme/default/app_colors.dart` 的 `lightBackground` / `lightCardBackground` / `darkBackground` / `darkCardBackground` 原 `/// @Deprecated(...)` 写在文档注释内（不会触发 `deprecated_member_use` 警告）→ 改为"建议：新代码使用 [xxx]"的说明性文案，避免误导
    - 未升级为真实 `@Deprecated` 注解：26 个调用点跨 8 文件，会引入非零风险警告噪音
  - `ab8706ed` 清理 `test/service/group_member_mute_s2c_parse_test.dart:12-16` 过时契约缺口注释 / Clean stale contract-gap comment：
    - 原注释声称 "⚠️ 已知后端契约缺口：mute_notice/4 payload 缺 user_id" → slice-1-finalize (2026-04-15) 已闭合此缺口，test body 122-205 行已有新/老契约双路径覆盖
  - **所有提交均严格控制面积**：仅 `lib/**` + `test/**`，保留区 `ios/*` + `plugin/r_upgrade` 零动 / All commits strictly scoped to `lib/**` + `test/**`; preservation zones `ios/*` + `plugin/r_upgrade` untouched
  - **回归基线**：`flutter analyze` 零警告，测试全绿 / Regression baseline: `flutter analyze` clean, tests all green
  - **静态债务出清**：lib/ 与 test/ 的 `TODO|FIXME|HACK|XXX` + `/// @Deprecated` 伪注释均已扫描完毕，sequential-safe loop 进入暂停态（剩余 pending 任务 #19/#20/#26/#28/#33/#35 均为真机/运行时依赖项）/ Static debt cleared; sequential-safe loop stalled — remaining pending tasks are device/runtime-dependent

### 2026-04-18
- **Completion Sprint Track A 推进：A-2 / A-4 / A-5 三切片落地（三次独立提交）** / **Completion Sprint Track A push: A-2 / A-4 / A-5 three slices landed (three independent commits)**：
  - `0b5dba2f` **A-2 moment_notify Phase 1（朋友圈通知中心客户端本地闭环）** / **Moment notification center, client-local closure Phase 1**：17 文件 +1559/-9；SQLite v18→v20（新增 `moment_notify` 表 + dedup 唯一索引）；Riverpod 3 sealed state + 分页 provider；i18n `momentNotify.*` 新键；路由 `/moment_notify` + `moment_feed_page.dart` 入口；采用 **Option C 混合策略**：Phase 1 仅客户端本地（未来 Phase 2 再做后端 REST v1.1 `/v1/moment/notify/page`）/ Option C hybrid: Phase 1 client-only now; Phase 2 backend REST later
  - `abf806de` **A-4 moment_friend_picker（朋友圈可见性好友选择器）** / **Moment-visibility friend picker**：4 文件 +778/-10；`friend_picker_rules.dart` 纯函数（`sortUidsForPayload` + `resolveTagSelectionState`，26 测全绿，零外部依赖）；`moment_create_page.dart` 接入 `_pickUids` + `_buildUidPickerField`
  - `69ee2fea` **A-5 contact_tag_filter（联系人按标签筛选）** / **Contact-by-tag filter**：3 文件 +247/-0；`contact_tag_filter_rules.dart` 纯函数（`filterContactsByTagUids` + `unionTagUids`，18 测全绿）；`contact_page.dart` AppBar 新增 `label_outline` IconButton 跳 `user_tag_list`
  - **全量回归 2661/2661 绿；`flutter analyze` 零警告** / Full regression 2661/2661 green; analyzer clean
  - **code-reviewer 结论 APPROVE WITH COMMENTS**（1 HIGH / 3 MEDIUM / 2 LOW）/ code-reviewer verdict APPROVE WITH COMMENTS：
    - **[HIGH]** `moment_like` 去重索引失效 —— SQLite `NULL != NULL` 语义使 `comment_id IS NULL` 行无法被唯一索引拦截；`ConflictAlgorithm.ignore` 对 NULL 列组无效。**修复方案（v21 migration）**：`CREATE UNIQUE INDEX uq_moment_notify_dedup ON moment_notify(user_id, action, moment_id, from_uid, COALESCE(comment_id, ''));` / HIGH: `moment_like` dedup unique index broken due to SQLite "NULL != NULL" semantics; fix with `COALESCE(comment_id, '')` in v21 migration
    - MEDIUM：`_onScroll` 快速滚动早于 `isLoading=true` 守卫；`_ensureTagUids` 硬编码 `size:1000` 魔数；`FutureBuilder._resolveContact` 每次 rebuild 重建 Future / rapid-fire scroll guard race, hardcoded magic numbers, FutureBuilder rebuild
    - LOW：`_loadTags` 硬编码 `size:200`；`refresh()/loadMore()` 静默 `on Exception`（state 缺 errorMessage 字段）/ hardcoded size, silent error swallow
  - **Track A 进度 9/10**（A-1~A-9 ✅，仅 A-10 channel regression 待做）/ Track A progress 9/10, only A-10 channel regression left

### 2026-04-15
- **群成员禁言/解禁 slice-9c 落地（UI 接线：群成员列表页实时刷新 + 聊天页输入框禁用/恢复）**：
  - **群成员列表页** `lib/page/group/group_member/group_member_page.dart`：
    - 新增 `_ssMemberMute` / `_ssMemberUnmute` 订阅
    - 守卫：`event.gid.toString() == widget.groupId && event.userId.isNotEmpty`
    - Mute → 原地更新 `_memberList[idx].muteUntilMs = event.muteUntilMs`，`setState` 触发 `MuteRemainingBadge` 重建
    - Unmute → `muteUntilMs = null`，badge 自动消失
    - dispose 清理两个订阅
    - **实现要点**：`GroupMemberModel.userId` 是 `int`，比较时用 `m.userId.toString() == event.userId` 对齐 TSID 字符串
  - **聊天页** `lib/page/chat/chat/chat_page.dart`：
    - 新增 `_ssGroupMemberMute` / `_ssGroupMemberUnmute` 订阅（仅 c2g）
    - 守卫：`event.gid.toString() == widget.peerId && event.userId == currentUid`（只响应当前用户在本群被禁言/解禁）
    - Mute → 新增 `_applyGroupMemberMuteState(event)`：设 `_isMuted=true` + 时长文案 + 到期自动清除定时器，复用 `_clearMuteState` 基础设施
    - Unmute → 直接调 `_clearMuteState()` 恢复输入框
    - dispose 清理两个订阅
  - **为何不做单测**：两处均为纯 widget 事件订阅管道（守卫条件平凡）；禁言状态切换逻辑已被 `UserMutedEvent` 路径覆盖（同一 `_isMuted` / `_muteExpiryTimer` 基础设施）；UI badge 刷新正确性依赖 slice-2 `MuteRemainingBadge` 的 7 个单测
  - 回归：28/28 全绿；`flutter analyze` 两文件零警告
  - **禁言/解禁功能全闭环（slice-1 ~ slice-9c）**：数据库 → API → Service → S2C → 事件总线 → 列表页 badge + 聊天页输入锁定/恢复

- **群角色 role >= 3 全局清零（role=5 副群主 badge 漏显修复）**：
  - **bug 修复**：`group_member_page.dart` 成员列表的角色徽章判断 `role == 3 || role == 4` 漏掉 role=5 → 副群主无角色 badge；改为 `isGroupAdmin(member.role)`
  - **mention_model.dart** 两处 `>= 3` 改为 `isGroupAdmin()`：`MentionCandidate.isAdmin`、`MentionState.isAdmin`、`MentionCandidate.showRoleBadge` — 统一由 `group_role_rules` 白名单管控
  - 全量回归 2172/2172 绿；`flutter analyze` 零警告

- **群角色规则 group_role_rules 落地（跨页面共用纯函数 + bug fix）**：
  - 新增 `lib/page/group/group_role_rules.dart`（13 测全绿，零外部依赖）：
    - `isGroupAdmin(int role) → bool`：白名单 {3,4,5}；`isGroupOwner(int role) → bool`：仅 role==4
  - **bug 修复**：`group_detail_page.dart:120` 原 `isAdmin = role == 3 || role == 4` 漏掉副群主(5)，导致副群主无法看到"移除成员"入口 → 改为 `isGroupAdmin(role)`
  - **可读性提升**：3 处 `state.role == 4` 判断改为 `isGroupOwner(state.role)`
  - **i18n 补全**：`zh-CN` + `en-US` 新增 `groupFile`("群文件") / `groupAlbum`("群相册") 两键，替换 `group_detail_page.dart` 中的硬编码中文字符串
  - **DRY 重构**：`announcement_permission_rules.dart` 改为委托 `isGroupAdmin`，消除重复的 `{3,4,5}` 集合定义
  - 全量回归 2150/2150 绿；`flutter analyze` 零警告

- **群公告权限控制 slice-F3-perm 落地（发布/删除按钮对非管理员隐藏）**：
  - **纯函数** `lib/page/group/announcement/announcement_permission_rules.dart`（8 测全绿，零外部依赖）：
    - `canManageAnnouncement(int role) → bool`：白名单 {admin=3, owner=4, vice_owner=5}，与 `canMentionAll` 相同策略（显式枚举防未来角色误放行）
  - **Provider 扩展**：`GroupAnnouncementState` 新增 `currentUserRole`（默认 0）；`_loadCurrentRole()` 在 `onRefresh` 时 `unawaited` 并行加载（复用 `GroupMemberRepo().findByUserId` 模式）
  - **UI 接线**（`group_announcement_page.dart`）：
    - AppBar `+` 号按钮：`if (canManageAnnouncement(state.currentUserRole))` 条件渲染
    - 列表项删除按钮：`_buildAnnouncementItem(..., canManage: ...)` 新增具名参数，`if (canManage)` 条件渲染
  - **安全默认**：`currentUserRole=0` 时 `canManageAnnouncement(0) → false`，加载失败/未在群时自然隐藏管理按钮
  - `flutter analyze lib/page/group/announcement/` 零警告；全量回归 2109/2109 绿

- **群成员解禁 slice-9b 落地（跨栈闭环：客户端 S2C 识别 + 后端 unmute 路由/handler/logic）**：
  - **客户端扩展**：
    - `lib/service/group_member_mute_s2c.dart` 新增 sealed 变体 `GroupMemberUnmutePayload(gid, userId, adminNickname)`；解析守卫由 `muteUntilMs <= 0` 收紧为 `< 0`（0 变为有效解禁信号）；新增分支 `mute_until == 0 → GroupMemberUnmutePayload`
    - `lib/service/events/common_events.dart` 新增对称事件 `GroupMemberUnmuteEvent`
    - `lib/service/message_s2c.dart:_handleGroupMemberMute` switch 新增 Unmute 分支：`GroupMemberRepo.update(gid, userId, {mute_until: null})` 写 NULL（依赖 slice-1 Repo 白名单对 `containsKey` + 显式 null 的兼容）→ 广播 `GroupMemberUnmuteEvent` → toast "xx 解除了群成员禁言"
  - **后端补丁**（`imboy/src/logic/group_member_logic.erl`）：
    - 补齐 slice-1-finalize 遗留：`mute_notice/4` 参数 `_UserId → UserId`，Payload 新增 `<<"user_id">> => UserId`
    - `mute_notice/4` 支持 `MuteUntil == 0` 特判：`RemainingSec=0`、`DurationText=<<>>`（广播解禁信号，复用既有 S2C action `group_member_mute`）
    - 新增 `unmute/3`：权限校验 → `elib_pg:with_tx(fun(Conn) -> group_member_ds:update_mute(Conn, Gid, UserId, null) end)` 写 NULL → `mute_notice(CurrentUid, Gid, UserId, 0)` 广播解禁
    - `-export` 列表追加 `unmute/3`
  - **后端新路由**（`imboy/src/api/group_member_handler.erl` + `imboy/src/imboy_router.erl`）：
    - `{"/v1/group_member/unmute", group_member_handler, #{action => unmute}}`
    - `group_member_handler:unmute/2` 处理器：throttle + gid/user_id 校验 → 调 `group_member_logic:unmute/3`
  - **设计要点**：
    - 单 S2C action 承载 mute/unmute 双语义（`mute_until` 值即信号），客户端 dispatcher 面积最小
    - sealed 变体扩展优于重载 `GroupMemberMutePayload`，保持类型安全（switch 穷尽强制所有消费侧更新）
    - 客户端 Repo 写 NULL 依赖 slice-1 的 `containsKey` 白名单（区分"未传"与"显式 null"）
  - 覆盖率：6 个新解析测试 + 5 个服务测试 + 17 个 s2c 测试，回归 28/28 全绿；`flutter analyze` 零警告；后端局部 `erlc` 验证干净（只剩 cowboy_rest behaviour 警告，与 cowboy 依赖未编入 ebin 有关）
  - slice-9c 待做（UI 接线）：`GroupMemberUnmuteEvent` 消费方（群成员列表页刷新禁言状态 icon / 聊天页取消输入框禁用）

- **群成员禁言/解禁 slice-9c 落地（UI 事件接线）**：`GroupMemberMuteEvent` / `GroupMemberUnmuteEvent` → 两处 UI 实时刷新
  - **群成员列表页** (`group_member_page.dart`)：
    - 新增 `_ssMemberMute` / `_ssMemberUnmute` 两个 `StreamSubscription` 字段
    - `_setupMuteEventListeners()` 在 `initState` 调用：双守卫 `event.gid == groupId && m.userId.toString() == event.userId`（关键：`GroupMemberModel.userId` 是 `int`，需 `.toString()` 转换）
    - Mute 处理：`_memberList[idx].muteUntilMs = event.muteUntilMs`；Unmute：`_memberList[idx].muteUntilMs = null`
  - **聊天页** (`chat_page.dart`)：
    - 仅 c2g 聊天订阅；守卫：`event.gid.toString() == widget.peerId && event.userId == currentUid`（仅当被禁言/解禁的是当前用户自己）
    - Mute → `_applyGroupMemberMuteState(event)`：设 `_isMuted=true`、计算剩余分钟数更新 `_muteMessage`、启动 `_muteExpiryTimer`（禁言到期自动调 `_clearMuteState()`）
    - Unmute → `_clearMuteState()`
    - dispose 补全两订阅取消
  - 类型安全修复：`unrelated_type_equality_checks` — `m.userId`(int) vs `event.userId`(String) 须 `.toString()` 对齐
  - slice-9c 无需新纯函数，故无新单测；既有 28/28 回归全绿

- **群成员禁言 slice-10 落地（GroupMemberDetailPage + 禁言时长选项纯函数 + 路由注册）**：
  - **纯函数模块** `lib/page/group/group_member/mute_duration_rules.dart`（11 测全绿，零外部依赖）：
    - `final class MuteDurationOption { seconds, labelKey }` — `==` / `hashCode` 实现，`const` 构造器
    - `const List<MuteDurationOption> muteDurationOptions`：7 档（5min/10min/30min/1h/1day/7days/30days），按秒升序
    - 测试钉死：非空、seconds>0、升序、包含关键档位、labelKey 非空/唯一、seconds 唯一、相等语义
  - **i18n 补全**：`zh-CN` + `en-US` 新增 `muteDuration5min`/`muteDuration10min`/`muteDuration30min`/`muteDuration30days` 四键（对齐既有 `muteDuration1hour`/`1day`/`7days` 命名风格）；`dart run slang` 重新生成
  - **GroupMemberDetailPage** `lib/page/group/group_member/group_member_detail_page.dart`（新建，`ConsumerStatefulWidget`）：
    - `_loadData()`：并行 `Future.wait` 同时查目标成员 + 当前用户，获取 `_myRole`
    - `_onMuteTap()`：`_showDurationPicker()` → `GroupMemberMuteService().mute(gid, userId, durationSec)` → switch sealed `MuteResult` → 更新 `_member.muteUntilMs` + `_anyChange=true`
    - `_onUnmuteTap()`：confirm dialog → `GroupMemberMuteService().unmute(gid, userId)` → switch `UnmuteResult` → `_member.muteUntilMs=null`
    - `_buildBody()`：用 `canMuteGroupMember(currentUserId, currentRole, targetUserId, targetRole)` 4 参控制按钮可见性；`MuteRemainingBadge` 展示剩余时间
    - `PopScope` + `context.pop(_anyChange)` 返回变更标志（调用方刷新列表）
    - Null-aware element：`?trailing,` (Dart 3)
  - **Barrel / 路由注册**：
    - `lib/modules/group_collab/public.dart` 追加 `group_member_detail_page.dart` export
    - `lib/config/router/app_router.dart` 在 `/group/member` 之后新增 `GoRoute(path: '/member_detail', name: 'group_member_detail')` → `CupertinoPage(child: GroupMemberDetailPage(...))`；extra `{groupId, userId}` 均 `.toString()` 安全解包
  - 修复细节：`unnecessary_import`（`theme_manager.dart` 已由 `font_types.dart` re-export）；`isSelf` 局部变量删除（计算后未用）；`canMuteGroupMember` 传 4 个具名参数而非 2 个
  - `flutter analyze lib/config/router/app_router.dart` 零警告；slice 全量 129/129 绿

- **群成员解禁 slice-9a 落地（客户端服务层 + API，等待后端 slice-9b）**：
  - 新增 `API.groupMemberUnmute = '/v1/group_member/unmute'`（`lib/config/const.dart`）
  - 新增 `GroupMemberApi.unmute({gid, userId})`：独立方法而非给 `mute` 传 `duration=0`（后端 mute/4 校验 >0 会拒）
  - 新增 sealed `UnmuteResult`（`UnmuteSuccess` / `UnmuteValidationError` / `UnmuteApiFailure`）与 `MuteResult` 对称独立，避免类型混用
  - 新增 `GroupMemberMuteService.unmute({gid, userId})`：前置校验 gid/userId 非空 → 调 API → 结构化返回；本方法**不写 Repo**，权威 `mute_until=0` 由后端 S2C 广播统一落库
  - 5 个单测全绿（ok→Success / fail→ApiFailure / 空 gid→ValidationError / 空 userId→ValidationError / sealed 穷尽）；`flutter analyze` 零警告；与既有 MuteResult 路径无回归（23/23 绿）
  - **slice-9b 待做（后端）**：
    1. `imboy_router.erl` 增加 `/v1/group_member/unmute` 路由
    2. `group_member_handler:unmute/2` 处理器
    3. `group_member_logic:unmute/3` 逻辑：`update_mute(Gid, Uid, 0)` + 复用 `mute_notice/4` 广播（mute_until=0 作为解禁信号）
    4. 客户端 `parseGroupMemberMutePayload` 扩展接受 `mute_until=0` 为解禁信号（当前被判为 invalid_mute_until）

- **群成员禁言 slice-1-finalize 落地（后端 user_id 缺口闭合，跨栈 TDD 完整闭环）**：
  - **后端补丁**：`imboy/src/logic/group_member_logic.erl:249-271` `mute_notice/4`
    - `_UserId` → `UserId`（参数解构）
    - Payload 新增 `<<"user_id">> => UserId`
  - **客户端解析扩展**：`lib/service/group_member_mute_s2c.dart`
    - `GroupMemberMutePayload` 新增 `userId` 字段（默认 `''` 向后兼容老后端）
    - 新增 `_asUserId` 归一化辅助：null/空白/`0`/`'0'` → `''`，数字/字符串 → 字符串
  - **事件总线**：`GroupMemberMuteEvent` 新增 `userId` 字段（默认 `''`）；UI 可定位被禁言成员行
  - **S2C 接线**：`message_s2c.dart:_handleGroupMemberMute`
    - userId 非空时调 `GroupMemberRepo.update(gid, userId, {mute_until: ms})` 写本地表
    - userId 为空（老后端）时仅广播事件 + toast，不动 Repo
    - Repo 异常吞掉不阻塞 toast（如当前用户未加入该群）
  - **Repo 白名单扩展**：`group_member_repo_sqlite.dart:update` 新增 `mute_until` 字段处理
    - 显式 `null` → 写 NULL（解禁语义）
    - 正整数 → 写值（设禁言）
    - 非法值（负数/非 int/0）→ 忽略防污染
    - 用 `containsKey` 而非 `??` 兜底，区分"未传"和"显式 null"
  - 新增 4 个解析单测（user_id 数字/字符串/缺失/归一化）；slice-1 全量回归 22 测全绿
  - **跨栈说明**：本切片同时改 Erlang 后端 + Dart 客户端，是项目首次跨栈 TDD slice；后端编译验证留待 `rebar3 compile` 时执行（非本切片范围）

- **群成员禁言 slice-1 落地（TDD 完整闭环）**：Model + API + Repo + Service + S2C 广播处理
  - 新增 `GroupMemberModel.muteUntilMs` (nullable int ms) + `isMuted({nowMs})`
  - 新增 `lib/store/model/group_member_columns.dart`（纯 Dart 列名常量），**解耦 Model ↔ Repo**：消除 Model-only 测试对 `sqflite_sqlcipher → win32` 链的传递依赖（方案 B）
  - `GroupMemberApi.mute` 前置校验 `duration <= 0` → `ArgumentError`
  - `GroupMemberRepo` 抽出静态 `toInsertMap()` → 可脱离 `SqliteService.to` 单例单测
  - 新增 `GroupMemberMuteService` + sealed `MuteResult`（`MuteSuccess` / `MuteValidationError` / `MuteApiFailure`）
  - 新增 `lib/service/group_member_mute_s2c.dart` 解析 S2C `group_member_mute` payload
  - `MessageS2CService` 新增 `group_member_mute` case 分支；新增 `GroupMemberMuteEvent`
  - **数据库迁移 v19**：`ALTER TABLE group_member ADD COLUMN mute_until INTEGER NULL` + 稀疏局部索引
- **已知后端契约缺口（slice-1 未修）**：`imboy/src/logic/group_member_logic.erl:249,260-266` 的 `mute_notice/4` 广播 payload 未携带被禁言成员的 `user_id`，客户端无法定位具体成员行 → 目前 S2C 只做群内通知（事件总线 + toast），不写 Repo。slice-2 待后端补 `<<"user_id">> => UserId` 后接入。
- **环境债务登记**：`pubspec.yaml` 现有 3 个 win32 相关 `dependency_overrides`（`package_info_plus ^8.3.0` / `win32_registry ^2.0.0` / `device_info_plus ^11.5.0`），同命运：待 `file_picker` 迁移 win32 6.x 后统一解锁。
- 覆盖率：slice-1 新增 38 个单元测试全绿（Model 13 + API 4 + 持久化 4 + insert_map 3 + Service 6 + S2C 解析 8）
- **群成员禁言 slice-2 落地（UI 权限纯函数）**：新增 `lib/page/group/group_member/group_member_mute_rules.dart`
  - `canMuteGroupMember` 角色权限矩阵：普通成员/嘉宾 → 全拒绝；管理员 → 仅禁言严格低于自己的角色；群主 → 除自身外均可；空 id / role<1 → 安全默认拒绝
  - `muteRemainingLabel` 剩余时间文案（秒/分钟/小时/天），与后端 `format_duration/1` 整数向下截断策略一致
  - 19 个纯函数单测全绿（不依赖 Widget / Provider / Repo，避开 sqflite→win32 传递链）
- **群资料编辑 slice-3 落地（group_edit S2C 广播同步）**：Model-less 纯函数分派闭环
  - 新增 `lib/service/group_edit_s2c.dart`：sealed `GroupEditParseResult`（`GroupEditPayload(gid, updates)` / `GroupEditParseError('invalid_gid')`）+ `handleGroupEditS2C` dispatcher（函数注入 `applyUpdate` / `fireEvent` / `log`）
  - 接线：`MessageS2CService` 新增 `group_edit` case 分支 → 调用 `GroupRepo.update` + 广播 `GroupEditEvent`
  - 设计亮点：
    - **字段 passthrough 不做白名单**，后端新增列时客户端无需同步升级（前向兼容），合法性由 `GroupRepo.update` 自身过滤
    - **updates 独立副本**，防止 handler 链路误改原始 payload
    - **applyUpdate 吞异常**，本地写失败不阻塞 `fireEvent` 广播
  - 对应后端契约：`imboy/src/api/group_handler.erl:262-267` `Payload = Data#{<<"gid">> => Gid}`
  - 16 个单测全绿（parse 11 + handler 5）；slice-1/2/3 回归 49 全绿
- **群成员角色变更 slice-4 落地（group_member_role S2C 广播同步）**：复用 slice-3 的分派架构
  - 新增 `lib/service/group_member_role_s2c.dart`：sealed `GroupMemberRoleParseResult`（`GroupMemberRolePayload(gid, userId, role, roleText, nickname, adminNickname, updatedAt)` / `GroupMemberRoleParseError('invalid_gid'|'invalid_user_id'|'invalid_role')`）+ `handleGroupMemberRoleS2C` dispatcher
  - 接线：`MessageS2CService` 新增 `group_member_role` case → `GroupMemberRepo.update` 写 role（+ updatedAt 若后端带）+ 广播 `GroupMemberRoleEvent`
  - 角色合法范围 `1..5`：对齐后端 `imboy/src/logic/group_role.hrl` 的 `ROLE_MEMBER=1`..`ROLE_VICE_OWNER=5`
  - 对应后端契约：`imboy/src/logic/group_member_logic.erl:351-376` `role_change_notice/4` payload 含 user_id（这次**契约完整**，不像 mute_notice 有 user_id 缺口）
  - **slice-2 后续 TODO**：`canMuteGroupMember` 权限矩阵尚未覆盖 `role=5 副群主`，待升级 UI 规则时同步加入
  - 17 个单测全绿（parse 12 + handler 5）；slice-1/2/3/4 回归 66 全绿
- **群消息免打扰 slice-5 落地（C6 纯客户端决策内核）**：新增 `lib/service/group_notice_rules.dart`
  - **后端侦察登记（重要契约缺口）**：
    - C3 群公告：`group_notice_handler.erl` / `group_notice_logic.erl` 只暴露 REST（`/v1/group/notice/*`），**无 S2C 广播**；publish 后不触发 `message_ds:broadcast`
    - C4 全员禁言 / C2 @所有人：`grep` 在 `imboy/src` 全库零命中，后端尚未立项
    - → 四选 C6（纯客户端零阻塞闭环），其余三项挂起或降级为 REST 对接（方案 A 共识）
  - `shouldNotifyGroupMessage({noticeDisabled, fromSelf, isMentioned}) → bool` 决策纯函数
  - **优先级约束**（从高到低）：
    1. `fromSelf=true` → 永不通知（压过 @ 定向）
    2. `noticeDisabled=true` 且非 @ → 不通知
    3. `noticeDisabled=true` 但被 @ → **仍通知**（对齐微信 / TG / Slack：定向 @ 穿透免打扰）
    4. 其余 → 通知
  - 本切片**不碰持久化**：`group.notice_disabled` 字段 / StorageService key 留给后续子切片（避免 v20 migration 牵连）
  - 14 个单测全绿（决策契约 6 + 真值表穷尽 8）；全量回归 792 绿
- **群消息免打扰 slice-6 落地（C6 持久化子切片）**：新增 `lib/service/group_notice_config.dart`
  - **技术路线**：KV 键值（`group_notice_disabled:${gid}`）而非 Group 表列
    - 原因 1：免打扰是用户-设备本地偏好，无需跨端同步
    - 原因 2：规避 v20 migration 牵连未解决的 win32 overrides 债务
    - 原因 3：函数注入 read/write → 纯函数单测，不依赖 `StorageService.to` 单例
  - `groupNoticeDisabledKey(gid)` / `readNoticeDisabled(gid, readBool:)` / `setNoticeDisabled(gid, bool, writeBool:)` 三个纯函数入口
  - **防污染**：`gid <= 0` 时读返回 false 且不调 readBool；写直接 return 不调 writeBool
  - **写 false 语义**：覆盖写（非 remove），保留"显式关闭 vs 从未设置"的语义区分
  - 调用侧接线：`StorageService.to.getBool` / `setBool` 注入即可落 shared_preferences
  - 10 个单测全绿（键格式 1 + 读 4 + 写 4 + 集成闭环 1）
- **群消息免打扰 slice-7 落地（C6 UI 开关 Widget）**：新增 `lib/page/group/group_detail/group_notice_disabled_tile.dart`
  - **受控模式**：`value` + `onChanged` 由父层持有（通常读写 `group_notice_config.dart`）→ UI 与持久化解耦，纯 widget test 不触发 `StorageService.to` 单例
  - **iOS 原生感**（对齐 `DESIGN.md` 第 10 章）：`Switch.adaptive` 自动在 iOS 渲染 Cupertino 样式；`ListTile` 默认 ≥ 48pt 满足 44pt 触达
  - **整行可点**：`ListTile.onTap` 与 `Switch.onChanged` 双入口，点 label 文字也能切换
  - `onChanged=null` → `ListTile.enabled=false` + `Switch.onChanged=null` 整行禁用
  - 6 个 widget 测试全绿（渲染 3 + 交互 3）
- **群消息免打扰 slice-8 落地（C6 @ 穿透接线）**：扩展 `shouldSuppressNotification` + 接线 `message.dart`
  - **架构发现**：原计划新建通知闸门，但 `shouldSuppressNotification`（C7-α-2）已管控会话级 DND，仅缺 @ 穿透 → 选**扩展现有函数**而非并行实现，避免冗余架构
  - `shouldSuppressNotification({isMuted, isMentioned = false})`：`isMentioned=true` 压过 `isMuted > 0`，对齐微信 / TG / Slack 行业共识
  - `isMentioned` 默认 `false` → 既有调用方零影响（向后兼容）
  - 接线：`message.dart:904-910` 用 `mentionIncrement > 0` 作为 isMentioned 信号（`computeMentionUnreadIncrement` 在第 833 行已算好）
  - 4 个新单测全绿（`isMuted>0 + 被@` / `isMuted>0 + 非@` / `isMuted=0 + 被@` / 参数省略向后兼容）
- **群成员禁言 slice-2 补丁（role=5 副群主权限）**：修复 `canMuteGroupMember` 数值比较陷阱
  - **发现的 bug**：原实现 `targetRole < currentRole` 假设 role 数值单调，但后端 `include/group_role.hrl` 的权威序是 `member(1) < guest(2) < admin(3) < vice_owner(5) < owner(4)` —— **数值 5 > 4 但权威 5 < 4**
  - **修复**：引入 `_authorityRank(role)` 显式归一化映射（owner→5, vice→4, admin→3, guest→2, member→1, 其他→0）
  - 规则改为 "权威严格高于目标" (`currentRank > targetRank`)，自然退化原 admin/owner 行为
  - 新增 7 个副群主场景测试全绿（副群主可禁言 admin/guest/member；不可禁言 owner / 同级副群主 / 自己；owner 可禁副群主；admin/member/guest 不可禁副群主）
  - slice-4 登记的 TODO 归账完结
  - 全量 26/26 绿（原 19 + 新 7）；slice-5~8 + E4 合计 80 测全绿

- **F5-A slice-4b-2 落地（订阅 GroupMemberRoleEvent 实时刷新 @所有人 权限）**：
  - 新增 `chat_page._ssGroupMemberRole` 订阅，接入既有 `_setupEventListeners`
  - 双重过滤守卫：`event.gid.toString() == widget.peerId && event.userId.toString() == UserRepoLocal.to.currentUid` —— 只响应"本群 + 当前用户"变更，其他成员改角色与本页无关，避免跨页污染
  - 仅 c2g 聊天订阅（c2c 无需）
  - 角色升级 / 降级实时生效：管理员将用户提升为 admin 后，用户无需重进页面即可 @所有人；反向降级后立即失去权限 → 下次发送 @所有人 会被 DeniedAll 拦截
  - 对应后端事件源：`imboy/src/logic/group_member_logic.erl:351-376` `role_change_notice/4` + slice-4 的 S2C 分派
  - dispose 清理补全
  - **为何不做单测**：纯 widget 事件订阅管道，守卫条件 `a && b && c` 过于平凡不值得抽出纯函数；角色值的决策正确性已被 `resolveMentionsForSend` 14 测完全覆盖

- **F5-A slice-4c 落地（@所有人权限闸门真实生效 + i18n toast）**：
  - **关键缺口发现**：`chat_input.dart:425` 早已对 @所有人注入字面量 `'all'` 到 mentionIds（`candidate.isAllMention ? 'all' : candidate.userId`），但 slice-4a/4b 时 `isAllSelected: false` 硬编码导致 `'all'` 被当普通 uid 混入 `mentions: [...]` 发给后端 → 非 admin 用户会收 `{error, permission_denied}` 但**客户端从未前置拦截**
  - 扩展 `lib/page/chat/mention_all_rules.dart`：新增 `splitMentionIds(List<String>) → (uids, isAllSelected)` 纯函数，从混合列表中提取 `'all'` 字面量信号
  - **精确匹配 `'all'`**（小写）：防误伤大小写变体（`'All'/'ALL'`）或包含 `all` 子串的 uid；TSID 数字字符串不会碰撞
  - 接线：`chat_page._sendTextMessage` 用 `splitMentionIds` 拆分后喂给 `resolveMentionsForSend`；DeniedAll 分支 `EasyLoading.showToast(t.mention.mentionAllDenied)` + 清空 mentions + `return false` **阻塞发送**
  - i18n：`zh-CN` "仅管理员可以 @所有人" / `en-US` "Only admins can @everyone"；`dart run slang` 重新生成
  - 6 个新单测全绿（空 / 仅普通 / 仅 all / 混合 / all 多次 / 大小写敏感）；slice-1+3+4c 合计 31 测全绿
  - 至此 @所有人闭环完成：UI 选择 → 字面量 all → split → resolve（权限白名单）→ Ok 附 `['all']` 或 DeniedAll toast 阻塞

- **F5-A slice-4b 落地（chat_page 接入真实群角色加载）**：
  - 新增状态字段 `chat_page.dart:_currentUserGroupRole`（默认 0）+ `_preloadCurrentUserGroupRole()` 异步加载（仿 `group_member_page.dart:74-85` 既有模式）
  - 加载时机：`_initChat` fire-and-forget，非 c2g 跳过；失败静默 debugPrint 回退 0
  - **安全默认 0 的正确性**：`canMentionAll(0) → false`（F5-A slice-1 白名单策略）→ 加载失败/查无记录时 @所有人会走 DeniedAll 分支，**不会误放行**
  - `_sendTextMessage` 硬编码 `role: 0` 替换为 `role: _currentUserGroupRole`
  - barrel 追加 `store_packages.dart` export `group_member_repo_sqlite.dart`
  - **为何不做单测**：本 slice 无新纯函数，仅 widget 状态 + 异步加载管道；已被 slice-1 `canMentionAll` 白名单测 + slice-3 `resolveMentionsForSend` 决策测覆盖（role=0 / 1..5 所有分支）
  - **遗留**：role 变更事件订阅（slice-4 的 `GroupMemberRoleEvent`）未接线 → 用户被改角色后需重进页面刷新；可按需做 slice-4b-2
  - 验证：`flutter analyze lib/page/chat/chat/chat_page.dart` 干净

- **F5-A slice-4a 落地（chat_page._sendTextMessage 接入 resolveMentionsForSend，零 widget 契约变动）**：
  - 接线点：`lib/page/chat/chat/chat_page.dart:1270-1289` 替换原 `if (_chatType == c2g && _currentMentionIds.isNotEmpty) metadata['mentions'] = _currentMentionIds` 朴素附加为 switch-case on `resolveMentionsForSend`
  - barrel 导出：`lib/page/chat/chat/barrel/imboy_packages.dart` 追加 `mention_all_rules.dart`，避免 chat_page.dart 新增 import
  - **slice-4a 安全约束**：硬编码 `role=0` / `isAllSelected=false` → 决策内核走"普通 uids"分支，行为等价于原代码但**免费获得**：
    1. uids 去重（防 ChatInput 上抛重复 uid 时 mentions 字段冗余）
    2. 空白 uid 过滤（防脏数据进 metadata）
    3. switch 骨架就位 —— slice-4b 接 GroupMemberRepo 加载真实 role / slice-4c 扩 ChatInput API 时只需替换硬编码 + 加 DeniedAll 分支
  - **零行为回归**：DeniedAll case 在 slice-4a 不可达（isAllSelected=false），仅占位
  - **TODO 显式登记**：源码注释标 slice-4b/4c
  - 验证：`flutter analyze` 干净；mention 双测 25/25 绿

- **F4 pre-existing 测试失败修复（12 绿）**：
  - **channel_list_state_sync_test（4 测）**：Riverpod 3 auto-dispose 语义陷阱 —— `container.read(provider.notifier)` + `notifier.state = ...` 后若无订阅者，`container.read(provider)` 读回会触发 rebuild 清空瞬态写入；修复：setUp 内 `container.listen(channelListProvider, (_, __) {})` 保活订阅（test-only，不影响生产行为）
  - **live_room_list_provider_test（8 测）**：`LiveRoomModel.id` / `userId` 由 `int` 改为 `String`，对齐 TSID BIGINT 字符串化（Dart Web 53 位精度 + 后端 JSON 约定）；`fromJson` 改 `data['id']?.toString() ?? ''` 防御空/非字符串；`publisher_provider.dart:74` 移除冗余 `.toString()` 调用
  - 两处修复均为最小面，未触碰 S2C / 持久化 / Widget 链路

- **F3 群公告解析契约钉死（TDD RED → GREEN → REFACTOR 闭环，25 绿）**：
  - **后端侦察登记**：`imboy/src/api/group_notice_handler.erl` / `logic/group_notice_logic.erl` 只暴露 REST（`/v1/group/notice/*`），publish 后**无 S2C 广播**（不触发 `message_ds:broadcast`）→ F3 降级为"客户端解析契约 + REST 集成"，不做 S2C dispatcher（对照 slice-3/4 的 group_edit / group_member_role 契约完整）
  - **架构决策：零外部依赖模型抽取**（复用 slice-1 `group_member_columns.dart` 先例）
    - 新增 `lib/page/group/announcement/announcement_model.dart`：仅 `dart:core`，含 `AnnouncementModel` + 4 个纯解析辅助（`parseAnnouncementTimestamp` / `parseOptionalAnnouncementTimestamp` / `buildNoticeTitle` / `toRfc3339`）
    - 原因：`group_announcement_provider.dart` 传递依赖 `http_client.dart → Dio → config`，而 Model/解析逻辑不需要，抽出后 Model-only 单测彻底绕开 sqflite→win32 链
    - `group_announcement_provider.dart` 改用 `import` + `export ... show AnnouncementModel` 保向后兼容（已有 `import ...group_announcement_provider.dart` 的调用点无需改动）
  - **解析契约（25 个单测钉死）**：
    - 字段别名融合：`id` / `notice_id`、`publisher_id` / `user_id`、`content` / `body`、`publisher_name` / `creator_name`（前者优先）
    - `publisher_name` 空 / 缺失 → 回退到 `publisher_id`（避免 UI 空昵称）
    - 数值 id / group_id 自动 `toString()`（对齐 TSID BIGINT 字符串化约定）
    - 时间戳单位自动放大：`>1e12` 毫秒原样 / `>1e9` 秒 → ×1000 / `≤1e9` 原样 / ISO-8601 → `millisecondsSinceEpoch` / 非法 → 0
    - `expired_at=0` → 解析为 `null`（避免"永不过期"被误读为立即过期）
  - **REFACTOR 收尾**：Notifier 内原 `_buildNoticeTitle` / `_toRfc3339` 实例方法删除，`publishAnnouncement` 改调公开函数 → DRY
  - 25 个单测全绿（parseTimestamp 7 + parseOptional 3 + buildTitle 4 + toRfc3339 1 + fromJson aliases 4 + defaults 5 + toJson 1）；`flutter analyze lib/page/group/announcement` 零警告

- **F5-A @所有人纯函数契约落地（后端契约完整，客户端解耦闭环）**：
  - **后端侦察更正**（推翻旧阻塞判断）：`imboy/src/logic/mention_logic.erl:36-48` create_mentions/4 + `imboy/src/ds/mention_ds.erl:38-43` save_mentions/4 **已有** @所有人支持 —— 客户端发 `mentions: ["all"]`，后端通过 `group_member_ds:check_admin/2` 校验 admin 权限（`Role >= 3`），通过后展开到群组全员。先前笔记"零命中"有误（关键词过窄），本次 `grep -rn "mention_all\|@所有人"` 命中多处实现。
  - **F5-B 全员禁言仍阻塞**：`grep mute_all` 零命中，后端只有针对单成员的 `group_member_logic:mute/4`，无群级禁言 API —— 确为跨栈阻塞项，等后端立项。
  - 新增 `lib/page/chat/mention_all_rules.dart`（零外部依赖）：
    - `canMentionAll(int role) → bool`：白名单枚举 {admin=3, owner=4, vice_owner=5}，**显式枚举而非 `>=3`** 防后端未来引入未知 role 时客户端默认放行
    - `buildMentionsPayload({uids, isAllSelected}) → List<String>`：isAllSelected 优先（返回 `["all"]` 字面量对齐后端识别），否则 uids 去重 + 保序 + 过滤空/全空白；返回独立副本
  - 11 个单测全绿（canMentionAll 4 + buildMentionsPayload 7）；`flutter analyze` 零警告
  - **为什么不做 UI 层**：UI 侧 @ 选择器 / 消息发送链路涉及 Widget + Provider + WebSocket 调用，与既有 `lib/service/mention_service.dart` / `lib/store/api/mention_api.dart` 耦合度高，超出"零外部依赖 slice"范围；后续可按需做 slice-3 UI 接线，本 slice 先钉死决策契约。

- **F5-A slice-3 @所有人发送侧决策内核（sealed Result 闸门）**：
  - **接入点识别**：`lib/page/chat/chat/chat_page.dart:1271-1275` 当前仅用 `_currentMentionIds.isNotEmpty` 作为 mentions 字段附加闸门，既**无 @所有人支持**，也**无权限校验**；若用户构造 `mentions: ["all"]` 但非 admin，后端会返回 `{error, permission_denied}` 但客户端无预校验。
  - 扩展 `lib/page/chat/mention_all_rules.dart`：新增 sealed `MentionResolveResult`（`MentionResolveOk(mentions)` / `MentionResolveEmpty` / `MentionResolveDeniedAll`）+ `resolveMentionsForSend({isGroupChat, role, uids, isAllSelected})` 决策函数。
  - **关键语义**：member/guest + `isAllSelected=true` → `DeniedAll`，**不偷偷降级**为 @ 子集 —— 用户意图是 @所有人，降级会造成语义失真，必须整体阻塞并提示。
  - 优先级：非群聊 > isAllSelected > 普通 uids（去重过滤）。
  - 14 个单测全绿（empty 分支 3 + @普通 3 + @所有人 7 + 非群聊 1）；slice-1/2/3 合计 25 测全绿，`flutter analyze` 零警告
  - **slice-4 待做**：`chat_page.dart:1271-1275` 改 switch 语句接入 `resolveMentionsForSend` —— 涉及 Widget + toast 链路，单独排期。

### 2026-04-10
- **新增设计规范文档**：`imboyapp/DESIGN.md` 确立 iOS 原生感设计方向
- 双蓝策略：`#2474E5` 品牌蓝 + `#007AFF` iOS 系统蓝分工明确
- 基于 Apple Human Interface Guidelines + 现有 `lib/theme/default/` Token 体系撰写
- 所有新 UI 代码必须先阅读 DESIGN.md

### 2026-02-20
- **Android 开发设备规则**：后续开发、调试、联调与自动化测试统一使用 Android 真机
- 禁止使用 Android 模拟器作为默认开发或测试设备

### 2026-02-08
- **ChatPage Mixin 架构**：完成 chat_page.dart 深度重构
- 新增 `ChatInitializationHandler` mixin（聊天初始化）
- chat_page.dart 从 2029 行减少到 1808 行（减少 10.9%）
- ChatPage Mixin 规范已并入 `README.md#chatpage-mixin-rules`
- Mixin 模块总数达到 8 个，实现清晰的关注点分离
- **资源 URL 授权规范**：所有附件资源 URL 必须通过 `AssetsService.viewUrl` 重新授权
- **权限 Web 平台适配**：创建 `permission_web.dart` 实现 Web 平台权限处理
- **音频文件下载修复**：非图片文件下载添加 `validateImageData: false` 参数

### 2026-01-28
- **前后端协作说明**：添加后端代码位置信息（`../imboy/`）
- 新增"前后端协作"章节，说明前后端目录结构和协作开发方式
- 提供前后端快速导航命令

### 2026-01-19
- **数据层命名重构**：`store/provider/` 重命名为 `store/api/`
- 统一 API 客户端命名：`*_provider.dart` → `*_api.dart`，`*Provider` → `*Api`
- 解决与 Riverpod 的 `Provider` 类型命名冲突
- 更新模块架构图和文档

### 2026-01-16
- **统一文件命名规范**：
  - 新页面 UI 组件使用 `*_page.dart` 后缀
  - 状态管理使用 `*_provider.dart` 后缀
  - 添加完整的命名规范文档和代码模板
  - 明确旧架构到新架构的迁移规则

### 2026-01-15
- 更新主题颜色：主色调从绿色 #059669 更改为科技蓝 #2474E5
- 同步更新 UI/UX 设计规范文档
- 更新颜色系统中的所有相关定义（主色、浅色、深色、容器色）
- **解决 Provider 命名冲突**：为旧 `provider` 包添加别名 `get_provider`，与 Riverpod 的 `Provider` 区分

### 2026-01-13
- 更新国际化方案说明：项目使用 slang 作为多语言解决方案
- 添加 slang 使用方式和配置说明
- 新增国际化相关 FAQ

### 2026-01-01
- 完善架构文档，更新技术栈信息
- 补充数据库架构和消息系统详细信息
- 更新国际化和主题系统说明
- 增加常见问题解答

### 2026-01-05
- 初始化架构文档
- 完成模块结构分析和文档生成
- 创建 Mermaid 架构图和模块索引

---

## 项目愿景

ImBoy 是一个基于 Flutter 开发的跨平台即时通讯（IM）应用，提供完整的聊天、群组、联系人管理等功能。项目采用现代化的架构设计，支持多端部署（iOS、Android、macOS）。

### 核心特性
- 实时消息通讯（C2C、C2G、S2C）
- 群组管理和面对面建群
- 联系人和好友管理
- 用户标签和分类
- WebRTC 音视频通话
- 多媒体消息（文本、图片、视频、音频、位置、文件）
- 本地数据库持久化（SQLite）
- 主题系统（亮色/暗色模式）
- 国际化支持

---

## 架构总览

### 技术栈
- **前端框架**：Flutter (Dart 3.8+)
- **状态管理**：
  - **主力架构**：**Riverpod**（最新版本，已完成80%迁移）
- **路由管理**：**go_router**（主力）
- **本地数据库**：SQLite (sqflite 2.4+)
- **网络请求**：Dio 5.9
- **实时通讯**：WebSocket + WebRTC

### 设计模式
- **架构模式**：MVVM + Repository 模式
- **路由管理**：**go_router
- **数据持久化**：Repository + SQLite
- **消息队列**：持久化队列 + 事件总线

### 迁移状态（2026-01-16 22:10）
- ✅ **服务层**：100% 迁移到 Riverpod
- ✅ **会话模块**：100% 迁移到 Riverpod
- ✅ **联系人模块**：100% 迁移到 Riverpod
- ✅ **个人信息模块**：100% 迁移到 Riverpod
- ✅ **群组模块**：100% 迁移到 Riverpod
- ✅ **登录注册模块**：100% 迁移到 Riverpod
- ✅ **我的模块**：95% 迁移到 Riverpod (user_collect已完成)
- ✅ **聊天模块**：100% 迁移到 Riverpod ⭐
- ✅ **GetX依赖**：0个Dart文件使用GetX
- ✅ **编译状态**：0 errors, 0 warnings (chat模块)

**迁移完成时间**：2026-01-16 22:10 CST
**详细报告**：`lib/page/chat/chat/CHAT_MODULE_GETX_REMOVAL_COMPLETE_REPORT.md`

---

## 模块结构图

```mermaid
graph TD
    Root["(根) ImBoy App"] --> lib["lib/"]
    lib --> page["page/ - 页面层"]
    lib --> component["component/ - 组件层"]
    lib --> service["service/ - 服务层"]
    lib --> store["store/ - 数据层"]
    lib --> theme["theme/ - 主题系统"]
    lib --> config["config/ - 配置"]
    lib --> utils["utils/ - 工具类"]

    page --> chat["chat/ - 聊天模块"]
    page --> contact["contact/ - 联系人模块"]
    page --> group["group/ - 群组模块"]
    page --> mine["mine/ - 我的模块"]
    page --> conversation["conversation/ - 会话列表"]
    page --> passport["passport/ - 登录注册"]
    page --> personal_info["personal_info/ - 个人信息"]

    component --> ui["ui/ - 通用UI组件"]
    component --> chat_comp["chat/ - 聊天组件"]
    component --> helper["helper/ - 辅助工具"]
    component --> http["http/ - 网络请求"]

    service --> websocket["websocket.dart - WebSocket服务"]
    service --> message["message*.dart - 消息服务"]
    service --> sqlite["sqlite.dart - 数据库服务"]
    service --> storage["storage*.dart - 存储服务"]

    store --> repository["repository/ - 数据仓库"]
    store --> api["api/ - HTTP API客户端"]
    store --> model["model/ - 数据模型"]

    click page "./lib/page/CLAUDE.md" "查看页面层文档"
    click component "./lib/component/CLAUDE.md" "查看组件层文档"
    click service "./lib/service/CLAUDE.md" "查看服务层文档"
    click store "./lib/store/CLAUDE.md" "查看数据层文档"
    click theme "./lib/theme/CLAUDE.md" "查看主题系统文档"

    Root --> assets["assets/ - 资源文件"]
    Root --> test["test/ - 测试文件"]
    Root --> plugin["plugin/ - 插件源码"]
</mermaid>

---

## 模块索引

| 模块路径 | 职责描述 | 文档链接 |
|---------|---------|---------|
| `lib/page/` | 所有页面视图和路由 | [查看详情](./lib/page/CLAUDE.md) |
| `lib/component/` | 可复用组件和工具类 | [查看详情](./lib/component/CLAUDE.md) |
| `lib/service/` | 核心业务服务（WebSocket、消息、数据库） | [查看详情](./lib/service/CLAUDE.md) |
| `lib/store/` | 数据层（Repository、Api、Model） | [查看详情](./lib/store/CLAUDE.md) |
| `lib/theme/` | 主题管理和样式系统 | [查看详情](./lib/theme/CLAUDE.md) |
| `lib/config/` | 应用配置和初始化 | - |
| `lib/utils/` | 通用工具类和辅助函数 | - |

### 设计文档
| 文档 | 描述 | 链接 |
|------|------|------|
| UI/UX 最小规范 | 统一设计约束（颜色、间距、组件等） | [查看](./README.md#uiux-minimal-rules) |
| ChatPage Mixin 规则 | 聊天页 Mixin 分层和依赖约束 | [查看](./README.md#chatpage-mixin-rules) |

---

## 运行与开发

### 环境要求
- Flutter SDK 3.8.0+
- Dart SDK 3.8.0+
- Xcode（iOS 开发）或 Android Studio（Android 开发）

### Android 设备规则
- 日常开发、调试、联调、自动化测试必须优先使用 Android 真机。
- 非特殊说明情况下，不使用 Android 模拟器执行功能验证。
- 连接方式可使用 USB 或 ADB 无线连接，但设备类型必须为真机。

### 常用命令

```bash
# 获取依赖
flutter pub get

# 运行开发版本
flutter run

# 构建生产版本
flutter build apk
flutter build ios

# 运行测试
flutter test

# 代码生成
flutter pub run build_runner build
```

### 环境配置
- 开发环境：`lib/config/env_dev.dart`
- 生产环境：`lib/config/env_pro.dart`
- 本地环境：`lib/config/env_local.dart`

通过 `main.dart` 中的 `env` 参数切换环境。

### 前后端协作
**后端代码位置**：`../imboy/`

项目采用前后端分离开发，后端代码位于上一级目录的 `imboy` 文件夹中：

```bash
# 目录结构
imboy.pub/
├── imboy/          # 后端代码（Erlang/Elixir）
└── imboyapp/       # 前端代码（Flutter/Dart）
```

**协作开发**：
- 后端 API 文档：查看 `../imboy/doc/api/` 或后端 README
- WebSocket 消息格式：参考 `lib/service/CLAUDE.md` 中的 WebSocket API v2.0 章节
- 数据库迁移脚本：后端和前端使用相同的迁移脚本（`assets/migrations/`）

**快速导航**：
```bash
# 从当前目录跳转到后端目录
cd ../imboy

# 从后端返回前端
cd imboyapp
```

---

## 测试策略

### 测试目录结构
- `test/` - 单元测试和集成测试
- `test/async_test.dart` - 异步测试
- `test/hidden_phone_test.dart` - 手机号隐藏测试
- `test/is_phone_test.dart` - 手机号验证测试
- `test/service/storage_service_test.dart` - 存储服务测试
- `test/service/event_bus/` - 事件总线测试
- `test/theme_migration_test.dart` - 主题迁移测试

### 测试原则
- **框架无关**：测试代码不依赖特定状态管理框架
- **Widget 测试**：使用 `ProviderScope` 包裹测试组件
- **单元测试**：直接测试业务逻辑，不依赖 UI 层
- **集成测试**：测试完整的用户流程

### 测试工具
- `flutter_test` - Flutter 官方测试框架
- `build_runner` - 代码生成工具
- `mockito` - Mock 框架（如需要）

---

## 国际化

### 多语言方案
项目使用 **slang** 作为国际化解决方案（版本: ^4.11.2）

### 支持语言
- 简体中文 (zh_CN) - 默认语言
- 繁体中文 (zh_Hant)
- 英语 (en_US)
- 德语 (de_DE)
- 法语 (fr_FR)
- 意大利语 (it_IT)
- 日语 (ja_JP)
- 韩语 (ko_KR)
- 俄语 (ru_RU)
- 阿拉伯语 (ar_SA)

### 翻译文件
- `lib/i18n/*.i18n.yaml` - YAML 格式翻译文件
  - `zh-CN.i18n.yaml` - 简体中文（主文件，包含所有翻译键）
  - `en-US.i18n.yaml` - 英语
  - 其他语言文件...
- `lib/i18n/strings.g.dart` - 自动生成的翻译入口文件
- `lib/i18n/strings_*.g.dart` - 各语言自动生成的翻译代码

### 使用方式
```dart
// 在代码中使用翻译
import 'package:imboy/i18n/strings.g.dart';

// 获取翻译字符串
String title = t.home.title; // 访问嵌套键
String message = t.errors.networkError;

// 切换语言
LocaleSettings.setLocale(AppLocale.enUs);

// 获取当前语言
AppLocale currentLocale = LocaleSettings.currentLocale;
```

### 添加新翻译
1. 在 `lib/i18n/zh-CN.i18n.yaml` 添加新的翻译键
2. 运行 `dart run slang` 生成翻译代码
3. 在其他语言文件中提供对应翻译

### 配置文件
- `build.yaml` - slang 构建配置
- `pubspec.yaml` - slang 依赖配置

### 优势
- **类型安全**: 编译时检查翻译键是否存在
- **自动代码生成**: 无需手动维护映射关系
- **支持嵌套**: 支持多层嵌套的翻译结构
- **缺失翻译检测**: 自动检测缺失的翻译
- **轻量高效**: 采用懒加载和代码分割，减小包体积

---

## 架构规则 (Architecture Rules)

### ⚠️ 重要：资源 URL 授权规范

**规则**：**所有附件资源 URL 请求都需要经过 `AssetsService.viewUrl` 重新授权**

#### 说明

ImBoy 服务器的资源 URL（图片、视频、音频、文件等）使用带签名的授权机制：
- `s` - upload scene（上传场景）
- `a` - authorization token（授权令牌，MD5 哈希）
- `v` - timestamp（时间戳，用于验证授权是否过期）

**授权有效时间**：3600 秒（1 小时）

#### 正确用法

```dart
import 'package:imboy/service/assets.dart';

// ✅ 正确 - 使用 AssetsService.viewUrl 重新授权
final authorizedUrl = AssetsService.viewUrl(originalUrl);
final file = await IMBoyCacheManager().getSingleFile(authorizedUrl.toString());

// ✅ 正确 - 使用 cachedImageProvider（内部已调用 AssetsService.viewUrl）
import 'package:imboy/component/helper/func.dart';
Image(
  image: cachedImageProvider(imageUrl, w: 400),
  width: 100,
  height: 100,
)

// ✅ 正确 - 使用 dynamicAvatar（内部已调用 AssetsService.viewUrl）
decoration: BoxDecoration(
  image: dynamicAvatar(avatarUrl),
)
```

#### 错误用法

```dart
// ❌ 错误 - 直接使用原始 URL
Image.network(imageUrl)

// ❌ 错误 - 直接使用原始 URL
CachedNetworkImage(imageUrl)

// ❌ 错误 - 直接下载原始 URL
await Dio().get(imageUrl)
```

#### 已正确实现的组件

以下组件**已经正确使用** `AssetsService.viewUrl`，无需额外处理：

| 组件/函数 | 文件 | 说明 |
|-----------|------|------|
| `IMBoyCacheManager.getSingleFile()` | `lib/component/extension/imboy_cache_manager.dart:102` | ✅ 内部调用 `AssetsService.viewUrl` |
| `cachedImageProvider()` | `lib/component/helper/func.dart:365-379` | ✅ 内部调用 `AssetsService.viewUrl` |
| `dynamicAvatar()` | `lib/component/helper/func.dart:381-393` | ✅ 调用 `cachedImageProvider` |
| `Avatar` 组件 | `lib/component/ui/avatar.dart` | ✅ 通过 `dynamicAvatar` 使用 |
| `OctoImage` (在 message.dart 中) | `lib/component/chat/message.dart:276` | ✅ 使用 `cachedImageProvider` |

#### 需要注意的地方

如果直接使用以下组件，**必须先通过** `AssetsService.viewUrl() **处理 URL**：

- `Image.network(url)` ❌
- `CachedNetworkImage(url)` ❌ (来自 `cross_cache` 包)
- `Dio().get(url)` ❌

#### 示例修复

**修复前**：
```dart
// ❌ 错误
Image.network(
  model.avatar ?? '',
  width: 56,
  height: 56,
)
```

**修复后**：
```dart
// ✅ 正确
Image(
  image: cachedImageProvider(
    model.avatar ?? '',
    w: 56,
  ),
  width: 56,
  height: 56,
)
```

#### 相关文件

- `lib/service/assets.dart` - `AssetsService.viewUrl()` 实现
- `lib/component/helper/func.dart` - `cachedImageProvider()` 工具函数
- `lib/component/extension/imboy_cache_manager.dart` - 缓存管理器

---
