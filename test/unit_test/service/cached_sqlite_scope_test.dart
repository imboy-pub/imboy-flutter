import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/cached_sqlite_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _DelayedDatabase implements Database {
  final result = Completer<List<Map<String, Object?>>>();

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => result.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test('相同查询不跨数据库复用结果', () async {
    final first = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final second = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    try {
      await first.execute('CREATE TABLE sample (value TEXT)');
      await second.execute('CREATE TABLE sample (value TEXT)');
      await first.insert('sample', {'value': 'first'});
      await second.insert('sample', {'value': 'second'});
      final cache = CachedSqliteService();
      expect(
        (await cache.cachedQuery(
          first,
          'SELECT value FROM sample',
        )).single['value'],
        'first',
      );
      expect(
        (await cache.cachedQuery(
          second,
          'SELECT value FROM sample',
        )).single['value'],
        'second',
      );
      await cache.cachedQuery(second, 'SELECT value FROM sample');
      expect(cache.getCacheStats()['cacheHits'], 1);
      await second.update('sample', {'value': 'updated'});
      cache.invalidateCache('sample');
      expect(
        (await cache.cachedQuery(
          second,
          'SELECT value FROM sample',
        )).single['value'],
        'updated',
      );
    } finally {
      await first.close();
      await second.close();
    }
  });

  test('旧数据库迟到结果不能污染新数据库缓存', () async {
    final oldDatabase = _DelayedDatabase();
    final current = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    try {
      await current.execute('CREATE TABLE sample (value TEXT)');
      await current.insert('sample', {'value': 'current'});
      final cache = CachedSqliteService();
      final oldQuery = cache.cachedQuery(
        oldDatabase,
        'SELECT value FROM sample',
      );
      expect(
        (await cache.cachedQuery(
          current,
          'SELECT value FROM sample',
        )).single['value'],
        'current',
      );
      oldDatabase.result.complete([
        {'value': 'old'},
      ]);
      await oldQuery;
      expect(
        (await cache.cachedQuery(
          current,
          'SELECT value FROM sample',
        )).single['value'],
        'current',
      );
    } finally {
      await current.close();
    }
  });

  test('SqliteService 换账号后不返回上一账号缓存', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final first = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final second = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    try {
      await first.execute('CREATE TABLE scope_test (value TEXT)');
      await second.execute('CREATE TABLE scope_test (value TEXT)');
      await first.insert('scope_test', {'value': 'first'});
      await second.insert('scope_test', {'value': 'second'});
      SqliteService.to.clearQueryCache();
      await StorageService.to.setString(Keys.currentUid, 'scope-a');
      SqliteService.setDbForTest(first);
      expect(
        (await SqliteService.to.rawQuery('SELECT value FROM scope_test'))
            .single['value'],
        'first',
      );
      await StorageService.to.setString(Keys.currentUid, 'scope-b');
      SqliteService.setDbForTest(second);
      expect(
        (await SqliteService.to.rawQuery('SELECT value FROM scope_test'))
            .single['value'],
        'second',
      );
    } finally {
      SqliteService.setDbForTest(null);
      SqliteService.to.clearQueryCache();
      await first.close();
      await second.close();
    }
  });
}
