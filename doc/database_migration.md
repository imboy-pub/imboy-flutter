# 数据库迁移系统使用文档

## 目录
- [概述](#概述)
- [当前状态](#当前状态)
- [架构说明](#架构说明)
- [迁移脚本格式](#迁移脚本格式)
- [使用指南](#使用指南)
- [实战示例](#实战示例)
- [最佳实践](#最佳实践)
- [常见问题](#常见问题)

---

## 概述

Imboy 使用基于 SQL 脚本的数据库迁移系统，支持应用升级时自动迁移数据库结构。

### 核心特性

- ✅ **自动化迁移**：应用启动时自动执行升级
- ✅ **版本管理**：基于 `PRAGMA user_version` 的版本控制
- ✅ **快照回滚**：迁移失败时自动回滚
- ✅ **离线支持**：所有迁移脚本打包在 assets 中
- ✅ **跨版本升级**：支持从任意旧版本升级到最新版本

---

## 当前状态

### 数据库版本信息

- **当前版本**: v9（基线版本）
- **数据库文件**: `assets/example.db`
- **状态**: 生产环境使用中

### 数据库表结构

当前数据库（v9）包含 **16 张表**，分为 5 大类别：

#### 【消息相关表】（5张）

| 表名 | 说明 | 主要字段 |
|------|------|----------|
| `message` | 单聊消息表 (C2C) | id, from_id, to_id, conversation_uk3, payload, created_at, status |
| `group_message` | 群聊消息表 (C2G) | 同上结构 |
| `c2s_message` | C2S 消息表（客户端到系统） | 同上结构 |
| `s2c_message` | S2C 消息表（系统到客户端） | 同上结构 |
| `msg_topic` | 消息主题表 | topic_id, user_id, to_id, type, title |

#### 【会话相关表】（1张）

| 表名 | 说明 | 主要字段 |
|------|------|----------|
| `conversation` | 会话表 | user_id, peer_id, type, unread_num, last_time, last_msg_id |

#### 【联系人相关表】（3张）

| 表名 | 说明 | 主要字段 |
|------|------|----------|
| `contact` | 联系人表 | user_id, peer_id, nickname, avatar, is_friend, category_id |
| `new_friend` | 新朋友/好友申请表 | uid, from_id, to_id, nickname, status |
| `user_denylist` | 黑名单表 | user_id, denied_user_id, nickname |

#### 【群组相关表】（4张）

| 表名 | 说明 | 主要字段 |
|------|------|----------|
| `group` | 群组表 | id, owner_uid, member_count, title, introduction |
| `group_member` | 群成员表 | group_id, user_id, nickname, role, is_join |
| `group_notice` | 群公告表 | group_id, user_id, body, expired_at |
| `user_group` | 用户群组关系表 | user_id, group_id, setting, status |

#### 【用户相关表】（3张）

| 表名 | 说明 | 主要字段 |
|------|------|----------|
| `user_collect` | 用户收藏表 | user_id, kind, kind_id, source, remark |
| `user_tag` | 用户标签表 | user_id, tag_id, scene, name |
| `user_device` | 用户设备表 | user_id, device_id, device_name, last_active_at |

### 查看当前版本

```dart
// 方法 1：通过代码查看
final db = await SqliteService.to.db;
final currentVersion = Sqflite.firstIntValue(
  await db!.rawQuery('PRAGMA user_version')
);
print('当前数据库版本: v$currentVersion');  // 输出: v9

// 方法 2：通过 sqlite3 命令行查看
// sqlite3 assets/example.db "PRAGMA user_version;"
// 输出: 9
```

---

## 架构说明

### 文件结构

```
imboyapp/
├── assets/migrations/
│   ├── upgrade.sql      # 升级脚本模板
│   └── downgrade.sql    # 降级脚本模板
├── lib/service/
│   ├── sqlite.dart              # 数据库服务
│   └── migration_service.dart   # 迁移服务
└── lib/config/
    └── init.dart                # 应用初始化（集成自动迁移）
```

### 工作流程

```
┌─────────────┐
│ App 启动    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────┐
│ MigrationService.autoMigrate()│
└──────┬──────────────────────┘
       │
       ├──► 读取当前版本 (PRAGMA user_version) → v9
       │
       ├──► 加载 upgrade.sql 脚本
       │
       ├──► 筛选需要执行的版本块 → 无（当前已是最新）
       │
       └──► 跳过迁移，直接启动
```

---

## 迁移脚本格式

### 升级脚本 (upgrade.sql)

```sql
-- ============================================================
-- VERSION: 9              ← 起始版本号
-- DESC: 版本描述
-- ROLLBACK_STRATEGY: sql  ← 降级策略
-- ============================================================
-- 功能说明：详细描述这个版本做了什么
-- 变更内容：列出了哪些表、哪些字段
-- 数据迁移：说明是否需要数据迁移

-- SQL 语句（当前 v9 为空，因为是基线版本）

-- 更新版本号（重要！）
-- PRAGMA user_version = 10;
```

### 关键规则

1. **VERSION 标记起始版本**
2. **必须以 `PRAGMA user_version` 结尾**，设置升级后的版本
3. **每个版本块是独立的**
4. **使用 `IF NOT EXISTS`** 避免重复执行错误

### 版本号规则

```
当前版本: v9
下一个版本: v10（当需要升级时）

VERSION: 9  →  PRAGMA user_version = 10  (从 v9 升级到 v10)
VERSION: 10 →  PRAGMA user_version = 11  (从 v10 升级到 v11)
...
```

---

## 使用指南

### 1. 自动迁移（已集成）

应用启动时自动执行，无需手动操作：

```dart
// lib/config/init.dart 中已集成
await _autoMigrateDatabase();
```

### 2. 手动触发迁移

```dart
// 执行自动迁移
final result = await MigrationService.to.autoMigrate();

if (result.success) {
  print('升级成功: v${result.fromVersion} → v${result.toVersion}');
} else {
  print('升级失败: ${result.error}');
}
```

### 3. 指定版本迁移

```dart
// 手动从 v9 升级到 v10（当有 v10 脚本时）
final db = await SqliteService.to.db;
final result = await MigrationService.to.migrate(
  db: db!,
  fromVersion: 9,
  toVersion: 10,
);
```

---

## 实战示例

以下示例展示如何在需要时添加新的数据库版本。

### 示例 1：新增消息撤回功能 (v9 → v10)

#### 需求
支持消息撤回功能，需要记录消息是否被撤回。

#### 实现步骤

**1. 在 upgrade.sql 中添加升级脚本**

```sql
-- ============================================================
-- VERSION: 9
-- DESC: 新增消息撤回状态字段
-- ROLLBACK_STRATEGY: sql
-- ============================================================
-- 功能说明：支持消息撤回功能，记录消息是否被撤回
-- 变更内容：在 message 表新增 recall_status 字段
-- 数据迁移：无需数据迁移，新字段默认值为 0（未撤回）

-- 添加撤回状态字段（0: 正常, 1: 已撤回, 2: 被管理员删除）
ALTER TABLE message ADD COLUMN recall_status INTEGER DEFAULT 0;

-- 创建索引以优化撤回消息查询
CREATE INDEX IF NOT EXISTS idx_message_recall_status
  ON message(recall_status);

-- 更新版本号
PRAGMA user_version = 10;
```

**2. 在 downgrade.sql 中添加降级脚本**

```sql
-- ============================================================
-- VERSION: 9
-- DESC: 从 v10 回退到 v9（基线版本）
-- ROLLBACK_STRATEGY: snapshot
-- ============================================================
-- 回退说明：移除消息撤回状态字段
-- 数据影响：recall_status 字段中的数据将丢失

-- 删除撤回消息索引
DROP INDEX IF EXISTS idx_message_recall_status;

-- 删除撤回状态字段
ALTER TABLE message DROP COLUMN IF EXISTS recall_status;

-- 更新版本号
PRAGMA user_version = 9;
```

**3. 修改代码使用新功能**

```dart
// lib/store/model/message_model.dart
class MessageModel {
  // 添加新字段
  int? recallStatus;

  // 更新 toJson 方法
  Map<String, dynamic> toJson() {
    return {
      // ... 其他字段
      'recall_status': recallStatus ?? 0,
    };
  }
}

// 使用示例
// 撤回消息
Future<void> recallMessage(String messageId) async {
  final repo = MessageRepo(tableName: 'message');
  await repo.update({
    'id': messageId,
    'recall_status': 1,  // 标记为已撤回
  });
}

// 查询未撤回的消息
Future<List<MessageModel>> getActiveMessages() async {
  final db = await SqliteService.to.db;
  final results = await db!.query(
    'message',
    where: 'recall_status = ?',
    whereArgs: [0],
  );
  return results.map((map) => MessageModel.fromJson(map)).toList();
}
```

**4. 测试验证**

```dart
void testMigration() async {
  // 1. 备份数据库
  final db = await SqliteService.to.db;
  final backupPath = await db!.getPath() + '.backup';
  await File(db.getPath()).copy(backupPath);

  try {
    // 2. 执行迁移
    final result = await MigrationService.to.migrate(
      db: db,
      fromVersion: 9,
      toVersion: 10,
    );

    // 3. 验证结果
    assert(result.success);
    assert(result.toVersion == 10);

    // 4. 验证字段存在
    final columns = await db.rawQuery('PRAGMA table_info(message)');
    final hasField = columns.any((col) => col['name'] == 'recall_status');
    assert(hasField);

    print('✅ 迁移成功: v9 → v10');

  } catch (e) {
    // 5. 失败则恢复备份
    await File(backupPath).copy(db.getPath());
    rethrow;
  }
}
```

### 示例 2：新增会话置顶功能 (v10 → v11)

#### 需求
支持会话置顶功能，让重要会话始终显示在顶部。

#### 实现步骤

**1. 编写升级脚本**

```sql
-- 在 upgrade.sql 中添加

-- ============================================================
-- VERSION: 10
-- DESC: 新增会话置顶功能
-- ROLLBACK_STRATEGY: sql
-- ============================================================
-- 功能说明：支持会话置顶功能
-- 变更内容：在 conversation 表新增 is_pinned 和 pinned_at 字段

ALTER TABLE conversation ADD COLUMN is_pinned INTEGER DEFAULT 0;
ALTER TABLE conversation ADD COLUMN pinned_at INTEGER DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_conversation_pinned
  ON conversation(user_id, is_pinned, pinned_at DESC);

PRAGMA user_version = 11;
```

**2. 使用新功能**

```dart
// 置顶会话
Future<void> pinConversation(String conversationId) async {
  final repo = ConversationRepo();
  await repo.updateById(conversationId, {
    'is_pinned': 1,
    'pinned_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
  });
}

// 查询置顶会话
Future<List<ConversationModel>> getPinnedConversations(String userId) async {
  final db = await SqliteService.to.db;
  final results = await db!.query(
    'conversation',
    where: 'user_id = ? AND is_pinned = ?',
    whereArgs: [userId, 1],
    orderBy: 'pinned_at DESC',
  );
  return results.map((map) => ConversationModel.fromJson(map)).toList();
}
```

### 示例 3：跨版本升级 (v9 → v11)

#### 场景
用户从旧版本 App (v9) 直接升级到新版本 (v11)，跳过了 v10。

#### 执行流程

```
当前版本: v9
目标版本: v11

执行顺序:
1. VERSION: 9  → v10 (新增消息撤回功能)
2. VERSION: 10 → v11 (新增会话置顶功能)
```

#### 代码实现

```dart
// 自动处理跨版本升级
final result = await MigrationService.to.autoMigrate();

// MigrationService 会自动：
// 1. 检测当前版本是 v9
// 2. 读取目标版本是 v11
// 3. 执行 v9→v10 的脚本
// 4. 执行 v10→v11 的脚本
// 5. 如果失败，自动回滚到 v9
```

---

## 最佳实践

### 1. 版本规划

- ✅ 使用连续的整数版本号：9, 10, 11, 12...
- ✅ 每个版本只做一件事（单一职责）
- ✅ 新字段必须有默认值
- ✅ 保持向后兼容

### 2. 编写迁移脚本

#### ✅ 推荐做法

```sql
-- 使用 IF NOT EXISTS 避免错误
CREATE INDEX IF NOT EXISTS idx_name ON table(field);

-- 新字段设置默认值
ALTER TABLE message ADD COLUMN new_field INTEGER DEFAULT 0;

-- 添加详细注释
-- 功能说明：xxx
-- 变更内容：xxx
-- 数据迁移：xxx
```

#### ❌ 避免做法

```sql
-- 不要假设字段不存在
ALTER TABLE message ADD COLUMN new_field TEXT;  -- 错误：重复执行会失败

-- 不要在迁移中删除数据
DELETE FROM message WHERE status = 0;  -- 错误：不应该在迁移中删除数据

-- 不要使用复杂的存储过程
-- SQLite 不支持复杂的存储过程
```

### 3. SQLite 限制

SQLite 的 ALTER TABLE 能力有限，需要注意：

| 操作 | 支持 | 说明 |
|------|------|------|
| 添加列 | ✅ | 只能在表末尾添加 |
| 删除列 | ⚠️ | SQLite 3.35.0+ 支持 |
| 重命名列 | ✅ | SQLite 3.25.0+ 支持 |
| 修改列类型 | ❌ | 不支持 |
| 删除约束 | ❌ | 不支持 |

**复杂变更的解决方案**：

```sql
-- 方案 1：创建新表，迁移数据
CREATE TABLE message_new (
  -- 新的表结构
);
INSERT INTO message_new SELECT * FROM message;
DROP TABLE message;
ALTER TABLE message_new RENAME TO message;

-- 方案 2：使用 ALTER TABLE 逐步修改
ALTER TABLE message ADD COLUMN new_field TEXT DEFAULT '';
UPDATE message SET new_field = CAST(old_field AS TEXT);
-- 保留旧字段用于兼容，或在后续版本中删除
```

### 4. 测试迁移

```dart
// 测试脚本
void testMigration() async {
  // 1. 备份数据库
  final db = await SqliteService.to.db;
  final backupPath = '${await db!.getPath()}.backup';
  await File(db.getPath()).copy(backupPath);

  try {
    // 2. 执行迁移
    final result = await MigrationService.to.autoMigrate();

    // 3. 验证结果
    assert(result.success);
    print('升级成功: v${result.fromVersion} → v${result.toVersion}');

    // 4. 验证数据完整性
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM message')
    );
    print('消息总数: $count');

    // 5. 测试新功能
    // ...

  } catch (e) {
    // 6. 失败则恢复备份
    await File(backupPath).copy(db.getPath());
    rethrow;
  } finally {
    // 7. 清理备份
    final backup = File(backupPath);
    if (await backup.exists()) {
      await backup.delete();
    }
  }
}
```

### 5. 错误处理

```dart
final result = await MigrationService.to.autoMigrate();

if (!result.success) {
  // 记录错误日志
  logger.e('迁移失败', error: result.error);

  // 检查是否有快照
  if (result.snapshotPath != null) {
    logger.i('快照路径: ${result.snapshotPath}');
    // 可以选择使用快照恢复
  }

  // 通知用户（可选）
  // 显示错误对话框，引导用户联系客服
}
```

---

## 常见问题

### Q1: 如何查看当前数据库版本？

```dart
final db = await SqliteService.to.db;
final version = Sqflite.firstIntValue(
  await db!.rawQuery('PRAGMA user_version')
);
print('当前版本: v$version');
```

### Q2: 迁移脚本执行失败怎么办？

MigrationService 会自动创建快照并在失败时回滚。如果需要手动恢复：

```dart
// 查找快照文件
final snapshotDir = Directory(
  path.join((await getTemporaryDirectory()).path, 'db_snapshots')
);

final snapshots = snapshotDir.listSync()
  .whereType<File>()
  .toList()
  ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

if (snapshots.isNotEmpty) {
  // 使用最新的快照恢复
  final latestSnapshot = snapshots.first;
  // 执行恢复...
}
```

### Q3: 如何在开发环境测试迁移？

```dart
// 1. 修改数据库版本（模拟旧版本）
await db.execute('PRAGMA user_version = 9');

// 2. 执行迁移
final result = await MigrationService.to.autoMigrate();

// 3. 验证结果
print('迁移结果: ${result.success}');
print('新版本: v${result.toVersion}');
```

### Q4: 跨版本升级会丢失数据吗？

不会。迁移系统会：
1. 创建数据库快照
2. 按顺序执行每个版本的升级脚本
3. 如果失败，自动回滚到快照状态
4. 所有升级脚本都是增量式的，不会删除现有数据

### Q5: 如何添加新的迁移版本？

1. 在 `upgrade.sql` 中添加新的 VERSION 块
2. 编写升级 SQL
3. 设置 `PRAGMA user_version = 新版本号`
4. 在 `downgrade.sql` 中添加对应的降级脚本
5. 更新数据模型代码
6. 编写测试用例
7. 测试升级和降级流程

---

## 附录

### 相关文件

- `lib/service/migration_service.dart` - 迁移服务实现
- `lib/service/backup_service.dart` - 备份服务实现
- `lib/service/sqlite.dart` - 数据库服务
- `assets/migrations/upgrade.sql` - 升级脚本模板
- `assets/migrations/downgrade.sql` - 降级脚本模板
- `assets/example.db` - 基线数据库文件 (v9)

### 参考资料

- [SQLite ALTER TABLE](https://www.sqlite.org/lang_altertable.html)
- [SQLite PRAGMA](https://www.sqlite.org/pragma.html)
- [Sqflite Package](https://pub.dev/packages/sqflite)
- [SQLite Version 3 Features](https://www.sqlite.org/releaselog/3_35_0.html) - 支持 DROP COLUMN

### 更新日志

| 日期 | 版本 | 说明 |
|------|------|------|
| 2024-12 | v9 | 基线版本，当前环境使用 |
| 未来 | v10+ | 待规划，按需添加 |
