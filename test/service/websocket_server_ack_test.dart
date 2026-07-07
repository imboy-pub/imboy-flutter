// Xid-id 出站消息确认回归测试
//
// 契约（方案 B）：
//   - 消息 id 为 Xid base32hex 字符串，二进制 0x03 ACK 帧（8 字节 uint64）
//     装不下它；出站消息确认一律走 JSON *_SERVER_ACK（v2 连接包 MSG_S2C 帧）。
//   - 收到 *_SERVER_ACK 必须：清机制A（_pendingMessages/_confirmationTimers）
//     并 fire RemoveFromRetryQueueRequestedEvent 驱动机制B停重发。
//   - WEBRTC_SERVER_ACK 是服务端回执，禁止落入 startsWith('WEBRTC_') 分支
//     反向再发 CLIENT_ACK。
//
// 对应后端：imboy/src/logic/webrtc_ws_logic.erl（WEBRTC_SERVER_ACK 回执）
//          imboy/src/api/websocket_handler.erl (msg_to_v2_frame_type 契约)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/websocket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _CapturingSink implements WebSocketSink {
  final List<dynamic> sent = [];

  @override
  void add(dynamic data) => sent.add(data);

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) async => null;

  @override
  Future<dynamic> get done => Future.value();

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) async {}
}

class _FakeChannel implements WebSocketChannel {
  final _CapturingSink capturingSink = _CapturingSink();

  @override
  WebSocketSink get sink => capturingSink;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => kSubProtocolV2;

  @override
  Stream<dynamic> get stream => const Stream.empty();

  @override
  Future<void> get ready => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 把 JSON map 包成服务端下发的 v2 MSG_S2C 帧（与后端
/// encode_delivery_frame_v2 / reply_frame 的确认类默认映射一致）
Uint8List _s2cFrame(Map<String, dynamic> msg) => ImboyFrame.encode(
  type: FrameType.msgS2C,
  flags: 0,
  payload: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
);

void main() {
  const xid = 'd94ie58821h5446u8ctg'; // Xid base32hex，int.tryParse 必失败

  late WebSocketService svc;
  late _FakeChannel fake;

  setUp(() {
    WebSocketService.resetForTest();
    svc = WebSocketService.to;
    fake = _FakeChannel();
    svc.framingForTest = FramingMode.v2;
    svc.channelForTest = fake;
  });

  tearDown(() {
    svc.channelForTest = null;
    svc.framingForTest = FramingMode.none;
    WebSocketService.resetForTest();
  });

  group('Xid 出站消息经 JSON *_SERVER_ACK 确认（机制A已删除）', () {
    test('C2C_SERVER_ACK 转发下游且不触发反向 ACK', () async {
      final forwarded = AppEventBus.on<WebSocketMessageReceivedEvent>().first;

      svc.handleV2BinaryForTest(
        _s2cFrame({
          'id': xid,
          'type': 'C2C_SERVER_ACK',
          'in_reply_to': xid,
          'server_ts': 1751850000000,
        }),
      );

      // 下游：SERVER_ACK 转发给 MessageService（_receiveServerAck 走
      // 单一清除入口 RemoveFromRetryQueueRequestedEvent + DB status→sent）
      final fwd = await forwarded.timeout(const Duration(seconds: 1));
      expect(fwd.type, 'C2C_SERVER_ACK');
      expect(fwd.data['id'], xid);

      // 回执不得触发出站 ACK
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.capturingSink.sent, isEmpty);
    });

    test('WEBRTC_SERVER_ACK 不反向发送 CLIENT_ACK', () async {
      svc.handleV2BinaryForTest(
        _s2cFrame({
          'id': xid,
          'type': 'WEBRTC_SERVER_ACK',
          'in_reply_to': xid,
          'server_ts': 1751850000000,
        }),
      );

      // 回执不得再触发 AckManager 出站（无论二进制 0x03 还是文本 CLIENT_ACK）
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.capturingSink.sent, isEmpty);
    });

    test('action-ACK 汇入单一清除入口（RemoveFromRetryQueueRequestedEvent）', () async {
      final retryRemoved =
          AppEventBus.on<RemoveFromRetryQueueRequestedEvent>().first;

      svc.handleV2BinaryForTest(
        _s2cFrame({'id': xid, 'type': 'S2C', 'action': 'C2C_REVOKE_ACK'}),
      );

      final removeEvent = await retryRemoved.timeout(
        const Duration(seconds: 1),
      );
      expect(removeEvent.messageId, xid);
      expect(removeEvent.reason, 'ws_action_ack');
    });

    test('入站 0x03 二进制 ACK 帧仅日志忽略（服务端从不下发）', () {
      // 0x03 载荷是 uint64，装不下 Xid；契约上确认一律走 JSON *_SERVER_ACK
      expect(
        () => svc.handleV2BinaryForTest(ImboyFrame.ack(9876543210)),
        returnsNormally,
      );
    });
  });
}
