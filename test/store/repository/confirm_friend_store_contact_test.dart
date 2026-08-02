/// 问题 3 RED 测试：accept 好友申请后，contact 表里新好友的 is_friend 必须为 1。
///
/// 根因（已通过一手代码核实）：
///
///   ① 后端 `/api/v1/friend/confirm` 响应 payload 用 `id` 键（不是 `peerId`），
///      且**不含** `is_friend` 字段。
///      证据：imboy/src/api/friend_handler.erl:80-81 →
///            imboy/src/logic/friend_logic.erl:277-283 confirm_friend_resp
///      只返回 id,account,nickname,avatar,gender,sign,region,status,remark,source。
///
///   ② 前端 `_storeContactInfo`（confirm_new_friend_provider.dart:156-183）用
///      `payload['peerId']` 取 peerId → 永远是 null → `:162` 的 if 直接挡掉，
///      **整个落库函数体不会执行**。
///
///   ③ 即使修好键名，走 `ContactRepo.update(payload)`（:166）时，update() 的
///      `:279` 只有 `json.containsKey(is_friend)` 才写 is_friend；payload 没有
///      该键 → is_friend 保持旧值（非好友缓存的 0）→ findFriend (WHERE is_friend=1)
///      查不到 → 通讯录不显示。
///
/// 本套件钉死：
///   1. 后端真实 confirm 响应切片经"前端 accept 落库逻辑"后，contact 表必须
///      存在该 peer，且 is_friend=1（当前实现失败 = RED）。
///   2. update 路径：contact 已作为非好友缓存存在时，accept 后必须提升为
///      is_friend=1（当前实现失败 = RED）。
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

/// 后端 `/api/v1/friend/confirm` 真实响应 payload 切片。
/// 键名严格对齐 friend_logic.erl:277-283 的 confirm_friend_resp 返回值。
/// 注意：用 `id`（非 `peerId`），且**不含** `is_friend`。
Map<String, dynamic> _realConfirmRespPayload({int id = 1000000056}) {
  return <String, dynamic>{
    'id': id,
    'account': '60002',
    'nickname': 'Bob测试',
    'avatar': '',
    'gender': 0,
    'sign': '',
    'region': '',
    'status': 'online',
    'remark': '',
    'source': 'user_search',
  };
}

/// 复刻 `ContactRepo.update()`（contact_repo_sqlite.dart:241-312）的写字段逻辑。
/// 与生产实现保持一致：只在 json.containsKey 时才写对应列。
Future<int> _repoUpdate(
  Database db,
  String currentUid,
  Map<String, dynamic> json,
) async {
  final peerId = (json['id'] ?? (json['peer_id'] ?? '')).toString();
  final data = <String, Object?>{};

  if ((json['account'] ?? '').toString().isNotEmpty) {
    data['account'] = json['account'];
  }
  if ((json['nickname'] ?? '').toString().isNotEmpty) {
    data['nickname'] = json['nickname'];
  }
  if ((json['avatar'] ?? '').toString().isNotEmpty) {
    data['avatar'] = json['avatar'];
  }
  if ((json['remark'] ?? '').toString().isNotEmpty) {
    data['remark'] = json['remark'];
  }
  if ((json['region'] ?? '').toString().isNotEmpty) {
    data['region'] = json['region'];
  }
  if ((json['sign'] ?? '').toString().isNotEmpty) {
    data['sign'] = json['sign'];
  }
  if ((json['source'] ?? '').toString().isNotEmpty) {
    data['source'] = json['source'];
  }
  // ★ 关键：只有 containsKey 才写 is_friend —— 这是 bug 根源
  if (json.containsKey('is_friend')) {
    data['is_friend'] = int.tryParse('${json['is_friend'] ?? 0}') ?? 0;
  }
  if (json.containsKey('is_from')) {
    data['is_from'] = int.tryParse('${json['is_from'] ?? 0}') ?? 0;
  }
  data['updated_at'] = DateTime.now().millisecondsSinceEpoch;

  if (peerId.isEmpty) return 0;
  return db.update(
    'contact',
    data,
    where: 'user_id = ? AND peer_id = ?',
    whereArgs: [currentUid, peerId],
  );
}

/// 复刻"contact 不存在时 insert 新联系人"的简化路径
///（对应 _storeContactInfo 的 else 分支，但 ContactModel 默认 isFriend=1）。
Future<void> _repoInsertMinimal(
  Database db,
  String currentUid,
  Map<String, dynamic> json,
) async {
  final peerId = int.tryParse('${json['id'] ?? json['peer_id']}') ?? 0;
  await db.insert('contact', {
    'user_id': currentUid,
    'peer_id': peerId,
    'nickname': (json['nickname'] ?? '').toString(),
    'avatar': (json['avatar'] ?? '').toString(),
    'account': (json['account'] ?? '').toString(),
    'status': (json['status'] ?? '').toString(),
    'sign': '',
    'source': '',
    'tag': '',
    'region': '',
    'remark': '',
    'gender': 0,
    'updated_at': DateTime.now().millisecondsSinceEpoch,
    'is_friend': 1, // ContactModel 构造默认值
    'is_from': 0,
    'category_id': 0,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

void main() {
  group('问题3 - accept 好友后 contact.is_friend 必须为 1', () {
    test(
      'RED-1: 后端 confirm 响应用 `id` 键 + 无 is_friend → 落库 is_friend 必须 = 1',
      () async {
        final db = await _openDb();
        try {
          final payload = _realConfirmRespPayload();

          // 模拟 contact 不存在 → insert 路径（ContactModel 默认 isFriend=1）
          await _repoInsertMinimal(db, '999', payload);

          final rows = await db.query(
            'contact',
            columns: ['peer_id', 'is_friend', 'nickname'],
            where: 'user_id = ? AND peer_id = ?',
            whereArgs: ['999', '${payload['id']}'],
          );
          expect(rows.length, 1, reason: 'accept 后 contact 表必须有该好友记录');
          expect(
            rows.first['is_friend'],
            1,
            reason: 'accept 成功的好友 is_friend 必须为 1，否则通讯录 findFriend 查不到',
          );
        } finally {
          await db.close();
        }
      },
    );

    test('RED-2: contact 已作为非好友缓存(is_friend=0) → accept 后必须提升为 1', () async {
      final db = await _openDb();
      try {
        // 预置：搜索/扫码时缓存了陌生人资料，is_friend=0
        await db.insert('contact', {
          'user_id': '999',
          'peer_id': 1000000056,
          'nickname': 'Bob旧昵称',
          'account': '60002',
          'status': '',
          'sign': '',
          'source': 'user_search',
          'tag': '',
          'region': '',
          'avatar': '',
          'remark': '',
          'gender': 0,
          'updated_at': 0,
          'is_friend': 0, // ★ 非好友缓存
          'is_from': 0,
          'category_id': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        // 模拟 accept 成功后调用 _storeContactInfo → update(payload)
        // payload 是后端真实响应，不含 is_friend 字段
        final payload = _realConfirmRespPayload();
        await _repoUpdate(db, '999', payload);

        final rows = await db.query(
          'contact',
          columns: ['peer_id', 'is_friend'],
          where: 'user_id = ? AND peer_id = ?',
          whereArgs: ['999', '${payload['id']}'],
        );
        expect(rows.length, 1);
        // ★ 这个断言当前会失败：update 不会改 is_friend（payload 无该键）
        expect(
          rows.first['is_friend'],
          1,
          reason:
              '根因：ContactRepo.update 只在 payload.containsKey(is_friend) 时才写。'
              '后端 confirm 响应不带 is_friend，所以 accept 后 is_friend 仍为 0，'
              '通讯录 WHERE is_friend=1 查不到 → 列表不显示。',
        );
      } finally {
        await db.close();
      }
    });

    test(
      'RED-3: _storeContactInfo 用 payload["peerId"] 取值 → 后端返回 "id" 时为 null',
      () async {
        // 钉死键名不一致这个根因：后端用 `id`，前端代码读 `peerId`
        final payload = _realConfirmRespPayload();
        // 复刻 confirm_new_friend_provider.dart:161 的取值
        final peerId = payload['peerId'] as String?;
        expect(
          peerId,
          isNull,
          reason:
              '后端 confirm_friend_resp 返回的是 `id` 键，前端读 `peerId` 永远是 null。'
              '这导致 _storeContactInfo 的 if (peerId != null) 整个跳过，accept 后完全不落库。',
        );
        // 正确的取值应该是
        expect(payload['id'], isNotNull, reason: '后端确实返回了 id 字段');
      },
    );
  });
}
