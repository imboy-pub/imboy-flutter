import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/collect_keychain.dart';
import 'package:imboy/service/e2ee/e2ee_secret_inventory.dart';

/// C05 清单接线（PLAN 2026-10-24-e2ee-collect §6）：
/// - CollectKeychain 持久键落 `collect_ck_` 前缀，logout/换号 purge 可达；
/// - purgeAll 同时丢弃单例内存副本——否则换号后 load() 命中缓存，
///   吐出前一账号的 CK 版本链（跨账号密钥泄漏）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStore = <String, String?>{};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    secureStore.clear();
    CollectKeychain.to.clearCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = call.arguments as Map<Object?, Object?>?;
          switch (call.method) {
            case 'write':
              secureStore[args!['key'] as String] = args['value'] as String?;
              return null;
            case 'read':
              return secureStore[args!['key'] as String];
            case 'delete':
              secureStore.remove(args!['key'] as String);
              return null;
            case 'containsKey':
              return secureStore.containsKey(args!['key'] as String);
            default:
              return null;
          }
        });
  });

  tearDown(() {
    CollectKeychain.to.clearCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  E2eeSecretInventory inventoryOverStore() => E2eeSecretInventory(
    readAll: () async => {
      for (final e in secureStore.entries) e.key: e.value ?? '',
    },
    deleteKey: (k) async => secureStore.remove(k),
    clearMemoryCaches: [CollectKeychain.to.clearCache],
  );

  test('持久键落 collect_ck_ 前缀，被清单 matchesSecretKey 覆盖', () async {
    await CollectKeychain.to.ensureBootstrap();
    expect(secureStore.keys, hasLength(1));
    final key = secureStore.keys.single;
    expect(key, startsWith('collect_ck_'));
    expect(E2eeSecretInventory.matchesSecretKey(key), isTrue);
  });

  test('purgeAll 清持久键并丢内存副本：之后 load() 为空链', () async {
    final before = await CollectKeychain.to.ensureBootstrap();
    expect(before.keys, isNotEmpty);

    await inventoryOverStore().purgeAll();

    expect(secureStore.keys.where((k) => k.startsWith('collect_ck_')), isEmpty);
    final after = await CollectKeychain.to.load();
    expect(after.keys, isEmpty, reason: '内存副本未清会让下一账号读到前一账号 CK');
  });

  test('仅删持久键不清缓存 → load 仍命中旧链（clearCache 接线必要）', () async {
    await CollectKeychain.to.ensureBootstrap();
    secureStore.clear();

    final stale = await CollectKeychain.to.load();
    expect(stale.keys, isNotEmpty, reason: '缓存命中：这正是 purge 必须清内存的原因');

    CollectKeychain.to.clearCache();
    final fresh = await CollectKeychain.to.load();
    expect(fresh.keys, isEmpty);
  });
}
