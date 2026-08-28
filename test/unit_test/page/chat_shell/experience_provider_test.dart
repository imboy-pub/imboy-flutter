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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/service/storage.dart';

void main() {
  setUp(() async {
    // 每个用例从「无缓存」状态出发（离线首启等价态）
    await StorageService.to.remove(Keys.effectiveProductExperience);
    await StorageService.to.remove(Keys.localProductExperience);
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
