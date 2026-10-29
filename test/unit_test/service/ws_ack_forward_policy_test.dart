/// ws_ack_forward_policy 单测：入站 action-ACK 是否在传输层终止。
///
/// 契约（J18.c 真机复现后修正）：
///   - CLIENT_ACK_CONFIRM / CLIENT_ACK_ERROR：入站收据确认，终止。
///   - 其他 *_ACK：默认终止（重试队列清除已在传输层完成）。
///   - message_revoke_ack / message_edit_ack：例外放行——本机状态转换
///     （原消息转已撤回/已编辑 + UI 刷新）在 MessageActions 的 ack 分支完成。
///   - 非 ACK action（含空串）：一律放行。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/ws_ack_forward_policy.dart';

void main() {
  group('isAckSwallowedByTransport — 入站收据确认', () {
    test('CLIENT_ACK_CONFIRM 终止', () {
      expect(isAckSwallowedByTransport('CLIENT_ACK_CONFIRM'), isTrue);
    });

    test('CLIENT_ACK_ERROR 终止', () {
      expect(isAckSwallowedByTransport('CLIENT_ACK_ERROR'), isTrue);
    });
  });

  group('isAckSwallowedByTransport — 通用 action-ACK', () {
    test('MESSAGE_READ_ACK 终止（无本机效应）', () {
      expect(isAckSwallowedByTransport('MESSAGE_READ_ACK'), isTrue);
    });

    test('C2C_REVOKE_ACK（非 message_* 命名）终止', () {
      expect(isAckSwallowedByTransport('C2C_REVOKE_ACK'), isTrue);
    });

    test('任意 *_ACK 终止', () {
      expect(isAckSwallowedByTransport('FOO_ACK'), isTrue);
    });
  });

  group('isAckSwallowedByTransport — 有本机效应的 action-ACK 放行', () {
    test('MESSAGE_REVOKE_ACK 放行', () {
      expect(isAckSwallowedByTransport('MESSAGE_REVOKE_ACK'), isFalse);
    });

    test('MESSAGE_EDIT_ACK 放行', () {
      expect(isAckSwallowedByTransport('MESSAGE_EDIT_ACK'), isFalse);
    });

    test('例外集与放行判定一致', () {
      for (final action in kActionAcksWithLocalEffect) {
        expect(
          isAckSwallowedByTransport(action),
          isFalse,
          reason: '$action 在例外集内却被终止',
        );
      }
    });
  });

  group('isAckSwallowedByTransport — 非 ACK action', () {
    test('MESSAGE_REVOKE 放行', () {
      expect(isAckSwallowedByTransport('MESSAGE_REVOKE'), isFalse);
    });

    test('MESSAGE_READ 放行', () {
      expect(isAckSwallowedByTransport('MESSAGE_READ'), isFalse);
    });

    test('空 action 放行', () {
      expect(isAckSwallowedByTransport(''), isFalse);
    });

    test('ACK 为子串而非后缀时放行（如 ACKNOWLEDGE）', () {
      expect(isAckSwallowedByTransport('ACKNOWLEDGE'), isFalse);
    });
  });
}
