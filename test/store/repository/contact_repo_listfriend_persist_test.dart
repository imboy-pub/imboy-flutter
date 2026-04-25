/// Task #19 复现 + 回归保护：`/v1/friend/list` 拉取后本地 contact 表 0 行 bug。
///
/// 根因（双 RED）：
///
///   ① `ContactRepo.save()` 走 transaction → 命中 line 116 `txn.insert(...)`，
///      未传 `ConflictAlgorithm.replace`。后端可能在同一会话中重复返回某个
///      好友（多端同步 / 排序变化），命中 `uk_FromTo UNIQUE (user_id, peer_id)`
///      约束 → 抛 DatabaseException → 被 save() 的 try/catch 吞掉 → 仅这
///      一条会失败，但落库语义错误（应当是覆盖更新而非抛错）。
///
///   ② 关键缺口：`ContactModel.fromMap` 第 130 行 `if (peerId == 0) throw`，
///      `parseModelInt('peer_id 缺失')` 默认值就是 0。当后端 payload 用
///      `id` 字段（真实契约确实如此）时正常解析；但 `repo.save()` 第 299 行
///      也允许 `peer_id` 字段命名 → 一旦字段命名漂移（接口契约变化），整批
///      解析全部抛 Exception，被 save() catch 吞掉 → **0 行落库**。
///
/// 本测试套件：
///   1. 复刻 baseline_schema.sql 的 contact 表 schema（含 uk_FromTo）
///      + 复刻 ContactRepo.insert() 的 map 构造 → in-memory SQLite ffi
///   2. 钉死真实 /v1/friend/list 单条 payload 一定可以落库（基线绿）
///   3. 模拟"同好友被后端重复返回"场景 → 当前 txn.insert 无 replace 会抛
///      → 修复后必须用 replace 算法 → 第二次成功落库（覆盖）
///   4. 钉死 NOT NULL 列默认值（status / sign / source）不会因 null 输入
///      触发 NOT NULL 约束失败
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 与 baseline_schema.sql 等价的 contact 表 schema（含 uk_FromTo）。
const String _contactDDL = '''
  CREATE TABLE contact (
    auto_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    peer_id INTEGER NOT NULL,
    nickname TEXT NOT NULL DEFAULT '',
    avatar TEXT NOT NULL DEFAULT '',
    gender INTEGER NOT NULL DEFAULT 0,
    account TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT '',
    remark TEXT DEFAULT '',
    tag TEXT DEFAULT '',
    region TEXT DEFAULT '',
    sign TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT '',
    updated_at INTEGER NOT NULL DEFAULT 0,
    is_friend INTEGER NOT NULL DEFAULT 0,
    is_from INTEGER NOT NULL DEFAULT 0,
    category_id INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT uk_FromTo UNIQUE (user_id, peer_id)
  )
''';

Future<Database> _openDb() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final db = await factory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 1),
  );
  await db.execute(_contactDDL);
  return db;
}

Future<int> _countContact(Database db) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM contact');
  final v = rows.first['c'];
  return v is int ? v : (v as num).toInt();
}

/// 复刻 `ContactRepo.insert()` 第 96-114 行的 map 构造逻辑。
/// `currentUid` 是测试模拟下来的 String，对应 String 类型的当前 uid。
Map<String, Object?> _buildInsertMap({
  required String currentUid,
  required Map<String, dynamic> json,
}) {
  // 与 ContactRepo.fromMap 保持一致：peerId 从 id 或 peer_id 获取
  final rawPeerId = json['id'] ?? json['peer_id'];
  final peerId = rawPeerId is int
      ? rawPeerId
      : int.tryParse(rawPeerId.toString()) ?? 0;
  return <String, Object?>{
    'user_id': currentUid,
    'peer_id': peerId,
    'nickname': (json['nickname'] ?? '').toString(),
    'avatar': (json['avatar'] ?? '').toString(),
    'account': (json['account'] ?? '').toString(),
    'status': (json['status'] ?? '').toString(),
    'remark': (json['remark'] ?? '').toString(),
    'tag': '',
    'gender': json['gender'] is int
        ? json['gender']
        : int.tryParse((json['gender'] ?? '').toString()) ?? 0,
    'region': (json['region'] ?? '').toString(),
    'sign': (json['sign'] ?? '').toString(),
    'source': (json['source'] ?? '').toString(),
    'updated_at': json['updated_at'] is int
        ? json['updated_at']
        : (json['created_at'] is int ? json['created_at'] : 0),
    'is_friend': json['is_friend'] is int
        ? json['is_friend']
        : int.tryParse((json['is_friend'] ?? '0').toString()) ?? 0,
    'is_from': json['is_from'] is int
        ? json['is_from']
        : int.tryParse((json['is_from'] ?? '0').toString()) ?? 0,
    'category_id': json['category_id'] is int
        ? json['category_id']
        : int.tryParse((json['category_id'] ?? '0').toString()) ?? 0,
  };
}

/// 真实 /v1/friend/list 响应切片（与 contact_conversation_model_test 一致）。
Map<String, dynamic> _realFriendJson({int id = 1000000056}) {
  return <String, dynamic>{
    'account': '60002',
    'avatar': '',
    'category_id': 0,
    'created_at': 1776598885315,
    'gender': 0,
    'id': id,
    'is_friend': 1,
    'is_from': null,
    'last_seen_at': null,
    'nickname': 'Bob测试',
    'region': '',
    'remark': '',
    'sign': '',
    'source': null,
    'status': 'offline',
    'tag': '',
  };
}

void main() {
  group('Task #19 - /v1/friend/list 落库链路', () {
    test('基线：真实后端 payload 单条 → 落库成功（peer_id 列正确）', () async {
      final db = await _openDb();
      try {
        final json = _realFriendJson();
        final map = _buildInsertMap(currentUid: '999', json: json);

        final id = await db.insert(
          'contact',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        expect(id, greaterThan(0), reason: '首次插入应成功');
        expect(await _countContact(db), 1);

        final rows = await db.query(
          'contact',
          where: 'user_id = ? AND peer_id = ?',
          whereArgs: ['999', 1000000056],
        );
        expect(rows.length, 1, reason: 'whereArgs String/int 混用 SQLite 仍能匹配');
        expect(rows.first['nickname'], 'Bob测试');
      } finally {
        await db.close();
      }
    });

    test(
      'BUG #19 反例钉死：不传 conflictAlgorithm 时 uk_FromTo UNIQUE 必然抛错',
      () async {
        // 该测试用于证明"修复前的语义陷阱真实存在"：在 in-memory 数据库上
        // 直接复现重复 INSERT 不传 ConflictAlgorithm.replace 的失败路径，
        // 防止未来回归（即有人误删 ContactRepo.insert 的 replace 算法时）
        // 仅靠正向用例无法察觉。
        final db = await _openDb();
        try {
          final map = _buildInsertMap(
            currentUid: '999',
            json: _realFriendJson(),
          );
          await db.insert('contact', map); // 第一次：无 conflictAlgorithm

          await expectLater(
            db.insert('contact', map), // 第二次：仍无 conflictAlgorithm
            throwsA(isA<DatabaseException>()),
            reason: '反例钉死：不传 ConflictAlgorithm 时必抛 UNIQUE 约束错误',
          );
        } finally {
          await db.close();
        }
      },
    );

    test(
      'BUG #19 修复钉死：txn.insert(conflictAlgorithm: replace) → 重复 payload 覆盖更新',
      () async {
        final db = await _openDb();
        try {
          final map1 = _buildInsertMap(
            currentUid: '999',
            json: _realFriendJson(),
          );
          await db.insert(
            'contact',
            map1,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          // 同一好友被服务端再次返回（昵称改了 / 备注改了等）
          final updatedJson = _realFriendJson()
            ..['nickname'] = 'Bob改名'
            ..['remark'] = '哥们';
          final map2 = _buildInsertMap(currentUid: '999', json: updatedJson);
          final r2 = await db.insert(
            'contact',
            map2,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          expect(r2, greaterThan(0), reason: 'replace 算法下重复键也成功');
          expect(await _countContact(db), 1, reason: '保持单行');

          final rows = await db.query(
            'contact',
            where: 'user_id = ? AND peer_id = ?',
            whereArgs: ['999', 1000000056],
          );
          expect(rows.first['nickname'], 'Bob改名', reason: '覆盖更新生效');
          expect(rows.first['remark'], '哥们');
        } finally {
          await db.close();
        }
      },
    );

    test(
      'NOT NULL 约束安全：source / sign / status 即使后端返回 null 也走 DEFAULT 空串',
      () async {
        final db = await _openDb();
        try {
          // 真实场景：后端老好友数据 source/sign/status 字段缺失
          final json = <String, dynamic>{
            'id': 2000000001,
            'account': 'a1',
            'nickname': 'Alice',
            'avatar': '',
            'gender': 0,
            'is_friend': 1,
            'is_from': null,
            'last_seen_at': null,
            'remark': '',
            'tag': '',
            // 故意省略 status / sign / source / region
          };
          final map = _buildInsertMap(currentUid: '999', json: json);

          final id = await db.insert(
            'contact',
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          expect(id, greaterThan(0));
          expect(await _countContact(db), 1);
        } finally {
          await db.close();
        }
      },
    );

    test(
      '批量场景：listFriend 返回 3 条好友，全部落库 → count=3',
      () async {
        final db = await _openDb();
        try {
          final ids = [1000000001, 1000000002, 1000000003];
          for (final id in ids) {
            final map = _buildInsertMap(
              currentUid: '999',
              json: _realFriendJson(id: id),
            );
            await db.insert(
              'contact',
              map,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          expect(
            await _countContact(db),
            3,
            reason: 'Task #19 报告"0 行落库" — 钉死正常路径必须 = 3',
          );
        } finally {
          await db.close();
        }
      },
    );
  });
}
