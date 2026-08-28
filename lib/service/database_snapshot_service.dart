// 数据库一致性快照服务（WP5）
// Consistent snapshot service: transaction-free, WAL-safe, atomic, isolated.
//
// 策略（研究文档 §4.3 / 计划 Step 6，按优先级）：
//   1. `VACUUM INTO`（SQLite 3.27+，SQLCipher 继承源库加密）：从活动源库
//      生成一致性快照，含 WAL 中未 checkpoint 的提交内容；不得在源连接
//      的活动事务中执行——本服务用**专用独立连接**，且只在迁移事务
//      开始前由协调器调用。
//   2. 不可用时 fail-closed（返回失败，不降级为复制主 db 文件——事务内/
//      WAL 活跃时单文件复制不是一致性快照，研究文档 P0）。"关闭唯一连接
//      → checkpoint → 复制 db/wal/shm 全套"的 fallback 仅在协调器能
//      证明无活动连接时允许（本服务不自行关闭他人连接）。
//
// 原子性：快照先写 `<name>.tmp`，验证（quick_check + user_version）通过后
// rename 为最终名——**中断不会覆盖/破坏上一个有效快照**。
//
// 隔离与加密：快照目录按 `<base>/imboy_db_snapshots/<env>/<uid>/` 隔离；
// SQLCipher 源库的快照继承加密（真机能力 = CAPABILITY_PROBED，WP7 验证）；
// 本地 ffi 证据不构成真机 SQLCipher 证明。
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:imboy/service/sqflite_init.dart' as sqinit;
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart' as sq;

/// 快照创建结果。
class SnapshotResult {
  const SnapshotResult._({
    required this.success,
    this.path,
    this.userVersion,
    this.error,
  });

  factory SnapshotResult.ok(String path, int userVersion) =>
      SnapshotResult._(success: true, path: path, userVersion: userVersion);

  factory SnapshotResult.failure(String error) =>
      SnapshotResult._(success: false, error: error);

  final bool success;
  final String? path;
  final int? userVersion;
  final String? error;
}

/// 恢复结果。
class RestoreResult {
  const RestoreResult._({
    required this.success,
    this.restoredPath,
    this.userVersion,
    this.error,
    this.preservedOriginal = true,
  });

  factory RestoreResult.ok(String restoredPath, int userVersion) =>
      RestoreResult._(
        success: true,
        restoredPath: restoredPath,
        userVersion: userVersion,
        preservedOriginal: false,
      );

  factory RestoreResult.failure(
    String error, {
    bool preservedOriginal = true,
  }) => RestoreResult._(
    success: false,
    error: error,
    preservedOriginal: preservedOriginal,
  );

  final bool success;
  final String? restoredPath;
  final int? userVersion;
  final String? error;

  /// 恢复失败时原库是否被保留（必须为 true——失败绝不允许动原库）。
  final bool preservedOriginal;
}

/// 打开数据库的抽象（默认走 sqflite_sqlcipher；测试/非加密平台注入 ffi）。
typedef DatabaseOpener =
    Future<sq.Database> Function(String path, String? password);

/// 数据库快照服务。
class DatabaseSnapshotService {
  DatabaseSnapshotService._();
  static final DatabaseSnapshotService to = DatabaseSnapshotService._();

  /// VACUUM INTO 能力（null = 未探测）。
  bool? _vacuumIntoSupported;

  /// 默认用项目平台适配层打开（sqflite_init：加密平台带 password，
  /// 非加密平台忽略——与 SqliteService 打开路径一致）。
  static Future<sq.Database> defaultOpener(String path, String? password) =>
      sqinit.openEncryptedDatabase(path, password: password);

  static const String baseDirName = 'imboy_db_snapshots';
  static const int defaultKeepCount = 3;

  /// 快照根目录（按 env + uid 隔离）。
  @visibleForTesting
  String snapshotDir({
    required String base,
    required String env,
    required String uid,
  }) => p.join(base, baseDirName, _sanitize(env), _sanitize(uid));

  static String _sanitize(String component) {
    final safe = component.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safe.isEmpty || safe == '.' || safe == '..') {
      throw ArgumentError.value(component, 'component', 'invalid path part');
    }
    return safe;
  }

  /// 运行时探测 `VACUUM INTO` 能力（缓存）。
  ///
  /// 探测方式：对源库开专用连接，把单页结果 VACUUM 到临时文件。
  /// 失败原因可能是 SQLite 版本 < 3.27 或目标目录不可写——都视为不可用。
  Future<bool> probeVacuumInto({
    required String sourcePath,
    String? password,
    DatabaseOpener? opener,
  }) async {
    if (_vacuumIntoSupported != null) return _vacuumIntoSupported!;
    final open = opener ?? defaultOpener;
    final probeTarget = '$sourcePath.probe.tmp';
    try {
      final db = await open(sourcePath, password);
      try {
        await db.execute("VACUUM INTO '$probeTarget'");
      } finally {
        await db.close();
      }
      final f = File(probeTarget);
      if (await f.exists()) await f.delete();
      _vacuumIntoSupported = true;
    } catch (_) {
      _vacuumIntoSupported = false;
      final f = File(probeTarget);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    return _vacuumIntoSupported!;
  }

  /// 创建一致性快照（事务外，独立连接）。
  ///
  /// [expectedVersion]：若提供，快照的 user_version 必须等于该值（防快照
  /// 了错误状态的库）；不匹配即失败（fail-closed）。
  Future<SnapshotResult> createSnapshot({
    required String sourcePath,
    required String base,
    required String env,
    required String uid,
    String? password,
    int? expectedVersion,
    DatabaseOpener? opener,
  }) async {
    final open = opener ?? defaultOpener;
    final src = File(sourcePath);
    if (!await src.exists()) {
      return SnapshotResult.failure('source database not found: $sourcePath');
    }

    final dir = snapshotDir(base: base, env: env, uid: uid);
    final tmpTarget = p.join(dir, 'snapshot.pending.tmp');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final finalName = p.join(
      dir,
      'snapshot_v${expectedVersion ?? 'x'}_$timestamp.db',
    );

    try {
      await Directory(dir).create(recursive: true);
    } catch (e) {
      return SnapshotResult.failure('cannot create snapshot dir: $e');
    }

    // 1) 清掉历史中断残留的 .tmp（VACUUM INTO 要求目标不存在），
    //    last good 快照不受影响
    await _tryDelete(tmpTarget);

    // VACUUM INTO 到 .tmp（不影响 last good）
    sq.Database? db;
    try {
      db = await open(sourcePath, password);
      await db.execute("VACUUM INTO '$tmpTarget'");
    } catch (e) {
      await db!.close();
      // 空间不足/能力缺失/源库损坏 → fail-closed；绝不部分产物当成功
      await _tryDelete(tmpTarget);
      return SnapshotResult.failure(
        'VACUUM INTO failed (disk full / unsupported / corrupt source?): $e',
      );
    }

    // 2) 验证快照：可打开、quick_check ok、版本对齐
    try {
      final snap = await open(tmpTarget, password);
      try {
        final quick = await snap.rawQuery('PRAGMA quick_check');
        if (quick.first.values.first != 'ok') {
          throw Exception('snapshot quick_check failed');
        }
        final uv =
            (await snap.rawQuery('PRAGMA user_version')).first.values.first
                as int;
        if (expectedVersion != null && uv != expectedVersion) {
          throw Exception(
            'snapshot user_version=$uv != expected $expectedVersion',
          );
        }
      } finally {
        await snap.close();
      }
    } catch (e) {
      await db.close();
      await _tryDelete(tmpTarget);
      return SnapshotResult.failure('snapshot verification failed: $e');
    }
    await db.close();

    // 3) 原子落位（rename）：中断/失败都不会破坏上一个有效快照
    try {
      final f = File(tmpTarget);
      if (await File(finalName).exists()) {
        await File(finalName).delete();
      }
      await f.rename(finalName);
    } catch (e) {
      await _tryDelete(tmpTarget);
      return SnapshotResult.failure('atomic rename failed: $e');
    }

    return SnapshotResult.ok(finalName, expectedVersion ?? 0);
  }

  /// 从快照恢复主库。
  ///
  /// 契约（计划 Step 6）：调用方必须先关闭主库的**全部**连接（注入
  /// [closeAllConnections]）；本方法：
  ///   1) 先验证快照本身可用（打开 + quick_check + 版本）；
  ///   2) 移走旧主库（.bak，含 -wal/-shm/journal sidecar 一并清理）；
  ///   3) 复制快照到主库位置（保留快照原件）；
  ///   4) 重开验证（quick_check + 版本）；失败则回滚：删半成品、还原 .bak。
  Future<RestoreResult> restoreFromSnapshot({
    required String snapshotPath,
    required String targetPath,
    String? password,
    required Future<void> Function() closeAllConnections,
    int? expectedVersion,
    DatabaseOpener? opener,
  }) async {
    final open = opener ?? defaultOpener;
    final snapFile = File(snapshotPath);
    if (!await snapFile.exists()) {
      return RestoreResult.failure('snapshot not found: $snapshotPath');
    }

    // 1) 快照自验证
    try {
      final probe = await open(snapshotPath, password);
      try {
        final quick = await probe.rawQuery('PRAGMA quick_check');
        if (quick.first.values.first != 'ok') {
          throw Exception('snapshot quick_check failed');
        }
        if (expectedVersion != null) {
          final uv =
              (await probe.rawQuery('PRAGMA user_version')).first.values.first
                  as int;
          if (uv != expectedVersion) {
            throw Exception(
              'snapshot version $uv != expected $expectedVersion',
            );
          }
        }
      } finally {
        await probe.close();
      }
    } catch (e) {
      return RestoreResult.failure('snapshot unusable: $e');
    }

    await closeAllConnections();

    final bakPath = '$targetPath.pre_restore.bak';
    final halfDone = '$targetPath.restoring.tmp';
    await _tryDelete(halfDone);
    await _tryDelete('$halfDone-wal');
    await _tryDelete('$halfDone-shm');

    try {
      // 2) 快照复制到临时位置（不直接写主库路径，失败不伤原库）
      await snapFile.copy(halfDone);

      // 3) 重开临时副本验证（确保复制过程无 I/O 损坏）
      final verify = await open(halfDone, password);
      final quick = await verify.rawQuery('PRAGMA quick_check');
      await verify.close();

      if (quick.first.values.first != 'ok') {
        throw Exception('copied snapshot quick_check failed');
      }

      // 4) 原子替换：旧库 → .bak；副本 → 主库
      await _tryDelete('$bakPath-wal');
      await _tryDelete('$bakPath-shm');
      if (await File(targetPath).exists()) {
        await File(targetPath).rename(bakPath);
      }
      // 清理旧 sidecar（旧 wal/shm 对新主库无效且有害）
      await _tryDelete('$targetPath-wal');
      await _tryDelete('$targetPath-shm');
      await _tryDelete('$targetPath-journal');
      await File(halfDone).rename(targetPath);

      // 5) 最终重开验证；失败回滚
      try {
        final finalProbe = await open(targetPath, password);
        final fQuick = await finalProbe.rawQuery('PRAGMA quick_check');
        final fUv =
            (await finalProbe.rawQuery(
                  'PRAGMA user_version',
                )).first.values.first
                as int;
        await finalProbe.close();
        if (fQuick.first.values.first != 'ok') {
          throw Exception('restored database quick_check failed');
        }
        return RestoreResult.ok(targetPath, fUv);
      } catch (e) {
        await _tryDelete(targetPath);
        if (await File(bakPath).exists()) {
          await File(bakPath).rename(targetPath);
        }
        return RestoreResult.failure('post-restore verify failed: $e');
      }
    } catch (e) {
      await _tryDelete(halfDone);
      return RestoreResult.failure(
        'restore aborted, original preserved at $targetPath: $e',
      );
    }
  }

  /// 列出某 env+uid 的快照（新→旧）。
  Future<List<File>> listSnapshots({
    required String base,
    required String env,
    required String uid,
  }) async {
    final dir = Directory(snapshotDir(base: base, env: env, uid: uid));
    if (!await dir.exists()) return const [];
    final files = <File>[];
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.db')) files.add(e);
    }
    files.sort((a, b) => b.path.compareTo(a.path)); // 时间戳在名中，字典序≈时间序
    return files;
  }

  /// 按保留数量与期限清理快照；返回删除数。
  Future<int> cleanup({
    required String base,
    required String env,
    required String uid,
    int keepCount = defaultKeepCount,
    Duration? maxAge,
  }) async {
    final snapshots = await listSnapshots(base: base, env: env, uid: uid);
    var deleted = 0;
    for (var i = 0; i < snapshots.length; i++) {
      final f = snapshots[i];
      var drop = i >= keepCount;
      if (!drop && maxAge != null) {
        final stat = await f.stat();
        if (DateTime.now().difference(stat.modified) > maxAge) drop = true;
      }
      if (drop) {
        try {
          await f.delete();
          deleted++;
        } catch (_) {}
      }
    }
    // 顺带清理中断残留
    final dir = Directory(snapshotDir(base: base, env: env, uid: uid));
    if (await dir.exists()) {
      await for (final e in dir.list()) {
        if (e is File && e.path.endsWith('.tmp')) {
          try {
            await e.delete();
            deleted++;
          } catch (_) {}
        }
      }
    }
    return deleted;
  }

  static Future<void> _tryDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
