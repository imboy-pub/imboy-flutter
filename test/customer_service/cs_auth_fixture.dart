import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class CsSyntheticAuthDatabase implements Database {
  @override
  bool get isOpen => true;
  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Real identity transition with fake platform storage/database, never private latch reset.
Future<void> establishCsAuthFixture({
  String uid = '7266418340025468999',
}) async {
  await StorageService.to.setString(Keys.currentUid, uid);
  SqliteService.setDbForTest(CsSyntheticAuthDatabase());
  final success = await UserRepoLocal.to.loginAfter('synthetic', {
    'uid': uid,
    'token': 'synthetic-access-token',
    'refreshtoken': 'synthetic-refresh-token',
  });
  if (!success || !authSessionReader.isCurrent(authSessionReader.current)) {
    throw StateError('fixture_login_refused');
  }
}

Future<void> establishCsWidgetAuthFixture(
  WidgetTester tester, {
  String uid = '7266418340025468999',
}) async {
  var finished = false;
  late Future<void> task;
  await tester.runAsync(() async {
    task = establishCsAuthFixture(uid: uid).whenComplete(() => finished = true);
  });
  for (var i = 0; i < 100 && !finished; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(finished, isTrue, reason: 'actual login queue must complete');
  await tester.runAsync(() => task);
  PersistentMessageQueue.to.dispose();
}

/// Fake secure-storage queue barrier; it must not restore authentication authority.
Future<void> drainCsAuthQueue(WidgetTester tester) async {
  final before = authSessionReader.current;
  var finished = false;
  late Future<bool> task;
  await tester.runAsync(() async {
    task = UserRepoLocal.to
        .saveAccessTokenForSession(
          UserRepoLocal.to.sessionGeneration,
          'synthetic-fixture-token',
        )
        .whenComplete(() => finished = true);
  });
  for (var i = 0; i < 100 && !finished; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(
    finished,
    isTrue,
    reason: 'existing authenticated write queue must finish',
  );
  await tester.runAsync(() => task);
  expect(authSessionReader.current, before);
}
