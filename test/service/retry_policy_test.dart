// RetryPolicy 客户端重试策略单一真值源 —— 守护测试
//
// 目的：固化三端客户端重试数值，杜绝 message_retry / ack_manager / SDK
// 各自为政且注释互相矛盾的分叉（见 ws 优化计划阶段一）。
//
// 语义区分（关键，勿与服务端投递重试混淆）：
// - messageSendRetryIntervals：客户端「发消息 → 等服务端确认」的重试节奏
//   （MessageRetry 发 C2C/C2G/C2S 等 SERVER_ACK；SDK sendWithAck 同语义）。
// - ackConfirmRetryIntervals：客户端「发 CLIENT_ACK → 等服务端 confirm」
//   的重试节奏（AckManager）。独立于服务端投递重试。
//
// 服务端「投递给接收端、等接收端 ACK、超时重投」的节奏在后端
// elib_retry_config.erl（按类型不同），是另一套语义，客户端不镜像。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/retry_policy.dart';

void main() {
  group('RetryPolicy 客户端重试单一真值源', () {
    test('messageSendRetryIntervals 为发消息等确认的节奏（4 次）', () {
      expect(RetryPolicy.messageSendRetryIntervals, [3000, 5000, 10000, 20000]);
    });

    test('ackConfirmRetryIntervals 为发 ACK 等 confirm 的节奏（4 次）', () {
      expect(RetryPolicy.ackConfirmRetryIntervals, [3000, 5000, 10000, 15000]);
    });

    test('maxRetryAttempts 为 4（两个语义一致）', () {
      expect(RetryPolicy.maxRetryAttempts, 4);
    });

    test('两个语义的重试次数都等于 maxRetryAttempts', () {
      expect(
        RetryPolicy.messageSendRetryIntervals.length,
        RetryPolicy.maxRetryAttempts,
      );
      expect(
        RetryPolicy.ackConfirmRetryIntervals.length,
        RetryPolicy.maxRetryAttempts,
      );
    });
  });
}
