// WP5 迁移协调器测试（本地 ffi 文件库证据）
// Orchestrator tests: preflight fail-closed, outbox-blocked downgrade,
// full upgrade flow with post-migration verification and meta.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/service/database_migration_orchestrator.dart';
import 'package:imboy/service/database_snapshot_service.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/schema_contract.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

Future<Database> ffiOpen(String path, String? password) => databaseFactory
    .openDatabase(path, options: OpenDatabaseOptions(singleInstance: false));

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('imboy_orch_test');
  });
  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  /// 构建一个真实 v30 文件库（生产形态：baseline+增量到 30）。
  Future<String> buildV30FileDb() async {
    final path = '${tmp.path}/main.db';
    final db = await openFixtureDatabaseAtVersion(version: 30, path: path);
    await db.close();
    return path;
  }

  group('WP5 prepareForOpen', () {
    test('v30 库 + target 31：需要迁移，快照生成且版本对齐 30', () async {
      final dbPath = await buildV30FileDb();
      final decision = await DatabaseMigrationOrchestrator.to.prepareForOpen(
        dbPath: dbPath,
        baseDir: tmp.path,
        env: 'prod',
        uid: '990001',
        targetVersion: 31,
        opener: ffiOpen,
      );
      expect(decision.proceed, isTrue);
      expect(decision.migrationNeeded, isTrue);
      expect(decision.currentVersion, equals(30));
      expect(decision.snapshotPath, isNotNull, reason: '迁移前必须有一致性快照');
    });

    test('v31 库 + target 31：无需迁移、无快照', () async {
      final path = '${tmp.path}/main.db';
      final db = await openFixtureDatabaseAtVersion(version: 31, path: path);
      await db.close();
      final decision = await DatabaseMigrationOrchestrator.to.prepareForOpen(
        dbPath: path,
        baseDir: tmp.path,
        env: 'prod',
        uid: '990001',
        targetVersion: 31,
        opener: ffiOpen,
      );
      expect(decision.proceed, isTrue);
      expect(decision.migrationNeeded, isFalse);
      expect(decision.snapshotPath, isNull);
    });

    test('损坏库（垃圾字节）→ fail-closed 不迁移', () async {
      final dbPath = '${tmp.path}/main.db';
      await File(dbPath).writeAsBytes([0x00, 0x01, 0x02]);
      final decision = await DatabaseMigrationOrchestrator.to.prepareForOpen(
        dbPath: dbPath,
        baseDir: tmp.path,
        env: 'prod',
        uid: '990001',
        targetVersion: 31,
        opener: ffiOpen,
      );
      expect(decision.proceed, isFalse);
      expect(decision.abortReason, contains('preflight failed'));
    });

    test('降级 + 未同步 outbox → 阻塞（防未同步数据丢失）', () async {
      final path = '${tmp.path}/main.db';
      final db = await openFixtureDatabaseAtVersion(version: 31, path: path);
      await db.close();
      final decision = await DatabaseMigrationOrchestrator.to.prepareForOpen(
        dbPath: path,
        baseDir: tmp.path,
        env: 'prod',
        uid: '990001',
        targetVersion: 30, // 降级
        opener: ffiOpen,
        unsyncedOutboxProbe: () async => ['channel_message_outbox: 2 unsynced'],
      );
      expect(decision.proceed, isFalse);
      expect(decision.blockers, isNotEmpty);
      expect(decision.abortReason, contains('unsynced outbox'));
    });

    test('库不存在（全新安装）：proceed 且无需快照', () async {
      final decision = await DatabaseMigrationOrchestrator.to.prepareForOpen(
        dbPath: '${tmp.path}/fresh.db',
        baseDir: tmp.path,
        env: 'prod',
        uid: '990001',
        targetVersion: 31,
        opener: ffiOpen,
      );
      expect(decision.proceed, isTrue);
      expect(decision.snapshotPath, isNull);
    });
  });

  group('WP5 全流程 / full orchestrated flow', () {
    test('v30 → prepare → open+升级 → verifyAfterMigration（meta 写入）', () async {
      final dbPath = await buildV30FileDb();
      final decision = await DatabaseMigrationOrchestrator.to.prepareForOpen(
        dbPath: dbPath,
        baseDir: tmp.path,
        env: 'prod',
        uid: '990001',
        targetVersion: 31,
        opener: ffiOpen,
      );
      expect(decision.proceed, isTrue);

      // 模拟生产：sqflite 打开（version 31 → onUpgrade 事务内 migrate+verify）
      final db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          singleInstance: false,
          version: 31,
          onUpgrade: (txn, oldV, newV) async {
            final result = await MigrationService.to.migrate(
              db: txn,
              fromVersion: oldV,
              toVersion: newV,
              isUpgrade: true,
            );
            if (!result.success) {
              throw Exception('Migration failed: ${result.error}');
            }
            final verify = await DatabaseMigrationOrchestrator.to
                .verifyAfterMigration(
                  txn,
                  toVersion: newV,
                  migrationId: 'orchestrated_upgrade_v30_v31',
                );
            if (!verify.ok) {
              throw Exception('verify failed: ${verify.violations}');
            }
          },
        ),
      );

      final uv = await db.rawQuery('PRAGMA user_version');
      expect(uv.first.values.first, equals(31));

      // meta 已写入（事务提交后可见）
      final meta = await ImboySchemaMeta.readAll(db);
      expect(meta[ImboySchemaMeta.keySchemaVersion], equals('31'));
      expect(
        meta[ImboySchemaMeta.keyLastMigrationId],
        equals('orchestrated_upgrade_v30_v31'),
      );
      expect(meta[ImboySchemaMeta.keySchemaHash], hasLength(64));
      expect(meta[ImboySchemaMeta.keyMigrationState], equals('ok'));

      // 快照存在且可恢复（灾难回退能力）
      expect(File(decision.snapshotPath!).existsSync(), isTrue);
      await db.close();
    });

    test('verifyAfterMigration：invariant 失败返回违规（供回滚）', () async {
      final db = await openFixtureDatabaseAtVersion(version: 31);
      addTearDown(db.close);
      // 篡改：去掉 channel 三字段 → invariant 必须失败
      await db.execute('DROP INDEX IF EXISTS idx_channel_type');
      await db.execute('ALTER TABLE channel RENAME TO channel_x');
      await db.execute('CREATE TABLE channel (id INTEGER PRIMARY KEY)');
      final verify = await DatabaseMigrationOrchestrator.to
          .verifyAfterMigration(db, toVersion: 31);
      expect(verify.ok, isFalse);
      expect(verify.violations.any((v) => v.contains('channel')), isTrue);
    });

    test('verifyAfterMigration：expectedFingerprint 强校验（golden 口径）', () async {
      final db = await openFixtureDatabaseAtVersion(version: 31);
      addTearDown(db.close);
      final ok = await DatabaseMigrationOrchestrator.to.verifyAfterMigration(
        db,
        toVersion: 31,
        expectedFingerprint: 'deadbeef', // 故意错
      );
      expect(ok.ok, isFalse);
      expect(
        ok.violations.any((v) => v.contains('fingerprint mismatch')),
        isTrue,
      );
    });
  });

  group('WP5 灾难恢复 / disaster recovery', () {
    test('升级后主库损坏 → restoreLatest 恢复到迁移前快照', () async {
      final dbPath = await buildV30FileDb();
      final decision = await DatabaseMigrationOrchestrator.to.prepareForOpen(
        dbPath: dbPath,
        baseDir: tmp.path,
        env: 'prod',
        uid: '990001',
        targetVersion: 31,
        opener: ffiOpen,
      );
      expect(decision.proceed, isTrue);

      // 模拟灾难：主库字节损坏
      await File(dbPath).writeAsBytes([0x00, 0xff, 0x00, 0xff]);

      final restore = await DatabaseMigrationOrchestrator.to.restoreLatest(
        dbPath: dbPath,
        baseDir: tmp.path,
        env: 'prod',
        uid: '990001',
        closeAllConnections: () async {},
        opener: ffiOpen,
        expectedVersion: 30,
      );
      expect(restore.success, isTrue, reason: restore.error);
      expect(restore.userVersion, equals(30));

      // 恢复后可正常打开
      final db = await ffiOpen(dbPath, null);
      final uv = await db.rawQuery('PRAGMA user_version');
      expect(uv.first.values.first, equals(30));
      await db.close();
    });
  });

  group('WP5 快照服务能力探测 / capability probe', () {
    test('probeVacuumInto 在 ffi 环境可用（CAPABILITY_PROBED 本地证据）', () async {
      final dbPath = await buildV30FileDb();
      final supported = await DatabaseSnapshotService.to.probeVacuumInto(
        sourcePath: dbPath,
        opener: ffiOpen,
      );
      expect(
        supported,
        isTrue,
        reason:
            '本地 ffi SQLite 支持 VACUUM INTO；真机 SQLCipher 能力'
            '由 WP7 实测（本断言不构成真机证明）',
      );
    });
  });
}
