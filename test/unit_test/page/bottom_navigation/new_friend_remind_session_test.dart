import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_provider.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class _Account extends Notifier<UserModel?> {
  @override
  UserModel? build() => UserModel(uid: '100', account: 'synthetic');
  void select(String uid) => state = UserModel(uid: uid, account: 'synthetic');
}

final _account = NotifierProvider<_Account, UserModel?>(_Account.new);

class _Database implements Database {
  final entered = Completer<void>();
  final release = Completer<List<Map<String, Object?>>>();
  @override
  bool get isOpen => true;
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    expect(whereArgs, [0, '100', '100']);
    entered.complete();
    return release.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stale in [false, true]) {
    test('friend reminders account changed=$stale', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final db = _Database();
      SqliteService.setDbForTest(db);
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => ref.watch(_account)),
        ],
      );
      final subscription = container.listen(newFriendRemindProvider, (_, _) {});
      addTearDown(() {
        subscription.close();
        container.dispose();
        SqliteService.setDbForTest(null);
      });
      final pending = container
          .read(newFriendRemindProvider.notifier)
          .countReminders();
      await db.entered.future;
      if (stale) {
        await StorageService.to.setString(Keys.currentUid, '101');
        container.read(_account.notifier).select('101');
        await container.pump();
      }
      db.release.complete([
        {NewFriendRepo.from: '200'},
        {NewFriendRepo.from: '200'},
        {NewFriendRepo.from: null},
      ]);
      await pending;
      expect(
        container.read(newFriendRemindProvider),
        stale ? <String>{} : {'200'},
      );
      if (!stale) {
        container.read(_account.notifier).select('100');
        await container.pump();
        expect(container.read(newFriendRemindProvider), {'200'});
        await StorageService.to.setString(Keys.currentUid, '101');
        container.read(_account.notifier).select('101');
        await container.pump();
        expect(container.read(newFriendRemindProvider), isEmpty);
      }
    });
  }
}
