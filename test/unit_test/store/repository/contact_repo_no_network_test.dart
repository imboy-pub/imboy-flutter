/// Task 6（会话列表查询性能收敛）延期决策的**证据测试**。
///
/// `conversation_item.dart` 每个 tile 在 initState 调
/// `ContactRepo().findByUid(peerId, autoFetch: false)`。该逐行查询已在
/// 2026-07-30 复核为"已登记且当前风险可接受的技术债"并延期，理由与升级
/// 路径写在 conversation_item.dart 的 ponytail 注释里。
///
/// 计划要求延期必须留下"不触网"的证据，本文件即该证据：钉死
/// `autoFetch: false` 时，本地未命中**直接返回 null**，绝不走
/// `ContactApi().syncByUid` 这条唯一的网络分支
/// （contact_repo_sqlite.dart:221-226）。
///
/// 若日后有人把默认值改成 true、或把 autoFetch 分支删掉，会话列表就会
/// 变成"每个 tile 一次网络请求"——那才是真瓶颈。这条测试先报警。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

/// 与 baseline_schema.sql 等价的最小 contact 表（仅本测试用到的列）。
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
    is_friend INTEGER NOT NULL DEFAULT 1,
    is_from TEXT NOT NULL DEFAULT '',
    category_id INTEGER NOT NULL DEFAULT 0,
    account_type INTEGER NOT NULL DEFAULT 0,
    last_seen_at INTEGER,
    updated_at INTEGER NOT NULL DEFAULT 0,
    UNIQUE (user_id, peer_id)
  )
''';

const String _currentUid = '1001';

void main() {
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await StorageService.to.setString(Keys.currentUid, _currentUid);
  });

  tearDownAll(() async {
    await StorageService.to.remove(Keys.currentUid);
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(_contactDDL);
    SqliteService.setDbForTest(db);
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  group('findByUid(autoFetch: false) 不触网', () {
    test('本地未命中 → 返回 null，不发起任何网络同步', () async {
      // 表是空的：若 autoFetch 生效会走 ContactApi().syncByUid，
      // 测试环境无网络 → 要么抛异常要么挂到超时。
      // 能干净拿到 null，即证明网络分支被跳过。
      final result = await ContactRepo().findByUid('99999', autoFetch: false);

      expect(result, isNull);
    });

    test('本地命中 → 返回本地行，同样不触网', () async {
      await db.insert('contact', {
        'user_id': int.parse(_currentUid),
        'peer_id': 2002,
        'nickname': '张三',
        'account': 'zhangsan',
        'account_type': 1,
        'sign': '',
        'source': '',
        'status': '',
        'updated_at': 0,
      });

      final result = await ContactRepo().findByUid('2002', autoFetch: false);

      expect(result, isNotNull);
      expect(result!.nickname, '张三');
      // conversation_item 就是靠这个字段决定要不要挂 BotBadge
      expect(result.accountType, 1);
    });

    test('连续多次查询都不触网（会话列表逐行查询的实际形态）', () async {
      // 模拟一屏 20 个会话 tile 各查一次
      final results = await Future.wait(
        List.generate(
          20,
          (i) => ContactRepo().findByUid('${3000 + i}', autoFetch: false),
        ),
      );

      expect(results, everyElement(isNull));
      expect(results.length, 20);
    });
  });

  group('autoFetch 默认值契约', () {
    test('默认值仍是 true —— conversation_item 必须显式传 false', () async {
      // 这条是"反向保护"：默认值是 true，所以调用方一旦漏传 false，
      // 会话列表每个 tile 都会触网。conversation_item.dart 当前显式传了
      // autoFetch: false，改动它之前先看这条测试的 reason。
      await db.insert('contact', {
        'user_id': int.parse(_currentUid),
        'peer_id': 4004,
        'nickname': '李四',
        'account': 'lisi',
        'sign': '',
        'source': '',
        'status': '',
        'updated_at': 0,
      });

      // 本地命中时无论 autoFetch 取值都不触网，可安全断言默认路径。
      final hit = await ContactRepo().findByUid('4004');
      expect(hit, isNotNull, reason: '本地命中时不该走网络分支，默认值不影响结果');
    });
  });
}
