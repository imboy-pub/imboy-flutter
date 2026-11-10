import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide getDatabasesPath;
import 'package:sqflite_sqlcipher/sqflite.dart' show getDatabasesPath;

import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';

class _DelayedQueryDatabase implements Database {
  final Completer<List<Map<String, Object?>>> result = Completer();

  @override
  bool get isOpen => true;

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => result.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// E2EE-015 纵深防御：SqliteService.db 句柄按 uid 隔离。
///
/// 修复前 getter 仅按 isOpen 复用句柄，若 logout 未 close（purge 失败旁路），
/// 换号后新账号会写进上一账号仍打开的 SQLCipher 库（安全审查 CRITICAL）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    SqliteService.setDbForTest(null);
  });

  Future<Database> openMem() =>
      databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

  test('uid 一致时复用已打开句柄', () async {
    await StorageService.to.setString(Keys.currentUid, 'uidA');
    final injected = await openMem();
    SqliteService.setDbForTest(injected);

    final got = await SqliteService.to.db;
    expect(got, same(injected));
    expect(injected.isOpen, isTrue);
    await injected.close();
  });

  test('uid 漂移时关闭旧账号句柄，不复用', () async {
    await StorageService.to.setString(Keys.currentUid, 'uidA');
    final oldHandle = await openMem();
    SqliteService.setDbForTest(oldHandle);

    // 模拟 logout 未 close 后直接换号
    await StorageService.to.setString(Keys.currentUid, 'uidB');
    // 漂移检测在重开之前先 close 旧句柄；宿主环境无 sqlcipher 插件，
    // 重开会抛 MissingPluginException——吞掉即可，关键断言是旧句柄已关、未复用。
    Object? got = oldHandle;
    try {
      got = await SqliteService.to.db;
    } on Object {
      got = null;
    }

    expect(oldHandle.isOpen, isFalse, reason: '旧账号句柄必须被关闭');
    expect(got, isNot(same(oldHandle)), reason: '绝不把旧句柄交给新账号');
  });

  test('同账号环境变化时不得复用旧环境句柄', () async {
    final previousEnv = currentEnv;
    currentEnv = 'local';
    await StorageService.to.setString(Keys.currentUid, 'uidA');
    final oldHandle = await openMem();
    SqliteService.setDbForTest(oldHandle);
    try {
      currentEnv = 'dev';
      expect(await SqliteService.to.db, isNull);
      expect(oldHandle.isOpen, isTrue);
      currentEnv = 'local';
      expect(await SqliteService.to.db, same(oldHandle));
    } finally {
      currentEnv = previousEnv;
      SqliteService.setDbForTest(null);
      if (oldHandle.isOpen) await oldHandle.close();
    }
  });

  test('waitUntilReady：db 就绪时立即返回 true', () async {
    await StorageService.to.setString(Keys.currentUid, 'uidA');
    final injected = await openMem();
    SqliteService.setDbForTest(injected);

    final sw = Stopwatch()..start();
    final ready = await SqliteService.to.waitUntilReady(
      const Duration(seconds: 2),
    );
    sw.stop();

    expect(ready, isTrue);
    expect(sw.elapsedMilliseconds, lessThan(500), reason: '就绪时不应轮询等待');
    await injected.close();
  });

  test('waitUntilReady：db 持续不可用时按 timeout 返回 false', () async {
    // uid 为空 + 无注入句柄 → _initDatabase 返回 null 进入冷却，db 恒 null
    final start = DateTime.now();
    final ready = await SqliteService.to.waitUntilReady(
      const Duration(milliseconds: 200),
    );
    final elapsedMs = DateTime.now().difference(start).inMilliseconds;

    expect(ready, isFalse);
    // 允许少量调度余量，但绝不能等到冷却期（5s）结束
    expect(elapsedMs, lessThan(2000), reason: '必须按 timeout 及时放弃');
  });

  test('rawQuery distinguishes unavailable database in strict mode', () async {
    expect(await SqliteService.to.rawQuery('SELECT 1'), isEmpty);
    await expectLater(
      SqliteService.to.rawQuery('SELECT 1', null, false, 100, true),
      throwsA(isA<Exception>()),
    );
  });

  test('rawQuery distinguishes timeout in strict mode', () async {
    await StorageService.to.setString(Keys.currentUid, 'uidA');
    final database = _DelayedQueryDatabase();
    SqliteService.setDbForTest(database);
    try {
      expect(
        await SqliteService.to.rawQuery('SELECT 1', null, false, 10),
        isEmpty,
      );
      await expectLater(
        SqliteService.to.rawQuery('SELECT 1', null, false, 10, true),
        throwsA(isA<TimeoutException>()),
      );
    } finally {
      database.result.complete([]);
      SqliteService.setDbForTest(null);
    }
  });

  test('登出时只删除指定 uid 的数据库及 sidecar 文件', () async {
    const uid = 'logout-delete-test-uid';
    const sqlcipherChannel = MethodChannel(
      'com.davidmartos96.sqflite_sqlcipher',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sqlcipherChannel, (call) async {
          if (call.method == 'getDatabasesPath') {
            return Directory.systemTemp.path;
          }
          return null;
        });

    try {
      final directory = await getDatabasesPath();
      final target = path.join(
        directory,
        SqliteService.databaseNameForUid(uid),
      );
      final other = path.join(
        directory,
        SqliteService.databaseNameForUid('other-uid'),
      );

      for (final suffix in const ['', '-wal', '-shm', '-journal']) {
        await File('$target$suffix').writeAsString('test');
      }
      await File(other).writeAsString('must-preserve');

      try {
        await SqliteService.to.deleteDatabaseForUid(uid);

        for (final suffix in const ['', '-wal', '-shm', '-journal']) {
          expect(
            await File('$target$suffix').exists(),
            isFalse,
            reason: '登出必须清理数据库 sidecar：$suffix',
          );
        }
        expect(await File(other).readAsString(), 'must-preserve');
      } finally {
        for (final file in [
          target,
          '$target-wal',
          '$target-shm',
          '$target-journal',
          other,
        ]) {
          final handle = File(file);
          if (await handle.exists()) await handle.delete();
        }
      }
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sqlcipherChannel, null);
    }
  });

  test(
    'history removal uses its saved environment and removes restore artifacts',
    () async {
      const uid = 'history-env-test-uid';
      const savedEnvironment = 'historyTest';
      const channel = MethodChannel('com.davidmartos96.sqflite_sqlcipher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getDatabasesPath') {
              return Directory.systemTemp.path;
            }
            return null;
          });
      final directory = await getDatabasesPath();
      final target = path.join(directory, '${savedEnvironment}_$uid.db');
      final other = path.join(directory, '${currentEnv}_$uid.db');
      final recovery = '$target.restore.selected';
      final otherRecoveries = [
        '$other.restore.other-environment',
        path.join(directory, '${savedEnvironment}_$uid-other.db.restore.b'),
      ];
      final artifacts = [
        for (final copy in ['', '.pre_restore.bak', '.restoring.tmp'])
          for (final suffix in ['', '-wal', '-shm', '-journal'])
            '$target$copy$suffix',
        for (final suffix in ['', '-wal', '-shm', '-journal'])
          '$recovery/original.db$suffix',
        '$recovery/replacement.db',
      ];
      final preserved = [
        other,
        for (final directory in otherRecoveries) '$directory/original.db-wal',
      ];
      final previousEnvironment = currentEnv;
      currentEnv = savedEnvironment;
      await StorageService.to.setString(Keys.currentUid, uid);
      final handle = await openMem();
      SqliteService.setDbForTest(handle);
      await StorageService.to.remove(Keys.currentUid);
      currentEnv = previousEnvironment;
      try {
        for (final name in [...artifacts, ...preserved]) {
          final file = File(name);
          await file.parent.create(recursive: true);
          await file.writeAsString('synthetic database');
        }
        await SqliteService.to
            .deleteDatabaseForUid(uid, environment: savedEnvironment)
            .timeout(const Duration(seconds: 5));
        expect(handle.isOpen, isFalse, reason: 'selected stale handle closes');
        for (final name in artifacts) {
          expect(await File(name).exists(), isFalse, reason: name);
        }
        expect(await Directory(recovery).exists(), isFalse);
        for (final name in preserved) {
          expect(await File(name).readAsString(), 'synthetic database');
        }
      } finally {
        currentEnv = previousEnvironment;
        SqliteService.setDbForTest(null);
        if (handle.isOpen) await handle.close();
        for (final name in [...artifacts, ...preserved]) {
          if (await File(name).exists()) await File(name).delete();
        }
        for (final directory in [recovery, ...otherRecoveries]) {
          final folder = Directory(directory);
          if (await folder.exists()) await folder.delete(recursive: true);
        }
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    },
  );

  test(
    'history removal rejects the active account before closing its handle',
    () async {
      await StorageService.to.setString(Keys.currentUid, 'still-signed-in');
      final handle = await openMem();
      SqliteService.setDbForTest(handle);
      try {
        await expectLater(
          SqliteService.to.closeDatabaseForUid('still-signed-in'),
          throwsStateError,
        );
        await expectLater(
          SqliteService.to.deleteDatabaseForUid('still-signed-in'),
          throwsStateError,
        );
        expect(handle.isOpen, isTrue);
      } finally {
        SqliteService.setDbForTest(null);
        await handle.close();
      }
    },
  );

  test('closing historical A preserves the cached B handle', () async {
    await StorageService.to.setString(Keys.currentUid, 'retained-b');
    final other = await openMem();
    SqliteService.setDbForTest(other);
    await StorageService.to.remove(Keys.currentUid);
    try {
      await SqliteService.to.closeDatabaseForUid('selected-a');
      expect(other.isOpen, isTrue);
      await StorageService.to.setString(Keys.currentUid, 'retained-b');
      expect(await SqliteService.to.db, same(other));
    } finally {
      SqliteService.setDbForTest(null);
      await other.close();
    }
  });
}
