/// Schema migration v24 → v25（A2-b 离线 decrypt-on-read 承载点）：
/// `msg_c2c` 表新增 `sender_did` 列。
///
/// 服务端在 WebSocket 认证态注入信封顶层，客户端不可伪造；PFv3 接收侧
/// context binding 第 6 项（ADR 15 §3.3）拿它与受认证的
/// `protected_header.sender_did` 硬比对。实时路径在内存帧里就有，
/// 离线路径**必须持久化**，否则重连拉取的 v3 消息永久判
/// `context_mismatch_sender_did` 不可读。
///
/// SQL duplicated from assets/migrations/upgrade.sql per the project
/// pattern (same trade-off as the v17/v18/v24 tests).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/store/model/message_columns.dart';
import 'package:imboy/store/model/message_model.dart';

/// V24 时点的 msg_c2c 表（与 baseline_schema.sql 的 v24 形状一致）。
const String _v24MsgC2cDDL = '''
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

/// V25 upgrade — must match assets/migrations/upgrade.sql "VERSION: 25" block.
const String _v25Upgrade = 'ALTER TABLE msg_c2c ADD COLUMN sender_did TEXT';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('v24 → v25 msg_c2c.sender_did migration', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath);
      await db.execute(_v24MsgC2cDDL);
      // v24 时点已落库的旧行：迁移后该列必须是 NULL，不得被回填成空串
      await db.insert('msg_c2c', {
        'id': 'legacy-row-1',
        'type': 'C2C',
        'from_id': 100,
        'to_id': 200,
        'payload': '',
        'msg_type': 'text',
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('迁移后新增 sender_did 列，且旧行保持 NULL（不得回填空串）', () async {
      await db.execute(_v25Upgrade);

      final columns = await db.rawQuery('PRAGMA table_info(msg_c2c)');
      final names = columns.map((c) => c['name']).toList();
      expect(names, contains('sender_did'));

      final rows = await db.query('msg_c2c', where: "id = 'legacy-row-1'");
      expect(
        rows.single['sender_did'],
        isNull,
        reason:
            '空串会让 context binding 把「服务端没提供」误判成「设备 ID 是空串」，'
            '两者失败语义不同；旧行必须保持 NULL 以如实失配（fail-closed）',
      );
    });

    // 正向可用性：新行写得进、读得回、并且能经 MessageModel 还原成
    // `toTypeMessage()` 组装入站帧所需的 `senderDid`。
    test('迁移后新行可写入并经 MessageModel 还原 senderDid', () async {
      await db.execute(_v25Upgrade);

      await db.insert('msg_c2c', {
        'id': 'v3-row-1',
        'type': 'C2C',
        'from_id': 100,
        'to_id': 200,
        'payload': '',
        'msg_type': 'text',
        'e2ee': '{"meta_version":3}',
        MessageColumns.senderDid: 'dev-sender-01',
      });

      final rows = await db.query('msg_c2c', where: "id = 'v3-row-1'");
      expect(rows.single[MessageColumns.senderDid], equals('dev-sender-01'));

      final model = MessageModel.fromJson(
        Map<String, dynamic>.from(rows.single),
      );
      expect(
        model.senderDid,
        equals('dev-sender-01'),
        reason: 'mapper 的 _toInboundFrame() 从这里取 context binding #6 的值',
      );

      // 回写对称：toJson 必须把它带回去，否则更新路径会静默抹掉该列
      expect(model.toJson()[MessageColumns.senderDid], equals('dev-sender-01'));
    });

    // 对照组：旧行经 MessageModel 还原后 senderDid 必须是 null，
    // 不得被序列化成空串（否则 fail-closed 分类会被污染）。
    test('对照组：旧行还原后 senderDid 为 null 且 toJson 不写该键', () async {
      await db.execute(_v25Upgrade);

      final rows = await db.query('msg_c2c', where: "id = 'legacy-row-1'");
      final model = MessageModel.fromJson(
        Map<String, dynamic>.from(rows.single),
      );
      expect(model.senderDid, isNull);
      expect(model.toJson().containsKey(MessageColumns.senderDid), isFalse);
    });
  });
}
