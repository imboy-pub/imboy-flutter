/// T2 (WP1) — Product Experience 消费层测试
///
/// 覆盖（任务卡要求的三个降级场景 + 缓存链路）：
/// - 默认 experience=chat（无缓存 / 字段缺失）
/// - 未知值降级 chat（空串 / 未知字符串 / 非字符串类型）
/// - init payload 字段缺失降级（T1 未就绪）
/// - workspace 已知值识别
/// - StorageService 缓存 → provider 读取全链路
/// - wire 字段名与 StorageService key 一致性（防漂移）
///
/// StorageService 由 test/unit_test/flutter_test_config.dart 全局以
/// SharedPreferences mock 初始化，可直接读写。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Native plugin test seam, already installed by shared_preferences.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _PreferenceStore extends SharedPreferencesStorePlatform {
  final values = <String, Object>{};
  final writes = <String>[];
  String failure = '';
  Completer<void>? pending;

  Future<bool> _write(String key, Object? value) async {
    writes.add(value?.toString() ?? 'remove');
    final gate = pending;
    pending = null;
    if (gate != null) await gate.future;
    if (failure == 'throw') throw StateError('synthetic preference failure');
    if (failure == 'false') return false;
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      _write(key, value);
  @override
  Future<bool> remove(String key) => _write(key, null);
  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async => Map.of(values);
}

Future<_PreferenceStore> _installStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = _PreferenceStore();
  SharedPreferencesStorePlatform.instance = store;
  await StorageService.init();
  addTearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });
  return store;
}

void main() {
  setUp(() async {
    // 每个用例从「无缓存」状态出发（离线首启等价态）
    await StorageService.to.remove(Keys.effectiveProductExperience);
    await StorageService.to.remove(Keys.localProductExperience);
  });

  for (final failure in ['false', 'throw']) {
    test('企业指针保存 $failure：不发布未持久化企业', () async {
      final native = await _installStore();
      const account = 'synthetic-pointer-account';
      final pointer = CurrentOrganizationStore.forAccount(account);
      addTearDown(() => CurrentOrganizationStore.disposeAccount(account));
      await pointer.set(const Organization(id: '10', name: 'synthetic old'));
      native.failure = failure;
      await expectLater(
        pointer.set(const Organization(id: '20', name: 'synthetic new')),
        throwsA(isA<StateError>()),
      );
      expect(pointer.value?.id, '10');
      expect(
        StorageService.to.getString('$kCurrentOrgStoragePrefix$account'),
        contains('synthetic old'),
      );
      native.failure = '';
    });
    for (final reset in [false, true]) {
      test('原生偏好 ${reset ? '删除' : '保存'} $failure：失败不切布局也不污染读取缓存', () async {
        final store = await _installStore();
        await StorageService.to.setString(Keys.localProductExperience, 'chat');
        await StorageService.to.setString(
          Keys.effectiveProductExperience,
          'workspace',
        );
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(productExperienceProvider.notifier);
        final published = <ProductExperience>[];
        container.listen(
          productExperienceProvider,
          (_, next) => published.add(next),
        );
        store.failure = failure;
        final change = reset
            ? notifier.resetToDefault()
            : notifier.select(ProductExperience.workspace);
        await expectLater(change, throwsA(isA<StateError>()));
        expect(
          container.read(productExperienceProvider),
          ProductExperience.chat,
        );
        expect(
          StorageService.to.getString(Keys.localProductExperience),
          'chat',
        );
        expect(store.values['flutter.${Keys.localProductExperience}'], 'chat');
        expect(published, isEmpty);
        store.failure = '';
        await notifier.select(ProductExperience.workspace);
        expect(
          container.read(productExperienceProvider),
          ProductExperience.workspace,
        );
      });
    }
  }

  test('保存完成前不发布布局，连续切换按顺序写入', () async {
    final store = await _installStore();
    final gate = Completer<void>();
    store.pending = gate;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(productExperienceProvider.notifier);
    final first = notifier.select(ProductExperience.workspace);
    await Future<void>.delayed(Duration.zero);
    final second = notifier.select(ProductExperience.chat);
    expect(container.read(productExperienceProvider), ProductExperience.chat);
    expect(store.writes, ['workspace']);
    gate.complete();
    await Future.wait([first, second]);
    expect(store.writes, ['workspace', 'chat']);
    expect(container.read(productExperienceProvider), ProductExperience.chat);
    expect(store.values['flutter.${Keys.localProductExperience}'], 'chat');
  });

  test('恢复默认值与保存共用顺序，不被迟到的保存覆盖', () async {
    final store = await _installStore();
    final gate = Completer<void>();
    store.pending = gate;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(productExperienceProvider.notifier);
    final first = notifier.select(ProductExperience.workspace);
    await Future<void>.delayed(Duration.zero);
    final reset = notifier.resetToDefault();
    gate.complete();
    await Future.wait([first, reset]);
    expect(store.writes, ['workspace', 'remove']);
    expect(container.read(productExperienceProvider), ProductExperience.chat);
    expect(
      store.values.containsKey('flutter.${Keys.localProductExperience}'),
      isFalse,
    );
  });

  test('选择当前默认布局也保存明确偏好，后续部署默认值不能覆盖', () async {
    final store = await _installStore();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.chat);
    expect(store.writes, ['chat']);
    await StorageService.to.setString(
      Keys.effectiveProductExperience,
      'workspace',
    );
    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    expect(restarted.read(productExperienceProvider), ProductExperience.chat);
  });

  group('parseProductExperience — fail-safe 解析', () {
    test('null → chat（字段缺失）', () {
      expect(parseProductExperience(null), ProductExperience.chat);
    });

    test('空串 → chat（T1 未就绪时 initConfig 写入空串）', () {
      expect(parseProductExperience(''), ProductExperience.chat);
    });

    test('未知值 → chat（大小写敏感 + 无前后空格容忍）', () {
      expect(parseProductExperience('enterprise'), ProductExperience.chat);
      expect(parseProductExperience('CHAT'), ProductExperience.chat);
      expect(parseProductExperience(' workspace'), ProductExperience.chat);
      expect(parseProductExperience('workspace '), ProductExperience.chat);
      expect(parseProductExperience('community'), ProductExperience.chat);
    });

    test('chat → chat（显式已知值）', () {
      expect(parseProductExperience('chat'), ProductExperience.chat);
    });

    test('workspace → workspace（唯一非 chat 已知值）', () {
      expect(parseProductExperience('workspace'), ProductExperience.workspace);
    });
  });

  group('resolveProductExperienceFromPayload — /api/v1/init 字段解析', () {
    test('null payload → chat', () {
      expect(resolveProductExperienceFromPayload(null), ProductExperience.chat);
    });

    test('字段缺失（T1 未就绪的旧后端响应）→ chat', () {
      expect(
        resolveProductExperienceFromPayload({
          'ws_url': 'wss://example',
          'public_base_url': 'https://s3.example',
        }),
        ProductExperience.chat,
      );
    });

    test('字段为非字符串（number / bool / null 显式存在）→ chat', () {
      expect(
        resolveProductExperienceFromPayload({
          kEffectiveProductExperienceField: 42,
        }),
        ProductExperience.chat,
      );
      expect(
        resolveProductExperienceFromPayload({
          kEffectiveProductExperienceField: true,
        }),
        ProductExperience.chat,
      );
      expect(
        resolveProductExperienceFromPayload({
          kEffectiveProductExperienceField: null,
        }),
        ProductExperience.chat,
      );
    });

    test('effective_product_experience=chat → chat', () {
      expect(
        resolveProductExperienceFromPayload({
          kEffectiveProductExperienceField: 'chat',
        }),
        ProductExperience.chat,
      );
    });

    test('effective_product_experience=workspace → workspace', () {
      expect(
        resolveProductExperienceFromPayload({
          kEffectiveProductExperienceField: 'workspace',
        }),
        ProductExperience.workspace,
      );
    });

    test('effective_product_experience=未知字符串 → chat', () {
      expect(
        resolveProductExperienceFromPayload({
          kEffectiveProductExperienceField: 'galaxy',
        }),
        ProductExperience.chat,
      );
    });
  });

  group('readCachedProductExperience — StorageService 缓存链路', () {
    test('无缓存（离线首启）→ chat（离线回落）', () {
      expect(readCachedProductExperience(), ProductExperience.chat);
    });

    test('缓存空串（T1 未就绪时 initConfig 已写空值）→ chat', () async {
      await StorageService.to.setString(Keys.effectiveProductExperience, '');
      expect(readCachedProductExperience(), ProductExperience.chat);
    });

    test('缓存未知值 → chat', () async {
      await StorageService.to.setString(
        Keys.effectiveProductExperience,
        'beta-verse',
      );
      expect(readCachedProductExperience(), ProductExperience.chat);
    });

    test('缓存 workspace → workspace（服务端有效值优先）', () async {
      await StorageService.to.setString(
        Keys.effectiveProductExperience,
        'workspace',
      );
      expect(readCachedProductExperience(), ProductExperience.workspace);
    });
  });

  group('productExperienceProvider — 消费方唯一入口', () {
    test('默认（无缓存）experience=chat → 渲染 ChatShell 的前提', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(productExperienceProvider), ProductExperience.chat);
    });

    test('缓存 workspace → provider 读到 workspace', () async {
      await StorageService.to.setString(
        Keys.effectiveProductExperience,
        'workspace',
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(productExperienceProvider),
        ProductExperience.workspace,
      );
    });

    test('缓存未知值 → provider 降级 chat', () async {
      await StorageService.to.setString(Keys.effectiveProductExperience, '???');
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(productExperienceProvider), ProductExperience.chat);
    });

    test('initConfig 覆盖缓存后（模拟下次启动）provider 生效值同步变化', () async {
      final container1 = ProviderContainer();
      addTearDown(container1.dispose);
      expect(
        container1.read(productExperienceProvider),
        ProductExperience.chat,
      );

      // 安装级切换：受控重启后 initConfig 覆盖缓存（§4.1 切换语义）
      await StorageService.to.setString(
        Keys.effectiveProductExperience,
        'workspace',
      );

      // 新的 ProviderContainer 等价于下次启动的新 provider 实例
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      expect(
        container2.read(productExperienceProvider),
        ProductExperience.workspace,
      );
    });

    test('用户本机选择优先于服务端默认值，并在新的 ProviderContainer 中保留', () async {
      await StorageService.to.setString(
        Keys.effectiveProductExperience,
        ProductExperience.workspace.wireName,
      );
      final container1 = ProviderContainer();
      addTearDown(container1.dispose);
      expect(
        container1.read(productExperienceProvider),
        ProductExperience.workspace,
      );

      await container1
          .read(productExperienceProvider.notifier)
          .select(ProductExperience.chat);
      expect(
        container1.read(productExperienceProvider),
        ProductExperience.chat,
      );
      expect(
        StorageService.to.getString(Keys.localProductExperience),
        ProductExperience.chat.wireName,
      );

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      expect(
        container2.read(productExperienceProvider),
        ProductExperience.chat,
      );
    });

    test('恢复部署默认值会删除本机覆盖并立即更新状态', () async {
      await StorageService.to.setString(
        Keys.effectiveProductExperience,
        ProductExperience.workspace.wireName,
      );
      await StorageService.to.setString(
        Keys.localProductExperience,
        ProductExperience.chat.wireName,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(productExperienceProvider.notifier).resetToDefault();

      expect(
        container.read(productExperienceProvider),
        ProductExperience.workspace,
      );
      expect(StorageService.to.getString(Keys.localProductExperience), isEmpty);
    });
  });

  group('命名契约（防漂移）', () {
    test('init wire 字段名与 StorageService key 同值（镜像 public_base_url 模式）', () {
      expect(
        kEffectiveProductExperienceField,
        Keys.effectiveProductExperience,
        reason:
            'initConfig 用字面量写入、experience_provider 用 Keys 读取，'
            '两处必须同值，否则缓存永远读不到',
      );
    });

    test('ProductExperience wireName 契约', () {
      expect(ProductExperience.chat.wireName, 'chat');
      expect(ProductExperience.workspace.wireName, 'workspace');
    });
  });
}
