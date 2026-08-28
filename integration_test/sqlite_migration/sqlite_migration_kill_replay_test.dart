/// WP7-B：迁移中 kill -9 真杀进程重放（两阶段：prepare / verify）。
///
/// 场景（docs/sqlite-migration-test-matrix.md §3"进程被杀"行）：
/// 升级事务进行中进程被 SIGKILL（am force-stop ≈ kill -9），下一次打开
/// 必须满足原子性——要么完整到 v31，要么完整留在 v16，任何中间态都
/// 不允许出现；迁移前数据行必须零丢失。
///
/// 用法（外部编排，见 README §2.5）：
///   flutter test ... --dart-define=KILL_PHASE=prepare --dart-define=KILL_ATTEMPT=1
///   #  宿主在看到 [WP7-EVIDENCE] step=kill_ready 后 adb shell am force-stop
///   flutter test ... --dart-define=KILL_PHASE=verify  --dart-define=KILL_ATTEMPT=1
///
/// 独立命名空间：db 位于应用 support 目录 imboy_wp7_kill/ 下，只增删
/// 自建文件；不登录、不连后端、不触碰真实账号数据库。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/service/embedded_schema_scripts.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/schema_contract.dart';
import 'package:imboy/service/schema_fingerprint.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

// 合成密钥（仅本测试沙箱），不含任何真实凭据。
const _password = 'wp7-synthetic-key-material'; // gitleaks:allow
const _phase = String.fromEnvironment('KILL_PHASE');
const _attempt = int.fromEnvironment('KILL_ATTEMPT', defaultValue: 1);

// 缩减版数据集（设备存储紧张）：20k 行足以让 3 次全表重建在 arm32 上
// 形成 1-3 秒的迁移窗口
const _contactRows = 8000;
const _tagRows = 8000;
const _collectRows = 4000;

Future<String> _dbPath() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory('${base.path}/imboy_wp7_kill');
  await dir.create(recursive: true);
  return '${dir.path}/replay_$_attempt.db';
}

void _evidence(String step, Map<String, Object?> kv) {
  final pairs = kv.entries.map((e) => '${e.key}=${e.value}').join(' ');
  // ignore: avoid_print
  print('[WP7-EVIDENCE] step=$step $pairs');
}

Future<Database> _open(String path, {String? password}) =>
    openDatabase(path, password: password, singleInstance: false);

/// 生产 _onCreate 同语义建 baseline。
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

Future<int> _count(DatabaseExecutor db, String table) async =>
    (await db.rawQuery('SELECT count(*) AS c FROM "$table"')).first.values.first
        as int;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (_phase == 'prepare') {
    test('kill_replay[$_attempt] prepare：建大数据集并进入 16→31 迁移', () async {
      final dbPath = await _dbPath();
      // 清理上次尝试残留（只删自建文件）
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final f = File('$dbPath$suffix');
        if (f.existsSync()) await f.delete();
      }
      final db = await _open(dbPath, password: _password);
      await db.transaction((txn) => applyBaseline(txn));
      await db.execute('PRAGMA user_version = 16');

      // 大数据集：命中 v17(user_tag 重建) / v22(user_collect 重建) /
      // v24(contact 重建) 三个全表重建，拉宽可杀窗口
      final sw = Stopwatch()..start();
      await db.transaction((txn) async {
        final contact = txn.batch();
        for (var i = 1; i <= _contactRows; i++) {
          contact.insert('contact', {
            'user_id': 990001,
            'peer_id': i,
            'nickname': 'synthetic-$i',
          });
        }
        await contact.commit(noResult: true);
      });
      await db.transaction((txn) async {
        final tag = txn.batch();
        for (var i = 1; i <= _tagRows; i++) {
          // UNIQUE(user_id, scene, name)：name 必须逐行唯一
          tag.insert('user_tag', {
            'user_id': 990001,
            'tag_id': i,
            'name': 't$i',
          });
        }
        await tag.commit(noResult: true);
      });
      await db.transaction((txn) async {
        final col = txn.batch();
        for (var i = 1; i <= _collectRows; i++) {
          col.insert('user_collect', {
            'user_id': 990001,
            'kind_id': 'k$i',
            'kind': 1,
          });
        }
        await col.commit(noResult: true);
      });
      sw.stop();
      _evidence('kill_seeded', {
        'attempt': _attempt,
        'contact': _contactRows,
        'user_tag': _tagRows,
        'user_collect': _collectRows,
        'seed_ms': sw.elapsedMilliseconds,
      });

      // 就绪标记：宿主见此行后 force-stop（杀点落在迁移事务内）
      _evidence('kill_ready', {'attempt': _attempt, 'db': dbPath});

      final result = await db.transaction((txn) async {
        final r = await MigrationService.to.migrate(
          db: txn,
          fromVersion: 16,
          toVersion: 31,
          isUpgrade: true,
        );
        if (!r.success) throw Exception(r.error);
        return r;
      });
      final uv = (await db.rawQuery('PRAGMA user_version')).first.values.first;
      _evidence('kill_done_window_missed', {
        'attempt': _attempt,
        'user_version': uv,
        'from': result.fromVersion,
        'to': result.toVersion,
      });
      await db.close();
    });
  } else if (_phase == 'verify') {
    test('kill_replay[$_attempt] verify：被杀后原子性与数据零丢失断言', () async {
      final dbPath = await _dbPath();
      expect(
        File(dbPath).existsSync(),
        isTrue,
        reason: 'replay 库不存在：prepare 阶段未成功建库',
      );
      final db = await _open(dbPath, password: _password);

      final quick = (await db.rawQuery(
        'PRAGMA quick_check',
      )).first.values.first;
      expect(quick, equals('ok'), reason: '被杀后库必须完好');
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);

      final uv =
          (await db.rawQuery('PRAGMA user_version')).first.values.first as int;
      expect(
        uv,
        anyOf(equals(16), equals(31)),
        reason: '原子性：版本只能停在起点或终点，绝不允许中间态',
      );

      // 数据零丢失（迁移前种子行在回滚/完成后都必须还在）
      expect(await _count(db, 'contact'), equals(_contactRows));
      expect(await _count(db, 'user_tag'), equals(_tagRows));
      expect(await _count(db, 'user_collect'), equals(_collectRows));

      final outcome = (uv == 31)
          ? 'WINDOW_MISSED_COMPLETED'
          : 'KILLED_ROLLED_BACK';
      if (uv == 31) {
        // 完成侧：结构=权威 v31
        expect(await SchemaContract.verifyInvariants(db, version: 31), isEmpty);
        final fp = await SchemaFingerprint.compute(db);
        expect(
          fp,
          equals(
            'f6d4a55a4374486660b8b0cd6e0b42867a7bf18383eb3676400dbe454774ee5c',
          ),
          reason: '真机 v31 指纹必须与 golden 一致（hash 与数据无关）',
        );
      } else {
        // 回滚侧：结构必须与全新 v16 完全一致
        final scratch = await _open(
          '$dbPath.scratch16.db',
          password: _password,
        );
        await scratch.transaction((txn) => applyBaseline(txn));
        await scratch.execute('PRAGMA user_version = 16');
        final fpRolled = await SchemaFingerprint.compute(db);
        final fpFresh16 = await SchemaFingerprint.compute(scratch);
        await scratch.close();
        await File('$dbPath.scratch16.db').delete();
        expect(fpRolled, equals(fpFresh16), reason: '被杀回滚后结构必须与全新 v16 逐指纹一致');
      }
      _evidence('kill_verify', {
        'attempt': _attempt,
        'user_version': uv,
        'outcome': outcome,
        'quick_check': quick,
        'rowsPreserved': true,
      });
      await db.close();
    });
  } else {
    test('kill_replay：缺少 KILL_PHASE', () {
      fail('用法：--dart-define=KILL_PHASE=prepare|verify');
    });
  }
}
