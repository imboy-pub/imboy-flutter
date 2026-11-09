/// ACK 管理器增强测试
///
/// 测试目标（IMBOY_AUTOTEST AT03 / M01、M02）：
/// 1. ACK 发送、待确认状态与统计的真实行为（精确计数，非恒真断言）
/// 2. 确认/拒绝语义区分：确认记 RTT 成功指标；拒绝停止重试且不记成功指标
/// 3. 超时清理边界：未过期（<30s）的待确认 ACK 必须保留，不得提前丢失重试义务
/// 4. 重试策略契约：RetryPolicy 间隔边界与最大重试次数一致；重试命中上限事件可观测
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/message_operation_events.dart';
import 'package:imboy/service/retry_policy.dart';

void main() {
  group('AckManager 增强测试', () {
    late AckManager ackManager;

    setUp(() {
      ackManager = AckManager.to;
      ackManager.clear();
    });

    tearDown(() {
      ackManager.clear();
    });

    group('ACK 发送和待确认状态', () {
      test('应该正确生成 ACK 消息格式', () {
        const type = 'C2C';
        const msgId = 'msg_123';
        const deviceId = 'test_device';

        final ackMsg = ackManager.generateAckMessage(
          type,
          msgId,
          overrideDeviceId: deviceId,
        );

        expect(ackMsg, contains('CLIENT_ACK'));
        expect(ackMsg, contains(type));
        expect(ackMsg, contains(msgId));
        expect(ackMsg, contains(deviceId));
      });

      test('应该在参数为空时抛出异常', () {
        expect(
          () => ackManager.generateAckMessage('', 'msg_123'),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => ackManager.generateAckMessage('C2C', ''),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('发送 ACK 后待确认恰好为该一条', () {
        ackManager.sendAck('C2C', 'msg_123', overrideDeviceId: 'test_device');

        expect(ackManager.pendingCount, 1);
        expect(ackManager.pendingAckList, ['msg_123']);
      });

      test('多条 ACK 各自独立登记待确认', () {
        ackManager.sendAck('C2C', 'msg_a', overrideDeviceId: 'test_device');
        ackManager.sendAck('C2G', 'msg_b', overrideDeviceId: 'test_device');
        ackManager.sendAck('C2C', 'msg_c', overrideDeviceId: 'test_device');

        expect(ackManager.pendingCount, 3);
        expect(
          ackManager.pendingAckList,
          containsAll(<String>['msg_a', 'msg_b', 'msg_c']),
        );
      });

      test('getStats 反映真实待确认数与重试契约常量', () {
        ackManager.sendAck('C2C', 'msg_1', overrideDeviceId: 'test_device');
        ackManager.sendAck('C2G', 'msg_2', overrideDeviceId: 'test_device');

        final stats = ackManager.getStats();

        expect(stats['pending_count'], 2);
        expect(stats['max_retries'], RetryPolicy.maxRetryAttempts);
        expect(
          stats['retry_interval_ms'],
          RetryPolicy.ackConfirmRetryIntervals.first,
        );
        expect(stats['pending_ack_list'], isA<List<dynamic>>());
      });

      test('dispose 清空全部待确认', () {
        ackManager.sendAck('C2C', 'msg_1', overrideDeviceId: 'test_device');
        ackManager.sendAck('C2G', 'msg_2', overrideDeviceId: 'test_device');

        expect(ackManager.pendingCount, 2);

        ackManager.dispose();

        expect(ackManager.pendingCount, 0);
      });
    });

    group('ACK 确认与拒绝语义（M01：失败/拒绝不得推进成功）', () {
      test('确认后移除待确认并发出 RTT 成功指标事件', () async {
        final events = <AckRttMetricsUpdatedEvent>[];
        final sub = AppEventBus.on<AckRttMetricsUpdatedEvent>().listen(
          events.add,
        );

        ackManager.sendAck('C2C', 'msg_confirmed', overrideDeviceId: 'dev');
        expect(ackManager.pendingAckList, contains('msg_confirmed'));

        ackManager.ackConfirmed('msg_confirmed');
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(ackManager.pendingCount, 0);
        expect(ackManager.pendingAckList, isNot(contains('msg_confirmed')));
        expect(events, hasLength(1));
        expect(events.single.messageId, 'msg_confirmed');
        expect(events.single.messageType, 'C2C');
        expect(events.single.retryCount, 0);
        expect(events.single.rttMs, greaterThanOrEqualTo(0));
        expect(events.single.sampleCount, 1);
        expect(events.single.p50Ms, greaterThanOrEqualTo(0));
        expect(events.single.p99Ms, greaterThanOrEqualTo(0));
      });

      test('确认不存在的收据：状态不变且不产生成功指标', () async {
        final events = <AckRttMetricsUpdatedEvent>[];
        final sub = AppEventBus.on<AckRttMetricsUpdatedEvent>().listen(
          events.add,
        );

        ackManager.sendAck('C2C', 'msg_real', overrideDeviceId: 'dev');
        ackManager.ackConfirmed('msg_unknown');
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(ackManager.pendingCount, 1);
        expect(ackManager.pendingAckList, ['msg_real']);
        expect(events, isEmpty);
      });

      test('拒绝（CLIENT_ACK_ERROR）停止重试且不记 RTT 成功指标', () async {
        final events = <AckRttMetricsUpdatedEvent>[];
        final sub = AppEventBus.on<AckRttMetricsUpdatedEvent>().listen(
          events.add,
        );

        ackManager.sendAck('C2C', 'msg_rejected', overrideDeviceId: 'dev');
        expect(ackManager.pendingCount, 1);

        ackManager.ackRejected('msg_rejected', reason: 'invalid_receipt');
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(ackManager.pendingCount, 0);
        expect(ackManager.pendingAckList, isNot(contains('msg_rejected')));
        expect(events, isEmpty, reason: '被拒绝的收据不得进入成功 RTT 统计');
      });
    });

    group('ACK 超时清理边界（不得提前丢失重试义务）', () {
      test('未过期（<30s）的待确认 ACK 在清理后必须原样保留', () async {
        ackManager.sendAck('C2C', 'msg_fresh', overrideDeviceId: 'dev');

        // 首次重试间隔 3s、过期阈值 30s：100ms 远未到期
        await Future<void>.delayed(const Duration(milliseconds: 100));
        ackManager.cleanupExpired();

        expect(
          ackManager.pendingCount,
          1,
          reason: '提前清理会让客户端丢失 CLIENT_ACK 重试义务',
        );
        expect(ackManager.pendingAckList, ['msg_fresh']);
      });

      test('清理后再确认仍走完整移除路径', () async {
        ackManager.sendAck('C2C', 'msg_keep', overrideDeviceId: 'dev');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        ackManager.cleanupExpired();
        expect(ackManager.pendingCount, 1);

        ackManager.ackConfirmed('msg_keep');
        expect(ackManager.pendingCount, 0);
      });
    });

    group('重试策略契约与命中上限事件（M02：不超过配置重试次数）', () {
      test('ackConfirmIntervalAt 边界：负数取首档、越界钳制到末档', () {
        expect(RetryPolicy.ackConfirmIntervalAt(-1), 3000);
        expect(RetryPolicy.ackConfirmIntervalAt(0), 3000);
        expect(RetryPolicy.ackConfirmIntervalAt(1), 5000);
        expect(RetryPolicy.ackConfirmIntervalAt(2), 10000);
        expect(RetryPolicy.ackConfirmIntervalAt(3), 15000);
        expect(RetryPolicy.ackConfirmIntervalAt(4), 15000);
        expect(RetryPolicy.ackConfirmIntervalAt(99), 15000);
      });

      test('最大重试次数与间隔档数一致（单一真值契约）', () {
        expect(RetryPolicy.maxRetryAttempts, 4);
        expect(
          RetryPolicy.ackConfirmRetryIntervals.length,
          RetryPolicy.maxRetryAttempts,
          reason: '间隔档数与最大重试次数必须同源一致',
        );
      });

      test('重试命中上限事件携带完整告警字段且可重复观测', () async {
        final events = <AckRetryCeilingReachedEvent>[];
        final sub = AppEventBus.on<AckRetryCeilingReachedEvent>().listen(
          events.add,
        );

        ackManager.debugMarkRetryCeilingReached(messageId: 'msg_ceiling_1');
        ackManager.debugMarkRetryCeilingReached(
          messageId: 'msg_ceiling_2',
          messageType: 'C2G',
        );
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(events, hasLength(2));
        final first = events.first;
        expect(first.messageId, 'msg_ceiling_1');
        expect(first.messageType, 'C2C');
        expect(first.retryCount, RetryPolicy.maxRetryAttempts);
        expect(first.maxRetryCount, RetryPolicy.maxRetryAttempts);
        expect(first.occurredAtMs, greaterThan(0));
        expect(first.pendingCount, greaterThanOrEqualTo(0));
        expect(events.last.messageType, 'C2G');
      });
    });
  });
}
