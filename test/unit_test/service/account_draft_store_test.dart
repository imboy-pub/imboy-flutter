import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/account_draft_store.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/utils/chat_draft_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Sessions extends ChangeNotifier implements AuthSessionReader {
  @override
  AuthSessionScope current = (uid: 'A', generation: 1, transitioning: false);

  @override
  bool isCurrent(AuthSessionScope captured) =>
      captured.uid.isNotEmpty &&
      !captured.transitioning &&
      !current.transitioning &&
      captured.uid == current.uid &&
      captured.generation == current.generation;
}

class _DelayedDraftStore extends InMemorySharedPreferencesStore {
  _DelayedDraftStore(this.key) : super.empty();
  final String key;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<bool> setValue(
    String valueType,
    String prefixedKey,
    Object value,
  ) async {
    if (prefixedKey == 'flutter.$key' && !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return super.setValue(valueType, prefixedKey, value);
  }
}

void main() {
  final aKeys = chatDraftKeys('A', 'C2C', 'peer:1')!;
  final bKeys = chatDraftKeys('B', 'C2C', 'peer:1')!;

  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: 'A'});
    await StorageService.init();
  });

  test(
    'retains UID keys and rejects reads, saves and resets from old account',
    () async {
      final a = AccountDraftStore.capture('C2C', 'peer:1');
      await a.save('A text', cursor: 3);
      expect(aKeys.text, 'draft_v2:A:C2C:peer%3A1');
      expect(StorageService.to.getString(aKeys.text), 'A text');
      await StorageService.to.setString(Keys.currentUid, 'B');
      final b = AccountDraftStore.capture('C2C', 'peer:1');
      await b.save('B text', cursor: 2);
      await a.save('late A', cursor: 1);
      await a.clear();
      expect(a.read(), (text: '', cursor: null));
      expect(b.read(), (text: 'B text', cursor: 2));
      expect(StorageService.to.getString(aKeys.text), 'A text');
      expect(StorageService.to.getString(aKeys.cursor), '3');
    },
  );

  for (final heldKey in [aKeys.text, aKeys.cursor]) {
    test('cleanup drains native $heldKey and rejects queued work', () async {
      final store = _DelayedDraftStore(heldKey);
      SharedPreferencesStorePlatform.instance = store;
      await StorageService.to.setString(bKeys.text, 'B text');
      await StorageService.to.setString('synthetic_device_setting', 'keep');
      final a = AccountDraftStore.capture('C2C', 'peer:1');
      final pending = a.save('in flight A', cursor: 4);
      await store.entered.future;
      final queuedSave = a.save('queued A', cursor: 1);
      final queuedReset = a.clear();
      final cleanup = AccountLocalTaskRegistry.instance.beginCleanup(a.owner);
      var stopped = false;
      final joined = cleanup.stopped.then<void>((_) => stopped = true);
      try {
        await a.save('during cleanup', cursor: 2);
        expect(stopped, isFalse);
        await StorageService.to.setString(Keys.currentUid, 'B');
        final b = AccountDraftStore.capture('C2C', 'peer:1');
        await b.save('B continues', cursor: 3);
        store.release.complete();
        await Future.wait([pending, queuedSave, queuedReset, joined]);
        await StorageService.to.remove(aKeys.text);
        await StorageService.to.remove(aKeys.cursor);
        cleanup.release();
        await a.save('after cleanup', cursor: 5);
        await a.clear();
        expect(StorageService.to.getKeys(), isNot(contains(aKeys.text)));
        expect(StorageService.to.getKeys(), isNot(contains(aKeys.cursor)));
        final native = await store.getAll();
        expect(native, isNot(contains('flutter.${aKeys.text}')));
        expect(native, isNot(contains('flutter.${aKeys.cursor}')));
        expect(b.read(), (text: 'B continues', cursor: 3));
        expect(StorageService.to.getString('synthetic_device_setting'), 'keep');
      } finally {
        if (!store.release.isCompleted) store.release.complete();
        await Future.wait([pending, queuedSave, queuedReset]);
        await cleanup.stopped;
        cleanup.release();
      }
    });
  }

  test(
    'reset waits behind an older native save and removes text and cursor',
    () async {
      final store = _DelayedDraftStore(aKeys.text);
      SharedPreferencesStorePlatform.instance = store;
      final draft = AccountDraftStore.capture('C2C', 'peer:1');
      final pending = draft.save('sending', cursor: 2);
      await store.entered.future;
      final reset = draft.clear();
      try {
        store.release.complete();
        await Future.wait([pending, reset]);
        expect(StorageService.to.getKeys(), isNot(contains(aKeys.text)));
        expect(StorageService.to.getKeys(), isNot(contains(aKeys.cursor)));
        expect(await store.getAll(), isNot(contains('flutter.${aKeys.text}')));
      } finally {
        if (!store.release.isCompleted) store.release.complete();
        await Future.wait([pending, reset]);
      }
    },
  );

  test(
    'old page cannot save or reset after cleanup and same UID signs in again',
    () async {
      final sessions = _Sessions();
      addTearDown(sessions.dispose);
      final old = AccountDraftStore.capture(
        'C2C',
        'peer:1',
        sessionReader: sessions,
      );
      await old.save('old session', cursor: 2);
      final cleanup = AccountLocalTaskRegistry.instance.beginCleanup(old.owner);
      sessions.current = (uid: '', generation: 2, transitioning: true);
      try {
        await cleanup.stopped;
        await StorageService.to.remove(aKeys.text);
        await StorageService.to.remove(aKeys.cursor);
      } finally {
        cleanup.release();
      }
      sessions.current = (uid: 'A', generation: 3, transitioning: false);
      final fresh = AccountDraftStore.capture(
        'C2C',
        'peer:1',
        sessionReader: sessions,
      );
      await fresh.save('new login', cursor: 3);
      await old.clear();
      await old.save('late old text', cursor: 1);
      expect(old.read(), (text: '', cursor: null));
      expect(fresh.read(), (text: 'new login', cursor: 3));
    },
  );
}
