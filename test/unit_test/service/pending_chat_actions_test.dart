import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/pending_chat_actions.dart';
import 'package:imboy/service/storage.dart';

class _DelayedPendingStore extends InMemorySharedPreferencesStore {
  _DelayedPendingStore() : super.empty();
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${PendingChatActions.readReceiptsKey}' &&
        !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  final pending = PendingChatActions.instance;
  const reads = PendingChatActions.readReceiptsKey;
  const reactions = PendingChatActions.reactionsKey;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test(
    'account removal keeps foreign owners even when action ids are equal',
    () async {
      for (final key in [reads, reactions]) {
        await StorageService.to.setString(
          key,
          jsonEncode([
            {'from': 'A', 'id': 'same'},
            {'from': 'AB', 'id': 'same'},
            {'from': 'B', 'id': 'same'},
          ]),
        );
      }
      await pending.validateAccountRemoval('A');
      await pending.removeAccount('A');
      for (final key in [reads, reactions]) {
        expect(await pending.snapshot(key), [
          {'from': 'AB', 'id': 'same'},
          {'from': 'B', 'id': 'same'},
        ]);
      }
      await pending.removeAccount('A');
      expect(await pending.snapshot(reads), hasLength(2));
    },
  );

  for (final unknown in [
    '{',
    '{}',
    '[1]',
    '[{}]',
    '[{"from":""}]',
    '[{"from":100}]',
  ]) {
    test(
      'unknown pending ownership refuses preflight and removal without partial changes: $unknown',
      () async {
        final retained = jsonEncode([
          {'from': 'A', 'id': 'read'},
        ]);
        await StorageService.to.setString(reads, retained);
        await StorageService.to.setString(reactions, unknown);
        await expectLater(
          pending.validateAccountRemoval('A'),
          throwsA(isA<AccountLocalDataOwnershipException>()),
        );
        await expectLater(
          pending.removeAccount('A'),
          throwsA(isA<AccountLocalDataOwnershipException>()),
        );
        expect(StorageService.to.getString(reads), retained);
        expect(StorageService.to.getString(reactions), unknown);
      },
    );
  }

  test('removal joins an in-flight mutation and stale queued updates cannot restore A', () async {
    final store = _DelayedPendingStore();
    SharedPreferencesStorePlatform.instance = store;
    var current = true;
    final write = pending.update(
      reads,
      (items) => items.addAll([
        {'from': 'A', 'id': 'A-read'},
        {'from': 'B', 'id': 'B-read'},
      ]),
      isCurrent: () => current,
    );
    await store.entered.future;
    final cleanup = pending.removeAccount('A');
    final late = pending.update(
      reads,
      (items) => items.add({'from': 'A', 'id': 'late'}),
      isCurrent: () => current,
    );
    current = false;
    try {
      store.release.complete();
      await Future.wait([write, cleanup, late]);
      expect(await pending.snapshot(reads), [
        {'from': 'B', 'id': 'B-read'},
      ]);
      final persisted = await store.getAll();
      expect(jsonDecode(persisted['flutter.$reads'] as String), [
        {'from': 'B', 'id': 'B-read'},
      ]);
    } finally {
      if (!store.release.isCompleted) store.release.complete();
      await Future.wait([write, cleanup, late]);
    }
  });
}
