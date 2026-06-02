> [imboy.pub 根目录](../../../../CLAUDE.md) > [imboyapp](../../../CLAUDE.md) > **modules/identity（身份 DDD 模块）**

# identity 模块 — DDD 限界上下文 / Identity Bounded Context

> 最后更新 / Last updated：2026-06-02 | DDD 充血改造 Phase 3 / Phase 4（T4.3 余项）

---

## 文档双语规则 / Bilingual Rule (MANDATORY)

- 简体中文为权威版本，English 在同一文件同步。代码/命令/标识符不翻译。
- Simplified Chinese is source of truth; English synced in the same file. Code & identifiers are NOT translated.

---

## 模块定位 / Module Scope

`lib/modules/identity/` 是**身份限界上下文**：登录/注册/找回密码/账号管理（passport），以及用户资料的领域校验。当前为**遗留 passport 页面之上的稳定 seam**，用户资料充血实体已抽取。

`lib/modules/identity/` is the **identity bounded context**: login / signup / forgot-password / account management (passport), plus domain-level user-profile validation. It is a **stable seam over legacy passport pages**, with the user-profile rich entity already extracted.

---

## 结构与依赖方向 / Structure & Dependency Direction

```
public.dart（对外 seam，re-export passport 页/状态）
   └─ domain/   纯领域：User 充血实体 + 值对象（UserId）
```

| 层 / Layer | 文件 | 职责 |
|---|---|---|
| **domain** | `domain/user.dart`（T3.5） | `User` 资料校验内聚：性别（1/2/3）、允许搜索（1/2）、邮箱正则（**逐字镜像后端 `elib_type:is_email`**）；`copyWith` 不可变 |
| **domain/value** | `value/user_id.dart` | `UserId` 标识值对象，杜绝裸 `String`/`int` 误用 |

> **依赖铁律**：domain 纯 Dart，禁 `flutter/*`、`repository/*`。资料校验为零副作用纯逻辑，可独立单测钉死契约。**BE↔FE 对称**：`User` 校验镜像后端 `user_agg:validate_update/2`（T3.1）。

---

## 充血实体 / Rich Entity

| 实体 | 不变量 | 不可变操作 |
|---|---|---|
| `User`（T3.5） | 性别∈{1,2,3}、允许搜索∈{1,2}、邮箱须匹配正则（镜像后端 `is_email`） | `copyWith()` 返回新实例 |

---

## 对外接口 / Public API

`public.dart` re-export passport 流程页面与状态（login / signup / signup_continue / forgot_password / manage_account / web_login + `passport_notifier` / `passport_state`）。上层一律经此导入。

---

## 待办与技术债 / TODO & Tech Debt

- **logic 接线**：`user_agg`（BE，T3.1/T3.2）与 `User`（FE，T3.5）已就位；FE passport notifier 仍走遗留校验路径，渐进委托领域 `User` 留后续。
- **值对象扩展**：`UserId` 已抽，其余身份值对象（account / mobile）按需补充（YAGNI）。

---

## 变更记录 / Changelog

| 日期 | 内容 |
|------|------|
| 2026-06-02 | T4.3 余项：首次创建 identity 模块文档（双语），记录 User 充血实体（资料校验，BE↔FE 对称）/UserId VO 与 seam 约定 |
