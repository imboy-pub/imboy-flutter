import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/notification.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<Map<String, Object?>> active;
  late List<String> calls;
  late NotificationService service;
  late AccountLocalTaskOwner accountA, accountB;
  Completer<void>? showing, release;
  Completer<void>? initializing, releaseInitialization;
  var rejectCancel = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    active = [];
    calls = [];
    showing = release = null;
    initializing = releaseInitialization = null;
    rejectCancel = false;
    accountA = AccountLocalTaskOwner.capture(uid: 'notification-a');
    accountB = AccountLocalTaskOwner.capture(uid: 'notification-b');
    service = NotificationService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'initialize') {
            initializing?.complete();
            await releaseInitialization?.future;
            return true;
          }
          if (call.method == 'getActiveNotifications') return active;
          final args = call.arguments as Map?;
          if (call.method == 'show') {
            showing?.complete();
            await release?.future;
            final details = args!['platformSpecifics'] as Map;
            active.add({
              'id': args['id'],
              'groupKey': details['groupKey'],
              'tag': details['tag'],
            });
          }
          if (call.method == 'cancel' && !rejectCancel) {
            active.removeWhere(
              (item) => item['id'] == args!['id'] && item['tag'] == args['tag'],
            );
          }
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'targeted cleanup preserves B and public device notifications',
    () async {
      for (final uid in [accountA.uid, accountB.uid, '']) {
        await StorageService.to.setString(Keys.currentUid, uid);
        await service.show(
          id: 7,
          title: 'Synthetic',
          body: 'Notification',
          devicePublic: uid.isEmpty,
        );
      }
      expect(active.length, 3);
      await service.validateAccountRemoval();
      await service.cancelAccount(accountA);
      expect(
        active.map((item) => item['groupKey']),
        unorderedEquals([
          'imboy-account:${accountB.storageDigest}',
          'imboy-device',
        ]),
      );
      expect(calls, isNot(contains('cancelAll')));
    },
  );

  test(
    'unattributed legacy notification blocks without cancelling anything',
    () async {
      active.add({'id': 1, 'groupKey': null});
      await expectLater(
        service.validateAccountRemoval(),
        throwsA(isA<AccountLocalDataOwnershipException>()),
      );
      expect(active.length, 1);
      expect(calls, isNot(contains('cancel')));
    },
  );

  test(
    'anonymous account messages never become public device notices',
    () async {
      await expectLater(
        service.showMessageNotification(
          senderName: 'Synthetic',
          content: 'Message',
          conversationUk3: 'C2C:synthetic',
          peerId: 'synthetic-peer',
          chatType: 'C2C',
        ),
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );
      expect(calls, isEmpty);
      expect(active, isEmpty);
    },
  );

  test(
    'old captured session cannot publish into B or a newer A session',
    () async {
      await StorageService.to.setString(Keys.currentUid, accountA.uid);
      final captured = authSessionReader.current;
      await StorageService.to.setString(Keys.currentUid, accountB.uid);
      await service.show(title: 'B', body: 'Retained');
      await expectLater(
        service.show(
          title: 'Old A',
          body: 'Discarded',
          session: captured,
          owner: accountA,
        ),
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );
      await StorageService.to.setString(Keys.currentUid, accountA.uid);
      await expectLater(
        service.show(
          title: 'Previous A generation',
          body: 'Discarded',
          owner: accountA,
          session: (
            uid: captured.uid,
            generation: captured.generation - 1,
            transitioning: false,
          ),
        ),
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );
      expect(
        active.single['groupKey'],
        'imboy-account:${accountB.storageDigest}',
      );
    },
  );

  test(
    'account switch during platform initialization discards only A',
    () async {
      await StorageService.to.setString(Keys.currentUid, accountA.uid);
      initializing = Completer<void>();
      releaseInitialization = Completer<void>();
      final pending = expectLater(
        service.show(title: 'A', body: 'Discarded'),
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );
      await initializing!.future.timeout(const Duration(seconds: 5));
      await StorageService.to.setString(Keys.currentUid, accountB.uid);
      releaseInitialization!.complete();
      await pending;
      expect(active, isEmpty);
      await service.show(title: 'B', body: 'Retained');
      expect(
        active.single['groupKey'],
        'imboy-account:${accountB.storageDigest}',
      );
    },
  );

  test('a rejected cancellation reports failure and allows retry', () async {
    await StorageService.to.setString(Keys.currentUid, accountA.uid);
    await service.show(id: 7, title: 'Synthetic', body: 'Notification');
    rejectCancel = true;
    await expectLater(service.cancelAccount(accountA), throwsStateError);
    expect(active, isNotEmpty);
    rejectCancel = false;
    await service.cancelAccount(accountA);
    expect(active, isEmpty);
  });

  test(
    'cleanup waits for an already entered platform notification write',
    () async {
      await StorageService.to.setString(Keys.currentUid, accountA.uid);
      showing = Completer<void>();
      release = Completer<void>();
      final pending = service.show(title: 'Synthetic', body: 'Notification');
      final cancelled = expectLater(
        pending,
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );
      await showing!.future.timeout(const Duration(seconds: 5));
      final lease = AccountLocalTaskRegistry.instance.beginCleanup(accountA);
      addTearDown(lease.release);
      var stopped = false;
      final stopping = lease.stopped.then((_) {
        stopped = true;
      });
      await Future<void>.value();
      expect(stopped, isFalse);
      release!.complete();
      await stopping;
      await cancelled;
      await service.cancelAccount(accountA);
      expect(active, isEmpty);
    },
  );
}
