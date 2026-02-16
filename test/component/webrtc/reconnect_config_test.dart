/// WebRTC 重连配置测试
///
/// 测试重连策略和配置计算
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/webrtc/reconnect/reconnect_config.dart';

void main() {
  group('WebRTCReconnectConfig', () {
    test('should create default config', () {
      final config = WebRTCReconnectConfig.defaultConfig();

      expect(config.enabled, isTrue);
      expect(config.strategy, equals(ReconnectStrategy.exponential));
      expect(config.maxRetries, equals(3));
      expect(config.retryDelay, equals(const Duration(seconds: 2)));
      expect(config.maxBackoff, equals(const Duration(seconds: 30)));
    });

    test('should calculate retry delay for fixed strategy', () {
      final config = WebRTCReconnectConfig(
        strategy: ReconnectStrategy.fixed,
        maxRetries: 3,
        retryDelay: const Duration(seconds: 2),
        maxBackoff: const Duration(seconds: 10),
      );

      // 固定策略：每次都是相同的延迟
      expect(config.calculateRetryDelay(0), equals(const Duration(seconds: 2)));
      expect(config.calculateRetryDelay(1), equals(const Duration(seconds: 2)));
      expect(config.calculateRetryDelay(2), equals(const Duration(seconds: 2)));
    });

    test('should calculate retry delay for exponential strategy', () {
      final config = WebRTCReconnectConfig(
        strategy: ReconnectStrategy.exponential,
        maxRetries: 5,
        retryDelay: const Duration(seconds: 1),
        maxBackoff: const Duration(seconds: 32),
      );

      // 指数退避：1, 2, 4, 8, 16, 32(max)
      expect(config.calculateRetryDelay(0), equals(const Duration(seconds: 1)));
      expect(config.calculateRetryDelay(1), equals(const Duration(seconds: 2)));
      expect(config.calculateRetryDelay(2), equals(const Duration(seconds: 4)));
      expect(config.calculateRetryDelay(3), equals(const Duration(seconds: 8)));
      expect(config.calculateRetryDelay(4), equals(const Duration(seconds: 16)));
      expect(config.calculateRetryDelay(5), equals(const Duration(seconds: 32))); // max
      expect(config.calculateRetryDelay(6), equals(const Duration(seconds: 32))); // max
    });

    test('should calculate retry delay for linear strategy', () {
      final config = WebRTCReconnectConfig(
        strategy: ReconnectStrategy.linear,
        maxRetries: 4,
        retryDelay: const Duration(seconds: 1),
        maxBackoff: const Duration(seconds: 5),
      );

      // 线性增长：1, 2, 3, 4, 5(max) - 使用 retryDelay * (retryCount + 1)
      expect(config.calculateRetryDelay(0), equals(const Duration(seconds: 1)));
      expect(config.calculateRetryDelay(1), equals(const Duration(seconds: 2)));
      expect(config.calculateRetryDelay(2), equals(const Duration(seconds: 3)));
      expect(config.calculateRetryDelay(3), equals(const Duration(seconds: 4)));
      expect(config.calculateRetryDelay(4), equals(const Duration(seconds: 5))); // max
    });

    test('should respect max backoff limit', () {
      final config = WebRTCReconnectConfig(
        strategy: ReconnectStrategy.exponential,
        maxRetries: 10,
        retryDelay: const Duration(seconds: 10),
        maxBackoff: const Duration(seconds: 30),
      );

      // 即使计算值超过 maxBackoff，也应该被限制
      expect(config.calculateRetryDelay(10), equals(const Duration(seconds: 30)));
    });

    test('should create heartbeat disabled config', () {
      final config = WebRTCReconnectConfig(
        enabled: false,
        heartbeatInterval: const Duration(seconds: 10),
        heartbeatTimeout: const Duration(seconds: 30),
      );

      expect(config.enabled, isFalse);
    });
  });

  group('ReconnectStrategy', () {
    test('should have correct enum values', () {
      expect(ReconnectStrategy.values.length, equals(3));
      expect(ReconnectStrategy.fixed, isNotNull);
      expect(ReconnectStrategy.exponential, isNotNull);
      expect(ReconnectStrategy.linear, isNotNull);
    });
  });
}
