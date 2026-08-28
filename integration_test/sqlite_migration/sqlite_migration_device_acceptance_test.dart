/// WP7 Android/iOS 真机 SQLite 迁移/降级/快照自动验收（自主命名空间）。
///
/// 执行前提（用户确认后才可运行，见同目录 README.md 的确认门清单）：
/// 需要真实设备执行；不登录、不连后端、不触碰任何真实账号数据库——
/// 全部文件使用合成 uid 命名空间（wp7_device_selftest / imboy_wp7_ 前缀
/// 临时目录），只增删自己创建的文件。
///
/// 覆盖（docs/sqlite-migration-test-matrix.md §6 中可自动化部分）：
///   STEP1  baseline→v31 与逐级→v31 两路径在真机引擎上 fingerprint 收敛
///   STEP2  生产式升级验证全链（invariant + 完整性 + meta + application_id）
///   STEP3  WAL 未 checkpoint 数据进一致性快照；SQLCipher 加密继承
///          （快照文件头不再含明文 SQLite magic）
///   STEP4  唯一受支持降级窗口 v31→v30 成功且数据影响与 manifest 一致
///   STEP5  不可逆边 30→29 被拒绝：打开失败、原库原样
///   STEP6  快照灾难恢复：主库损坏后按"先关全部连接"协议复原
///
/// 不覆盖（人工步骤，见 README）：旧版安装包安装与旧 App 自身建样、
/// kill -9 真杀进程重放、跨 App 版本的真机回滚——这些是 PARTIAL→PASS
/// 的最后缺口。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/service/database_migration_orchestrator.dart';
import 'package:imboy/service/database_snapshot_service.dart';
import 'package:imboy/service/embedded_schema_scripts.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/schema_contract.dart';
import 'package:imboy/service/schema_fingerprint.dart';
import 'package:imboy/service/sqflite_init.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

const _uid = 'wp7_device_selftest';
const _env = 'selftest';

/// 合成密钥（仅本测试沙箱），不含任何真实凭据。
const _password = 'wp7-synthetic-key-material'; // gitleaks:allow

typedef VersionChangeStep =
    Future<void> Function(Database db, int oldVsn, int newVsn);

Directory? _sandbox;

Future<String> _sandboxRoot() async {
  _sandbox ??= await Directory.systemTemp.createTemp('imboy_wp7_');
  return _sandbox!.path;
}

/// 隔离打开（singleInstance:false），避免同名路径复用共享连接导致
/// 快照探测的内部 close 影响测试持有的句柄。加密平台经 password 走
/// SQLCipher，非加密平台由工厂忽略该参数（与生产 _initDatabase 同语义）。
Future<Database> openIso(
  String path, {
  String? password,
  int? version,
  VersionChangeStep? onUpgrade,
  VersionChangeStep? onDowngrade,
}) => openDatabase(
  path,
  password: isEncryptionSupported ? password : null,
  version: version,
  singleInstance: false,
  onUpgrade: onUpgrade == null ? null : (db, o, n) => onUpgrade(db, o, n),
  onDowngrade: onDowngrade == null ? null : (db, o, n) => onDowngrade(db, o, n),
);

/// 生产迁移语义封装：把 migrate 包进数据库自带事务（等价 sqflite 版本
/// 回调的事务上下文），失败向上抛触发回滚。
Future<void> migrateInTransaction(
  Database db, {
  required int from,
  required int to,
  required bool isUpgrade,
}) async {
  await db.transaction((txn) async {
    final result = await MigrationService.to.migrate(
      db: txn,
      fromVersion: from,
      toVersion: to,
      isUpgrade: isUpgrade,
    );
    if (!result.success) throw Exception('migrate failed: ${result.error}');
  });
}

/// 与生产 _onCreate 相同的 baseline 执行语义（事务内）。
Future<void> applyBaseline(DatabaseExecutor db) async {
  for (final sql
      in kBaselineSchemaSql
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && !s.startsWith('--'))) {
    if (sql.toLowerCase().contains('sqlite_')) continue;
    try {
      await db.execute(sql);
    } catch (e) {
      if (!e.toString().toLowerCase().contains('already exists')) rethrow;
    }
  }
}

void _evidence(String step, Map<String, Object?> kv) {
  final pairs = kv.entries.map((e) => '${e.key}=${e.value}').join(' ');
  // ignore: avoid_print
  print('[WP7-EVIDENCE] step=$step $pairs');
}

/// baseline(16) → v31（经 manifest 单段迁移，事务内，等价生产升级语义）。
Future<void> upgradeTo31(Database db) async {
  await db.execute('PRAGMA user_version = 16');
  await db.transaction((txn) async {
    final r = await MigrationService.to.migrate(
      db: txn,
      fromVersion: 16,
      toVersion: 31,
      isUpgrade: true,
    );
    if (!r.success) throw Exception(r.error);
  });
}

/// baseline(16) → v30。
Future<void> upgradeTo30(Database db) async {
  await db.execute('PRAGMA user_version = 16');
  await db.transaction((txn) async {
    final r = await MigrationService.to.migrate(
      db: txn,
      fromVersion: 16,
      toVersion: 30,
      isUpgrade: true,
    );
    if (!r.success) throw Exception(r.error);
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(() async {
    final dir = _sandbox;
    if (dir != null && dir.existsSync()) {
      // 只删除本测试自己的临时目录（imboy_wp7_ 前缀），绝不触碰其他文件
      _evidence('cleanup', {'deleting_sandbox': dir.path});
      await dir.delete(recursive: true);
    }
  });

  test('STEP1+2 升级双路径收敛 + 生产式升级验证全链', () async {
    final root = await _sandboxRoot();
    final freshPath = '$root/fresh31.db';
    final stepPath = '$root/step31.db';
    _evidence('prep', {'engine': 'device', 'root': root});

    // 路径 A：fresh = baseline(16) → 16→31 单段迁移
    final a = await openIso(freshPath, password: _password);
    await applyBaseline(a);
    await a.execute('PRAGMA user_version = 16');
    await migrateInTransaction(a, from: 16, to: 31, isUpgrade: true);
    final fpA = await SchemaFingerprint.compute(a);

    // 路径 B：baseline(16) 后逐级单跳到 31
    final b = await openIso(stepPath, password: _password);
    await applyBaseline(b);
    await b.execute('PRAGMA user_version = 16');
    for (var v = 17; v <= 31; v++) {
      await migrateInTransaction(b, from: v - 1, to: v, isUpgrade: true);
    }
    final fpB = await SchemaFingerprint.compute(b);

    expect(fpA, equals(fpB), reason: '真机引擎上 fresh 与逐级升级必须结构收敛');
    expect(await SchemaContract.verifyInvariants(b, version: 31), isEmpty);
    _evidence('step1', {'fingerprint': fpA, 'paths': 2, 'converged': true});

    // STEP2：生产式验证全链（invariant + quick/fk + meta + application_id）
    final verify = await DatabaseMigrationOrchestrator.to.verifyAfterMigration(
      b,
      toVersion: 31,
      migrationId: 'device_step2_v31',
    );
    expect(verify.ok, isTrue, reason: verify.violations.join('; '));
    final meta = await ImboySchemaMeta.readAll(b);
    expect(meta[ImboySchemaMeta.keySchemaVersion], equals('31'));
    expect(meta[ImboySchemaMeta.keyMigrationState], equals('ok'));
    final appIdRow = await b.rawQuery('PRAGMA application_id');
    final appId = appIdRow.first.values.first as int;
    expect(appId, equals(kImboyApplicationId));
    final uv = (await b.rawQuery('PRAGMA user_version')).first.values.first;
    expect(uv, equals(31));
    _evidence('step2', {
      'meta_state': meta[ImboySchemaMeta.keyMigrationState],
      'application_id': '0x${appId.toRadixString(16)}',
      'user_version': uv,
    });
    await a.close();
    await b.close();
  });

  test('STEP3 WAL 活跃数据一致性快照 + SQLCipher 加密继承', () async {
    final root = await _sandboxRoot();
    final dbPath = '$root/wal31.db';
    final db = await openIso(dbPath, password: _password);
    await db.transaction((txn) => applyBaseline(txn));
    await upgradeTo31(db);

    // Android SQLite 通道禁止 execute 跑 PRAGMA（生产 F-01 同款约束），
    // journal 切换用 rawQuery；设备不支持时降级为证据注记而非失败。
    var mode = 'unavailable';
    try {
      final r = await db.rawQuery('PRAGMA journal_mode = WAL');
      mode = r.first.values.first?.toString() ?? 'unavailable';
    } catch (e) {
      mode = 'error:${e.toString().split('(').first.trim()}';
    }
    await db.execute(
      'CREATE TABLE IF NOT EXISTS wp7_probe '
      '(id INTEGER PRIMARY KEY, tag TEXT)',
    );
    await db.insert('wp7_probe', {'id': 1, 'tag': 'in-wal-row'});
    _evidence('step3_wal', {'journal_mode': mode});

    final snap = await DatabaseSnapshotService.to.createSnapshot(
      sourcePath: dbPath,
      base: root,
      env: _env,
      uid: _uid,
      password: _password,
      expectedVersion: 31,
    );
    expect(snap.success, isTrue, reason: snap.error);
    await db.close();

    // 快照必须包含未 checkpoint 的提交行（一致性证据）
    final snapDb = await openIso(snap.path!, password: _password);
    final rows = await snapDb.query('wp7_probe');
    expect(
      rows.map((r) => r['tag']),
      contains('in-wal-row'),
      reason: 'WAL 未 checkpoint 的提交必须进快照',
    );
    await snapDb.close();
    _evidence('step3_snapshot', {
      'file': File(snap.path!).uri.pathSegments.last,
      'containsWalRow': true,
    });

    // 加密继承：加密平台上快照头不得出现明文 SQLite magic。
    // 非加密平台记为 CAPABILITY_PROBED_OFF 后跳过断言。
    final headBytes = <int>[];
    await for (final chunk in File(snap.path!).openRead(0, 16)) {
      headBytes.addAll(chunk);
    }
    final magic = String.fromCharCodes(headBytes.take(15));
    if (isEncryptionSupported) {
      expect(
        magic,
        isNot(equals('SQLite format 3')),
        reason: 'SQLCipher 快照不得是明文头（加密继承证据）',
      );
      _evidence('step3_cipher', {
        'encryptedInherited': true,
        'headerMagicAbsent': true,
      });
    } else {
      _evidence('step3_cipher', {
        'platformEncryption': false,
        'note': 'CAPABILITY_PROBED_OFF',
      });
    }
  });

  test('STEP4 唯一受支持降级窗口 v31→v30：成功且数据影响与 manifest 声明一致', () async {
    final root = await _sandboxRoot();
    final dbPath = '$root/down30.db';
    // 构建真实 v31 库（baseline→31），再注入 v31 形态样本
    var db = await openIso(dbPath, password: _password);
    await db.transaction((txn) => applyBaseline(txn));
    await upgradeTo31(db);
    await db.insert('channel', {
      'id': 42,
      'name': 'synthetic-channel-001',
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
      'conversation_uk3': 'synthetic-keep',
      'payload': '{"synthetic":true}',
      'created_at': 1,
      'type': 'C2C',
    });
    await db.close();

    var verified = false;
    db = await openIso(
      dbPath,
      password: _password,
      version: 30,
      onDowngrade: (txn, oldV, newV) async {
        final r = await MigrationService.to.migrate(
          db: txn,
          fromVersion: oldV,
          toVersion: newV,
          isUpgrade: false,
        );
        if (!r.success) throw Exception(r.error);
        final v = await DatabaseMigrationOrchestrator.to.verifyAfterMigration(
          txn,
          toVersion: newV,
        );
        if (!v.ok) throw Exception(v.violations.join('; '));
        verified = true;
      },
    );
    expect(verified, isTrue);
    final uv = (await db.rawQuery('PRAGMA user_version')).first.values.first;
    expect(uv, equals(30));

    // 数据断言：消息保留；权限列按 dataLoss 声明丢弃；type 兼容列保留
    final msg = await db.query('msg_c2c', where: 'id = ?', whereArgs: [7]);
    expect(msg, isNotEmpty);
    final cols = (await db.rawQuery(
      'PRAGMA table_info("channel")',
    )).map((r) => r['name']).toSet();
    expect(
      cols.contains('visibility'),
      isFalse,
      reason: 'manifest dataLoss=true：v31 权限列在降级中丢弃',
    );
    expect(cols.contains('type'), isTrue);
    expect(await SchemaContract.verifyInvariants(db, version: 30), isEmpty);
    _evidence('step4', {
      'downgrade': '31->30',
      'verified': true,
      'messageKept': true,
      'visibilityDropped': true,
    });
    await db.close();
  });

  test('STEP5 不可逆边 30→29 被拒绝：打开失败、原库原样', () async {
    final root = await _sandboxRoot();
    final dbPath = '$root/reject29.db';
    var db = await openIso(dbPath, password: _password);
    await db.transaction((txn) => applyBaseline(txn));
    await upgradeTo30(db);
    await db.insert('msg_c2c', {
      'id': 8,
      'conversation_uk3': 'keep-me',
      'payload': '{"synthetic":true}',
      'created_at': 1,
      'type': 'C2C',
    });
    await db.close();

    Object? rejected;
    try {
      final bad = await openIso(
        dbPath,
        password: _password,
        version: 29,
        onDowngrade: (txn, oldV, newV) async {
          final r = await MigrationService.to.migrate(
            db: txn,
            fromVersion: oldV,
            toVersion: newV,
            isUpgrade: false,
          );
          if (!r.success) {
            rejected = r.error;
            throw Exception('blocked by policy');
          }
        },
      );
      await bad.close();
    } catch (_) {
      rejected ??= 'open-threw(fail-closed)';
    }
    expect(rejected, isNotNull, reason: '30→29 必须 fail-closed 拒绝');

    // 原库以原版本重新打开完好
    final after = await openIso(dbPath, password: _password, version: 30);
    final uv = (await after.rawQuery('PRAGMA user_version')).first.values.first;
    expect(uv, equals(30), reason: '被拒降级不得推进 user_version');
    final row = await after.query('msg_c2c', where: 'id = ?', whereArgs: [8]);
    expect(row, isNotEmpty);
    _evidence('step5', {
      'edge': '30->29',
      'rejected': true,
      'originalIntact': true,
    });
    await after.close();
  });

  test('STEP6 快照灾难恢复：主库损坏后按"先关全部连接"协议复原', () async {
    final root = await _sandboxRoot();
    final dbPath = '$root/crash.db';

    // 建 v30 库并做迁移前快照
    var db = await openIso(dbPath, password: _password);
    await db.transaction((txn) => applyBaseline(txn));
    await upgradeTo30(db);
    await db.insert('msg_c2c', {
      'id': 9,
      'conversation_uk3': 'pre-crash',
      'payload': '{"synthetic":true}',
      'created_at': 1,
      'type': 'C2C',
    });
    final snap = await DatabaseSnapshotService.to.createSnapshot(
      sourcePath: dbPath,
      base: root,
      env: _env,
      uid: _uid,
      password: _password,
      expectedVersion: 30,
    );
    expect(snap.success, isTrue, reason: snap.error);
    await db.close(); // 恢复协议第一步：全部连接已关闭

    // 主库损坏（模拟迁移失败后的最坏情况）
    await File(dbPath).writeAsBytes([0x00, 0xff, 0x11, 0x22]);

    final restore = await DatabaseSnapshotService.to.restoreFromSnapshot(
      snapshotPath: snap.path!,
      targetPath: dbPath,
      password: _password,
      closeAllConnections: () async {},
      expectedVersion: 30,
    );
    expect(restore.success, isTrue, reason: restore.error);

    final back = await openIso(dbPath, password: _password);
    final row = await back.query(
      'msg_c2c',
      where: 'conversation_uk3 = ?',
      whereArgs: ['pre-crash'],
    );
    expect(row, isNotEmpty);
    final uv = (await back.rawQuery('PRAGMA user_version')).first.values.first;
    expect(uv, equals(30));
    _evidence('step6', {'restoredVersion': uv, 'dataPreserved': true});
    await back.close();
  });
}
