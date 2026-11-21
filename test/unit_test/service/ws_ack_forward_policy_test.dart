/// ws_ack_forward_policy 单测：入站 action-ACK 是否在传输层终止。
///
/// 契约（J18.c 真机复现后修正）：
///   - CLIENT_ACK_CONFIRM / CLIENT_ACK_ERROR：入站收据确认，终止。
///   - 其他 *_ACK：默认终止（重试队列清除已在传输层完成）。
///   - message_revoke_ack / message_edit_ack：例外放行——本机状态转换
///     （原消息转已撤回/已编辑 + UI 刷新）在 MessageActions 的 ack 分支完成。
///   - 非 ACK action（含空串）：一律放行。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/protocol/imboy.pb.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/service/ws_ack_forward_policy.dart';

void main() {
  test('按协议边界接收正文和 v2 封包', () {
    const max = ImboyFrame.maxPayload;
    const framedMax = max + ImboyFrame.headerSize;
    final bytes = Uint8List(framedMax + 1);
    final nakedAtLimit = Uint8List.sublistView(bytes, 0, max);
    final nakedOverLimit = Uint8List.sublistView(bytes, 0, max + 1);
    expect(isInboundFrameSizeAllowed(nakedAtLimit, usesV2Frame: true), isTrue);
    expect(
      isInboundFrameSizeAllowed(nakedOverLimit, usesV2Frame: true),
      isFalse,
    );
    ByteData.sublistView(bytes).setUint16(0, ImboyFrame.magic);
    final framedAtLimit = Uint8List.sublistView(bytes, 0, framedMax);
    expect(isInboundFrameSizeAllowed(framedAtLimit, usesV2Frame: true), isTrue);
    expect(
      isInboundFrameSizeAllowed(framedAtLimit, usesV2Frame: false),
      isFalse,
    );
    expect(isInboundFrameSizeAllowed(bytes, usesV2Frame: true), isFalse);
  });

  test('文本边界按 UTF-8 字节计入多字节字符', () {
    const max = ImboyFrame.maxPayload;
    final atLimit = '${'a' * (max - 9)}é你💬';
    expect(isInboundTextSizeAllowed(atLimit), isTrue);
    expect(isInboundTextSizeAllowed('${atLimit}a'), isFalse);
  });

  test('已通过传输层限额的 protobuf 可以扩张成更大的 JSON', () async {
    const max = ImboyFrame.maxPayload;
    const action = 'protobuf_size_boundary';
    final payload = IMBoyMessage(
      type: MsgDirection.C2S,
      action: action,
      payload: Uint8List(max - max ~/ 8),
    ).writeToBuffer();
    expect(payload.length, lessThan(max));

    WebSocketService.resetForTest();
    addTearDown(WebSocketService.resetForTest);
    final socket = WebSocketService.to..framingForTest = FramingMode.v2;
    final events = <WebSocketMessageReceivedEvent>[];
    final subscription = AppEventBus.on<WebSocketMessageReceivedEvent>().listen(
      (event) {
        if (event.data['action'] == action) events.add(event);
      },
    );
    addTearDown(subscription.cancel);
    final bytes = ImboyFrame.encode(
      type: FrameType.msgC2S,
      flags: 0,
      payload: payload,
    );
    socket.handleV2BinaryForTest(bytes);
    socket.handleV2BinaryForTest(payload);
    await pumpEventQueue();
    expect(events, hasLength(2));
    for (final event in events) {
      expect((event.data['payload'] as String).length, greaterThan(max));
    }
  });

  test('流式增量免收据，而 S2C/C2S 终态及新业务继续确认', () {
    for (final type in ['S2C', 'C2S']) {
      expect(shouldAcknowledgeBusinessFrame(type, 'stream_delta'), isFalse);
      expect(shouldAcknowledgeBusinessFrame(type, 'text'), isTrue);
      expect(shouldAcknowledgeBusinessFrame(type, null), isTrue);
      expect(shouldAcknowledgeBusinessFrame(type, 'future_business'), isTrue);
    }
    expect(shouldAcknowledgeBusinessFrame('FUTURE_TYPE', null), isFalse);
  });

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
