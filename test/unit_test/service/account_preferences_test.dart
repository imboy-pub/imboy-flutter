import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/services/chat_burn_service.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/account_preferences.dart';
import 'package:imboy/service/storage.dart';

class _DelayedAccountStore extends InMemorySharedPreferencesStore {
  _DelayedAccountStore(this.key) : super.empty();
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: 'synthetic-A'});
    await StorageService.init();
  });

  for (final key in [
    'chat_search_history',
    'user_collect_pinned_ids',
    ChatBurnService.deletedMessageIdsKey,
  ]) {
    test(
      '$key isolates A and B and leaves unknown legacy values unchanged',
      () async {
        await StorageService.to.setList(key, ['mixed legacy']);
        final a = AccountPreferences.capture();
        expect(a.readList(key), isEmpty);
        await a.writeList(key, ['A value']);
        await StorageService.to.setString(Keys.currentUid, 'synthetic-B');
        final b = AccountPreferences.capture();
        expect(b.readList(key), isEmpty);
        await b.writeList(key, ['B value']);
        await a.writeList(key, ['late A value']);
        await a.remove(key);
        expect(a.readList(key), isEmpty);
        expect(b.readList(key), ['B value']);
        expect(StorageService.to.getStringList(a.owner.preferenceKey(key)), [
          'A value',
        ]);
        expect(StorageService.to.getStringList(key), ['mixed legacy']);
      },
    );

    test(
      '$key waits for a native write before cleanup and ignores late callbacks',
      () async {
        final a = AccountPreferences.capture();
        final scopedKey = a.owner.preferenceKey(key);
        final store = _DelayedAccountStore(scopedKey);
        SharedPreferencesStorePlatform.instance = store;
        final pending = a.writeList(key, ['in flight']);
        await store.entered.future;
        final cleanup = AccountLocalTaskRegistry.instance.beginCleanup(a.owner);
        var stopped = false;
        final joined = cleanup.stopped.then((_) => stopped = true);
        try {
          await a.writeList(key, ['callback during cleanup']);
          expect(stopped, isFalse);
          await StorageService.to.remove(Keys.currentUid);
          store.release.complete();
          await pending;
          await joined;
          await StorageService.to.remove(scopedKey);
          cleanup.release();
          await a.writeList(key, ['callback after cleanup']);
          expect(StorageService.to.getStringList(scopedKey), isNull);
          expect(await store.getAll(), isNot(contains('flutter.$scopedKey')));
        } finally {
          if (!store.release.isCompleted) store.release.complete();
          await pending;
          await cleanup.stopped;
          cleanup.release();
        }
      },
    );
  }

  test('same uid in another environment has independent preferences', () async {
    final previous = currentEnv;
    try {
      currentEnv = 'dev';
      final dev = AccountPreferences.capture();
      await dev.writeList('chat_search_history', ['dev only']);
      currentEnv = 'pro';
      final production = AccountPreferences.capture();
      expect(production.readList('chat_search_history'), isEmpty);
      expect(dev.isCurrent, isFalse);
      expect(dev.owner.storageDigest, isNot(production.owner.storageDigest));
    } finally {
      currentEnv = previous;
    }
  });

  test(
    'deleted-message reads and retention cleanup use the captured account',
    () async {
      const service = ChatBurnService();
      final a = AccountPreferences.capture();
      await service.recordDeletedMessageId('same-message-id', a);
      expect(await ChatNotifier.isMessageDeleted('same-message-id'), isTrue);
      await StorageService.to.setString(Keys.currentUid, 'synthetic-B');
      final b = AccountPreferences.capture();
      expect(await ChatNotifier.isMessageDeleted('same-message-id'), isFalse);
      await service.recordDeletedMessageId('B-message', b);
      await service.recordDeletedMessageId('late-A-message', a);
      await service.cleanupDeletedMessageIds(a);
      expect(await ChatNotifier.isMessageDeleted('B-message'), isTrue);
      expect(await ChatNotifier.isMessageDeleted('late-A-message'), isFalse);
      expect(
        StorageService.to.getStringList(
          a.owner.preferenceKey(ChatBurnService.deletedMessageIdsKey),
        ),
        hasLength(1),
      );
    },
  );
}
