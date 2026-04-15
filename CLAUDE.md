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

### 2026-04-15
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
