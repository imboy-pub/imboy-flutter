# imboyapp 项目入口 / Project Entry for AI & New Contributors

> **用途**：任何新的 AI 对话或新协作者，读这一页即可快速理解 imboyapp 全貌、关键约束与当前进展，然后开始工作。
> 这是**通用入口文档**（稳定知识为主），不是某次会话的流水账。正式使用说明见根级 `README.md`。
> **最后更新**：2026-07-25

---

## 0. 先记住三条硬约束（最易踩坑）

1. **`~/project/imboy.pub/` 不是 git 仓库**（伪 monorepo 工作区）。真实仓库：`imboyapp/`（本仓，Flutter 端）、`imboy/`（Erlang 后端）、`imboyadmin/`（React 后台）。写文件前先确认在 `imboyapp/` 内。
2. **保留区禁改**：`ios/*`、`macos/*`、`plugin/r_upgrade`、`erlang.mk`。
3. **调试用真机**：项目规则禁止用模拟器做功能验证（媒体/相机功能模拟器无法覆盖）。

---

## 1. 项目是什么

imboyapp 是 **imboy 开箱即用 IM 平台**的 Flutter 移动客户端（iOS/Android），提供 C2C/C2G 消息、WebSocket 长连接、E2EE 加密、附件直传、频道、朋友圈等能力。后端在 `../imboy/`（Erlang/OTP 28+）。

| 层级 | 技术 |
|------|------|
| 框架 | Flutter / Dart SDK `^3.8.0` |
| 状态管理 | Riverpod（100% 迁移，0 GetX） |
| 路由 | go_router |
| 本地库 | SQLite（sqflite，schema **v24**，以 `lib/service/sqlite.dart` 为准） |
| 网络 | Dio + WebSocket + WebRTC |
| i18n | slang（默认 zh-CN，10 语言） |
| 架构 | MVVM + Repository；DDD 模块化 |

---

## 2. 代码结构与规模

`lib/` 顶层（文件数反映重心）：

| 目录 | 规模 | 职责 |
|------|------|------|
| `page/` | 290 | 页面层（路由页面），UI 务实区 |
| `component/` | 145 | 可复用组件 + 辅助工具 |
| `store/` | 99 | 数据层（Repository / Api / Model） |
| `modules/` | 87 | **DDD 功能模块**（充血领域 + 分层） |
| `service/` | 56 | WebSocket / 消息 / 数据库服务 |
| `theme/` | 51 | 主题系统 + 设计 Token |
| `config/` | 21 | 配置与路由 |
| `i18n/` | 16 | slang 生成物（勿手改） |
| `app_core/` | 13 | feature_flags / routing |
| `capabilities/` | 9 | **能力契约层**（隔离重型/高危三方依赖） |

**8 个 DDD 模块**（`lib/modules/`，每个内部分 `domain / application / infrastructure / presentation` 层）：
`channel_content` `group_collab` `identity` `messaging` `moment_social` `ops_governance` `security_privacy` `social_graph`。

**必读文档**：根级 `CLAUDE.md`（架构总览）、`DESIGN.md`（UI 规范，写 UI 前必读）、`lib/*/CLAUDE.md`（各层 codemap）。

---

## 3. 架构规则（动手前必知）

- **分层依赖单向**：`service → store → theme`；DDD 模块内 `domain/application` 必须纯净（不依赖三方技术包），技术细节下沉到 `infrastructure/`。由 `scripts/check_boundaries.dart` 强制守护（CI 阻断）。
- **能力契约层**：重型/高危平台能力（媒体选择、HTTP、存储等）通过 `lib/capabilities/contracts/` 接口调用，三方包仅允许出现在 `adapters/`。用法：`CapabilityLocator.I.get<MediaPickerCapability>().pickSingle(context, MediaType.image)`。
- **TSID**：64-bit ID 用 `EntityId` 类型，禁直接 `string`/`int`。
- **附件 URL 授权（CRITICAL）**：所有附件 URL 必须经 `AssetsService.viewUrl` 重授权；用 `cachedImageProvider`/`Avatar` 而非裸 `Image.network`。
- **设计 Token**：颜色/间距/字号走 `AppColors`/`AppSpacing`/`FontSizeType`，禁硬编码。
- **文件/函数尺寸**：函数 < 50 行、文件 < 800 行。

---

## 4. 上手命令

```bash
cd ~/project/imboy.pub/imboyapp
flutter pub get
flutter run                      # 真机调试（项目规则禁模拟器做功能验证）
flutter test                     # 单元/widget 测试
dart analyze lib                 # 静态分析（应 0 issues；高成本,收尾跑一次即可）
dart run slang                   # 重新生成 i18n 代码
dart scripts/check_boundaries.dart   # 领域边界门禁（应 0 违反）
flutter pub run build_runner build   # 生成 Provider/JSON 序列化等
```

环境配置：`lib/config/env_{dev,pro,local}.dart`。

---

## 5. 当前进展里程碑（2026-06）

- ✅ **依赖瘦身完成**：移除 14 个三方包，自研 `ShimmerBox`/`BadgeWidget`、迁移 `crop_your_image v2` + `wechat_assets_picker`。
- ✅ **能力契约层落地**（`lib/capabilities/`）+ **领域边界门禁转强制**（CI 阻断领域层泄漏技术依赖）。
- ✅ 质量基线：`dart analyze lib` = 0 issues；领域边界门禁 = 0 违反。
- ⏳ **待办**：
  - T16/T17 媒体功能（头像裁剪 + 9 处媒体选择点）**真机回归未完成**（模拟器无相机，拍照/录像路径需真机）。
  - T18（长期）：`flutter pub outdated` 监测依赖升级闸门。

---

## 6. 协作与会话连续性约定

> 本项目是**多人协作**项目，AI 会话状态与团队知识须分离：

- **个人 AI 会话交接**（临时、易腐）→ 建议放 `.ai/handoff.md` 并 `.gitignore`，**不进团队仓库**，避免多人冲突。
- **团队共享知识**（架构决策、踩坑）→ 沉淀到 `CLAUDE.md` 或 `docs/adr/`，走正常 PR review。
- **未完成功能性工作** → 用 **draft PR + checklist** 承载（队友可见、CI 验证、状态随 git 走）。
- **本文件（通用入口）** → 跟随项目里程碑更新即可，不要塞单次会话的临时流水账。
- 注意：AI memory（`~/.claude/`）是**个人本地、不在团队间共享**，团队该知道的知识必须落到 git 文档。

---

## 7. 关键文件索引

| 路径 | 说明 |
|------|------|
| `CLAUDE.md` / `DESIGN.md` | 架构总览 / UI 规范（必读） |
| `lib/capabilities/` | 能力契约层（contracts / adapters / locator） |
| `scripts/check_boundaries.dart` | 领域纯洁边界门禁（CI 强制） |
| `.github/workflows/ci.yml` | CI 流水线（含边界门禁 step） |

---

## 8. docs/ 目录导航

| 目录 | 内容 |
|------|------|
| `codemaps/` | 代码地图（架构/依赖/数据流；2026-06-18 生成，部分条目已标时效） |
| `qa/` | 测试宪章（`testing-charter.md`）、全量测试清单 |
| `reference/` | 功能状态清单（`feature-status.md`） |
| `adr/` | 架构决策记录 |
| `plans/` | 进行中的计划（日期前缀） |
| `archive/` | 已完成计划、一次性 QA/审计报告（只进不出） |

根级文档：`changelog.md`（更新日志）、`FAQ.md`、`privacy-policy.md`、`data-safety-declaration.md`（后三个被 app asset 打包，**禁止改名**，见 `pubspec.yaml`）。

### 文档维护规则

- **命名**：稳定文档用小写 kebab-case（`module-map.md`）；`adr/`、`plans/`、`archive/` 内保留日期前缀；asset 打包文件不改名。
- **一次性产物**（审计报告、QA 台账、已完成计划）完成后 `git mv` 入 `archive/`，不留在活目录。
- 新增长期文档先考虑能否并入现有文档；本索引只放稳定入口。
