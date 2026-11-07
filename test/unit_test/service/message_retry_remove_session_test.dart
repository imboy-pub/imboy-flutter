import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _Database implements Database {
  int confirmations = 0;
  void Function()? onOpen;
  Future<void> Function()? onOutboxProbe;
  @override
  bool get isOpen {
    final callback = onOpen;
    onOpen = null;
    callback?.call();
    return true;
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    confirmations++;
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async => 0;
  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    // 45019020 起 CryptoStore.confirmOutbox 先查 sqlite_master 里
    // crypto_outbox 表是否存在（明文 ACK 跳过可选表确认）。探测是参数化
    // SQL（表名在绑定参数里），mock 库需按参数应答该探测，ACK 移除才能
    // 走到 UPDATE（confirmations 计数）。
    if (sql.contains('sqlite_master') &&
        arguments?.contains('crypto_outbox') == true) {
      final callback = onOutboxProbe;
      onOutboxProbe = null;
      if (callback != null) await callback();
      return [
        <String, Object?>{'name': 'crypto_outbox'},
      ];
    }
    return [];
  }

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
  }) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  for (final phase in [
    'current',
    'before_delivery',
    'owner_switch',
    'owner_round_trip',
    'outbox_getter',
    'outbox_probe',
    'outbox_probe_owner_switch',
  ]) {
    test('retry remove session phase=$phase', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final database = _Database();
      final otherDatabase = _Database();
      SqliteService.setDbForTest(database);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, (call) async {
            if (call.method == 'write' &&
                (call.arguments as Map)['key'] == 'secure_token') {
              throw PlatformException(code: 'synthetic-login-stop');
            }
            return null;
          });
      final retry = MessageRetry.instance;
      Future<void> change() => expectLater(
        UserRepoLocal.to.loginAfter('synthetic-session', {
          'uid': '101',
          'token': 'synthetic-token',
          'refreshtoken': 'synthetic-refresh',
        }),
        throwsA(isA<PlatformException>()),
      );
      final beforeDelivery = {
        'before_delivery',
        'owner_switch',
        'owner_round_trip',
      }.contains(phase);
      final probeStarted = Completer<void>();
      final releaseProbe = Completer<void>();
      try {
        await retry.debugWaitForIdle();
        retry.addToRetryQueue('synthetic-shared-id', 'C2C');
        await pumpEventQueue();
        final event = RemoveFromRetryQueueRequestedEvent(
          messageId: 'synthetic-shared-id',
          messageType: 'C2C_SERVER_ACK',
          reason: 'server_ack',
        );
        if (beforeDelivery) {
          await change();
          if (phase == 'owner_switch' || phase == 'owner_round_trip') {
            await StorageService.to.setString(Keys.currentUid, '101');
            if (phase == 'owner_round_trip') {
              // Returning to the same UID must not revive the old generation.
              await change();
              await StorageService.to.setString(Keys.currentUid, '100');
            }
            SqliteService.setDbForTest(
              phase == 'owner_switch' ? otherDatabase : database,
            );
          }
          retry.clearRetryQueue();
          retry.addToRetryQueue('synthetic-shared-id', 'C2C');
          await pumpEventQueue();
        }
        var current = retry.getRetryInfo('synthetic-shared-id');
        Future<void>? changed;
        if (phase == 'outbox_getter') {
          database.onOpen = () {
            changed = change();
          };
        }
        if (phase.startsWith('outbox_probe')) {
          database.onOutboxProbe = () async {
            probeStarted.complete();
            await releaseProbe.future;
          };
        }
        AppEventBus.fire(event);
        if (phase.startsWith('outbox_probe')) {
          // Force the await inside confirmOutbox, after its caller's session
          // check, to resume only once the captured generation is obsolete.
          await probeStarted.future;
          await change();
          if (phase == 'outbox_probe_owner_switch') {
            await StorageService.to.setString(Keys.currentUid, '101');
            SqliteService.setDbForTest(otherDatabase);
            retry.addToRetryQueue('synthetic-shared-id', 'C2C');
            current = retry.getRetryInfo('synthetic-shared-id');
          }
          releaseProbe.complete();
        }
        await pumpEventQueue();
        if (changed != null) await changed;
        expect(
          retry.getRetryInfo('synthetic-shared-id'),
          beforeDelivery || phase == 'outbox_probe_owner_switch'
              ? same(current)
              : isNull,
        );
        expect(database.confirmations, phase == 'current' ? 1 : 0);
        expect(otherDatabase.confirmations, 0);
      } finally {
        if (!releaseProbe.isCompleted) releaseProbe.complete();
        await retry.debugWaitForIdle();
        retry.dispose();
        SqliteService.setDbForTest(null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureChannel, null);
        UserRepoLocal.to.clearAuthTransitionFailureForTest();
      }
    });
  }
}
