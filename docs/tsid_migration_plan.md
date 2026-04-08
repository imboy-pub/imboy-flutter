# TSID 迁移计划 — Flutter 客户端

> 创建日期: 2026-04-06
> 状态: **已完成** (2026-04-07 后端迁移完成，elib_hashids 已删除)
> 背景: 后端从 BIGSERIAL + hashids 编码迁移到 elib_tsid (分布式时间排序 ID)

---

## 1. 迁移概述

### 1.1 变更说明

| 项目 | 旧方案 | 新方案 |
|------|--------|--------|
| ID 生成 | DB BIGSERIAL 自增 | 后端 elib_tsid 生成 (64-bit BIGINT) |
| 传输格式 | hashids 编码字符串 (如 `"p25vd5"`) | 原始数字 (如 `1838294017982464`) |
| Dart 类型 | `String` | `String`（内部统一用 String 表示，值为纯数字字符串） |

### 1.2 核心策略

**保持所有 ID 字段为 `String` 类型不变**。原因：

1. SQLite 中所有 ID 列已经是 `TEXT` 类型，无需改表结构
2. `ConversationUk3Generator` 用字符串拼接生成会话唯一键
3. `flutter_chat_core` 的 `Message.authorId` / `Message.id` 都是 `String`
4. Dart 的 `int` 是 64-bit，可以精确表示 TSID，但 JSON 解析时大数字可能丢精度
5. 用 `String` 统一表示可以兼容 hashids (旧) 和 TSID (新) 两种格式

**关键改动聚焦在**：
- 确保 `fromJson` / 反序列化代码能正确处理 `int` 和 `String` 两种 JSON 值
- 移除 `hashidEncode` 函数（不再需要客户端做任何编码）
- 更新文档注释中的 hashids 引用
- 利用已有的 `TsidHelper` 工具类和 `parseModelString` 做兼容处理

---

## 2. 影响分析

### 2.1 已有的兼容基础设施 (无需修改)

| 文件 | 说明 |
|------|------|
| `lib/utils/tsid_helper.dart` | 已实现 `parseIdAsString` / `parseIdAsInt` / `isTsid` / `idsEqual` |
| `lib/store/model/model_parse_utils.dart` | `parseModelString(dynamic)` 已处理 int→String 转换 |
| `test/utils/tsid_helper_test.dart` | 已有完整测试 |

`parseModelString` 内部调用 `value.toString()`，所以当后端返回 `int` 类型的 TSID 时，会自动转为 `"1838294017982464"` 字符串，现有模型的 `fromJson` 无需改动即可兼容。

### 2.2 需要修改的文件

#### 优先级 P0 — 必须修改（功能性阻塞）

| # | 文件 | 当前问题 | 修改内容 |
|---|------|----------|----------|
| 1 | `lib/service/e2ee_shard_message_handler.dart:464-480` | `hashidEncode()` 函数：客户端自行做 Base62 编码发送给后端 | 删除 `hashidEncode` 函数，直接用 `TsidHelper.parseIdAsString(id)` 替代 |
| 2 | `lib/service/e2ee_shard_message_handler.dart:149` | `'to': hashidEncode(fromUid)` | 改为 `'to': TsidHelper.parseIdAsString(fromUid)` |
| 3 | `lib/service/e2ee_shard_message_handler.dart:299` | `'to': hashidEncode(toUid)` | 改为 `'to': TsidHelper.parseIdAsString(toUid)` |

#### 优先级 P1 — 建议修改（文档/注释更新）

| # | 文件 | 修改内容 |
|---|------|----------|
| 4 | `lib/store/api/msg_api.dart:15` | 注释 `hashids 编码的 uid` → `对端 ID` |
| 5 | `lib/store/api/e2ee_plus_api.dart:26,175,199` | 注释 `HashID 编码` → `用户 ID` |
| 6 | `lib/store/api/live_room_api.dart:56,69,82` | 注释 `hashids 编码字符串` → `直播间 ID` |
| 7 | `lib/store/api/report_api.dart:10` | 注释 `hashids编码的群ID/用户ID等` → `目标 ID` |
| 8 | `lib/store/model/live_room_model.dart:2` | 注释 `后端 hashids 编码后的 ID` → `直播间 ID` |
| 9 | `lib/service/events/common_events.dart:621` | 注释 `HashID` → `动态 ID` |
| 10 | `lib/service/e2ee_social_service.dart:849` | 注释 `HashID 编码` → `用户 ID` |
| 11 | `lib/service/e2ee_transfer_service.dart:22` | 注释 `HashID 编码` → `用户 ID` |
| 12 | `lib/service/e2ee/e2ee_transfer_handler.dart:189` | 注释 `HashID 编码` → `用户 ID` |
| 13 | `lib/service/e2ee_health_check_service.dart:72` | 注释 `HashID 编码` → `用户 ID` |
| 14 | `lib/page/chat/chat/chat_provider.dart:1952` | 注释 `hashids 编码 ID` → `对端 ID` |
| 15 | `lib/page/live_room/publisher/publisher_provider.dart:18` | 注释 `hashids 字符串` → `直播间 ID` |
| 16 | `lib/store/CLAUDE.md:274` | 文档 `hashids 编码的对端 ID` → `对端 ID` |
| 17 | `lib/service/CLAUDE.md` (多处) | 文档中所有 hashids 相关描述需要更新 |

#### 优先级 P2 — 测试文件更新

| # | 文件 | 修改内容 |
|---|------|----------|
| 18 | `test/store/api/group_feature_api_id_compat_test.dart` | 测试用例中的 `hashid` 变量命名可更新，但不影响功能 |
| 19 | `test_automation/scenarios/06_add_friend_request.yaml:33` | `target_uid: "target_user_id_hashid"` 占位符更新 |

### 2.3 无需修改的文件（已天然兼容）

以下文件中 ID 字段使用 `parseModelString(dynamic)` 解析，当后端返回 `int` 时会自动转为 `String`：

- `lib/store/model/message_model.dart` — `fromId`, `toId` 通过 `parseModelString` 解析
- `lib/store/model/conversation_model.dart` — `peerId` 通过 `parseModelString` 解析
- `lib/store/model/user_model.dart` — `uid` 通过 `parseModelString(json['uid'] ?? json['id'])` 解析
- `lib/store/model/contact_model.dart` — `peerId` 通过 `parseModelString` 解析
- `lib/store/model/group_model.dart` — `groupId`, `ownerUid`, `creatorUid` 通过 `parseModelString` 解析
- `lib/store/model/group_member_model.dart` — `groupId`, `userId` 通过 `parseModelString` 解析
- `lib/store/model/new_friend_model.dart` — `uid`, `from`, `to` 通过 `parseModelString` 解析
- `lib/store/model/denylist_model.dart` — `deniedUid` 通过 `parseModelString` 解析
- `lib/store/model/people_model.dart` — `id` 通过 `parseModelString` 解析
- `lib/store/model/live_room_model.dart` — `id`, `userId` 通过 `?.toString() ?? ''` 解析
- `lib/store/model/webrtc_signaling_model.dart` — `from`, `to` 直接从 JSON 读取（需确认后端返回类型）
- `lib/store/repository/user_repo_local.dart` — `currentUid` 存储在 SharedPreferences 中作为 String
- `lib/utils/conversation_uk3_generator.dart` — 接收 `String` 参数，无影响

---

## 3. SQLite 本地数据库影响

### 3.1 表结构

所有 ID 列在 SQLite 中都是 `TEXT` 类型（参见预置 `example10.db` 和 `upgrade.sql`）。
TSID 作为纯数字字符串存储在 `TEXT` 列中完全兼容，**无需数据库迁移**。

### 3.2 会话唯一键 (conversation_uk3)

`ConversationUk3Generator` 使用字符串拼接：`"C2C_123_456"`。
当 ID 从 hashids 字符串变为 TSID 数字字符串后，新会话的 `uk3` 格式会变化：
- 旧: `C2C_p25vd5_gdwqa5`
- 新: `C2C_1838294017982464_1838294017982465`

**影响**：同一对用户的旧会话和新会话会有不同的 `uk3`。这在后端 ID 迁移完成后不会发生（所有用户的 ID 统一为 TSID），但在过渡期如果同一用户的 ID 在不同 API 中返回不同格式，可能导致会话分裂。

**建议**：后端应确保所有 API 统一返回新格式 ID，避免同一用户在不同接口中 ID 格式不一致。

### 3.3 索引和查询

现有索引基于 `conversation_uk3`、`from_id`、`to_id` 等 TEXT 列，不受影响。

---

## 4. 过渡期兼容策略

### 4.1 双格式兼容

在过渡期，后端可能部分 API 返回 hashids、部分返回 TSID。客户端应对策略：

1. **反序列化兼容**：`parseModelString(dynamic)` 已经处理 `int → String` 转换 ✅
2. **ID 比较兼容**：使用 `TsidHelper.idsEqual(a, b)` 进行跨格式比较 ✅
3. **发送兼容**：直接发送后端返回的原始 ID（String 形式），不做任何编码/解码

### 4.2 WebRTCSignalingModel 特殊处理

`WebRTCSignalingModel.fromJson` 直接赋值 `from: json['from']`, `to: json['to']`，没有经过 `parseModelString`。如果后端返回 `int`，这里会得到 `dynamic` 类型，后续使用时可能报错。

**建议**：添加 `parseModelString` 调用确保类型安全。

---

## 5. 实施步骤

### Phase 1: 基础修改（立即执行）
1. 修改 `e2ee_shard_message_handler.dart` — 删除 `hashidEncode`，使用 `TsidHelper.parseIdAsString`
2. 修复 `WebRTCSignalingModel.fromJson` 的类型安全问题

### Phase 2: 文档更新（与 Phase 1 同步）
1. 更新所有源码中的 hashids 注释
2. 更新 CLAUDE.md 文档

### Phase 3: 测试验证
1. 确保现有 `TsidHelper` 测试通过
2. 添加 `WebRTCSignalingModel` 的 TSID 兼容测试
3. 验证端到端消息流

### Phase 4: 后端切换后清理
1. 移除 `hashidEncode` 残留引用
2. 清理测试中的 hashid 占位符

---

## 6. 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 过渡期同一用户 ID 格式不一致 | 会话分裂、消息丢失 | 后端确保原子切换，所有 API 同步返回新格式 |
| JavaScript JSON 大数字精度丢失 | Web 端 TSID 截断 | Dart `int` 是 64-bit，无此问题；Web 端 Dart 编译为 JS 时 `int` 可表示 2^53，TSID 不超过此范围 |
| SharedPreferences 存储的 currentUid 格式变化 | 登录状态异常 | 不影响，`setString/getString` 存储 String，内容无关格式 |
| 本地缓存的旧 hashid 格式数据 | 查询不到历史数据 | 不影响，本地数据库的 ID 是后端返回值的原样存储 |

---

## 7. 结论

此次迁移对 Flutter 客户端的影响**非常小**，主要原因：
1. 所有模型的 ID 字段已经是 `String` 类型
2. `parseModelString(dynamic)` 已经能将 `int` 转为 `String`
3. SQLite 中 ID 列是 `TEXT` 类型

**必须修改的代码仅有 1 个文件中的 3 处**：删除 `hashidEncode` 函数及其 2 处调用。其余均为文档/注释更新。
