// WebSocketService v2 framing 接入测试
//
// 验证：
//   - 发送业务消息时的 v2 frame 编码
//   - 收到 ping frame 能回 pong
//   - 收到 ack frame 能正确提取 msgId
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/websocket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 捕获所有写入的数据
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

/// 最小 fake channel：暴露 sink，其它成员抛出
class _FakeChannel implements WebSocketChannel {
  final _CapturingSink _sink = _CapturingSink();

  @override
  WebSocketSink get sink => _sink;

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

void main() {
  group('WebSocketService v2 framing', () {
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

    test('C2C JSON 消息编码为 v2 frame (magic IB, type msgC2C)', () {
      const json =
          '{"id":"1","type":"C2C","from":"a","to":"b","msg_type":"text","payload":"hi"}';
      final bytes = svc.encodeV2BusinessFrameForTest(json);

      expect(bytes.length >= ImboyFrame.headerSize, isTrue);
      // magic IB
      expect(bytes[0], 0x49);
      expect(bytes[1], 0x42);
      // version
      expect(bytes[2], 0x02);
      // type = msgC2C (0x20)
      expect(bytes[4], FrameType.msgC2C);

      // 能被 tryDecode 解回
      final decoded = ImboyFrame.tryDecode(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.frame.type, FrameType.msgC2C);
    });

    test('C2G JSON 消息使用 msgC2G', () {
      const json = '{"id":"2","type":"C2G","from":"a","to":"g1"}';
      final bytes = svc.encodeV2BusinessFrameForTest(json);
      expect(bytes[4], FrameType.msgC2G);
    });

    test('CLIENT_ACK 字符串使用 msgC2S', () {
      final bytes = svc.encodeV2BusinessFrameForTest('CLIENT_ACK,C2C,abc,dev1');
      expect(bytes[4], FrameType.msgC2S);
    });

    test('S2C JSON 使用 msgS2C', () {
      const json = '{"id":"3","type":"S2C","payload":"ok"}';
      final bytes = svc.encodeV2BusinessFrameForTest(json);
      expect(bytes[4], FrameType.msgS2C);
    });

    test('收到 ping frame 时回 pong frame', () {
      const seq = 0x1234;
      final ping = ImboyFrame.heartbeatPing(seq);

      svc.handleV2BinaryForTest(ping);

      final sink = fake.sink as _CapturingSink;
      expect(sink.sent.length, 1);
      final sent = sink.sent.first;
      expect(sent, isA<Uint8List>());

      final decoded = ImboyFrame.tryDecode(sent as Uint8List);
      expect(decoded, isNotNull);
      expect(decoded!.frame.type, FrameType.heartbeatPong);
      // 校验 seq 回显
      final gotSeq =
          ByteData.sublistView(decoded.frame.payload).getUint16(0, Endian.big);
      expect(gotSeq, seq);
    });

    test('收到 ack frame 能提取 msgId (uint64)', () {
      const msgId = 1838294017982465; // TSID 典型值
      final ackFrame = ImboyFrame.ack(msgId);

      // 直接解码验证 msgId 提取（与 _handleV2Binary 内部逻辑一致）
      final decoded = ImboyFrame.tryDecode(ackFrame);
      expect(decoded, isNotNull);
      expect(decoded!.frame.type, FrameType.ack);
      expect(decoded.frame.payload.length, 8);
      final extracted =
          ByteData.sublistView(decoded.frame.payload).getUint64(0, Endian.big);
      expect(extracted, msgId);

      // 调用 handler，不应抛出（AckManager.ackConfirmed 会被调用但无副作用断言）
      expect(() => svc.handleV2BinaryForTest(ackFrame), returnsNormally);
    });

    test('损坏的 frame 不会 crash', () {
      final bad = Uint8List.fromList([0x00, 0x00, 0x02, 0, 0, 0, 0, 0, 0]);
      expect(() => svc.handleV2BinaryForTest(bad), returnsNormally);
    });

    test('不完整 frame 被忽略', () {
      final short = Uint8List.fromList([0x49, 0x42, 0x02]);
      expect(() => svc.handleV2BinaryForTest(short), returnsNormally);
    });
  });
}
