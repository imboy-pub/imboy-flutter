import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/account_media_cache_store.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _FailingOwnershipStore extends InMemorySharedPreferencesStore {
  _FailingOwnershipStore() : super.empty();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.contains(AccountMediaCacheStore.indexPrefix)) return false;
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const accountA = AccountLocalTaskOwner(
    uid: 'a',
    environment: 'local',
    endpoint: 'https://cache.example.test',
  );
  const accountB = AccountLocalTaskOwner(
    uid: 'b',
    environment: 'local',
    endpoint: 'https://cache.example.test',
  );
  late Directory root;
  late AccountMediaCacheStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    root = await Directory.systemTemp.createTemp('imboy-cache-index-');
    store = AccountMediaCacheStore(
      cacheDirectory: () async => root,
      temporaryDirectory: () async => Directory('${root.path}/temporary'),
    );
  });
  tearDown(() async => root.delete(recursive: true));

  test('a rejected ownership write cannot publish an index', () async {
    final previous = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance = _FailingOwnershipStore();
    addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
    await expectLater(
      store.reserve(accountA, 'objkey://synthetic'),
      throwsStateError,
    );
    expect(
      StorageService.to.containsKey(AccountMediaCacheStore.indexKey(accountA)),
      isFalse,
    );
    expect(await root.list().isEmpty, isTrue);
  });

  test(
    'failed removal retains its owner index for a new service retry',
    () async {
      final aKey = await store.reserve(accountA, 'objkey://same');
      final bKey = await store.reserve(accountB, 'objkey://same');
      final cache = <String>{aKey, bKey};
      await expectLater(
        store.removeAccount(
          accountA,
          deleteKey: (_) async {},
          containsKey: (key) async => cache.contains(key),
        ),
        throwsStateError,
      );
      expect(
        StorageService.to.getStringList(
          AccountMediaCacheStore.indexKey(accountA),
        ),
        [aKey],
      );
      final restarted = AccountMediaCacheStore(
        cacheDirectory: () async => root,
        temporaryDirectory: () async => Directory('${root.path}/temporary'),
      );
      await restarted.removeAccount(
        accountA,
        deleteKey: (key) async {
          cache.remove(key);
        },
        containsKey: (key) async => cache.contains(key),
      );
      expect(cache, {bKey});
      expect(
        StorageService.to.containsKey(
          AccountMediaCacheStore.indexKey(accountA),
        ),
        isFalse,
      );
      expect(
        StorageService.to.getStringList(
          AccountMediaCacheStore.indexKey(accountB),
        ),
        [bKey],
      );
    },
  );

  test('malformed or cross-owner indexes block before file removal', () async {
    final bKey = await store.reserve(accountB, 'objkey://same');
    await StorageService.to.setList(AccountMediaCacheStore.indexKey(accountA), [
      bKey,
    ]);
    await expectLater(
      store.assertRemovalCanBeAttributed(),
      throwsA(isA<AccountLocalDataOwnershipException>()),
    );
    expect(
      StorageService.to.getStringList(
        AccountMediaCacheStore.indexKey(accountB),
      ),
      [bKey],
    );
  });
}
