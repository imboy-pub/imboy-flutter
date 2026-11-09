// IMBOY_AUTOTEST AT10 / L01 缺口补测（断言映射行 3 + 行 5）：
//   行 3「重试完整」：迁移失败 → 关闭 → 重开 → 重试走完整路径 →
//     升满 v37，无半迁移残留（版本停回起点、无 *_new 残表、schema 与
//     干净全链升级逐字节等价、行数据无损、同版本重入 no-op）。
//   行 5「scope/workspace 不串」：v37 只加列不回填——旧行来源保持
//     双 NULL（不推断 personal/workspace）；升级后 personal/workspace
//     来源并存互不串写；失败回滚不留半列状态，重试路径不把来源写串。
//
// 证据边界：sqflite_common_ffi 文件库（close/reopen 模拟进程重启）。
// 与既有套件互补：migration_atomic_failure_test（原子性）、
// migration_v22_reentry_recovery_test（重启续升/链中恢复）、
// migration_v37_channel_scope_test（v37 单边重试）——本文件把它们
// 收敛为断言映射行 3/行 5 的显式闭环证据（含与干净全链的指纹对齐）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/schema_contract.dart';
import 'package:imboy/service/schema_fingerprint.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

/// 单测兜底：任何一步挂起（如事务死锁回归）必须在有界时间失败。
const _perTestTimeout = Timeout(Duration(seconds: 60));

Future<int> _userVersion(Database db) async =>
    (await db.rawQuery('PRAGMA user_version')).single['user_version'] as int;

/// 生产调用契约：onUpgrade/onDowngrade 已在 sqflite 事务内调 migrate，
/// failure 后 rethrow 触发 sqflite 回滚。[wrapTxn] 可包装事务句柄注入
/// 失败；绝不允许把外层 Database 连接传给 migrate（事务死锁）。
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

/// v36 链首注入失败：重建块第一条语句（msg_c2c_new）即抛，
/// 制造「单边内完成一半重建」的失败点（区别于既有用例的 msg_c2g_new）。
class _FailAtChainHeadRebuild implements DatabaseExecutor {
  _FailAtChainHeadRebuild(this.inner);
  final DatabaseExecutor inner;
  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    if (sql.contains('msg_c2c_new')) {
      throw StateError('injected v36 chain-head rebuild failure');
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

/// v37 第一列注入失败：scope 列已执行、workspace_id 未执行时抛，
/// 制造「半个来源列」的失败点（区别于既有用例的第二列注入）。
class _FailAtFirstScopeColumn implements DatabaseExecutor {
  _FailAtFirstScopeColumn(this.inner);
  final DatabaseExecutor inner;
  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    if (sql.contains('ADD COLUMN workspace_id')) {
      throw StateError('injected v37 first-column failure');
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

Future<Set<String>> _channelColumns(Database db) async =>
    (await db.rawQuery('PRAGMA table_info(channel)'))
        .map((row) => row['name'] as String)
        .toSet();

/// msg_c2c.id 的声明列类型（v35 前 INTEGER；v36 后 TEXT）。
Future<String> _msgIdColumnType(Database db) async {
  final rows = await db.rawQuery('PRAGMA table_info(msg_c2c)');
  for (final row in rows) {
    if (row['name'] == 'id') {
      return ((row['type'] ?? '') as String).toUpperCase();
    }
  }
  return '';
}

/// *_new 残表查询（v36 重建块的临时表名形态）。
Future<List<Map<String, Object?>>> _newResidueTables(Database db) async =>
    db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%_new'",
    );

Future<void> _expectIntegrity(Database db) async {
  expect(await db.rawQuery('PRAGMA integrity_check'), [
    {'integrity_check': 'ok'},
  ]);
  expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
}

/// 「不串」业务不变量的真实 SQL 断言：
/// personal 行不得携带 workspace_id；workspace 行必须带 workspace_id；
/// 未知来源行（NULL）必须双列皆 NULL（不推断）。
Future<void> _expectScopeWorkspaceDisjoint(Database db) async {
  final personalWithWorkspace = await db.rawQuery(
    "SELECT count(*) AS c FROM channel WHERE scope = 'personal' "
    'AND workspace_id IS NOT NULL',
  );
  expect(
    personalWithWorkspace.single['c'],
    0,
    reason: 'personal 行不得携带 workspace_id（来源互不串）',
  );
  final workspaceWithoutId = await db.rawQuery(
    "SELECT count(*) AS c FROM channel WHERE scope = 'workspace' "
    "AND (workspace_id IS NULL OR workspace_id = '')",
  );
  expect(
    workspaceWithoutId.single['c'],
    0,
    reason: 'workspace 行必须携带 workspace_id（来源成对）',
  );
  final legacyInferred = await db.rawQuery(
    'SELECT count(*) AS c FROM channel '
    'WHERE scope IS NULL AND workspace_id IS NOT NULL',
  );
  expect(
    legacyInferred.single['c'],
    0,
    reason: '未知来源行不得只推断出 workspace_id（保持双 NULL）',
  );
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await MigrationService.to.init();
  });

  group('L01 行 3：失败 → 关闭 → 重开 → 重试走完整路径 / retry full path', () {
    test(
      '链中失败（v36 链首注入）回滚停回 v33，重试升满 v37 且与干净全链等价',
      timeout: _perTestTimeout,
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'imboy-l01-retry-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final path = '${directory.path}/retry.db';

        var db = await openFixtureDatabaseAtVersion(
          version: 33,
          path: path,
          withSyntheticRows: true,
        );
        final msgRowsBefore = await db.query('msg_c2c');
        final convRowsBefore = await db.query('conversation');
        await db.close();

        // 第 1 次启动：33→37 链中 v36 重建首句注入失败 → rethrow → 回滚。
        db = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(singleInstance: false),
        );
        await expectLater(
          _migrate(db, 33, 37, (txn) => _FailAtChainHeadRebuild(txn)),
          throwsStateError,
        );
        await db.close();

        // 失败后重开（相当于用户重启）：版本停回起点 33，无半迁移残留。
        db = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(singleInstance: false),
        );
        addTearDown(db.close);
        expect(await _userVersion(db), 33, reason: '失败回滚必须停回起点 33');
        expect(await _newResidueTables(db), isEmpty, reason: '不得有 *_new 残表');
        expect(
          await _channelColumns(db).then((c) => c.contains('scope')),
          isFalse,
          reason: '链中断点之后无任何 v37 残留',
        );
        expect(await db.query('msg_c2c'), msgRowsBefore, reason: '行数据无损');
        expect(await db.query('conversation'), convRowsBefore);
        await _expectIntegrity(db);

        // 重试（移除注入）：走完整路径升满 v37。
        await _migrate(db, 33, 37);
        expect(await _userVersion(db), 37);
        expect(await _newResidueTables(db), isEmpty, reason: '重试后无重建残表');
        await _expectIntegrity(db);
        expect(await SchemaContract.verifyInvariants(db, version: 37), isEmpty);
        expect(
          await SchemaFingerprint.compute(db),
          await openFixtureDatabaseAtVersion(version: 37).then((clean) async {
            final fp = await SchemaFingerprint.compute(clean);
            await clean.close();
            return fp;
          }),
          reason: '重试结果必须与干净全链升级的 schema 完全等价（无半迁移）',
        );
        // 旧行经完整重试路径后数据无损、默认值语义正确。
        final upgradedMsg = (await db.query('msg_c2c')).single;
        expect('${upgradedMsg['id']}', '${msgRowsBefore.single['id']}');
        expect(upgradedMsg['conv_seq'], isNull);
        expect(upgradedMsg['accepted_at'], isNull);
        expect(
          await _msgIdColumnType(db),
          'TEXT',
          reason: '重试完整应用 v36：id 列已转 TEXT',
        );

        // 同版本重入 no-op：指纹稳定、版本不动（行 4 的单测级补充证据）。
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

    test(
      'v37 首列失败（scope 已执行/workspace_id 未执行）回滚后双列皆无，重试成对补齐',
      timeout: _perTestTimeout,
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'imboy-l01-v37-first-col-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final path = '${directory.path}/first-col.db';

        var db = await openFixtureDatabaseAtVersion(version: 36, path: path);
        await db.insert('channel', {
          'id': 10,
          'name': 'synthetic-old',
          'creator_id': 1,
          'created_at': 1,
          'updated_at': 1,
        });
        await expectLater(
          _migrate(db, 36, 37, (txn) => _FailAtFirstScopeColumn(txn)),
          throwsStateError,
        );
        await db.close();

        // 回滚后不得出现「只有 scope 没有 workspace_id」的半列状态。
        db = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(singleInstance: false),
        );
        addTearDown(db.close);
        expect(await _userVersion(db), 36);
        final cols = await _channelColumns(db);
        expect(cols.contains('scope'), isFalse);
        expect(cols.contains('workspace_id'), isFalse);
        expect((await db.query('channel')).single['name'], 'synthetic-old');

        // 重试：成对补齐且旧行来源保持双 NULL（迁移不回填来源）。
        await _migrate(db, 36, 37);
        expect(await _userVersion(db), 37);
        final retriedCols = await _channelColumns(db);
        expect(retriedCols.contains('scope'), isTrue);
        expect(retriedCols.contains('workspace_id'), isTrue);
        final upgraded = (await db.query('channel')).single;
        expect(upgraded['name'], 'synthetic-old');
        expect(upgraded['scope'], isNull, reason: '旧行不推断 personal');
        expect(upgraded['workspace_id'], isNull);
        expect(await SchemaContract.verifyInvariants(db, version: 37), isEmpty);
      },
    );
  });

  group('L01 行 5：scope / workspace 迁移数据互不串 / provenance isolation', () {
    test(
      'v37 只加列不回填：旧行保持双 NULL，新插入缺省行同样双 NULL（无 personal 推断）',
      timeout: _perTestTimeout,
      () async {
        final db = await openFixtureDatabaseAtVersion(
          version: 36,
          withSyntheticRows: true,
        );
        addTearDown(db.close);
        await db.insert('channel', {
          'id': 990101,
          'name': 'synthetic-legacy-2',
          'creator_id': 1,
          'created_at': 1,
          'updated_at': 1,
        });

        await _migrate(db, 36, 37);

        // 旧行（迁移前已存在）双 NULL：不推断 personal，也不猜 workspace。
        final legacyRows = await db.query('channel');
        expect(legacyRows.length, 2, reason: '迁移不增删行');
        for (final row in legacyRows) {
          expect(
            row['scope'],
            isNull,
            reason: "行 ${row['id']} 的来源必须保持未知（NULL）",
          );
          expect(row['workspace_id'], isNull, reason: '不得推断 workspace 归属');
        }
        // 迁移后新插入的缺省行同样双 NULL（列无默认值回填）。
        await db.insert('channel', {
          'id': 990102,
          'name': 'synthetic-post-migration',
          'creator_id': 1,
          'created_at': 2,
          'updated_at': 2,
        });
        final postRow = (await db.query(
          'channel',
          where: 'id = ?',
          whereArgs: [990102],
        )).single;
        expect(postRow['scope'], isNull);
        expect(postRow['workspace_id'], isNull);
        expect(await SchemaContract.verifyInvariants(db, version: 37), isEmpty);
      },
    );

    test(
      '升级后 personal/workspace 来源并存互不串：同版本重开 + no-op 重入均不改写',
      timeout: _perTestTimeout,
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'imboy-l01-scope-iso-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final path = '${directory.path}/scope-iso.db';

        var db = await openFixtureDatabaseAtVersion(
          version: 36,
          path: path,
          withSyntheticRows: true,
        );
        await _migrate(db, 36, 37);
        // 三种来源形态并存：personal（无 workspace）、workspace（成对）、
        // 未知（迁移遗留 NULL 行 synthetic-channel-001）。
        await db.insert('channel', {
          'id': 11,
          'name': 'personal-fixture',
          'creator_id': 1,
          'created_at': 1,
          'updated_at': 1,
          'scope': 'personal',
        });
        await db.insert('channel', {
          'id': 12,
          'name': 'workspace-fixture',
          'creator_id': 1,
          'created_at': 1,
          'updated_at': 1,
          'scope': 'workspace',
          'workspace_id': 'ws-fixture-1',
        });
        await db.close();

        // 同版本重开（生产重启形态）：三种形态逐行原样保留。
        db = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(singleInstance: false),
        );
        addTearDown(db.close);
        expect(await _userVersion(db), 37);

        final personal = (await db.query(
          'channel',
          where: 'id = ?',
          whereArgs: [11],
        )).single;
        expect(personal['scope'], 'personal');
        expect(
          personal['workspace_id'],
          isNull,
          reason: 'personal 不串入 workspace',
        );

        final workspace = (await db.query(
          'channel',
          where: 'id = ?',
          whereArgs: [12],
        )).single;
        expect(workspace['scope'], 'workspace');
        expect(workspace['workspace_id'], 'ws-fixture-1', reason: '成对保留');

        final legacy = (await db.query(
          'channel',
          where: 'name = ?',
          whereArgs: ['synthetic-channel-001'],
        )).single;
        expect(legacy['scope'], isNull);
        expect(legacy['workspace_id'], isNull);

        await _expectScopeWorkspaceDisjoint(db);

        // 同版本 no-op 重入（migrate 37→37）：不改写任何来源数据。
        final beforeAll = await db.query('channel');
        final replay = await MigrationService.to.migrate(
          db: db,
          fromVersion: 37,
          toVersion: 37,
        );
        expect(replay.success, isTrue, reason: replay.error);
        expect(await db.query('channel'), beforeAll, reason: 'no-op 重入零改写');
        await _expectScopeWorkspaceDisjoint(db);
        expect(await SchemaContract.verifyInvariants(db, version: 37), isEmpty);
      },
    );
  });
}
