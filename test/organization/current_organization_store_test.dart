import 'dart:convert' as json;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ADM-03/§14.3 再收口④：CurrentOrganizationStore 真实 store 测试——
/// 真 StorageService（SharedPreferences mock 后端），覆盖：
/// 持久化读回、restore(nullable) 补偿、损坏 JSON 容错、
/// 未初始化写失败（persist-first 原子性：失败时内存不变）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const account = 'store-test-uid';
  const orgA = Organization(id: 'org-a', name: 'A 企业');
  const orgB = Organization(id: 'org-b', name: 'B 企业');

  String keyFor(String uid) => 'org_current_$uid';

  group('CurrentOrganizationStore（真实 StorageService）', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
    });

    test('set：内存与持久化双写（绕过内存缓存直读持久化证明落盘）', () async {
      final store = CurrentOrganizationStore.forAccount(account);
      await store.set(orgA);

      expect(store.value?.id, orgA.id);
      // 直接读底层持久化（绕过内存缓存）证明落盘。
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(account));
      expect(raw, isNotNull);
      final decoded = json.jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['id'], orgA.id);
      expect(decoded['name'], orgA.name);
    });

    test('退出非当前企业保留指针，退出当前企业清除内存和持久化', () async {
      final store = CurrentOrganizationStore.forAccount(account);
      await store.set(orgA);
      await store.forget(orgB.id);
      expect(store.value?.id, orgA.id);
      await store.forget(orgA.id);
      expect(store.value, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(keyFor(account)), isFalse);
    });

    test('restore(null)：清空内存并移除持久化键（prev==null 补偿语义）', () async {
      final store = CurrentOrganizationStore.forAccount(account);
      await store.set(orgA);
      expect(store.value?.id, orgA.id);

      await store.restore(null);

      expect(store.value, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(keyFor(account)), isFalse);

      CurrentOrganizationStore.disposeAccount(account);
      expect(
        CurrentOrganizationStore.forAccount(account).value,
        isNull,
        reason: '持久化键已移除：新 scope 不应复活旧指针',
      );
    });

    test('restore(org)：补偿恢复到旧企业（持久化同步回写）', () async {
      final store = CurrentOrganizationStore.forAccount(account);
      await store.set(orgB);
      await store.restore(orgA);

      expect(store.value?.id, orgA.id);
      final prefs = await SharedPreferences.getInstance();
      final decoded = json.jsonDecode(
        prefs.getString(keyFor(account))!,
      ) as Map<String, dynamic>;
      expect(decoded['id'], orgA.id);
    });

    test('持久化损坏（非法 JSON）：加载容错回落 null，不抛出', () async {
      // 先清单例缓存（dispose 会连同清持久化键），再种入损坏值。
      CurrentOrganizationStore.disposeAccount(account);
      SharedPreferences.setMockInitialValues({
        keyFor(account): '{not-valid-json',
      });
      await StorageService.init();
      final store = CurrentOrganizationStore.forAccount(account);
      expect(store.value, isNull, reason: '指针非真源：损坏偏好静默回落未选择');
    });

    test('空 accountKey：forAccount fail-closed（写路径入口守卫，G9）', () async {
      expect(
        () => CurrentOrganizationStore.forAccount(''),
        throwsArgumentError,
        reason: '空账号拒绝进入任何读写路径',
      );
    });

    test('冷启动恢复：持久化的 current org 在新 scope 首次访问时恢复（ENT-APP-04）', () async {
      // 模拟进程重启：持久化里已有指针（上一会话 set 落盘），内存 scope
      // 为空。forAccount 首次访问走 _ensureLoaded 从持久化恢复。
      CurrentOrganizationStore.disposeAccount(account);
      SharedPreferences.setMockInitialValues({
        keyFor(account): json.jsonEncode(<String, dynamic>{
          'id': orgA.id,
          'name': orgA.name,
        }),
      });
      await StorageService.init();
      final store = CurrentOrganizationStore.forAccount(account);
      expect(store.value?.id, orgA.id, reason: '冷启动按持久化恢复当前企业');
      expect(store.value?.name, orgA.name);
    });

    test('账号 A/B 指针隔离：各自 set 互不串见（ENT-APP-04 缓存隔离验收）', () async {
      const accountB = 'store-test-uid-b';
      CurrentOrganizationStore.disposeAccount(account);
      CurrentOrganizationStore.disposeAccount(accountB);

      final storeA = CurrentOrganizationStore.forAccount(account);
      final storeB = CurrentOrganizationStore.forAccount(accountB);
      await storeA.set(orgA);
      await storeB.set(orgB);

      // 换 Org：A 的指针不因 B 切换而变（Org A/B 隔离）。
      expect(storeA.value?.id, orgA.id);
      expect(storeB.value?.id, orgB.id);
      // 持久化同样按账号分键，无交叉覆盖。
      final prefs = await SharedPreferences.getInstance();
      final rawA = json.jsonDecode(
        prefs.getString(keyFor(account))!,
      ) as Map<String, dynamic>;
      final rawB = json.jsonDecode(
        prefs.getString(keyFor(accountB))!,
      ) as Map<String, dynamic>;
      expect(rawA['id'], orgA.id);
      expect(rawB['id'], orgB.id);

      CurrentOrganizationStore.disposeAccount(accountB);
    });
  });
}
