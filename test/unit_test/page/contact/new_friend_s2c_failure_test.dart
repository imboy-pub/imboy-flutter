import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/contact/new_friend/new_friend_provider.dart';
import 'package:imboy/page/contact/contact/contact_provider.dart';
import 'package:imboy/service/message_s2c.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets(
    'confirmation redelivery keeps one contact when request update fails',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        Keys.currentUid: '9007199254740995',
      });
      await StorageService.init();
      sqfliteFfiInit();
      final db = await tester.runAsync(
        () => databaseFactoryFfi.openDatabase(inMemoryDatabasePath),
      );
      SqliteService.setDbForTest(db);
      addTearDown(() async {
        SqliteService.setDbForTest(null);
        await db!.close();
      });
      await tester.runAsync(() async {
        await db!.execute('''CREATE TABLE contact (
        user_id INTEGER, peer_id INTEGER, nickname TEXT, avatar TEXT,
        account TEXT, status INTEGER, remark TEXT, tag TEXT, region TEXT,
        sign TEXT, source TEXT, gender INTEGER, is_friend INTEGER,
        is_from INTEGER, category_id INTEGER, account_type INTEGER,
        last_seen_at INTEGER, updated_at INTEGER)''');
      });
      await tester.pumpWidget(
        MaterialApp(builder: AppLoading.init(), home: const Scaffold()),
      );
      final container = ProviderContainer();
      final keep = container.listen(contactProvider, (_, _) {});
      MessageS2CService.setProviderContainer(container);
      final event = <String, dynamic>{
        'id': 'af_confirm_retry_test',
        'action': 'apply_friend_confirm',
        'from': '9007199254740993',
        'to': '9007199254740995',
        'payload': {
          'from': {'remark': '', 'source': ''},
          'to': {
            'account': '',
            'nickname': 'synthetic',
            'avatar': '',
            'sign': '',
            'gender': 0,
            'region': '',
          },
        },
      };
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.runAsync(
          () async => expectLater(
            MessageS2CService.switchS2C(event, propagateErrors: true),
            throwsA(anything),
          ),
        );
        final contacts = container.read(contactProvider).contactList;
        expect(
          contacts.where((c) => c.peerId == '9007199254740993'),
          hasLength(1),
        );
      }
      final rows = await tester.runAsync(() => db!.query('contact'));
      expect(rows, hasLength(1));
      keep.close();
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets('failed friend persistence does not complete or retain dedup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '9007199254740995',
    });
    await StorageService.init();
    sqfliteFfiInit();
    final db = await tester.runAsync(
      () => databaseFactoryFfi.openDatabase(inMemoryDatabasePath),
    );
    SqliteService.setDbForTest(db);
    addTearDown(() async {
      SqliteService.setDbForTest(null);
      await db!.close();
    });
    await tester.pumpWidget(
      MaterialApp(builder: AppLoading.init(), home: const Scaffold()),
    );
    final container = ProviderContainer();
    MessageS2CService.setProviderContainer(container);
    final data = <String, dynamic>{
      'id': 'af_failed_test',
      'action': 'apply_friend',
      'from': '9007199254740993',
      'to': '9007199254740995',
      'payload': {
        'from': {'nickname': 'synthetic'},
      },
    };
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.runAsync(
        () async => expectLater(
          MessageS2CService.switchS2C(data, propagateErrors: true),
          throwsA(anything),
        ),
      );
      expect(container.read(newFriendProvider).items, isEmpty);
    }
    await tester.runAsync(() async {
      await db!.execute('''CREATE TABLE contact (
        user_id INTEGER, peer_id INTEGER, nickname TEXT, avatar TEXT,
        account TEXT, status INTEGER, remark TEXT, tag TEXT, region TEXT,
        sign TEXT, source TEXT, gender INTEGER, is_friend INTEGER,
        is_from INTEGER, category_id INTEGER, account_type INTEGER,
        last_seen_at INTEGER, updated_at INTEGER)''');
      await db.execute('''CREATE TRIGGER contact_insert_failure
        BEFORE INSERT ON contact BEGIN SELECT RAISE(FAIL, 'injected'); END''');
    });
    final confirmation = <String, dynamic>{
      'id': 'af_confirm_failed_test',
      'action': 'apply_friend_confirm',
      'from': '9007199254740993',
      'to': '9007199254740995',
      'payload': {
        'from': {'remark': '', 'source': ''},
        'to': {
          'account': '',
          'nickname': '',
          'avatar': '',
          'sign': '',
          'gender': 0,
          'region': '',
        },
      },
    };
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.runAsync(
        () async => expectLater(
          MessageS2CService.switchS2C(confirmation, propagateErrors: true),
          throwsA(anything),
        ),
      );
      expect(container.read(contactProvider).contactList, isEmpty);
    }
    container.dispose();
    await tester.pump();
  });
}
