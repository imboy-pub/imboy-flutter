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

Future<Database> ffiOpen(String path, String? password) => openFileDb(path);

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

  test('WAL 未 checkpoint 的最新提交行进入快照（VACUUM INTO 一致性）', () async {
    final dbPath = '${tmp.path}/main.db';
    final db = await openFileDb(dbPath);
    await db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');
    await db.insert('t', {'id': 1, 'v': 'base'});
    await db.execute('PRAGMA journal_mode = WAL');
    // WAL 中写入但不 checkpoint
    await db.insert('t', {'id': 2, 'v': 'in-wal'});
    final walMode = (await db.rawQuery(
      'PRAGMA journal_mode',
    )).first.values.first;
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
