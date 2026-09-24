import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/service/storage.dart';

/// 再收口④：持久化写失败的真实测试。
///
/// 本文件**刻意不调用 StorageService.init()**——flutter test 每文件独立
/// isolate，因此这里是唯一能构造「持久化层未就绪」真实失败的环境。
/// 合同：store persist-first——写失败必须抛出，且内存保持旧值不变
/// （§14.3 补偿路径依赖这一语义才能看到一致旧状态）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('未初始化持久化：set 抛出且内存不变（persist-first 原子性）', () async {
    final store = CurrentOrganizationStore.forAccount('uninit-uid');
    expect(store.value, isNull, reason: '未初始化读路径容错回落 null');

    await expectLater(
      store.set(const Organization(id: 'org-x', name: 'X')),
      throwsException,
      reason: 'StorageService 未初始化：setString 必须抛出（persist 先行）',
    );
    expect(store.value, isNull, reason: 'persist-first：持久化失败时内存绝不先落新值');
  });

  test('未初始化持久化：restore 同样抛出且内存不变', () async {
    final store = CurrentOrganizationStore.forAccount('uninit-uid-2');
    await expectLater(store.restore(null), throwsException);
    expect(store.value, isNull);
  });

  test('StorageService.to 在未初始化下读路径容错（不抛）', () {
    // 读路径（getString）在未初始化时由 store 的 _ensureLoaded try/catch
    // 吞掉——forAccount 已在上面两条中隐式验证（未抛出即通过）。
    expect(StorageService.to, isNotNull);
  });
}
