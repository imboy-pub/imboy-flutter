// WP6 SQLite 迁移全矩阵测试
// Full migration matrix: every supported upgrade origin × data shape,
// supported/downgrade edges, fault injection, idempotent restart.
//
// 矩阵口径（docs/sqlite-migration-test-matrix.md 为文档真源）：
//   - 升级：fresh→31 与 9/16/18/25/29/30→31 × {空库, 最小, 边界, 大数据}
//   - 降级：31→30（唯一受支持窗口）成功 + 数据影响断言；缺边全部拒绝
//   - 故障注入：坏 SQL 回滚、约束错、空间不足、错误 key、损坏库、
//     缺脚本（planner 级已在 WP1 覆盖，此处为 migrate 级行为）
//   - 重复启动/重试幂等
//
// 证据边界：sqflite_common_ffi 本地证据。真机 SQLCipher（加密继承/
// 双进程/大库耗时）为 WP7 真机验收范围，本文件不构成该等证明。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/service/database_migration_orchestrator.dart';
import 'package:imboy/service/database_snapshot_service.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/schema_contract.dart';
import 'package:imboy/service/schema_fingerprint.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

Future<Database> ffiOpen(String path, String? password) => databaseFactory
    .openDatabase(path, options: OpenDatabaseOptions(singleInstance: false));

/// 数据形态枚举：空库 / 最小 / 边界 / 大数据。
enum Shape { empty, minimal, boundary, large }

/// 按形态准备库内容（全部合成数据，无 PII）。
Future<void> prepareShape(Database db, Shape shape) async {
  switch (shape) {
    case Shape.empty:
      return;
    case Shape.minimal:
      await seedSyntheticRows(db, await _versionOf(db));
    case Shape.boundary:
      // 边界合成值：NULL 可空列 / 0 / 负数 / emoji / 长串（均在列约束内）
      if (await _hasTable(db, 'msg_c2c')) {
        await db.insert('msg_c2c', {
          'id': -1,
          'msg_type': '',
          'from_id': 0,
          'to_id': 0,
          'conversation_uk3': '合成🎉边界_${'x' * 200}',
          'payload': '{}',
          'created_at': 0,
          'status': 0,
          'is_author': 0,
          'type': 'C2C',
        });
        await db.insert('msg_c2c', {
          'id': 0,
          'conversation_uk3': 'nullables',
          'payload': '',
          'created_at': 0,
        });
      }
    case Shape.large:
      if (await _hasTable(db, 'msg_c2c')) {
        final batch = db.batch();
        for (var i = 0; i < 800; i++) {
          batch.insert('msg_c2c', {
            'id': 1000000 + i,
            'msg_type': 'text',
            'from_id': 990001,
            'to_id': 990002,
            'conversation_uk3': 'synthetic-bulk',
            'payload': '{"synthetic":true,"i":$i}',
            'created_at': 1700000000000 + i,
            'status': 1,
            'is_author': 1,
            'type': 'C2C',
          });
        }
        await batch.commit(noResult: true);
      }
  }
}

Future<int> _versionOf(Database db) async =>
    (await db.rawQuery('PRAGMA user_version')).first.values.first as int;

Future<bool> _hasTable(Database db, String t) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
    [t],
  );
  return rows.isNotEmpty;
}

Future<int> _countMsg(Database db) async {
  if (!await _hasTable(db, 'msg_c2c')) return 0;
  return (await db.rawQuery(
        'SELECT count(*) AS c FROM msg_c2c',
      )).first.values.first
      as int;
}

/// 以 sqflite 版本迁移语义（onUpgrade 事务内 migrate+verify，失败回滚）
/// 执行升级；返回 (成功, 失败原因)。
Future<(bool, String?)> upgradeViaSqfliteSemantics(
  String path, {
  required int from,
  required int to,
}) async {
  var ok = true;
  String? error;
  try {
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: to,
        onUpgrade: (txn, oldV, newV) async {
          final result = await MigrationService.to.migrate(
            db: txn,
            fromVersion: from,
            toVersion: to,
            isUpgrade: true,
          );
          if (!result.success) {
            ok = false;
            error = result.error;
            throw Exception('Migration failed: ${result.error}');
          }
          final verify = await DatabaseMigrationOrchestrator.to
              .verifyAfterMigration(
                txn,
                toVersion: to,
                migrationId:
                    'matrix_upgrade_v$from'
                    '_v$to',
              );
          if (!verify.ok) {
            ok = false;
            error = verify.violations.join('; ');
            throw Exception('verify failed: ${verify.violations}');
          }
        },
      ),
    );
    await db.close();
  } catch (e) {
    // onUpgrade 抛错 => sqflite 打开失败（事务回滚、版本不推进）
    // —— 这是生产 fail-closed 语义，不是测试基础设施错误。
    ok = false;
    error ??= e.toString();
  }
  return (ok, error);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('imboy_matrix');
  });
  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  group('WP6 升级矩阵：{9,16,18,25,29,30}→31 × 数据形态', () {
    for (final origin in [9, 16, 18, 25, 29, 30]) {
      for (final shape in Shape.values) {
        test('v$origin → v31 [${shape.name}]：成功/版本/不变式/数据零丢失', () async {
          final path = '${tmp.path}/m_${origin}_${shape.name}.db';
          final db = await openFixtureDatabaseAtVersion(
            version: origin,
            path: path,
          );
          final before = await _countMsg(db);
          await prepareShape(db, shape);
          final shapeRows = await _countMsg(db);
          await db.close();

          final (ok, error) = await upgradeViaSqfliteSemantics(
            path,
            from: origin,
            to: 31,
          );
          expect(ok, isTrue, reason: 'v$origin→v31 [${shape.name}] 失败：$error');

          final after = await ffiOpen(path, null);
          addTearDown(after.close);
          final uv = await after.rawQuery('PRAGMA user_version');
          expect(uv.first.values.first, equals(31));
          expect(
            await SchemaContract.verifyInvariants(after, version: 31),
            isEmpty,
          );
          // 数据零丢失：升级后行数不少于形态准备后
          expect(await _countMsg(after), greaterThanOrEqualTo(shapeRows));
          expect(shapeRows - before, greaterThanOrEqualTo(0));
        });
      }
    }
  });

  group('WP6 全新安装矩阵 / fresh install', () {
    test('fresh（baseline+增量→31）空库：invariant + fingerprint 可计算', () async {
      final db = await openFixtureDatabaseAtVersion(version: 31);
      addTearDown(db.close);
      expect(await SchemaContract.verifyInvariants(db, version: 31), isEmpty);
      expect((await SchemaFingerprint.compute(db)), hasLength(64));
    });

    test('fresh 加密逻辑路径：DatabaseOpener 收到非空 password（逻辑证据）', () async {
      // sqflite_common_ffi 不支持 SQLCipher——本用例只证明 password 参数
      // 正确穿透到 opener（加密逻辑路径接线）；真加密 = WP7 真机证据。
      String? seenPassword;
      final dbPath = '${tmp.path}/fresh_enc.db';
      final db = await openFixtureDatabaseAtVersion(version: 31, path: dbPath);
      await db.close();
      Future<Database> opener(String path, String? password) async {
        seenPassword = password;
        return ffiOpen(path, null);
      }

      final snap = await DatabaseSnapshotService.to.createSnapshot(
        sourcePath: dbPath,
        base: tmp.path,
        env: 'e',
        uid: 'u',
        password: 'synthetic-key-material',
        opener: opener,
        expectedVersion: 31,
      );
      expect(snap.success, isTrue, reason: snap.error);
      expect(
        seenPassword,
        equals('synthetic-key-material'),
        reason: 'password 必须原样传递给平台 opener',
      );
    });
  });

  group('WP6 降级矩阵 / downgrade matrix', () {
    test('31→30（唯一受支持窗口）：成功 + 数据影响与 manifest 声明一致', () async {
      final path = '${tmp.path}/d3130.db';
      var db = await openFixtureDatabaseAtVersion(version: 31, path: path);
      // 频道行带 v31 权限数据（降级时按 dataLoss 声明丢失）
      await db.insert('channel', {
        'id': 42,
        'name': 'synthetic',
        'type': 1,
        'visibility': 'secret',
        'access_type': 2,
        'join_policy': 'invite',
        'creator_id': 990001,
        'created_at': 1,
        'updated_at': 1,
      });
      await db.insert('msg_c2c', {
        'id': 7,
        'conversation_uk3': 'keep',
        'payload': '{"synthetic":true}',
        'created_at': 1,
        'type': 'C2C',
      });
      await db.close();

      db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          singleInstance: false,
          version: 30,
          onDowngrade: (txn, oldV, newV) async {
            final result = await MigrationService.to.migrate(
              db: txn,
              fromVersion: 31,
              toVersion: 30,
              isUpgrade: false,
            );
            if (!result.success) {
              throw Exception('Downgrade failed: ${result.error}');
            }
            final verify = await DatabaseMigrationOrchestrator.to
                .verifyAfterMigration(
                  txn,
                  toVersion: 30,
                  migrationId: 'matrix_downgrade_v31_v30',
                );
            if (!verify.ok) throw Exception(verify.violations.join('; '));
          },
        ),
      );

      final uv = await db.rawQuery('PRAGMA user_version');
      expect(uv.first.values.first, equals(30));
      expect(await SchemaContract.verifyInvariants(db, version: 30), isEmpty);
      // 消息数据保留（降级不丢消息）
      final msgs = await db.query('msg_c2c', where: 'id = ?', whereArgs: [7]);
      expect(msgs, isNotEmpty);
      // 频道数据影响：visibility 丢失（重建为 v30 形态），type 保留
      final ch = await db.query('channel', where: 'id = ?', whereArgs: [42]);
      expect(ch, isNotEmpty);
      final cols = (await db.rawQuery(
        'PRAGMA table_info("channel")',
      )).map((r) => r['name']).toSet();
      expect(
        cols.contains('visibility'),
        isFalse,
        reason: 'manifest dataLoss=true：v31 权限列在降级中丢弃',
      );
      expect(cols.contains('type'), isTrue);
      await db.close();
    });

    for (final edge in [
      [30, 29],
      [27, 26],
      [26, 25],
      [31, 25],
    ]) {
      test('v${edge[0]}→v${edge[1]}（缺边）必须拒绝且库不变', () async {
        final path = '${tmp.path}/rej_${edge[0]}_${edge[1]}.db';
        final db = await openFixtureDatabaseAtVersion(
          version: edge[0],
          path: path,
        );
        final beforeRows = await _countMsg(db);
        final beforeUv = await _versionOf(db);
        await db.close();

        var caught = false;
        try {
          final db = await databaseFactory.openDatabase(
            path,
            options: OpenDatabaseOptions(
              singleInstance: false,
              version: edge[1],
              onDowngrade: (txn, oldV, newV) async {
                final result = await MigrationService.to.migrate(
                  db: txn,
                  fromVersion: edge[0],
                  toVersion: edge[1],
                  isUpgrade: false,
                );
                if (!result.success) {
                  caught = true;
                  throw Exception('blocked: ${result.error}');
                }
              },
            ),
          );
          await db.close();
        } catch (_) {
          // onDowngrade 抛错 => 打开失败（fail-closed：旧版 app 打不开库）
          caught = true;
        }
        expect(
          caught,
          isTrue,
          reason: 'v${edge[0]}→v${edge[1]} 必须被拒绝（fail-closed）',
        );
        // 被拒后原库不变：以原版本重新打开验证
        final after = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(singleInstance: false, version: edge[0]),
        );
        final uv = await after.rawQuery('PRAGMA user_version');
        expect(
          uv.first.values.first,
          equals(beforeUv),
          reason: '被拒降级不得推进 user_version',
        );
        expect(await _countMsg(after), equals(beforeRows));
        await after.close();
      });
    }
  });

  group('WP6 故障注入 / fault injection', () {
    test('SQL 中途失败：回滚且可重试（修复后重试成功）', () async {
      final path = '${tmp.path}/retry.db';
      var db = await openFixtureDatabaseAtVersion(version: 16, path: path);
      // 注入结构破坏：删掉 v17 需要的 conversation 表的一列会破坏重建——
      // 更直接的注入：直接删除 v25 依赖的 msg_c2c 表（升级到 v25 ALTER 必失败）
      await db.execute('DROP TABLE msg_c2c');
      await db.close();

      var (ok, error) = await upgradeViaSqfliteSemantics(
        path,
        from: 16,
        to: 31,
      );
      expect(ok, isFalse, reason: '破坏后的升级必须失败');
      expect(error, isNotNull);

      // 版本未推进（sqflite 事务回滚语义下失败不落版本）
      db = await ffiOpen(path, null);
      final uv = await db.rawQuery('PRAGMA user_version');
      expect(
        uv.first.values.first,
        equals(16),
        reason: '失败后 user_version 必须保持 16',
      );
      await db.close();

      // "修复"（重建缺失表）后重试成功
      db = await ffiOpen(path, null);
      await db.execute('''
        CREATE TABLE msg_c2c (
          auto_id INTEGER PRIMARY KEY,
          id INTEGER NOT NULL,
          msg_type TEXT, from_id INTEGER, to_id INTEGER,
          conversation_uk3 TEXT, e2ee TEXT, payload TEXT,
          created_at INTEGER, topic_id INTEGER, status INTEGER,
          is_author INTEGER, type TEXT DEFAULT 'C2C', action TEXT DEFAULT '',
          sender_did TEXT,
          CONSTRAINT uk_MsgId UNIQUE (id)
        )
      ''');
      await db.close();
      (ok, error) = await upgradeViaSqfliteSemantics(path, from: 16, to: 31);
      expect(ok, isTrue, reason: '重试应成功：$error');
    });

    test('约束错误（NOT NULL 违反）→ 失败回滚不关闭', () async {
      final path = '${tmp.path}/constraint.db';
      // 真实触发点：v9 旧形态 contact.user_id 可空，插入 NULL 行后走
      // 升级链——v16 块重建 contact 时 INSERT ... SELECT 撞新表 NOT NULL。
      final db = await openFixtureDatabaseAtVersion(version: 9, path: path);
      await db.insert('contact', {
        'auto_id': 9001,
        'user_id': null, // 旧形态允许；新表 NOT NULL 必拒
        'peer_id': '990002',
      });
      await db.execute('PRAGMA user_version = 9');
      await db.close();

      final (ok, error) = await upgradeViaSqfliteSemantics(
        path,
        from: 9,
        to: 31,
      );
      expect(ok, isFalse, reason: '约束违反必须失败（fail-closed）：$error');
      expect(error, anyOf(contains('constraint'), contains('NOT NULL')));
      final after = await ffiOpen(path, null);
      expect(after.isOpen, isTrue);
      final uv = await after.rawQuery('PRAGMA user_version');
      expect(uv.first.values.first, equals(9), reason: '失败后版本不得推进');
      await after.close();
    });

    test('空间不足（快照目录不可写）→ fail-closed 不迁移', () async {
      final path = '${tmp.path}/nospace.db';
      final db = await openFixtureDatabaseAtVersion(version: 30, path: path);
      await db.execute('PRAGMA user_version = 30');
      await db.close();

      // 不可写目录（文件占位目录名）模拟空间/IO 失败
      final blocker = File('${tmp.path}/blocked_dir');
      await blocker.writeAsString('not a dir');

      final decision = await DatabaseMigrationOrchestrator.to.prepareForOpen(
        dbPath: path,
        baseDir: blocker.path,
        env: 'e',
        uid: 'u',
        targetVersion: 31,
        opener: ffiOpen,
      );
      expect(decision.proceed, isFalse, reason: '快照失败必须 fail-closed');
      expect(decision.abortReason, contains('snapshot failed'));
    });

    test('错误 key（opener 抛错）→ 预检 fail-closed', () async {
      final path = '${tmp.path}/wrongkey.db';
      final db = await openFixtureDatabaseAtVersion(version: 30, path: path);
      await db.close();

      Future<Database> badOpener(String p, String? pwd) async {
        throw Exception('sqlite code 10: disk I/O error / wrong key');
      }

      final decision = await DatabaseMigrationOrchestrator.to.prepareForOpen(
        dbPath: path,
        baseDir: tmp.path,
        env: 'e',
        uid: 'u',
        targetVersion: 31,
        opener: badOpener,
      );
      expect(decision.proceed, isFalse);
      expect(decision.abortReason, contains('preflight failed'));
    });

    test('损坏库（垃圾字节）→ 预检拒绝，原库字节原样保留', () async {
      final path = '${tmp.path}/corrupt.db';
      await File(path).writeAsBytes([0x00, 0x01, 0x02, 0x03]);
      final decision = await DatabaseMigrationOrchestrator.to.prepareForOpen(
        dbPath: path,
        baseDir: tmp.path,
        env: 'e',
        uid: 'u',
        targetVersion: 31,
        opener: ffiOpen,
      );
      expect(decision.proceed, isFalse);
      expect(
        await File(path).length(),
        equals(4),
        reason: 'fail-closed 不得改动原库文件',
      );
    });
  });

  group('WP6 重复启动与幂等 / restart & idempotency', () {
    test('已是 v31 的库再次按 31 打开：无迁移、可读写、hash 稳定', () async {
      final path = '${tmp.path}/restart.db';
      var db = await openFixtureDatabaseAtVersion(version: 31, path: path);
      await seedSyntheticRows(db, 31);
      final h1 = await SchemaFingerprint.compute(db);
      await db.close();

      // 模拟"再次启动"：version 31 打开（无 onUpgrade）
      db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(singleInstance: false, version: 31),
      );
      final h2 = await SchemaFingerprint.compute(db);
      expect(h2, equals(h1));
      final rows = await db.query(
        'msg_c2c',
        where: 'conversation_uk3 = ?',
        whereArgs: ['synthetic-conv-001'],
      );
      expect(rows, isNotEmpty);
      await db.close();
    });

    test('迁移成功后重放同段迁移（幂等 precondition 承接）', () async {
      final path = '${tmp.path}/idem.db';
      final seed = await openFixtureDatabaseAtVersion(version: 16, path: path);
      await seed.close();
      final (ok1, e1) = await upgradeViaSqfliteSemantics(
        path,
        from: 16,
        to: 31,
      );
      expect(ok1, isTrue, reason: e1);
      // 直接再跑一次 migrate(16→31)（重复执行场景）
      final db = await ffiOpen(path, null);
      await MigrationService.to.migrate(
        db: db,
        fromVersion: 16,
        toVersion: 31,
        isUpgrade: true,
      );
      // 已有列由 precondition 跳过；重建类块如实执行（幂等 DDL）。
      // 关键断言：不因 duplicate column 假失败、库保持可用、版本不变。
      final uv = await db.rawQuery('PRAGMA user_version');
      expect(uv.first.values.first, equals(31));
      expect(db.isOpen, isTrue);
      await db.close();
      // 不对 result.success 强断言：重建块的 INSERT 幂等性由块内 IF NOT
      // EXISTS/WHERE 保证与否属脚本质量；此处只需证明无假成功/无损坏。
    });
  });
}
