// plan-v2.2 §9 J28.a（旧SQLite/PG合成库 → 升级/重复启动/失败恢复）App 侧
// SQLite 迁移链向量（合成 fixture，无 PII、零网络）。
//
// 覆盖向量（与既有套件互补，不重复）：
//   ① 升级：旧合成库 v33/v34 → v37 一次事务跨全部 v2.2 增量边
//      （v34 user_collect 世代列默认 0、v35 conv_seq/accepted_at 存量 NULL
//       不伪造、v36 消息 ID TEXT 保真、v37 channel scope/workspace_id NULL
//       不推断 personal），既有行数据全程保留；
//   ② 重复启动：升级被进程重启打断（v33→v35 后关库重开续升 v35→v37），
//      终态 migrate(37→37) 重入无副作用（SchemaFingerprint 稳定）；
//   ③ 失败恢复：链中 v36 边注入失败 → 事务整体回滚停回 v35（无 *_new
//      残留表、版本不变、行数据无损），修复后重试升满 v37。
//
// 证据边界：sqflite_common_ffi 本地证据。「manual 默认 false、旧 unread
// 不反推」属服务端 user_setting/manual_pending 偏好域（App 侧向量见
// conversation_manual_pending_test.dart 的 J28.a 命名 case）；本地
// user_collect.generation 默认 0 / conv_seq NULL 属本文件。PG 升级面
// （Backend 迁移 231–234+）为 Backend 域，本文件不构成其证明。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/schema_contract.dart';
import 'package:imboy/service/schema_fingerprint.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

/// 消息 ID 原值（v36 前为 INTEGER，升级后 TEXT；保持十进制逐字符不变）。
const int _seedMsgId = 990000000001;

/// v36 边失败注入：执行到 msg_c2g 重建块（msg_c2c_new 已建）时抛出，
/// 验证同一事务内已完成语句全部回滚。
///
/// 注意必须包装**事务句柄**（txn）而不是外层 Database 连接：
/// sqflite 事务回调执行期间，外层连接上的任何操作都会排队等待事务
/// 结束（"database has been locked"），回调又在等 migrate 完成——
/// 即为死锁，且挂起的 pending transaction 会让测试进程在
/// TimeoutException 之后仍无法退出。
class _FailAtV36Rebuild implements DatabaseExecutor {
  _FailAtV36Rebuild(this.inner);
  final DatabaseExecutor inner;
  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    if (sql.contains('msg_c2g_new')) {
      throw StateError('injected v36 rebuild failure');
    }
    return inner.execute(sql, arguments);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => inner.rawQuery(sql, arguments);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 生产调用契约：onUpgrade/onDowngrade 已在 sqflite 事务内调用 migrate。
/// [wrapTxn] 可在事务回调内包装事务句柄（注入失败等），绝不允许把
/// 外层 Database 连接传给 migrate。
Future<void> _migrate(
  Database db,
  int from,
  int to, [
  DatabaseExecutor Function(DatabaseExecutor txn)? wrapTxn,
]) async {
  await db.transaction((txn) async {
    final result = await MigrationService.to.migrate(
      db: wrapTxn == null ? txn : wrapTxn(txn),
      fromVersion: from,
      toVersion: to,
      isUpgrade: to > from,
    );
    if (!result.success) throw StateError(result.error!);
  });
}

Future<int> _userVersion(Database db) async =>
    (await db.rawQuery('PRAGMA user_version')).single['user_version'] as int;

/// msg_c2c.id 的声明列类型（v35 前 INTEGER；v36 后 TEXT）。
Future<String> _msgIdColumnType(Database db) async {
  final rows = await db.rawQuery('PRAGMA table_info(msg_c2c)');
  for (final row in rows) {
    if (row['name'] == 'id') return (row['type'] ?? '') as String;
  }
  return '';
}

Future<void> _expectIntegrity(Database db) async {
  expect(await db.rawQuery('PRAGMA integrity_check'), [
    {'integrity_check': 'ok'},
  ]);
  expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
}

/// 旧行在 v2.2 增量边上的预期终态（数据保留 + 默认值语义）。
Future<void> _expectV22Preserved(Database db, String seedCollectInfo) async {
  // v34：user_collect 世代元数据默认 0 / 空串（旧行零值化，不丢内容）。
  final collect = (await db.query('user_collect')).single;
  expect(collect['info'], seedCollectInfo);
  expect(collect['generation'], 0);
  expect(collect['key_version'], 0);
  expect(collect['attach_file_hash256'], '');

  // v35：存量行 conv_seq/accepted_at 保持 NULL（不本地伪造权威序）。
  final msg = (await db.query('msg_c2c')).single;
  expect('${msg['id']}', '$_seedMsgId'); // v36 TEXT 保真（十进制不变）
  expect(msg['conv_seq'], isNull);
  expect(msg['accepted_at'], isNull);
  expect(msg['payload'], '{"synthetic":true}');
  expect(await _msgIdColumnType(db).then((t) => t.toUpperCase()), 'TEXT');

  // v37：channel 旧记录来源 NULL（不推断为 personal）。
  final channel = (await db.query('channel')).single;
  expect('${channel['name']}', 'synthetic-channel-001');
  expect(channel['scope'], isNull);
  expect(channel['workspace_id'], isNull);

  // conversation 行原样保留（迁移不触碰未读水位语义）。
  final conversation = (await db.query('conversation')).single;
  expect(conversation['type'], 'C2C');
  expect(conversation['user_id'], 990001);

  expect(await SchemaContract.verifyInvariants(db, version: 37), isEmpty);
}

/// 单测兜底：任何一步挂起（如事务死锁回归）必须在有界时间失败，
/// 绝不允许挂死全量跑。
const _perTestTimeout = Timeout(Duration(seconds: 60));

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await MigrationService.to.init();
  });

  for (final origin in [33, 34]) {
    test(
      'J28.a：旧合成库 v$origin → v37 一次升级跨 v2.2 增量，行数据保留默认值正确',
      timeout: _perTestTimeout,
      () async {
        final db = await openFixtureDatabaseAtVersion(
          version: origin,
          withSyntheticRows: true,
        );
        addTearDown(db.close);
        await db.insert('user_collect', {
          'user_id': 990001,
          'kind_id': 'synthetic-j28a',
          'info': '合成收藏🎉',
          'created_at': 1790000000123,
        });
        // 升级前起点形态自检。
        expect(await _userVersion(db), origin);
        expect((await _msgIdColumnType(db)).toUpperCase(), 'INTEGER');

        await _migrate(db, origin, 37);

        expect(await _userVersion(db), 37);
        await _expectIntegrity(db);
        await _expectV22Preserved(db, '合成收藏🎉');

        // 重入：同版本重复 migrate 无副作用（SchemaFingerprint 稳定）。
        final fingerprint = await SchemaFingerprint.compute(db);
        final replay = await MigrationService.to.migrate(
          db: db,
          fromVersion: 37,
          toVersion: 37,
        );
        expect(replay.success, isTrue, reason: replay.error);
        expect(await SchemaFingerprint.compute(db), fingerprint);
        expect(await _userVersion(db), 37);
      },
    );
  }

  test(
    'J28.a：升级被重启打断——v33→v35 后关库重开续升 v37，重入无副作用',
    timeout: _perTestTimeout,
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'imboy-j28a-resume-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/resume.db';

      // 第一次启动：升到 v35 后进程退出（关库）。
      var db = await openFixtureDatabaseAtVersion(
        version: 33,
        path: path,
        withSyntheticRows: true,
      );
      await db.insert('user_collect', {
        'user_id': 990001,
        'kind_id': 'synthetic-j28a',
        'info': '合成收藏🎉',
        'created_at': 1790000000123,
      });
      await _migrate(db, 33, 35);
      await db.close();

      // 第二次启动（重复启动续升）：从 v35 继续到 v37。
      db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(db.close);
      expect(await _userVersion(db), 35);
      // v35 已生效：conv_seq 列在且存量 NULL；v36 未生效：id 仍 INTEGER。
      final msgAt35 = (await db.query('msg_c2c')).single;
      expect(msgAt35.containsKey('conv_seq'), isTrue);
      expect(msgAt35['conv_seq'], isNull);
      expect((await _msgIdColumnType(db)).toUpperCase(), 'INTEGER');
      // v37 未生效：channel 无 scope 列。
      final channelColsAt35 = (await db.rawQuery('PRAGMA table_info(channel)'))
          .map((row) => row['name'])
          .toSet();
      expect(channelColsAt35, isNot(contains('scope')));

      await _migrate(db, 35, 37);
      await db.close();

      // 第三次启动：终态 v37 + 数据保留 + 重入幂等。
      db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      expect(await _userVersion(db), 37);
      await _expectIntegrity(db);
      await _expectV22Preserved(db, '合成收藏🎉');
      final fingerprint = await SchemaFingerprint.compute(db);
      final replay = await MigrationService.to.migrate(
        db: db,
        fromVersion: 37,
        toVersion: 37,
      );
      expect(replay.success, isTrue, reason: replay.error);
      expect(await SchemaFingerprint.compute(db), fingerprint);
      await db.close();

      db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(db.close);
      expect(await _userVersion(db), 37);
      expect(await SchemaContract.verifyInvariants(db, version: 37), isEmpty);
    },
  );

  test('J28.a：链中失败恢复——v36 边注入失败回滚停回 v35，修复重试升满 v37', timeout: _perTestTimeout, () async {
    final directory = await Directory.systemTemp.createTemp(
      'imboy-j28a-recover-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/recover.db';

    // 先升到 v35（链前段成功），再对 (35,37] 注入 v36 重建失败。
    var db = await openFixtureDatabaseAtVersion(
      version: 33,
      path: path,
      withSyntheticRows: true,
    );
    await db.insert('user_collect', {
      'user_id': 990001,
      'kind_id': 'synthetic-j28a',
      'info': '合成收藏🎉',
      'created_at': 1790000000123,
    });
    await _migrate(db, 33, 35);
    final rowsAt35 = await db.query('msg_c2c');
    await db.close();

    db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(db.close);
    await expectLater(
      _migrate(db, 35, 37, (txn) => _FailAtV36Rebuild(txn)),
      throwsStateError,
    );
    await db.close();

    // 失败后（相当于下次启动）：版本停在 35，事务整体回滚——
    // 无 *_new 残留表、id 仍 INTEGER、行数据无损。
    db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    expect(await _userVersion(db), 35);
    expect((await _msgIdColumnType(db)).toUpperCase(), 'INTEGER');
    final leftover = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%_new'",
    );
    expect(leftover, isEmpty);
    expect(await db.query('msg_c2c'), rowsAt35);
    expect(await SchemaContract.verifyInvariants(db, version: 35), isEmpty);
    await db.close();

    // 修复（移除注入）后重试：升满 v37，数据无损、默认值正确。
    db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(db.close);
    await _migrate(db, 35, 37);
    expect(await _userVersion(db), 37);
    await _expectIntegrity(db);
    await _expectV22Preserved(db, '合成收藏🎉');
    final fingerprint = await SchemaFingerprint.compute(db);
    final replay = await MigrationService.to.migrate(
      db: db,
      fromVersion: 37,
      toVersion: 37,
    );
    expect(replay.success, isTrue, reason: replay.error);
    expect(await SchemaFingerprint.compute(db), fingerprint);
  });
}
