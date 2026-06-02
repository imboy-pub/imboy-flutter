> [imboy.pub 根目录](../../../../CLAUDE.md) > [imboyapp](../../../CLAUDE.md) > **modules/group_collab（群组协作 DDD 模块）**

# group_collab 模块 — DDD 限界上下文 / Group Collaboration Bounded Context

> 最后更新 / Last updated：2026-06-02 | DDD 充血改造 Phase 2 / Phase 4（T4.3 余项）

---

## 文档双语规则 / Bilingual Rule (MANDATORY)

- 简体中文为权威版本，English 在同一文件同步。代码/命令/标识符不翻译。
- Simplified Chinese is source of truth; English synced in the same file. Code & identifiers are NOT translated.

---

## 模块定位 / Module Scope

`lib/modules/group_collab/` 是**群组协作限界上下文**：群组身份、角色权限、成员管理，以及群投票/日程/任务/相册/文件等协作能力。当前为**遗留页面/服务之上的稳定 seam**，DDD 充血成果（聚合 + 值对象）已抽取，仓储端口已就位。

`lib/modules/group_collab/` is the **group collaboration bounded context**: group identity, role-based permissions, membership, plus vote/schedule/task/album/file collaboration. It is a **stable seam over legacy pages/services**, with the DDD aggregate + value objects already extracted and the repository port in place.

---

## 结构与依赖方向 / Structure & Dependency Direction

```
public.dart（对外 seam，re-export 遗留页/服务）
   └─ domain/      纯领域：Group 聚合 + 值对象（GroupId / GroupRole）
   └─ infrastructure/  GroupRepository 端口（务实 port，T4.4a）
```

| 层 / Layer | 文件 | 职责 |
|---|---|---|
| **domain** | `domain/group.dart`（T2.4） | `Group` 聚合根：成员上限、转让/解散等不变量内聚；不可变操作返回新实例 |
| **domain/value** | `value/group_id.dart`、`value/group_role.dart` | `GroupId` 标识值对象；`GroupRole` 角色值对象（`isAdmin`/`isOwner`/`canAnnounce`/`canMute`），**移除散落硬编码白名单 {3,4,5}** |
| **infrastructure** | `infrastructure/group_repository.dart`（T4.4a） | `GroupRepository` abstract 端口；`GroupRepo`（`store/repository/group_repo_sqlite.dart`）`implements`。务实 port：核心 CRUD（insert/update/delete/save/findById），引用 `sqflite_sqlcipher.Transaction` |

> **依赖铁律**：domain 纯 Dart，禁 `flutter/*`、`repository/*`；infrastructure 端口允许引用持久化 `Transaction`（方向 A 务实 port，见 [messaging/CLAUDE.md](../messaging/CLAUDE.md) 同款决策）。

---

## 充血实体与值对象 / Rich Entity & Value Objects

| 类型 | 不变量 / 决策 | 来源 |
|---|---|---|
| `Group`（聚合根） | 成员数 ≤ 上限；转让须 owner、解散须 owner；状态变更逐字镜像后端 `group_agg` | T2.4 |
| `GroupRole`（VO） | `isAdmin`（role≥3）/`isOwner`/`canAnnounce`/`canMute`；权限判定集中于此，散落白名单已收敛 | T2.4 / T2.5 |
| `GroupId`（VO） | 封装群组标识，杜绝裸 `String`/`int` 误用 | T2.4 |

---

## 对外接口 / Public API

`public.dart` 是模块唯一对外出口，re-export 群组协作的页面与服务（group_list / group_detail / group_member / announcement / vote / schedule / task / album / file 等 28 项）。上层一律经此导入，**勿深链 page/service 内部文件**。

---

## 待办与技术债 / TODO & Tech Debt

- **DS 接线**：`group_agg`（BE）与 `Group`（FE）聚合已就位，部分既有 logic/service 仍走遗留路径，渐进接线留后续。
- **store SQL 角色判定**：`group_repo_sqlite` 内 `role>=3` 等 SQL 内联角色判定（数据层一致性）非本上下文领域范畴，留数据层一致性任务处理。

---

## 变更记录 / Changelog

| 日期 | 内容 |
|------|------|
| 2026-06-02 | T4.3 余项：首次创建 group_collab 模块文档（双语），记录 Group 聚合/GroupRole VO/GroupRepository 端口与 seam 约定 |
