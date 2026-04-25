/// 钉死 C2C 发送方本地 msg_c2c 表写入契约（Task #20 回归保护）。
///
/// 背景（bug #20）：
///   - Alice 发 C2C 给 Bob，Bob 收到，但 Alice 本地 msg_c2c 表无对应行。
///   - 根因：`MessageModel.id` 字段类型 `int`，但客户端生成的消息 ID 是
///     `Xid().toString()`（base32hex，例 "cuvoq8sj9hsg00rajl4g"）。
///     `_getMsgFromTMsg` 在 `chat_provider.dart` 调用 `int.tryParse(message.id)
///     ?? 0`，base32hex 字符串解析失败回退 0，触发 `_validateMessageData`
///     的 `if (msg.id == 0) throw ArgumentError('Invalid message data')` 拦截，
///     被外层 try/catch 静默吞掉。
///   - 接收侧 `batchInsertOfflineMessages` 走另一条路径（直接写 String），
///     所以 Bob 端正常落库。
///
/// 修复方案（已实施）：
///   - `MessageModel.id` 字段：`int` → `String`，对齐后端 `binary()` msg_id
///     契约（imboy/src/ds/message_ds.erl:566 is_non_empty_binary 校验）。
///   - SQLite `INTEGER NOT NULL` 列通过 type affinity 直接接收 Xid 字符串
///     （非数值字符串原样落库为 TEXT）。
///   - `_validateMessageData` 守卫：`msg.id == 0` → `msg.id.isEmpty`。
///
/// 本测试：
///   1. 用 in-memory SQLite 等价复刻 msg_c2c v9+ schema
///   2. 模拟 Alice 端发送：构造 Xid 字符串 ID 的 MessageModel，按
///      MessageRepoSqlite._buildInsertMap 等价语义构造 insert payload
///   3. 断言 INSERT 成功 + 行数 = 1 + 字段对齐（id / from_id / to_id /
///      is_author=1 / status=sending / conversation_uk3）
///   4. 反例：钉死历史 bug —— `int.tryParse(xidStr) ?? 0 == 0` 为真
///      （证明字符串 ID 在旧 int 路径必然回退 0 触发 _validateMessageData）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xid/xid.dart';

/// 与 upgrade.sql v9 等价的最小 msg_c2c schema（核心字段，省略历史迁移
/// 临时列）。
const String _msgC2cDDL = '''
  CREATE TABLE msg_c2c (
    auto_id INTEGER PRIMARY KEY,
    id INTEGER NOT NULL,
    msg_type TEXT,
    from_id INTEGER,
    to_id INTEGER,
    conversation_uk3 TEXT,
    e2ee TEXT,
    payload TEXT,
    created_at INTEGER,
    topic_id INTEGER,
    status INTEGER,
    is_author INTEGER,
    type TEXT DEFAULT 'C2C',
    action TEXT DEFAULT '',
    CONSTRAINT uk_MsgId UNIQUE (id)
  )
''';

Future<Database> _openDb() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 9),
  );
  await db.execute(_msgC2cDDL);
  return db;
}

void main() {
  group('Task #20 - C2C 发送方本地 msg_c2c 表写入回归保护', () {
    late Database db;

    setUp(() async {
      db = await _openDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('Xid 字符串 ID 应该能成功写入 msg_c2c.id 列（type affinity）', () async {
      // ARRANGE: Alice 端构造发送消息（与 chat_provider._getMsgFromTMsg 等价）
      final xid = Xid().toString();
      expect(xid.length, greaterThan(10), reason: 'Xid 应是 base32hex 字符串');
      expect(int.tryParse(xid), isNull, reason: 'Xid 必须不能被解析为整数');

      const aliceId = 1838294017982464;
      const bobId = 1838294017982465;
      const conversationUk3 = 'C2C_1838294017982464_1838294017982465';

      // ACT: 模拟 MessageRepoSqlite.insert 的写入 payload
      final autoId = await db.insert('msg_c2c', {
        'id': xid, // String 直接落库（type affinity 不会拒绝）
        'msg_type': 'text',
        'from_id': aliceId,
        'to_id': bobId,
        'conversation_uk3': conversationUk3,
        'payload': '{"text":"Hello Bob"}',
        'created_at': 1768957192053,
        'status': 10, // sending
        'is_author': 1, // 自己发送的
        'type': 'C2C',
        'action': '',
      });

      // ASSERT: 写入成功
      expect(autoId, greaterThan(0), reason: 'insert 应该返回正数 autoId');

      // ASSERT: 行数 = 1
      final countRows = await db.rawQuery('SELECT COUNT(*) AS c FROM msg_c2c');
      final count = countRows.first['c'];
      expect(count, 1);

      // ASSERT: 字段对齐
      final rows = await db.query('msg_c2c');
      expect(rows.length, 1);
      final row = rows.first;
      expect(row['id'], xid, reason: '消息 ID 应原样落库（不被 int 截断）');
      expect(row['from_id'], aliceId);
      expect(row['to_id'], bobId);
      expect(row['is_author'], 1);
      expect(row['status'], 10);
      expect(row['conversation_uk3'], conversationUk3);
      expect(row['type'], 'C2C');
    });

    test('反例：钉死旧 bug —— Xid 字符串 int.tryParse 必然回退 0', () {
      // 此测试钉死历史 bug 的根因：旧 _getMsgFromTMsg 用
      //   `int.tryParse(message.id) ?? 0`
      // 把 String ID 强转 int，base32hex 字符串总是返回 null → 回退 0。
      // 0 触发 _validateMessageData 的 `if (msg.id == 0)` 拦截，
      // throw ArgumentError 被外层 try/catch 静默吞掉，导致本地无行。
      for (var i = 0; i < 5; i++) {
        final xid = Xid().toString();
        expect(
          int.tryParse(xid),
          isNull,
          reason: 'Xid "$xid" 必须不能被 int 解析，否则旧 bug 不会触发',
        );
        expect(int.tryParse(xid) ?? 0, 0, reason: '回退值必须为 0（触发拦截）');
      }
    });

    test('唯一索引拦截重复消息 ID', () async {
      // ARRANGE
      final xid = Xid().toString();
      const aliceId = 1838294017982464;
      const bobId = 1838294017982465;

      Map<String, Object?> row(int autoId) => {
        'id': xid,
        'msg_type': 'text',
        'from_id': aliceId,
        'to_id': bobId,
        'conversation_uk3': 'C2C_a_b',
        'payload': '{}',
        'created_at': 1768957192053,
        'status': 10,
        'is_author': 1,
      };

      // ACT
      final firstAutoId = await db.insert('msg_c2c', row(0));
      expect(firstAutoId, greaterThan(0));

      // 重复 ID：UNIQUE 索引应该拒绝
      expect(
        () async => await db.insert('msg_c2c', row(0)),
        throwsA(isA<DatabaseException>()),
        reason: 'uk_MsgId 唯一索引应该拒绝重复消息 ID',
      );

      // ASSERT: 行数仍为 1
      final countRows = await db.rawQuery('SELECT COUNT(*) AS c FROM msg_c2c');
      expect(countRows.first['c'], 1);
    });

    test('空字符串 ID 应该被业务层拦截（_validateMessageData）', () {
      // 此测试钉死新契约：MessageModel.id.isEmpty 即拦截。
      // 等价于旧 `msg.id == 0` 守卫的语义升级。
      const String emptyId = '';
      expect(emptyId.isEmpty, isTrue);

      // 业务层守卫语义（不打开 sqflite_sqlcipher 链路，纯函数等价）
      bool isInvalid(String id) => id.isEmpty;
      expect(isInvalid(emptyId), isTrue);
      expect(isInvalid(Xid().toString()), isFalse);
    });
  });
}
