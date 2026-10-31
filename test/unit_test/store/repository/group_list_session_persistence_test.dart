import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/group_list_session_persistence.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _DelayedTransactionDatabase implements Database {
  _DelayedTransactionDatabase(this._database);

  final Database _database;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  bool get isOpen => _database.isOpen;

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    entered.complete();
    await release.future;
    return _database.transaction(action, exclusive: exclusive);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements AuthSessionReader {
  @override
  AuthSessionScope current = (uid: '1001', generation: 1, transitioning: false);
  int checks = 0;
  int? invalidateAt;

  @override
  bool isCurrent(AuthSessionScope captured) {
    checks++;
    if (checks == invalidateAt) {
      current = (uid: '2002', generation: 2, transitioning: false);
    }
    return !captured.transitioning &&
        !current.transitioning &&
        captured.uid.isNotEmpty &&
        current == captured;
  }
}

const _profile = (nickname: 'A', avatar: '', sign: '', account: 'synthetic');

Future<Database> _openDb() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  await db.execute('''CREATE TABLE "group" (
    id INTEGER PRIMARY KEY, type INTEGER, join_limit INTEGER,
    content_limit INTEGER, owner_uid INTEGER NOT NULL, creator_uid INTEGER NOT NULL,
    member_max INTEGER, member_count INTEGER, introduction TEXT, avatar TEXT,
    title TEXT, status INTEGER, updated_at INTEGER, created_at INTEGER NOT NULL,
    pinned_msg TEXT)''');
  await db.execute('''CREATE TABLE group_member (
    id INTEGER PRIMARY KEY, group_id INTEGER NOT NULL, user_id INTEGER NOT NULL,
    nickname TEXT, avatar TEXT, sign TEXT, account TEXT, invite_code TEXT,
    alias TEXT, description TEXT, role INTEGER, is_join INTEGER, join_mode TEXT,
    status INTEGER NOT NULL, updated_at INTEGER, created_at INTEGER NOT NULL,
    mute_until INTEGER, UNIQUE(group_id, user_id))''');
  return db;
}

Map<String, dynamic> _group({
  String title = 'original',
  String owner = '3003',
}) => {
  'id': '9007199254740993',
  'owner_uid': owner,
  'creator_uid': '3003',
  'title': title,
  'status': 1,
  'created_at': 123,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database a;
  late Database b;
  late _Auth auth;
  late String env;
  late String endpoint;
  late Database selected;

  Future<GroupListSessionPersistence> bind({
    Future<Database?> Function()? database,
  }) => GroupListSessionPersistence.bind(
    reader: auth,
    environmentNow: () => env,
    endpointNow: () => endpoint,
    database: database ?? () async => selected,
    selfProfile: () => _profile,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
    await StorageService.init();
    SqliteService.to.clearQueryCache();
    a = await _openDb();
    b = await _openDb();
    auth = _Auth();
    env = 'local';
    endpoint = 'https://synthetic.invalid';
    selected = a;
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    SqliteService.to.clearQueryCache();
    if (a.isOpen) await a.close();
    if (b.isOpen) await b.close();
    auth.dispose();
  });

  test('external transaction supports insert, update and rollback', () async {
    await a.transaction((txn) async {
      await GroupRepo().save('', _group(), txn: txn);
      final updated = await GroupRepo().save(
        '',
        _group(title: 'updated'),
        txn: txn,
      );
      expect(updated.title, 'updated');
    });
    expect((await a.query('group')).single['title'], 'updated');
    await expectLater(
      a.transaction((txn) async {
        await GroupRepo().save('', _group(title: 'rolled back'), txn: txn);
        throw StateError('rollback');
      }),
      throwsStateError,
    );
    expect((await a.query('group')).single['title'], 'updated');
  });

  test('group and membership are saved on the fixed database', () async {
    final persistence = await bind();
    selected = b;
    final group = await persistence.saveGroup(_group(), attr: 'manager');
    expect(group.groupId, '9007199254740993');
    expect((await a.query('group')).single['title'], 'original');
    final member = (await a.query('group_member')).single;
    expect(member['user_id'], 1001);
    expect(member['role'], 3);
    expect(member['is_join'], 1);
    expect(member['nickname'], 'A');
    expect(await b.query('group'), isEmpty);
    expect(await b.query('group_member'), isEmpty);

    await persistence.saveGroup(
      _group(owner: '1001', title: 'owner'),
      attr: 'owner',
    );
    expect((await a.query('group')).single['title'], 'owner');
    final updated = (await a.query('group_member')).single;
    expect(updated['role'], 4);
    expect(updated['is_join'], 0);
    expect(await b.query('group'), isEmpty);
  });

  test('successful save invalidates cached group and member queries', () async {
    SqliteService.setDbForTest(a);
    final persistence = await bind();
    const groupSql = 'SELECT title FROM "group"';
    const memberSql = 'SELECT role FROM group_member';
    expect(await SqliteService.to.rawQuery(groupSql), isEmpty);
    expect(await SqliteService.to.rawQuery(memberSql), isEmpty);
    await SqliteService.to.rawQuery(groupSql);
    await SqliteService.to.rawQuery(memberSql);
    expect(SqliteService.to.getCacheStats()['cacheHits'], 2);

    await persistence.saveGroup(_group(), attr: 'manager');
    expect(
      (await SqliteService.to.rawQuery(groupSql)).single['title'],
      'original',
    );
    expect((await SqliteService.to.rawQuery(memberSql)).single['role'], 3);
    await persistence.saveGroup(
      _group(owner: '1001', title: 'updated'),
      attr: 'owner',
    );
    expect(
      (await SqliteService.to.rawQuery(groupSql)).single['title'],
      'updated',
    );
    expect((await SqliteService.to.rawQuery(memberSql)).single['role'], 4);
  });

  test(
    'a changed database does not clear its cache after old-db commit',
    () async {
      final persistence = await bind();
      await b.insert('group', _group(title: 'B'));
      SqliteService.setDbForTest(b);
      selected = b;
      const sql = 'SELECT title FROM "group"';
      expect((await SqliteService.to.rawQuery(sql)).single['title'], 'B');
      await SqliteService.to.rawQuery(sql);
      final hits = SqliteService.to.getCacheStats()['cacheHits'] as int;
      await persistence.saveGroup(_group(), attr: 'join');
      expect((await SqliteService.to.rawQuery(sql)).single['title'], 'B');
      expect(SqliteService.to.getCacheStats()['cacheHits'], hits + 1);
    },
  );

  test(
    'closed database error is preserved while session remains valid',
    () async {
      final persistence = await bind();
      await a.close();
      await expectLater(
        persistence.saveGroup(_group(), attr: 'join'),
        throwsA(isNot(isA<GroupListSessionCancelled>())),
      );
      expect(await b.query('group'), isEmpty);
    },
  );

  test('transaction error after account switch reports cancellation', () async {
    final delayed = _DelayedTransactionDatabase(a);
    final persistence = await bind(database: () async => delayed);
    final pending = persistence.saveGroup(_group(), attr: 'join');
    final failed = expectLater(
      pending,
      throwsA(isA<GroupListSessionCancelled>()),
    );
    await delayed.entered.future;
    auth.current = (uid: '2002', generation: 2, transitioning: false);
    selected = b;
    await a.close();
    delayed.release.complete();
    await failed;
    expect(await b.query('group'), isEmpty);
    expect(await b.query('group_member'), isEmpty);
  });

  test('session switch while acquiring database fails closed', () async {
    final entered = Completer<void>();
    final release = Completer<Database?>();
    final pending = bind(
      database: () {
        entered.complete();
        return release.future;
      },
    );
    final failed = expectLater(
      pending,
      throwsA(isA<GroupListSessionCancelled>()),
    );
    await entered.future;
    auth.current = (uid: '2002', generation: 2, transitioning: false);
    selected = b;
    release.complete(b);
    await failed;
    expect(await a.query('group'), isEmpty);
    expect(await b.query('group'), isEmpty);
  });

  for (final step in [5, 8]) {
    test('session switch at check $step rolls back both tables', () async {
      final persistence = await bind();
      auth.checks = 0;
      auth.invalidateAt = step;
      await expectLater(
        persistence.saveGroup(_group(), attr: 'join'),
        throwsA(isA<GroupListSessionCancelled>()),
      );
      expect(await a.query('group'), isEmpty);
      expect(await a.query('group_member'), isEmpty);
      expect(await b.query('group'), isEmpty);
      expect(await b.query('group_member'), isEmpty);
    });
  }

  test(
    'invalidation after updating both rows rolls both changes back',
    () async {
      final persistence = await bind();
      await persistence.saveGroup(_group(), attr: 'join');
      auth.checks = 0;
      auth.invalidateAt = 9;
      await expectLater(
        persistence.saveGroup(
          _group(owner: '1001', title: 'changed'),
          attr: 'owner',
        ),
        throwsA(isA<GroupListSessionCancelled>()),
      );
      expect((await a.query('group')).single['title'], 'original');
      final member = (await a.query('group_member')).single;
      expect(member['role'], 1);
      expect(member['is_join'], 1);
      expect(await b.query('group'), isEmpty);
      expect(await b.query('group_member'), isEmpty);
    },
  );

  test('stale binding does not resolve the database', () async {
    auth.current = (uid: '1001', generation: 1, transitioning: true);
    var databaseRequested = false;
    await expectLater(
      bind(
        database: () async {
          databaseRequested = true;
          return b;
        },
      ),
      throwsA(isA<GroupListSessionCancelled>()),
    );
    expect(databaseRequested, isFalse);
  });

  test('database failure after a switch reports cancellation', () async {
    final entered = Completer<void>();
    final release = Completer<Database?>();
    final pending = bind(
      database: () {
        entered.complete();
        return release.future;
      },
    );
    final failed = expectLater(
      pending,
      throwsA(isA<GroupListSessionCancelled>()),
    );
    await entered.future;
    auth.current = (uid: '2002', generation: 2, transitioning: false);
    release.completeError(StateError('database unavailable'));
    await failed;
  });

  test(
    'same uid with new generation, transition, env or endpoint cancels',
    () async {
      for (final mutate in <void Function()>[
        () => auth.current = (uid: '1001', generation: 2, transitioning: false),
        () => auth.current = (uid: '1001', generation: 1, transitioning: true),
        () => env = 'dev',
        () => endpoint = 'https://other.invalid',
      ]) {
        auth.current = (uid: '1001', generation: 1, transitioning: false);
        env = 'local';
        endpoint = 'https://synthetic.invalid';
        final persistence = await bind();
        mutate();
        await expectLater(
          persistence.saveGroup(_group(), attr: 'join'),
          throwsA(isA<GroupListSessionCancelled>()),
        );
      }
      expect(await a.query('group'), isEmpty);
      expect(await b.query('group'), isEmpty);
    },
  );
}
