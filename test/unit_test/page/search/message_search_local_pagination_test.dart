import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/search/message_search_provider.dart';
import 'package:imboy/service/migrations/upgrade_edges_v38_fts.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _DelayedSearchDatabase implements Database {
  final entered = Completer<void>();
  final release = Completer<void>();
  int queries = 0;

  @override
  bool get isOpen => true;

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    queries++;
    if (sql.contains('FROM msg_c2c_fts')) {
      entered.complete();
      await release.future;
      return [
        {
          'id': 'old',
          'conversation_uk3': 'C2C_100_200',
          'snippet': 'old',
          'rank': -1.0,
        },
      ];
    }
    if (sql.contains('FROM msg_c2g_fts')) return [];
    return [
      {'from_id': '', 'to_id': '', 'created_at': 1},
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reset discards an in-flight search result', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    final database = _DelayedSearchDatabase();
    SqliteService.setDbForTest(database);
    final container = ProviderContainer();
    final subscription = container.listen(messageSearchProvider, (_, _) {});
    try {
      final notifier = container.read(messageSearchProvider.notifier);
      final pending = notifier.performSearch(query: 'old');
      await database.entered.future;
      notifier.resetSearch();
      database.release.complete();
      await pending;
      final state = container.read(messageSearchProvider);
      expect(state.currentQuery, isEmpty);
      expect(state.searchResults, isEmpty);
      expect(state.isLoading, isFalse);
      expect(database.queries, 1);
    } finally {
      if (!database.release.isCompleted) database.release.complete();
      subscription.close();
      container.dispose();
      SqliteService.setDbForTest(null);
    }
  });

  test(
    'account change stops an in-flight search before the next query',
    () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final database = _DelayedSearchDatabase();
      SqliteService.setDbForTest(database);
      final container = ProviderContainer();
      final subscription = container.listen(messageSearchProvider, (_, _) {});
      try {
        final notifier = container.read(messageSearchProvider.notifier);
        final pending = notifier.performSearch(query: 'old');
        await database.entered.future;
        await StorageService.to.setString(Keys.currentUid, '200');
        database.release.complete();
        await pending;
        expect(database.queries, 1);
        expect(container.read(messageSearchProvider).searchResults, isEmpty);
      } finally {
        if (!database.release.isCompleted) database.release.complete();
        subscription.close();
        container.dispose();
        SqliteService.setDbForTest(null);
      }
    },
  );

  test('new session clears existing search results at login intent', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    final database = _DelayedSearchDatabase();
    SqliteService.setDbForTest(database);
    final container = ProviderContainer();
    final subscription = container.listen(messageSearchProvider, (_, _) {});
    const secure = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    Future<void>? rejected;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
          if (call.method == 'write')
            throw PlatformException(code: 'synthetic-stop');
          return null;
        });
    try {
      final notifier = container.read(messageSearchProvider.notifier);
      final pending = notifier.performSearch(query: 'old');
      await database.entered.future;
      database.release.complete();
      await pending;
      expect(container.read(messageSearchProvider).searchResults, hasLength(1));
      final login = UserRepoLocal.to.loginAfter('synthetic', {
        'uid': '995011',
        'token': 'synthetic-token',
        'refreshtoken': 'synthetic-refresh',
      });
      rejected = expectLater(login, throwsA(isA<PlatformException>()));
      expect(container.read(messageSearchProvider).searchResults, isEmpty);
      expect(container.read(messageSearchProvider).currentQuery, isEmpty);
    } finally {
      await rejected;
      UserRepoLocal.to.clearAuthTransitionFailureForTest();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secure, null);
      subscription.close();
      container.dispose();
      SqliteService.setDbForTest(null);
    }
  });

  test('local search paginates without repeating results', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(db);
    final container = ProviderContainer();
    final subscription = container.listen(messageSearchProvider, (_, _) {});
    try {
      await db.transaction((txn) async {
        for (final sql in upgradeV38Fts.sqlStatements) {
          await txn.execute(sql);
        }
      });
      for (var index = 0; index < 21; index++) {
        await db.insert('msg_c2c', {
          'id': 'pagination-$index',
          'type': 'C2C',
          'from_id': '',
          'to_id': '',
          'conversation_uk3': 'C2C_100_200',
          'msg_type': 'text',
          'payload': '{"text":"paginationword"}',
          'status': 20,
          'created_at': 1700000000000 + index,
        });
        await db.insert('msg_c2g', {
          'id': 'group-pagination-$index',
          'type': 'C2G',
          'from_id': '',
          'to_id': '',
          'conversation_uk3': 'C2G_100_300',
          'msg_type': 'text',
          'payload': '{"text":"paginationword"}',
          'status': 20,
          'created_at': 1700000000000 + index,
        });
      }
      final notifier = container.read(messageSearchProvider.notifier);
      await notifier.performSearch(query: 'paginationword');
      final first = container.read(messageSearchProvider);
      expect(first.searchResults, hasLength(20));
      expect(first.hasMore, isTrue);
      await notifier.loadMore();
      final second = container.read(messageSearchProvider);
      expect(second.searchResults, hasLength(40));
      expect(
        second.searchResults.map((result) => result.id).toSet(),
        hasLength(40),
      );
      expect(second.hasMore, isTrue);
      await notifier.loadMore();
      final third = container.read(messageSearchProvider);
      expect(third.searchResults, hasLength(42));
      expect(
        third.searchResults.map((result) => result.id).toSet(),
        hasLength(42),
      );
      expect(
        third.searchResults.where((result) => result.type == 'C2G'),
        hasLength(21),
      );
      expect(third.hasMore, isFalse);

      notifier.resetSearch();
      notifier.setTypeFilter('C2G');
      notifier.setCustomDateRange(
        DateTime.fromMillisecondsSinceEpoch(1700000000010),
        DateTime.fromMillisecondsSinceEpoch(1700000000015),
      );
      await notifier.performSearch(query: 'paginationword');
      final filtered = container.read(messageSearchProvider);
      expect(filtered.searchResults, hasLength(6));
      expect(
        filtered.searchResults.every((result) => result.type == 'C2G'),
        isTrue,
      );
      expect(
        filtered.searchResults.every(
          (result) =>
              result.createdAt >= 1700000000010 &&
              result.createdAt <= 1700000000015,
        ),
        isTrue,
      );
      expect(filtered.hasMore, isFalse);

      await db.update(
        'msg_c2g',
        {'from_id': '901'},
        where: 'id = ?',
        whereArgs: ['group-pagination-10'],
      );
      notifier.cacheContact('901', ContactModel(peerId: 901, nickname: 'test'));
      await notifier.performSearch(query: 'paginationword');
      final refreshed = container.read(messageSearchProvider);
      expect(
        refreshed.searchResults
            .singleWhere((result) => result.id == 'group-pagination-10')
            .fromId,
        '901',
      );
    } finally {
      subscription.close();
      container.dispose();
      SqliteService.setDbForTest(null);
      await db.close();
    }
  });

  test('local pagination does not switch source after deletion', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(db);
    final container = ProviderContainer();
    final subscription = container.listen(messageSearchProvider, (_, _) {});
    try {
      await db.transaction((txn) async {
        for (final sql in upgradeV38Fts.sqlStatements) {
          await txn.execute(sql);
        }
      });
      for (var index = 0; index < 21; index++) {
        await db.insert('msg_c2c', {
          'id': 'source-$index',
          'type': 'C2C',
          'from_id': '',
          'to_id': '',
          'conversation_uk3': 'C2C_100_200',
          'msg_type': 'text',
          'payload': '{"text":"sourceword"}',
          'status': 20,
          'created_at': 1700000000000 + index,
        });
      }
      final notifier = container.read(messageSearchProvider.notifier);
      await notifier.performSearch(query: 'sourceword');
      expect(container.read(messageSearchProvider).hasMore, isTrue);
      await db.delete('msg_c2c');
      await notifier.loadMore();
      final exhausted = container.read(messageSearchProvider);
      expect(exhausted.currentPage, 2);
      expect(exhausted.hasMore, isFalse);
      expect(exhausted.errorMessage, isEmpty);

      for (var index = 0; index < 21; index++) {
        await db.insert('msg_c2c', {
          'id': 'failure-$index',
          'type': 'C2C',
          'from_id': '',
          'to_id': '',
          'conversation_uk3': 'C2C_100_200',
          'msg_type': 'text',
          'payload': '{"text":"failureword"}',
          'status': 20,
          'created_at': 1700000000000 + index,
        });
      }
      await notifier.performSearch(query: 'failureword');
      expect(container.read(messageSearchProvider).hasMore, isTrue);
      await db.execute('DROP TABLE msg_c2g_fts');
      await notifier.loadMore();
      final failed = container.read(messageSearchProvider);
      expect(failed.currentPage, 1);
      expect(failed.searchResults, hasLength(20));
      expect(failed.errorMessage, isNotEmpty);
      expect(failed.isLoading, isFalse);
    } finally {
      subscription.close();
      container.dispose();
      SqliteService.setDbForTest(null);
      if (db.isOpen) await db.close();
    }
  });
}
