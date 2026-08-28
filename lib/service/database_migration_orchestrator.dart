// 数据库迁移协调器（WP5）
// Migration orchestrator: preflight → transaction-free consistent snapshot →
// (caller opens & migrates) → post-migration verification + schema meta.
//
// 职责边界（计划 Step 6）：
//   - prepareForOpen：在 sqflite 版本迁移事务**开始前**执行预检（quick/
//     foreign key check、user_version、未同步 outbox 阻塞检查）并创建
//     一致性快照（DatabaseSnapshotService，VACUUM INTO）。任何失败都
//     fail-closed——绝不"跳过快照继续迁移"。
//   - verifyAfterMigration：迁移事务成功末尾调用（onUpgrade/onDowngrade
//     回调内，仍在事务中）。关键 invariant + quick/fk check +
//     _imboy_schema_meta 写入；失败抛出让 sqflite 回滚且版本号不推进。
//   - restoreFromSnapshot：灾难恢复入口（调用方负责关连接），转发快照
//     服务并在恢复后做 application_id/version/hash 校验。
//
// 证据边界：本地 ffi 证据不构成真机 SQLCipher/生产证明；Android/iOS 的
// VACUUM INTO 与加密继承能力标记 CAPABILITY_PROBED，真机验证在 WP7。
library;

import 'dart:io';

import 'package:sqflite_sqlcipher/sqflite.dart' as sq;

import 'package:imboy/service/database_snapshot_service.dart';
import 'package:imboy/service/schema_contract.dart';
import 'package:imboy/service/schema_fingerprint.dart';

/// 打开前协调决策。
class PreMigrationDecision {
  const PreMigrationDecision._({
    required this.proceed,
    this.migrationNeeded = false,
    this.currentVersion,
    this.snapshotPath,
    this.abortReason,
    this.blockers = const [],
  });

  /// false = fail-closed，调用方不得打开数据库进行迁移。
  final bool proceed;

  /// 是否需要版本迁移（当前 user_version != target）。
  final bool migrationNeeded;

  final int? currentVersion;

  /// 迁移前一致性快照路径（仅迁移场景且快照成功时非空）。
  final String? snapshotPath;

  final String? abortReason;

  /// 阻塞项描述（如未同步 outbox 清单）。
  final List<String> blockers;
}

/// 迁移后验证结果。
class PostMigrationVerification {
  const PostMigrationVerification._({
    required this.ok,
    this.fingerprint,
    this.violations = const [],
  });

  factory PostMigrationVerification.ok(String fingerprint) =>
      PostMigrationVerification._(ok: true, fingerprint: fingerprint);

  factory PostMigrationVerification.failed(List<String> violations) =>
      PostMigrationVerification._(ok: false, violations: violations);

  final bool ok;
  final String? fingerprint;
  final List<String> violations;
}

/// 迁移协调器。
class DatabaseMigrationOrchestrator {
  DatabaseMigrationOrchestrator._();
  static final DatabaseMigrationOrchestrator to =
      DatabaseMigrationOrchestrator._();

  final DatabaseSnapshotService _snapshots = DatabaseSnapshotService.to;

  /// 打开前预检 + 一致性快照。
  ///
  /// [unsyncedOutboxProbe]：返回未同步 outbox 描述清单（空=无阻塞）。
  /// 降级场景存在未同步 outbox 时禁止迁移（防未同步数据丢失）；
  /// 升级场景不阻塞（升级不删数据）。
  Future<PreMigrationDecision> prepareForOpen({
    required String dbPath,
    required String baseDir,
    required String env,
    required String uid,
    required int targetVersion,
    String? password,
    DatabaseOpener? opener,
    Future<List<String>> Function()? unsyncedOutboxProbe,
  }) async {
    final open = opener ?? DatabaseSnapshotService.defaultOpener;

    // 新库：无预检/快照必要（onCreate 建库路径）
    if (!File(dbPath).existsSync()) {
      return const PreMigrationDecision._(
        proceed: true,
        migrationNeeded: true,
        currentVersion: 0,
      );
    }

    // 预检：独立连接只读检查（不在任何迁移事务中）
    final preflight = await _preflight(
      dbPath: dbPath,
      password: password,
      opener: open,
    );
    if (preflight == null) {
      return const PreMigrationDecision._(
        proceed: false,
        abortReason:
            'preflight failed: quick_check/foreign_key_check not ok '
            'or database unreadable (corrupt / wrong key)',
      );
    }
    final versionRows = await preflight.rawQuery('PRAGMA user_version');
    final currentVersion = versionRows.first.values.first as int;

    if (currentVersion == targetVersion) {
      await preflight.close();
      return PreMigrationDecision._(
        proceed: true,
        migrationNeeded: false,
        currentVersion: currentVersion,
      );
    }

    // 需要迁移（升或降）。降级 + 未同步 outbox → 阻塞
    final isDowngrade = currentVersion > targetVersion;
    if (isDowngrade && unsyncedOutboxProbe != null) {
      final blockers = await unsyncedOutboxProbe();
      if (blockers.isNotEmpty) {
        await preflight.close();
        return PreMigrationDecision._(
          proceed: false,
          currentVersion: currentVersion,
          abortReason: 'downgrade blocked: unsynced outbox present',
          blockers: blockers,
        );
      }
    }
    await preflight.close();

    // 事务外一致性快照（fail-closed：失败不迁移）
    final snap = await _snapshots.createSnapshot(
      sourcePath: dbPath,
      base: baseDir,
      env: env,
      uid: uid,
      password: password,
      expectedVersion: currentVersion,
      opener: opener,
    );
    if (!snap.success) {
      return PreMigrationDecision._(
        proceed: false,
        currentVersion: currentVersion,
        abortReason: 'consistent snapshot failed (fail-closed): ${snap.error}',
      );
    }

    return PreMigrationDecision._(
      proceed: true,
      migrationNeeded: true,
      currentVersion: currentVersion,
      snapshotPath: snap.path,
    );
  }

  /// 迁移后验证（仍在迁移事务内；失败必须抛给 sqflite 回滚）。
  ///
  /// [expectedFingerprint]：提供则强校验（测试用 golden）；生产传 null
  /// 时仅校验 invariant + 完整性并写入 meta（hash 记录供后续比对）。
  Future<PostMigrationVerification> verifyAfterMigration(
    sq.DatabaseExecutor db, {
    required int toVersion,
    String? migrationId,
    String? expectedFingerprint,
  }) async {
    final violations = <String>[];

    // 1) 完整性
    final quick = await db.rawQuery('PRAGMA quick_check');
    if (quick.first.values.first != 'ok') {
      violations.add('quick_check: ${quick.first.values.first}');
    }
    final fk = await db.rawQuery('PRAGMA foreign_key_check');
    if (fk.isNotEmpty) {
      violations.add('foreign_key_check violations: ${fk.length}');
    }

    // 2) 关键业务 invariant（代码内声明清单）
    violations.addAll(
      await SchemaContract.verifyInvariants(db, version: toVersion),
    );

    // 3) 指纹（记录 + 可选强校验）
    final fingerprint = await SchemaFingerprint.compute(db);
    if (expectedFingerprint != null && fingerprint != expectedFingerprint) {
      violations.add(
        'fingerprint mismatch: got $fingerprint expected $expectedFingerprint',
      );
    }

    if (violations.isNotEmpty) {
      return PostMigrationVerification.failed(violations);
    }

    // 4) meta 写入（版本/hash/迁移 ID/状态）——事务内，回滚安全
    await ImboySchemaMeta.write(db, {
      ImboySchemaMeta.keySchemaVersion: '$toVersion',
      ImboySchemaMeta.keySchemaHash: fingerprint,
      ImboySchemaMeta.keyLastMigrationId: ?migrationId,
      ImboySchemaMeta.keyMigrationState: 'ok',
    });

    // 5) application_id 契约（幂等写入；库身份标记）
    await db.execute('PRAGMA application_id = $kImboyApplicationId');

    return PostMigrationVerification.ok(fingerprint);
  }

  /// 灾难恢复：从最新有效快照恢复（调用方保证可关闭全部连接）。
  Future<RestoreResult> restoreLatest({
    required String dbPath,
    required String baseDir,
    required String env,
    required String uid,
    String? password,
    required Future<void> Function() closeAllConnections,
    DatabaseOpener? opener,
    int? expectedVersion,
  }) async {
    final snaps = await _snapshots.listSnapshots(
      base: baseDir,
      env: env,
      uid: uid,
    );
    if (snaps.isEmpty) {
      return RestoreResult.failure('no snapshots available for $env/$uid');
    }
    return _snapshots.restoreFromSnapshot(
      snapshotPath: snaps.first.path,
      targetPath: dbPath,
      password: password,
      closeAllConnections: closeAllConnections,
      expectedVersion: expectedVersion,
      opener: opener,
    );
  }

  /// 迁移成功后收尾：按保留策略清理快照。
  Future<int> postMigrationCleanup({
    required String baseDir,
    required String env,
    required String uid,
    int keepCount = DatabaseSnapshotService.defaultKeepCount,
    Duration maxAge = const Duration(days: 14),
  }) => _snapshots.cleanup(
    base: baseDir,
    env: env,
    uid: uid,
    keepCount: keepCount,
    maxAge: maxAge,
  );

  Future<sq.Database?> _preflight({
    required String dbPath,
    String? password,
    required DatabaseOpener opener,
  }) async {
    try {
      final db = await opener(dbPath, password);
      final quick = await db.rawQuery('PRAGMA quick_check');
      if (quick.first.values.first != 'ok') {
        await db.close();
        return null;
      }
      final fk = await db.rawQuery('PRAGMA foreign_key_check');
      if (fk.isNotEmpty) {
        await db.close();
        return null;
      }
      return db;
    } catch (_) {
      return null; // 打不开（密钥错/损坏）= fail-closed
    }
  }
}
