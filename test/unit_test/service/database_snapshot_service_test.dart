// WP5 快照服务测试（本地 ffi 文件库证据）
// Snapshot service tests: WAL consistency, atomicity, isolation, restore.
//
// 证据边界：sqflite_common_ffi 本地文件库；不构成真机 SQLCipher
// （快照加密继承）或生产环境证明——该能力为 CAPABILITY_PROBED（WP7）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/service/database_snapshot_service.dart';

Future<Database> openFileDb(String path) => databaseFactory.openDatabase(
  path,
  options: OpenDatabaseOptions(singleInstance: false),
);

Future<Database> ffiOpen(String path, String? password) =>
    databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );

class _RestoreProbe implements Database {
  _RestoreProbe(this.delegate, {this.failingQuery, this.onClose}) {
    addTearDown(() async {
      if (delegate.isOpen) await delegate.close();
    });
  }

  final Database delegate;
  final String? failingQuery;
  final Future<void> Function()? onClose;
  var closeCalls = 0;

  @override
  bool get isOpen => delegate.isOpen;

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    if (sql == failingQuery) throw StateError('synthetic query failure: $sql');
    return delegate.rawQuery(sql, arguments);
  }

  @override
  Future<void> close() async {
    closeCalls++;
    await delegate.close();
    await onClose?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _seedProofDb(String path, String value) async {
  final db = await openFileDb(path);
  try {
    await db.execute('CREATE TABLE proof (id INTEGER PRIMARY KEY, value TEXT)');
    await db.insert('proof', {'id': 1, 'value': value});
    await db.execute('PRAGMA user_version = 7');
  } finally {
    await db.close();
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('imboy_snap_test');
  });
  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  DatabaseSnapshotService svc() => DatabaseSnapshotService.to;

  test('源库打开失败返回失败并保留原件和最近有效快照', () async {
    final dbPath = '${tmp.path}/main.db';
    final db = await openFileDb(dbPath);
    await db.execute('CREATE TABLE proof (value TEXT)');
    await db.insert('proof', {'value': 'synthetic-snapshot-data'});
    await db.close();
    final original = await File(dbPath).readAsBytes();
    final snapshotDir = Directory(
      svc().snapshotDir(base: tmp.path, env: 'local', uid: 'fixture'),
    );
    await snapshotDir.create(recursive: true);
    final previous = File('${snapshotDir.path}/snapshot_v1_1.db');
    await previous.writeAsBytes(original);

    final result = await svc().createSnapshot(
      sourcePath: dbPath,
      base: tmp.path,
      env: 'local',
      uid: 'fixture',
      opener: (_, _) async => throw StateError('synthetic open failure'),
    );

    expect(result.success, isFalse);
    expect(result.error, contains('synthetic open failure'));
    expect(await File(dbPath).readAsBytes(), original);
    expect(await previous.readAsBytes(), original);
    expect(
      await File('${snapshotDir.path}/snapshot.pending.tmp').exists(),
      isFalse,
    );
  });

  test('WAL 未 checkpoint 的最新提交行进入快照（VACUUM INTO 一致性）', () async {
    final dbPath = '${tmp.path}/main.db';
    final db = await openFileDb(dbPath);
    await db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');
    await db.insert('t', {'id': 1, 'v': 'base'});
    await db.execute('PRAGMA journal_mode = WAL');
    // WAL 中写入但不 checkpoint
    await db.insert('t', {'id': 2, 'v': 'in-wal'});
    final walMode = (await db.rawQuery('PRAGMA journal_mode'))
        .first
        .values
        .first;
    expect(walMode, equals('wal'));

    final snap = await svc().createSnapshot(
      sourcePath: dbPath,
      base: tmp.path,
      env: 'test_env',
      uid: '990001',
      opener: ffiOpen,
      expectedVersion: 0,
    );
    expect(snap.success, isTrue, reason: snap.error);

    final snapDb = await openFileDb(snap.path!);
    final rows = await snapDb.query('t');
    expect(rows.length, equals(2), reason: 'WAL 中未 checkpoint 的行必须进快照');
    expect(rows.any((r) => r['v'] == 'in-wal'), isTrue);
    await snapDb.close();
    await db.close();
  });

  test('快照版本验证失败（expectedVersion 不匹配）→ fail-closed', () async {
    final dbPath = '${tmp.path}/main.db';
    final db = await openFileDb(dbPath);
    await db.execute('PRAGMA user_version = 30');
    await db.close();

    final snap = await svc().createSnapshot(
      sourcePath: dbPath,
      base: tmp.path,
      env: 'e',
      uid: 'u1',
      opener: ffiOpen,
      expectedVersion: 31, // 故意错
    );
    expect(snap.success, isFalse);
    expect(snap.error, contains('user_version'));
  });

  test('中断残留 .tmp 不影响新快照与既有有效快照（原子落位）', () async {
    final dbPath = '${tmp.path}/main.db';
    final db = await openFileDb(dbPath);
    await db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY)');
    await db.execute('PRAGMA user_version = 3');

    // 预置一个 last-good 快照 + 一个垃圾 .tmp
    final dir = Directory('${tmp.path}/imboy_db_snapshots/e/u1');
    await dir.create(recursive: true);
    File('${dir.path}/snapshot_v3_1.db').writeAsStringSync('last-good');
    File('${dir.path}/snapshot.pending.tmp').writeAsStringSync('garbage');

    final snap = await svc().createSnapshot(
      sourcePath: dbPath,
      base: tmp.path,
      env: 'e',
      uid: 'u1',
      opener: ffiOpen,
      expectedVersion: 3,
    );
    expect(snap.success, isTrue, reason: snap.error);

    // last-good 仍在；.tmp 已被消费（rename 走）
    expect(File('${dir.path}/snapshot_v3_1.db').existsSync(), isTrue);
    final files = dir.listSync().map((f) => f.path).toList();
    expect(files.any((p) => p.endsWith('.tmp')), isFalse);
    await db.close();
  });

  test('恢复成功：损坏后的主库从快照复原且数据在', () async {
    final dbPath = '${tmp.path}/main.db';
    var db = await openFileDb(dbPath);
    await db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');
    await db.insert('t', {'id': 1, 'v': 'important'});
    await db.execute('PRAGMA user_version = 7');
    await db.close();

    final snap = await svc().createSnapshot(
      sourcePath: dbPath,
      base: tmp.path,
      env: 'e',
      uid: 'u1',
      opener: ffiOpen,
      expectedVersion: 7,
    );
    expect(snap.success, isTrue);

    // 模拟主库损坏（垃圾字节覆盖）
    await File(dbPath).writeAsBytes([0x00, 0x01, 0x02, 0x03]);

    final restore = await svc().restoreFromSnapshot(
      snapshotPath: snap.path!,
      targetPath: dbPath,
      closeAllConnections: () async {},
      opener: ffiOpen,
      expectedVersion: 7,
    );
    expect(restore.success, isTrue, reason: restore.error);

    db = await openFileDb(dbPath);
    final rows = await db.query('t');
    expect(rows.single['v'], equals('important'));
    final uv = await db.rawQuery('PRAGMA user_version');
    expect(uv.first.values.first, equals(7));
    await db.close();
  });

  test('恢复失败保留原库（快照本身损坏）', () async {
    final dbPath = '${tmp.path}/main.db';
    var db = await openFileDb(dbPath);
    await db.execute("CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)");
    await db.insert('t', {'id': 1, 'v': 'live-data'});
    await db.execute('PRAGMA user_version = 5');
    await db.close();

    // 损坏快照
    final dir = Directory('${tmp.path}/imboy_db_snapshots/e/u1');
    await dir.create(recursive: true);
    final badSnap = File('${dir.path}/snapshot_v5_1.db');
    await badSnap.writeAsBytes([0xde, 0xad, 0xbe, 0xef]);

    final restore = await svc().restoreFromSnapshot(
      snapshotPath: badSnap.path,
      targetPath: dbPath,
      closeAllConnections: () async {},
      opener: ffiOpen,
    );
    expect(restore.success, isFalse);
    expect(restore.preservedOriginal, isTrue, reason: '恢复失败绝不允许动原库');

    // 原库完好
    db = await openFileDb(dbPath);
    final rows = await db.query('t');
    expect(rows.single['v'], equals('live-data'));
    await db.close();
  });

  test('恢复副本校验抛错时关闭句柄并保留原库', () async {
    final dbPath = '${tmp.path}/main.db';
    final snapshotPath = '${tmp.path}/snapshot.db';
    await _seedProofDb(dbPath, 'original');
    await _seedProofDb(snapshotPath, 'snapshot');
    final original = await File(dbPath).readAsBytes();
    _RestoreProbe? copyProbe;

    final restore = await svc().restoreFromSnapshot(
      snapshotPath: snapshotPath,
      targetPath: dbPath,
      closeAllConnections: () async {},
      expectedVersion: 7,
      opener: (openedPath, password) async {
        final db = await ffiOpen(openedPath, password);
        if (openedPath != snapshotPath && openedPath != dbPath) {
          copyProbe = _RestoreProbe(db, failingQuery: 'PRAGMA quick_check');
          return copyProbe!;
        }
        return db;
      },
    );

    expect(restore.success, isFalse);
    expect(restore.preservedOriginal, isTrue);
    expect(restore.error, contains('synthetic query failure'));
    expect(copyProbe!.closeCalls, 1);
    expect(copyProbe!.isOpen, isFalse);
    expect(await File(dbPath).readAsBytes(), orderedEquals(original));
  });

  test('恢复副本落位失败会还原原库和全部 sidecar', () async {
    final dbPath = '${tmp.path}/main.db';
    final snapshotPath = '${tmp.path}/snapshot.db';
    await _seedProofDb(dbPath, 'original');
    await _seedProofDb(snapshotPath, 'snapshot');
    final originals = <String, List<int>>{'': await File(dbPath).readAsBytes()};
    // 这里只验证文件集回滚；合成 sidecar 不交给数据库引擎读取。
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final bytes = 'synthetic-original$suffix'.codeUnits;
      await File('$dbPath$suffix').writeAsBytes(bytes);
      originals[suffix] = bytes;
    }
    _RestoreProbe? copyProbe;

    final restore = await svc().restoreFromSnapshot(
      snapshotPath: snapshotPath,
      targetPath: dbPath,
      closeAllConnections: () async {},
      opener: (openedPath, password) async {
        final db = await ffiOpen(openedPath, password);
        if (openedPath != snapshotPath && openedPath != dbPath) {
          copyProbe = _RestoreProbe(
            db,
            // 确定性注入落位 I/O 失败：验证结束后移走本测试的临时副本。
            onClose: () async {
              await File(openedPath).delete();
            },
          );
          return copyProbe!;
        }
        return db;
      },
    );

    expect(restore.success, isFalse);
    expect(restore.preservedOriginal, isTrue);
    expect(copyProbe!.closeCalls, 1);
    expect(copyProbe!.isOpen, isFalse);
    for (final entry in originals.entries) {
      expect(
        await File('$dbPath${entry.key}').readAsBytes(),
        orderedEquals(entry.value),
        reason: 'original ${entry.key} must survive failed promotion',
      );
    }
  });

  for (final failingQuery in ['PRAGMA quick_check', 'PRAGMA user_version']) {
    test('最终校验 $failingQuery 抛错后关闭句柄并还原未 checkpoint 的提交', () async {
      final writerPath = '${tmp.path}/fixture_writer.db';
      final dbPath = '${tmp.path}/main.db';
      final snapshotPath = '${tmp.path}/snapshot.db';
      await _seedProofDb(snapshotPath, 'snapshot');
      final writer = await openFileDb(writerPath);
      try {
        await writer.rawQuery('PRAGMA journal_mode = WAL');
        await writer.rawQuery('PRAGMA wal_autocheckpoint = 0');
        await writer.execute(
          'CREATE TABLE proof (id INTEGER PRIMARY KEY, value TEXT)',
        );
        await writer.insert('proof', {'id': 1, 'value': 'checkpointed'});
        await writer.execute('PRAGMA user_version = 7');
        await writer.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
        await writer.insert('proof', {'id': 2, 'value': 'committed-in-wal'});
        expect(await File('$writerPath-wal').length(), greaterThan(32));

        // 单一合成写连接保持空闲，复制完整一致的 db/WAL/SHM 文件集。
        // 副本没有任何活动连接，模拟上次进程退出后留下的已提交 WAL。
        for (final suffix in ['', '-wal', '-shm']) {
          final file = File('$writerPath$suffix');
          if (await file.exists()) await file.copy('$dbPath$suffix');
        }
      } finally {
        await writer.close();
      }
      final originalMain = await File(dbPath).readAsBytes();
      final originalWal = await File('$dbPath-wal').readAsBytes();
      _RestoreProbe? finalProbe;

      final restore = await svc().restoreFromSnapshot(
        snapshotPath: snapshotPath,
        targetPath: dbPath,
        closeAllConnections: () async {},
        expectedVersion: 7,
        opener: (openedPath, password) async {
          final db = await ffiOpen(openedPath, password);
          if (openedPath == dbPath) {
            finalProbe = _RestoreProbe(db, failingQuery: failingQuery);
            return finalProbe!;
          }
          return db;
        },
      );

      expect(restore.success, isFalse);
      expect(restore.preservedOriginal, isTrue);
      expect(finalProbe!.closeCalls, 1);
      expect(finalProbe!.isOpen, isFalse);
      expect(await File(dbPath).readAsBytes(), orderedEquals(originalMain));
      expect(
        await File('$dbPath-wal').readAsBytes(),
        orderedEquals(originalWal),
      );
      final restored = await ffiOpen(dbPath, null);
      try {
        expect(await restored.query('proof', orderBy: 'id'), [
          {'id': 1, 'value': 'checkpointed'},
          {'id': 2, 'value': 'committed-in-wal'},
        ]);
        expect(await restored.getVersion(), 7);
      } finally {
        await restored.close();
      }
    });
  }

  test('回滚也失败时明确报告并保留可恢复的原件', () async {
    final dbPath = '${tmp.path}/main.db';
    final snapshotPath = '${tmp.path}/snapshot.db';
    await _seedProofDb(dbPath, 'original');
    await _seedProofDb(snapshotPath, 'snapshot');
    final original = await File(dbPath).readAsBytes();
    _RestoreProbe? finalProbe;

    final restore = await svc().restoreFromSnapshot(
      snapshotPath: snapshotPath,
      targetPath: dbPath,
      closeAllConnections: () async {},
      opener: (openedPath, password) async {
        final db = await ffiOpen(openedPath, password);
        if (openedPath == dbPath) {
          finalProbe = _RestoreProbe(
            db,
            failingQuery: 'PRAGMA quick_check',
            onClose: () async {
              await File(dbPath).delete();
              // 只在本测试临时目录中制造无法以 File.rename 覆盖的目标。
              await Directory(dbPath).create();
            },
          );
          return finalProbe!;
        }
        return db;
      },
    );

    expect(restore.success, isFalse);
    expect(restore.preservedOriginal, isFalse);
    expect(restore.error, contains('rollback incomplete'));
    expect(finalProbe!.closeCalls, 1);
    expect(finalProbe!.isOpen, isFalse);
    final backups = (await tmp.list(recursive: true).toList())
        .whereType<File>()
        .where((file) => file.path.endsWith('original.db'))
        .toList();
    expect(backups, hasLength(1));
    expect(restore.error, contains(backups.single.parent.path));
    expect(await backups.single.readAsBytes(), orderedEquals(original));
  });

  test('关闭现有连接失败时返回失败并保留原库', () async {
    final dbPath = '${tmp.path}/main.db';
    final snapshotPath = '${tmp.path}/snapshot.db';
    await _seedProofDb(dbPath, 'original');
    await _seedProofDb(snapshotPath, 'snapshot');
    final original = await File(dbPath).readAsBytes();

    final restore = await svc().restoreFromSnapshot(
      snapshotPath: snapshotPath,
      targetPath: dbPath,
      closeAllConnections: () async =>
          throw StateError('synthetic close failure'),
      opener: ffiOpen,
    );

    expect(restore.success, isFalse);
    expect(restore.preservedOriginal, isTrue);
    expect(restore.error, contains('synthetic close failure'));
    expect(await File(dbPath).readAsBytes(), orderedEquals(original));
  });

  test('多 uid 隔离：A 的快照目录不含 B 的快照', () async {
    for (final uid in ['uidA', 'uidB']) {
      final dbPath = '${tmp.path}/main_$uid.db';
      final db = await openFileDb(dbPath);
      await db.execute('PRAGMA user_version = 2');
      await db.close();
      final snap = await svc().createSnapshot(
        sourcePath: dbPath,
        base: tmp.path,
        env: 'prod',
        uid: uid,
        opener: ffiOpen,
        expectedVersion: 2,
      );
      expect(snap.success, isTrue);
    }
    final dirA = Directory('${tmp.path}/imboy_db_snapshots/prod/uidA');
    final dirB = Directory('${tmp.path}/imboy_db_snapshots/prod/uidB');
    expect(dirA.listSync().length, equals(1));
    expect(dirB.listSync().length, equals(1));
    expect(dirA.path, isNot(equals(dirB.path)));
  });

  test('清理按 keepCount 保留最新', () async {
    final dir = Directory('${tmp.path}/imboy_db_snapshots/e/u1');
    await dir.create(recursive: true);
    for (var i = 1; i <= 5; i++) {
      await File('${dir.path}/snapshot_v3_$i.db').writeAsString('x$i');
    }
    final deleted = await svc().cleanup(
      base: tmp.path,
      env: 'e',
      uid: 'u1',
      keepCount: 2,
    );
    expect(deleted, greaterThanOrEqualTo(3));
    final rest = dir.listSync().where((f) => f.path.endsWith('.db')).toList();
    expect(rest.length, equals(2));
    // 保留的是字典序最新（≈时间戳最新）
    expect(
      rest
          .map((f) => f.path)
          .every((p) => p.contains('_4.db') || p.contains('_5.db')),
      isTrue,
    );
  });

  test('源库不存在 → fail-closed', () async {
    final snap = await svc().createSnapshot(
      sourcePath: '${tmp.path}/nope.db',
      base: tmp.path,
      env: 'e',
      uid: 'u1',
      opener: ffiOpen,
    );
    expect(snap.success, isFalse);
    expect(snap.error, contains('not found'));
  });
}
