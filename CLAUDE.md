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
- **`56ccea0a` Splash + Welcome + 个人信息 UI/UX 统一升级（5 文件 +29/-39，3 Token，零回归）** / **Splash + Welcome + Personal Info UI/UX coherent uplift (5 files +29/-39, 3 new Tokens, zero regression)**：
  - **个人信息头像 3 重 bug 闭环** / **Personal info avatar 3-fold bug closure**：外 64×64 容器 vs `Avatar` 内部默认 50×50 错位 + 双层圆角嵌套（外层 `borderRadiusSmall` + 内层 `borderRadiusTiny`）+ Avatar 灰底透出 → `ClipRRect` 直接包 `Avatar` 显式 `width: 64, height: 64`；同步替换 BottomSheet 弃用 Token（`darkCardBackground` → `darkSurfaceContainer`）/ Outer 64×64 vs Avatar default 50×50 mismatch + double-radius nesting + grey-bg bleed-through fixed by ClipRRect-wraps-Avatar with explicit dims; deprecated Token swap
  - **Splash UX 清理 5 处** / **Splash UX cleanup, 5 sites**：
    - 强制 `Future.delayed(2000ms)` → `Future.wait + 800ms` 并行最低延时（认证检查为本地同步操作几乎瞬时；总时长由 800ms 保底）/ Forced 2s → parallel 800ms min-delay; auth check is sync local, total bounded by floor
    - 移除无效 `PatternPainter`（透明度 `0.06` 几乎不可见 + 整段 `CustomPainter` class）+ 多余 `CircularProgressIndicator`（路径为同步本地检查，无加载语义）/ Removed invisible PatternPainter (0.06 alpha) + redundant spinner (path is sync)
    - 底部 `SafeArea(minimum: bottom 24)` 包裹避开 iOS 全面屏 home indicator / SafeArea wraps bottom to avoid notched home indicator
    - `Color.fromRGBO(0, 0, 0, 0.2)` → `Color(0x33000000)` ARGB 字面量（弃用 RGBO 工厂迁移）/ Color.fromRGBO → ARGB hex literal
    - 3 色渐变全 Token 化：`#42A5F5/#2474E5/#1565C0` → `splashGradientStart/primary/primaryDark`
  - **Welcome 品牌锚点 + 全色 Token 化** / **Welcome brand anchor + full color Token-ization**：
    - 顶部新增品牌锚点（`assets/images/imboy_logo0.png` 28×28 + "ImBoy" wordmark）补 Splash → Welcome 视觉延续 / Top brand anchor (Logo 28×28 + wordmark) bridges Splash → Welcome
    - 按钮圆角硬编码 `BorderRadius.circular(28)` → `AppRadius.borderRadiusXLarge` (24pt)
    - 4 处 hex 字面量 → Token：`Color(0xFF64748B)` (3 处) → `AppColors.slateText`、`Color(0xFFCBD5E1)` → `AppColors.slateMuted`
    - **SVG 配色重绘对齐 DESIGN.md 双蓝品牌策略**：`gradGreen` 重命名 `gradBrand`，6 处绿 / 橙 hex (`#34D399` / `#10B981` / `#F59E0B`) → 蓝色家族 (`#42A5F5` / `#1565C0`)；起始色由 `#34D399` 改为 `#42A5F5` 与 Splash 渐变首段同色 / SVG palette repainted to dual-blue brand strategy: green / orange replaced by blue family aligning with Splash gradient
  - **AppColors Token 扩展 +3** / **AppColors Token expansion +3**（`lib/theme/default/app_colors.dart` +21 行）：
    - `slateText (#64748B)` — Tailwind slate-500 蓝灰中性次级文本，区别于 Material 3 紫灰 `lightTextSecondary` (#49454F)，与 `primary` 蓝色家族同色相
    - `slateMuted (#CBD5E1)` — Tailwind slate-300 未激活指示器 / 浅边框，与 `slateText` 配套
    - `splashGradientStart (#42A5F5)` — Material Blue 400 渐变起始色，与 `primary` + `primaryDark` 组成 Splash 三段式品牌蓝渐变（值与 `darkSentMessageBackground` 相同但语义独立）
  - **范围**：5 文件 +29/-39 / Scope: 5 files +29/-39
  - **保留区零动**：`ios/*` / `macos/*` / `plugin/r_upgrade` 未触碰 / Preservation zones untouched
  - **回归**：`flutter analyze` 4 文件零警告（4.3s）；现有 `Avatar` / `Splash` / `Welcome` 调用链零行为变更 / Regression: analyzer clean (4.3s); zero behavioral change in call sites
- **R-3-token-expansion#2 Chat Web 主题三件套 hex → AppColors Token** / **R-3-token-expansion#2: 3 Chat-Web theme hex literals folded into AppColors Tokens**：
  - **新增 3 个 Token**（与既有 `chatWebSecondaryLight/Dark` + `chatWebBrand` 同主题家族）/ Add 3 new Tokens in same Chat-Web theme family：
    - `chatWebBackgroundLight (#F0F2F5)` — 亮色 header / 容器背景，5 处
    - `chatWebBackgroundDark (#202C33)` — 暗色 header / 容器背景，3 处
    - `chatWebSurfaceDark (#2A3942)` — 暗色 input/selected/高一层 surface（比 BackgroundDark 略浅），4 处
  - **范围**：3 文件 +20/-7：`lib/theme/default/app_colors.dart` +13 行 + `lib/page/conversation/web_conversation_page.dart` 3 处替换 + `lib/page/search/web_search_page.dart` 5 处替换
  - **回归**：`flutter analyze` 三文件零警告；`grep` 兜底 lib/ 三 hex 0 命中（仅 Token 源头保留）/ analyzer clean, 0 hex residue
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
- **R-3-token-expansion#3 Chat Web divider/surfaceDarkest + Material info 蓝（5 文件 14 hex → Token）** / **R-3-token-expansion#3: Chat Web divider/surfaceDarkest + Material info blue, 14 hex literals folded into AppColors Tokens across 5 files**：
  - **新增 5 个 Token**（`lib/theme/default/app_colors.dart` +22 行）/ Add 5 new Tokens：
    - `chatWebDividerLight (#E9EDEF)` — Chat Web 风格亮色分隔线/边框，3 处使用 / Chat Web light divider, 3 sites
    - `chatWebDividerDark (#3B4A54)` — Chat Web 风格暗色分隔线/边框，3 处使用 / Chat Web dark divider, 3 sites
    - `chatWebSurfaceDarkest (#111B21)` — Chat Web 最深暗 surface（Black 近黑），比 `chatWebBackgroundDark` 更深，2 处使用 / Chat Web darkest surface, 2 sites
    - `infoBlueContainer (#E1F5FE)` — Material Blue 50 信息容器底色（中性信息态色对），3 处使用 / Material Blue 50 info container, 3 sites
    - `infoBlue (#0277BD)` — Material Blue 700 信息强调色 / icon 色，3 处使用 / Material Blue 700 info emphasis / icon color, 3 sites
  - **范围**：6 文件 +38/-23 / Scope: 6 files +38/-23：
    - `lib/theme/default/app_colors.dart`：+22 行 Token 定义（含 docstring）
    - `lib/page/conversation/web_conversation_page.dart`：3 处替换
    - `lib/page/search/web_search_page.dart`：5 处替换
    - `lib/page/mine/user_device/user_device_page.dart`：2 处替换
    - `lib/page/mine/user_device/user_device_detail_page.dart`：2 处替换
    - `lib/page/mine/user_collect/user_collect_detail_page.dart`：2 处替换
    - **保留区零动**：`ios/*` / `macos/*` / `plugin/r_upgrade`
  - **回归**：6 文件 `flutter analyze` 零警告；`grep` 兜底 `lib/page/` 5 hex 0 命中（仅 app_colors.dart Token 源头保留）/ Regression: analyzer clean, 0 hex residue in `lib/page/`
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
- 多 slice 落地：群成员禁言/解禁、群公告权限、群编辑同步、@所有人、群消息免打扰、F3-F5 系列纯函数契约（共 ~14 slice）。
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
