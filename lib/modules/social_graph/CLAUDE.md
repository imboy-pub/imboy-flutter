> [imboy.pub 根目录](../../../../CLAUDE.md) > [imboyapp](../../../CLAUDE.md) > **modules/social_graph（社交图谱 DDD 模块）**

# social_graph 模块 — DDD 限界上下文 / Social Graph Bounded Context

> 最后更新 / Last updated：2026-06-02 | DDD 充血改造 Phase 3 / Phase 4（T4.3 余项）

---

## 文档双语规则 / Bilingual Rule (MANDATORY)

- 简体中文为权威版本，English 在同一文件同步。代码/命令/标识符不翻译。
- Simplified Chinese is source of truth; English synced in the same file. Code & identifiers are NOT translated.

---

## 模块定位 / Module Scope

`lib/modules/social_graph/` 是**社交图谱限界上下文**：联系人/好友关系、关系状态机、@提及、用户收藏、附近的人。当前为**遗留 contact/mention/user_collect 页面之上的稳定 seam**，关系状态机充血实体与联系人仓储端口已抽取。

`lib/modules/social_graph/` is the **social graph bounded context**: contacts/friendship, relationship state machine, @mention, user collect, people-nearby. A **stable seam over legacy pages**, with the relationship state-machine entity and contact repository port already extracted.

---

## 结构与依赖方向 / Structure & Dependency Direction

| 层 / Layer | 文件 | 职责 |
|---|---|---|
| **domain** | `domain/friendship.dart`（T3.5） | `Friendship` from→to 关系状态机：状态 `none/pending/friends/blocked`，**逐字镜像后端 `friend_agg`**（T3.3）；非法转换抛 `StateError`，`block` 幂等 |
| **domain/value** | `value/value.dart` | 社交图谱值对象聚合 |
| **infrastructure** | `infrastructure/contact_repository.dart`（T4.4a） | `ContactRepository` abstract 端口；`ContactRepo`（`store/repository/contact_repo_sqlite.dart`）`implements`。务实 port：核心 CRUD（insert/update/delete/deleteByUid/findByUid/save），引用 `sqflite_sqlcipher.Transaction` |

> **依赖铁律**：domain 纯 Dart，禁 `flutter/*`、`repository/*`；infrastructure 端口允许引用持久化 `Transaction`（方向 A 务实 port）。**BE↔FE 对称**：`Friendship` 状态/转换/不变量逐字镜像后端 `friend_agg`。

---

## 充血实体 / Rich Entity

| 实体 | 不变量 | 不可变操作 |
|---|---|---|
| `Friendship`（T3.5） | 状态机 `none→pending→friends`/`blocked`；非法转换抛 `StateError`（对齐后端 `{error,atom}`）；`block` 幂等 | 转换方法返回新实例 |

> **命名映射**：backlog 所称「User Repository」在本上下文真身为 `ContactRepo`（联系人/好友数据仓储）；`UserRepoLocal` 是会话单例（非 CRUD 仓储），不在端口范围。

---

## 对外接口 / Public API

`public.dart` re-export 社交图谱页面与服务（contact / add_friend / new_friend / people_info / people_nearby / recently_registered_user / mention_list / user_collect / contact_tag_list + `mention_service`）。上层一律经此导入。

---

## 待办与技术债 / TODO & Tech Debt

- **logic 接线**：`friend_agg`（BE，T3.3）与 `Friendship`（FE，T3.5）已就位；现状 friend_logic 为无状态消息流（T3.4 blocked，待产品评审），委托接线待解阻。
- **toTypeMessage 富化依赖**：messaging 的 `message_model_mapper`（T4.4b）经 `ContactRepository` 实现取联系人富化作者信息——跨上下文协作经端口，符合分层。

---

## 变更记录 / Changelog

| 日期 | 内容 |
|------|------|
| 2026-06-02 | T4.3 余项：首次创建 social_graph 模块文档（双语），记录 Friendship 状态机（BE↔FE 对称）/ContactRepository 端口与 seam 约定 |
