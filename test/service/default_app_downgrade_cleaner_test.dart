// DefaultAppDowngradeCleaner 单元测试
// Unit tests for DefaultAppDowngradeCleaner
//
// 验证降级时精确清理协议/策略缓存，保留用户身份与业务数据。
// Verifies downgrade-time purge targets protocol/strategy keys only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/default_app_downgrade_cleaner.dart';
import 'package:imboy/service/upgrade_strategy.dart';

import '../helpers/fake_storage.dart';

void main() {
  group('DefaultAppDowngradeCleaner.onDowngrade', () {
    late FakeStorage storage;
    late DefaultAppDowngradeCleaner cleaner;

    setUp(() {
      storage = FakeStorage();
      cleaner = DefaultAppDowngradeCleaner(storage: storage);
    });

    test('清理 WS 消息队列 / purges ws_message_queue', () async {
      storage.setString(
        DefaultAppDowngradeCleaner.wsMessageQueueKey,
        '[{"id":"1","payload":"..."}]',
      );

      await cleaner.onDowngrade(fromVsn: '2.0.0', toVsn: '1.0.0');

      expect(
        storage.getString(DefaultAppDowngradeCleaner.wsMessageQueueKey),
        isEmpty,
      );
    });

    test(
      '清理升级提示 dismiss 状态 / purges upgrade dismiss records',
      () async {
        storage.setString(AppUpgradeDismissState.dismissedVsnKey, '2.0.0');
        storage.setString(
          AppUpgradeDismissState.lastCheckTimeKey,
          '1700000000000',
        );

        await cleaner.onDowngrade(fromVsn: '2.0.0', toVsn: '1.0.0');

        expect(
          storage.getString(AppUpgradeDismissState.dismissedVsnKey),
          isEmpty,
        );
        expect(
          storage.getString(AppUpgradeDismissState.lastCheckTimeKey),
          isEmpty,
        );
      },
    );

    test(
      '保留用户身份与业务数据 / preserves identity and business data',
      () async {
        // 模拟用户身份与业务缓存
        // Simulate identity + business caches
        storage.setString('secure_token', 'jwt_xxx');
        storage.setString('secure_refresh_token', 'refresh_xxx');
        storage.setString('e2ee_enabled', 'true');
        storage.setString('user_profile_cache', '{"uid":"u1"}');
        storage.setString('contact_list_version', '42');

        await cleaner.onDowngrade(fromVsn: '2.0.0', toVsn: '1.0.0');

        expect(storage.getString('secure_token'), 'jwt_xxx');
        expect(storage.getString('secure_refresh_token'), 'refresh_xxx');
        expect(storage.getString('e2ee_enabled'), 'true');
        expect(storage.getString('user_profile_cache'), '{"uid":"u1"}');
        expect(storage.getString('contact_list_version'), '42');
      },
    );

    test(
      '对不存在的 key 也不报错 / idempotent on absent keys',
      () async {
        // 所有 key 都不存在
        expect(
          () => cleaner.onDowngrade(fromVsn: '2.0.0', toVsn: '1.0.0'),
          returnsNormally,
        );
      },
    );

    test('连续调用幂等 / idempotent on repeated calls', () async {
      storage.setString(
        DefaultAppDowngradeCleaner.wsMessageQueueKey,
        'queue-data',
      );

      await cleaner.onDowngrade(fromVsn: '2.0.0', toVsn: '1.0.0');
      await cleaner.onDowngrade(fromVsn: '2.0.0', toVsn: '1.0.0');

      expect(
        storage.getString(DefaultAppDowngradeCleaner.wsMessageQueueKey),
        isEmpty,
      );
    });
  });
}
