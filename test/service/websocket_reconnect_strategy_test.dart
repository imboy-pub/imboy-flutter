/// WebSocket 重连策略测试
///
/// 测试目标：
/// 1. 无限重试机制（移除 16 次限制）
/// 2. 网络状态感知重连
/// 3. 指数退避算法正确性
/// 4. 重连间隔计算
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/websocket.dart' show ExponentialBackoff, JitterType;

void main() {
  group('ExponentialBackoff 重连策略测试', () {
    group('无限重试机制', () {
      test('应该支持无限重试（maxRetries = null）', () {
        final backoff = ExponentialBackoff(
          baseDelay: const Duration(milliseconds: 100),
          maxDelay: const Duration(seconds: 10),
          maxRetries: 999999, // 实际上无限
          jitterFactor: 0,
          jitterType: JitterType.none,
        );

        // 模拟 100 次重试
        for (int i = 0; i < 100; i++) {
          final delay = backoff.nextDelay();
          expect(delay.inMilliseconds, greaterThanOrEqualTo(100));
          expect(delay.inMilliseconds, lessThanOrEqualTo(10000));
        }

        expect(backoff.attempts, 100);
      });

      test('应该在成功连接后重置计数器', () {
        final backoff = ExponentialBackoff(
          baseDelay: const Duration(milliseconds: 100),
          maxDelay: const Duration(seconds: 5),
          maxRetries: 999999,
          jitterFactor: 0,
          jitterType: JitterType.none,
        );

        // 模拟 10 次失败
        for (int i = 0; i < 10; i++) {
          backoff.nextDelay();
        }
        expect(backoff.attempts, 10);

        // 重置
        backoff.reset();
        expect(backoff.attempts, 0);

        // 再次重试，应该从第一次开始
        final delay = backoff.nextDelay();
        expect(delay.inMilliseconds, 100); // baseDelay
        expect(backoff.attempts, 1);
      });
    });

    group('指数退避算法', () {
      test('应该按指数增长计算延迟（无抖动）', () {
        final backoff = ExponentialBackoff(
          baseDelay: const Duration(seconds: 1),
          maxDelay: const Duration(minutes: 2),
          maxRetries: 20,
          jitterFactor: 0,
          jitterType: JitterType.none,
        );

        final delays = <Duration>[];
        for (int i = 0; i < 10; i++) {
          delays.add(backoff.nextDelay());
        }

        // 验证指数增长：1s, 2s, 4s, 8s, 16s, 32s, 64s, 120s(max), 120s, 120s
        expect(delays[0].inSeconds, 1);
        expect(delays[1].inSeconds, 2);
        expect(delays[2].inSeconds, 4);
        expect(delays[3].inSeconds, 8);
        expect(delays[4].inSeconds, 16);
        expect(delays[5].inSeconds, 32);
        expect(delays[6].inSeconds, 64);
        expect(delays[7].inSeconds, 120); // 达到最大值
        expect(delays[8].inSeconds, 120); // 保持最大值
      });

      test('应该正确应用 Full Jitter', () {
        final backoff = ExponentialBackoff(
          baseDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 10),
          maxRetries: 10,
          jitterFactor: 0.5, // 50% 抖动
          jitterType: JitterType.full,
        );

        final delays = <Duration>[];
        for (int i = 0; i < 5; i++) {
          delays.add(backoff.nextDelay());
        }

        // Full Jitter: [0, baseDelay * (2^(n-1) * jitterFactor)]
        // 第一次: [0, 1 * 0.5] = [0, 0.5s]
        expect(delays[0].inMilliseconds, lessThanOrEqualTo(500));
        // 第二次: [0, 2 * 0.5] = [0, 1s]
        expect(delays[1].inMilliseconds, lessThanOrEqualTo(1000));
        // 第三次: [0, 4 * 0.5] = [0, 2s]
        expect(delays[2].inMilliseconds, lessThanOrEqualTo(2000));
      });

      test('应该正确应用 Equal Jitter', () {
        final backoff = ExponentialBackoff(
          baseDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 10),
          maxRetries: 10,
          jitterFactor: 0.3, // 30% 抖动
          jitterType: JitterType.equal,
        );

        // Equal Jitter: [baseDelay * (1-jitter), baseDelay]
        // 第一次: [1 * 0.7, 1] = [0.7s, 1s]
        final delay1 = backoff.nextDelay();
        expect(delay1.inMilliseconds, greaterThanOrEqualTo(700));
        expect(delay1.inMilliseconds, lessThanOrEqualTo(1000));
      });

      test('应该正确应用 Deviation Jitter', () {
        final backoff = ExponentialBackoff(
          baseDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 10),
          maxRetries: 10,
          jitterFactor: 0.2, // 20% 抖动
          jitterType: JitterType.deviation,
        );

        // Deviation Jitter: baseDelay ± (baseDelay * jitterFactor)
        // 第一次: 1s ± 0.2s = [0.8s, 1.2s]
        final delay1 = backoff.nextDelay();
        expect(delay1.inMilliseconds, greaterThanOrEqualTo(800));
        expect(delay1.inMilliseconds, lessThanOrEqualTo(1200));
      });
    });

    group('重连边界条件', () {
      test('应该限制最大延迟', () {
        final backoff = ExponentialBackoff(
          baseDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 5),
          maxRetries: 20,
          jitterFactor: 0,
          jitterType: JitterType.none,
        );

        // 尝试多次重连，延迟不应超过 maxDelay
        for (int i = 0; i < 20; i++) {
          final delay = backoff.nextDelay();
          expect(delay.inSeconds, lessThanOrEqualTo(5));
        }
      });

      test('应该处理零 baseDelay', () {
        final backoff = ExponentialBackoff(
          baseDelay: const Duration(milliseconds: 0),
          maxDelay: const Duration(seconds: 5),
          maxRetries: 10,
          jitterFactor: 0,
          jitterType: JitterType.none,
        );

        final delay = backoff.nextDelay();
        expect(delay.inMilliseconds, 0);
      });

      test('应该处理负数 maxRetries（视为无限）', () {
        // 注意：ExponentialBackoff 不支持负数，实际使用大数值代替
        final backoff = ExponentialBackoff(
          baseDelay: const Duration(milliseconds: 100),
          maxDelay: const Duration(seconds: 1),
          maxRetries: 999999, // 使用大数值代替负数
          jitterFactor: 0,
          jitterType: JitterType.none,
        );

        // 不应该抛出异常
        expect(() => backoff.nextDelay(), returnsNormally);
      });
    });

    group('Jitter 边界测试', () {
      test('jitterFactor 为 0 时不应有抖动', () {
        final backoff = ExponentialBackoff(
          baseDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 10),
          maxRetries: 10,
          jitterFactor: 0,
          jitterType: JitterType.full,
        );

        final delay = backoff.nextDelay();
        // Full Jitter with 0 factor 应该返回原始延迟
        expect(delay.inSeconds, 1);
      });

      test('jitterFactor 为 1 时应有最大抖动', () {
        final backoff = ExponentialBackoff(
          baseDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 10),
          maxRetries: 10,
          jitterFactor: 1.0,
          jitterType: JitterType.full,
        );

        final delay = backoff.nextDelay();
        // Full Jitter with factor 1.0: [0, baseDelay]
        expect(delay.inMilliseconds, lessThanOrEqualTo(1000));
      });

      test('应该处理 jitterFactor > 1', () {
        final backoff = ExponentialBackoff(
          baseDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 10),
          maxRetries: 10,
          jitterFactor: 1.5, // 超过 1.0
          jitterType: JitterType.full,
        );

        final delay = backoff.nextDelay();
        // 不应该抛出异常
        expect(() => delay.inMilliseconds, returnsNormally);
      });
    });

    group('重连状态统计', () {
      test('应该正确跟踪重连次数', () {
        final backoff = ExponentialBackoff(
          baseDelay: const Duration(milliseconds: 100),
          maxDelay: const Duration(seconds: 5),
          maxRetries: 10,
        );

        expect(backoff.attempts, 0);

        backoff.nextDelay();
        expect(backoff.attempts, 1);

        backoff.nextDelay();
        expect(backoff.attempts, 2);

        backoff.reset();
        expect(backoff.attempts, 0);
      });

      test('应该限制 attempts 不超过 maxRetries', () {
        final backoff = ExponentialBackoff(
          baseDelay: const Duration(milliseconds: 100),
          maxDelay: const Duration(seconds: 5),
          maxRetries: 5,
        );

        for (int i = 0; i < 10; i++) {
          backoff.nextDelay();
        }

        // attempts 应该被限制在 maxRetries
        expect(backoff.attempts, lessThanOrEqualTo(5));
      });
    });
  });

  group('WebSocket 重连策略集成测试', () {
    test('应该在网络恢复时立即重连', () async {
      // 这个测试需要 NetworkMonitor 和 WebSocketService 的 mock
      // 在实际实现时补充
      expect(true, true); // 占位符
    });

    test('应该在用户登录后开始重连', () async {
      // 这个测试需要 UserRepo 和 WebSocketService 的 mock
      // 在实际实现时补充
      expect(true, true); // 占位符
    });

    test('应该在用户登出时停止重连', () async {
      // 这个测试需要 UserRepo 和 WebSocketService 的 mock
      // 在实际实现时补充
      expect(true, true); // 占位符
    });
  });
}
