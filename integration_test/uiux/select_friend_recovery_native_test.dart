import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/select_friend.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../enterprise/macos_storage_isolation.dart';

const _uid = '990044';
const _peer = '990045';
const _name = 'UX04 Synthetic Alice';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('UX04 physical Android contact failure and recovery', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    expect(const bool.fromEnvironment('IMBOY_ANDROID_QA_BUILD'), isTrue);
    expect(const bool.fromEnvironment('IMBOY_TEST_ISOLATED'), isTrue);
    expect(const String.fromEnvironment('APP_ENV'), 'local');
    expect((await DeviceInfoPlugin().androidInfo).isPhysicalDevice, isTrue);
    expect(
      (await PackageInfo.fromPlatform()).packageName,
      'pub.imboy.app.uiuxqa',
    );
    final previousEnv = currentEnv;
    final root = await tester.runAsync(isolateNativeStorage);
    expect(root, isNotNull);
    Database? native;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        // Restore ownership of the real handle before closing and scoped cleanup.
        if (native != null) SqliteService.setDbForTest(native);
        await SqliteService.to.close();
        SqliteService.setDbForTest(null);
        await clearMacosStorage(root!);
        currentEnv = previousEnv;
      });
    });
    await tester.runAsync(() async {
      currentEnv = 'local';
      await StorageService.init();
      await StorageService.to.persistPreference(
        () => StorageService.to.setString(Keys.currentUid, _uid),
      );
      native = await SqliteService.to.db;
      expect(native, isNotNull, reason: 'real native SQLCipher initialization');
      expect(native!.path, startsWith('${root!.path}/'));
      final cipher = await native!.rawQuery('PRAGMA cipher_version');
      expect(cipher, isNotEmpty);
      expect(cipher.first.values.single.toString(), isNotEmpty);
      expect(
        await native!.query('contact'),
        isEmpty,
        reason: 'fresh scoped database must not contain inherited contacts',
      );
      await ContactRepo().insert(
        ContactModel(peerId: _peer, nickname: _name, updatedAt: 1790000000000),
      );
      final stored = await native!.query(
        'contact',
        where: 'user_id = ? AND peer_id = ?',
        whereArgs: [_uid, _peer],
      );
      expect(stored, hasLength(1));
      expect(stored.single['nickname'], _name);
      await native!.rawQuery('PRAGMA wal_checkpoint(FULL)');
      final header = await File(native!.path)
          .openRead(0, 16)
          .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
      expect(header, hasLength(16));
      expect(
        ascii.decode(header, allowInvalid: true),
        isNot('SQLite format 3\u0000'),
      );
    });
    final faults = _ContactQueryFault(native!)..failNext();
    SqliteService.setDbForTest(faults);
    await _mount(tester);
    await _open(tester);
    await _wait(
      tester,
      () => tester.any(find.text(t.common.loadError)),
      'initial error',
    );
    expect(find.byType(ShimmerList), findsNothing);
    expect(faults.queries, 1);
    expect(faults.failures, 1);
    expect(faults.delegated, 0);
    await tester.tap(find.text(t.common.buttonRetry));
    await _wait(
      tester,
      () => tester.any(find.text(_name)),
      'retry reads real row',
    );
    expect(find.text(t.common.loadError), findsNothing);
    expect(faults.queries, 2);
    expect(faults.delegated, 1);

    faults.failNext();
    final contacts = find
        .descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
          ),
        )
        .hitTestable();
    expect(contacts, findsOneWidget);
    await tester.drag(contacts, const Offset(0, 320));
    await _wait(
      tester,
      () => tester.any(find.text(t.common.loadError)),
      'refresh error',
    );
    expect(
      find.text(_name),
      findsOneWidget,
      reason: 'failed refresh retains real row',
    );
    expect(faults.queries, 3);
    expect(faults.failures, 2);
    await tester.tap(find.text(t.common.buttonRetry));
    await _wait(
      tester,
      () =>
          !tester.any(find.text(t.common.loadError)) &&
          tester.any(find.text(_name)),
      'refresh retry',
    );
    expect(faults.queries, 4);
    expect(faults.delegated, 2);

    final search = find.byKey(const Key('select_friend_search_input'));
    await tester.tap(search);
    await _wait(
      tester,
      () => View.of(tester.element(search)).viewInsets.bottom > 0,
      'real Android keyboard',
    );
    await tester.enterText(search, 'Alice');
    await tester.pump();
    expect(find.text(_name).hitTestable(), findsOneWidget);
    await tester.tap(find.text(_name));
    await _wait(
      tester,
      () => tester.any(find.byType(CupertinoAlertDialog)),
      'selection confirmation',
    );
    expect(find.text(t.chat.sendTo), findsOneWidget);
    expect(find.text(_name), findsNWidgets(2));
    await tester.tap(find.text(t.common.buttonCancel));
    await _wait(
      tester,
      () => !tester.any(find.byType(CupertinoAlertDialog)),
      'selection cancellation',
    );
    expect(find.text(_name), findsOneWidget);
    expect(
      faults.queries,
      4,
      reason: 'search and cancellation do not requery or send',
    );
    await tester.tap(find.byIcon(CupertinoIcons.xmark));
    await _wait(
      tester,
      () => !tester.any(find.byType(SelectFriendPage)),
      'close after keyboard',
    );
    await _wait(
      tester,
      () =>
          View.of(tester.element(find.text('Open synthetic contacts')))
              .viewInsets
              .bottom ==
          0,
      'keyboard dismissal after return',
    );

    await tester.runAsync(() async {
      expect(
        await native!.delete(
          'contact',
          where: 'user_id = ? AND peer_id = ?',
          whereArgs: [_uid, _peer],
        ),
        1,
      );
    });
    await _open(tester);
    await _wait(
      tester,
      () => tester.any(find.text(t.common.noContacts)),
      'real empty query',
    );
    expect(find.byType(ShimmerList), findsNothing);
    expect(find.text(t.common.loadError), findsNothing);
    expect(find.text(t.common.buttonRetry), findsNothing);
    expect(faults.queries, 5);
    expect(faults.delegated, 3);
    expect(faults.failures, 2);
    expect(faults.pendingFailure, isFalse);
    await tester.binding.handlePopRoute();
    await _wait(
      tester,
      () => !tester.any(find.byType(SelectFriendPage)),
      'route return',
    );
    expect(find.text('Open synthetic contacts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<void> _mount(WidgetTester tester) async {
  await LocaleSettings.setLocale(AppLocale.zhCn);
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const SelectFriendPage(
                      peer: {
                        'nickname': 'Synthetic card',
                        'title': 'Synthetic card',
                        'avatar': '',
                      },
                      peerIsReceiver: true,
                    ),
                  ),
                ),
                child: const Text('Open synthetic contacts'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open synthetic contacts'));
  await _wait(
    tester,
    () => tester.any(find.byType(SelectFriendPage)),
    'contact route',
  );
}

Future<void> _wait(
  WidgetTester tester,
  bool Function() ready,
  String stage,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 25));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  expect(ready(), isTrue, reason: 'UX04 native $stage');
  expect(tester.takeException(), isNull);
}

/// Only the next contact query fails; every successful query uses native SQLCipher.
class _ContactQueryFault implements Database {
  _ContactQueryFault(this.native);
  final Database native;
  int queries = 0;
  int failures = 0;
  int delegated = 0;
  bool pendingFailure = false;
  void failNext() {
    expect(pendingFailure, isFalse);
    pendingFailure = true;
  }

  @override
  bool get isOpen => native.isOpen;
  @override
  String get path => native.path;
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
  }) async {
    if (table == 'contact') {
      // Native callbacks may overlap a guarded tester pump; validate without expect.
      if (whereArgs == null ||
          whereArgs.length != 2 ||
          whereArgs[0] != _uid ||
          whereArgs[1] != 1) {
        throw StateError('UX04 unexpected contact query scope');
      }
      queries++;
      if (pendingFailure) {
        pendingFailure = false;
        failures++;
        throw StateError('UX04 one-shot synthetic contact query failure');
      }
      delegated++;
    }
    return native.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected UX04 database operation: ${invocation.memberName}',
  );
}
