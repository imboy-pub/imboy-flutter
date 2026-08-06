/// 问题 1 RED 测试：contact 表缺少 last_seen_at 列，导致详情页永远显示"从未上线"。
///
/// 根因（已通过一手代码核实）：
///   - baseline_schema.sql / embedded_schema_scripts.dart 的 contact 表 DDL
///     没有 last_seen_at 列（grep 确认为空）。
///   - ContactRepo.defaultColumns 不含 last_seen_at（contact_repo_sqlite.dart:39-55）。
///   - ContactRepo.insert / update 的写入 map 不含 last_seen_at。
///   - 后端 /api/v1/friend/list 和 /api/v1/user/show 确实返回 last_seen_at
///     （见 contact_repo_listfriend_persist_test._realFriendJson 有该字段；
///      user_ds.batch_online_state 也注入该字段）。
///   - 详情页 people_info_provider.initData 读 ct.lastSeenAt，但因落库丢弃
///     → 永远为 0 → UserOnlineTimeHelper 走 lastSeenTimestamp==0 分支
///     → 显示"从未上线"（user_online_time_helper.dart:63-68）。
///
/// 本套件钉死：
///   1. contact 表 DDL 必须含 last_seen_at 列（当前 baseline 缺失 = RED）。
///   2. ContactRepo.defaultColumns 必须包含 last_seen_at（当前缺失 = RED）。
///   3. insert 写入 map 必须含 last_seen_at（当前缺失 = RED）。
///   4. 端到端：含 last_seen_at 的 payload 落库后能被查回（当前失败 = RED）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/embedded_schema_scripts.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 从 embedded_schema_scripts 提取 contact 表 DDL，验证生产 schema 真实形态。
String _extractContactDDL() {
  // kBaselineSchemaSql 是完整的多表 schema，切出 contact 表段
  final src = kBaselineSchemaSql;
  final start = src.indexOf('CREATE TABLE contact');
  expect(
    start,
    greaterThanOrEqualTo(0),
    reason: 'baseline schema 必须含 contact 表',
  );
  // contact 表定义到第一个分号后的换行
  final end = src.indexOf(');', start);
  expect(end, greaterThan(start), reason: 'contact DDL 必须完整闭合');
  return src.substring(start, end + 2);
}

void main() {
  group('问题1 - contact 表 last_seen_at 列', () {
    test('RED-1: contact 表 DDL 必须含 last_seen_at 列', () {
      final ddl = _extractContactDDL();
      // 钉死生产 schema 真实包含该列
      expect(
        ddl.contains('last_seen_at'),
        isTrue,
        reason:
            'baseline_schema.sql 的 contact 表当前没有 last_seen_at 列。'
            '后端 friend/list、user/show 都返回该字段，但落库被 NOT NULL/列缺失丢弃，'
            '详情页 lastSeenAt 永远为 0 → UserOnlineTimeHelper 显示"从未上线"。',
      );
    });

    test('RED-2: ContactRepo.defaultColumns 必须含 last_seen_at', () {
      // 钉死查询投影包含该列，否则即使列存在也查不回来
      expect(
        ContactRepo.defaultColumns.contains('last_seen_at'),
        isTrue,
        reason:
            'ContactRepo.defaultColumns 当前不含 last_seen_at，'
            'findByUid/findFriend 的 columns 投影会丢掉该字段。',
      );
    });

    test('RED-3: ContactRepo 必须有 last_seen_at 列名常量', () {
      // 钉死存在静态列名常量，供 insert/update/查询统一引用
      expect(
        ContactRepo.lastSeenAt,
        'last_seen_at',
        reason: 'ContactRepo 必须定义 static String lastSeenAt 列名常量',
      );
    });

    test('RED-4: 端到端 - 含 last_seen_at 的 payload 落库后能查回', () async {
      // 用 in-memory ffi + 当前生产 DDL 验证完整链路
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );
      try {
        // 用当前生产的 contact 表 DDL 建表
        await db.execute(_extractContactDDL());

        // 如果 DDL 真的没有 last_seen_at 列，这里 insert 会抛错
        // 钉死：修复后该插入应成功
        final now = DateTime.now().millisecondsSinceEpoch;
        try {
          await db.insert('contact', {
            'user_id': '999',
            'peer_id': 1000000056,
            'nickname': 'Bob',
            'avatar': '',
            'account': '60002',
            'status': 'online',
            'sign': '',
            'source': 'user_search',
            'tag': '',
            'region': '',
            'remark': '',
            'gender': 0,
            'updated_at': now,
            'is_friend': 1,
            'is_from': 0,
            'category_id': 0,
            'last_seen_at': now, // ★ 关键字段
            // account_type 列在 v24 才加，baseline 已含则这里也会成功
          });
        } catch (e) {
          fail('插入含 last_seen_at 的记录失败，说明 contact 表没有该列: $e');
        }

        // 查回必须能拿到 last_seen_at
        final rows = await db.query(
          'contact',
          columns: ['peer_id', 'last_seen_at', 'status'],
          where: 'user_id = ? AND peer_id = ?',
          whereArgs: ['999', 1000000056],
        );
        expect(rows.length, 1);
        expect(
          rows.first['last_seen_at'],
          now,
          reason: '落库的 last_seen_at 必须能完整查回，供详情页显示最后上线时间',
        );
      } finally {
        await db.close();
      }
    });
  });
}
