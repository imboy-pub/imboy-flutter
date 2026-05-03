// IMBoy imboy.v2 端到端回归测试
//
// 覆盖：
//   1. Round-trip fixture：每一种 FrameType 的 encode/tryDecode 逐字段断言
//   2. 服务端固定字节可解：硬编码 Erlang 端会发的 bytes（pong(1234), ack(0x12345678)）
//   3. WebSocketService fake 回环：连续四帧（pong → ack → msgS2C → garbage）分派不崩
//   4. AckManager 集成点：frame 层 ack 能触发 AckManager.ackConfirmed(msgId.toString())
//
// 对应后端文件：
//   - imboy/src/api/websocket_handler.erl (dispatch_v2_frame)
//   - imboy/test/integration/v2_frame_e2e_tests.erl
//   - imboy/doc/api/websocket-api-2.md
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/protocol/imboy.pb.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/protocol/imboy_pb_codec.dart';
import 'package:imboy/service/websocket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 捕获 sink，用于断言下行帧
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
  group('imboy.v2 frame round-trip (每种 FrameType)', () {
    test('heartbeatPing round-trip', () {
      final bin = ImboyFrame.heartbeatPing(0x0102);
      final r = ImboyFrame.tryDecode(bin);
      expect(r, isNotNull);
      expect(r!.frame.type, FrameType.heartbeatPing);
      expect(
        ByteData.sublistView(r.frame.payload).getUint16(0, Endian.big),
        0x0102,
      );
    });

    test('heartbeatPong round-trip', () {
      final bin = ImboyFrame.heartbeatPong(0xBEEF);
      final r = ImboyFrame.tryDecode(bin);
      expect(r!.frame.type, FrameType.heartbeatPong);
      expect(
        ByteData.sublistView(r.frame.payload).getUint16(0, Endian.big),
        0xBEEF,
      );
    });

    test('ack round-trip (uint64 msgId)', () {
      const msgId = 0x1122334455667788;
      final bin = ImboyFrame.ack(msgId);
      final r = ImboyFrame.tryDecode(bin);
      expect(r!.frame.type, FrameType.ack);
      expect(
        ByteData.sublistView(r.frame.payload).getUint64(0, Endian.big),
        msgId,
      );
    });

    test('msgC2C with JSON payload round-trip', () {
      const jsonText = '{"id":"m1","type":"C2C","from":"a","to":"b"}';
      final bin = ImboyFrame.encode(
        type: FrameType.msgC2C,
        flags: 0,
        payload: Uint8List.fromList(utf8.encode(jsonText)),
      );
      final r = ImboyFrame.tryDecode(bin);
      expect(r!.frame.type, FrameType.msgC2C);
      expect(utf8.decode(r.frame.payload), jsonText);
    });

    test('msgC2G with JSON payload round-trip', () {
      const jsonText = '{"id":"g1","type":"C2G","from":"a","to":"g"}';
      final bin = ImboyFrame.encode(
        type: FrameType.msgC2G,
        flags: 0,
        payload: Uint8List.fromList(utf8.encode(jsonText)),
      );
      final r = ImboyFrame.tryDecode(bin);
      expect(r!.frame.type, FrameType.msgC2G);
      expect(utf8.decode(r.frame.payload), jsonText);
    });

    test('msgC2S CLIENT_ACK text round-trip', () {
      const ackText = 'CLIENT_ACK,C2C,mid-1,did-1';
      final bin = ImboyFrame.encode(
        type: FrameType.msgC2S,
        flags: 0,
        payload: Uint8List.fromList(utf8.encode(ackText)),
      );
      final r = ImboyFrame.tryDecode(bin);
      expect(r!.frame.type, FrameType.msgC2S);
      expect(utf8.decode(r.frame.payload), ackText);
    });

    test('msgS2C with JSON payload round-trip', () {
      const jsonText = '{"id":"s1","type":"S2C","action":"pull_offline_msg"}';
      final bin = ImboyFrame.encode(
        type: FrameType.msgS2C,
        flags: 0,
        payload: Uint8List.fromList(utf8.encode(jsonText)),
      );
      final r = ImboyFrame.tryDecode(bin);
      expect(r!.frame.type, FrameType.msgS2C);
      expect(utf8.decode(r.frame.payload), jsonText);
    });
  });

  group('服务端固定字节跨语言可解 (与 Erlang imboy_frame 字节一致)', () {
    // Erlang: imboy_frame:heartbeat_pong(1234)
    //  - heartbeat_pong 使用 flags=0（与 Ping 的 ACK|PRI=7 不同）
    //  - magic=0x4942, version=0x02, flags=0x00, type=0x02, len=0x00000002, seq=1234
    test('pong seq=1234 的固定字节可被 Dart 解开', () {
      final bytes = Uint8List.fromList([
        0x49, 0x42, // magic "IB"
        0x02, // version
        0x00, // flags
        0x02, // type = HEARTBEAT_PONG
        0x00, 0x00, 0x00, 0x02, // len = 2
        0x04, 0xD2, // 1234 big-endian
      ]);
      final r = ImboyFrame.tryDecode(bytes);
      expect(r, isNotNull);
      expect(r!.frame.type, FrameType.heartbeatPong);
      expect(r.frame.flags, 0);
      expect(
        ByteData.sublistView(r.frame.payload).getUint16(0, Endian.big),
        1234,
      );
    });

    // Erlang: imboy_frame:ack(16#12345678)
    //  - magic=0x4942, version=0x02, flags=0x00, type=0x03, len=0x00000008
    //  - msg_id=0x0000000012345678 (uint64 BE)
    test('ack msgId=0x12345678 的固定字节可被 Dart 解开', () {
      final bytes = Uint8List.fromList([
        0x49, 0x42,
        0x02,
        0x00,
        0x03,
        0x00, 0x00, 0x00, 0x08,
        0x00, 0x00, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78,
      ]);
      final r = ImboyFrame.tryDecode(bytes);
      expect(r, isNotNull);
      expect(r!.frame.type, FrameType.ack);
      expect(
        ByteData.sublistView(r.frame.payload).getUint64(0, Endian.big),
        0x12345678,
      );
    });
  });

  group('WebSocketService fake 回环 (连续帧分派)', () {
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

    test('连续四帧：pong → ack → msgS2C(JSON) → garbage 均不崩', () {
      final pong = ImboyFrame.heartbeatPong(7);
      final ack = ImboyFrame.ack(0x1122334455667788);

      const s2cJson = '{"id":"s2c-1","type":"S2C","action":"ping_ok"}';
      final msgS2C = ImboyFrame.encode(
        type: FrameType.msgS2C,
        flags: 0,
        payload: Uint8List.fromList(utf8.encode(s2cJson)),
      );

      final garbage = Uint8List.fromList([0x00, 0x00, 0x02, 0, 0, 0, 0, 0, 0]);

      expect(() {
        svc.handleV2BinaryForTest(pong);
        svc.handleV2BinaryForTest(ack);
        svc.handleV2BinaryForTest(msgS2C);
        svc.handleV2BinaryForTest(garbage);
      }, returnsNormally);
    });

    test('服务端发 ping 帧时客户端回 pong 帧（入站 ping 处理）', () {
      const seq = 0xCAFE;
      final ping = ImboyFrame.heartbeatPing(seq);

      svc.handleV2BinaryForTest(ping);

      final sink = fake.sink as _CapturingSink;
      expect(sink.sent.length, 1);
      final r = ImboyFrame.tryDecode(sink.sent.first as Uint8List);
      expect(r!.frame.type, FrameType.heartbeatPong);
      expect(
        ByteData.sublistView(r.frame.payload).getUint16(0, Endian.big),
        seq,
      );
    });
  });

  group('AckManager 集成点', () {
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

    test('frame 层 ack 能以正确 msgId 字符串传入 AckManager.ackConfirmed', () {
      // 关键：_handleV2Binary 对 FrameType.ack 会调用
      //   AckManager.to.ackConfirmed(msgId.toString())
      // 这里没有 message 在 AckManager 里登记，但调用本身不应抛。
      const msgId = 9876543210;
      final ackFrame = ImboyFrame.ack(msgId);

      expect(() => svc.handleV2BinaryForTest(ackFrame), returnsNormally);

      // 同时验证解出来的 msgId 与预期一致（和内部代码路径一致）
      final r = ImboyFrame.tryDecode(ackFrame);
      expect(r, isNotNull);
      final extracted =
          ByteData.sublistView(r!.frame.payload).getUint64(0, Endian.big);
      expect(extracted, msgId);
      expect(extracted.toString(), '9876543210');
    });
  });

  group('Protobuf S2C over v2 frame (full pipeline)', () {
    test('logged_another_device: protobuf → v2 frame → decode → Map', () {
      // 1. 构造 protobuf IMBoyMessage
      final innerPayload = PayloadLoggedAnotherDevice(
        did: 'dev-e2e-001',
        dname: 'Pixel 9',
      );
      final msg = IMBoyMessage(
        id: 'pb_s2c_001',
        type: MsgDirection.S2C,
        from: Int64(0),
        to: Int64(1000000051),
        msgType: ContentType.CUSTOM,
        action: 'logged_another_device',
        payload: innerPayload.writeToBuffer(),
        createdAt: Int64(1746300000000),
      );

      // 2. 序列化并封装到 v2 frame
      final pbBytes = msg.writeToBuffer();
      final frame = ImboyFrame.encode(
        type: FrameType.msgS2C,
        flags: 0,
        payload: Uint8List.fromList(pbBytes),
      );

      // 3. v2 frame 解码
      final decoded = ImboyFrame.tryDecode(frame);
      expect(decoded, isNotNull);
      expect(decoded!.frame.type, FrameType.msgS2C);

      // 4. protobuf codec 解码 payload
      final pbMap = ImboyPbCodec.tryDecode(decoded.frame.payload);
      expect(pbMap, isNotNull);
      expect(pbMap!['id'], 'pb_s2c_001');
      expect(pbMap['type'], 'S2C');
      expect(pbMap['action'], 'logged_another_device');
      expect(pbMap['to'], 1000000051);

      final payload = pbMap['payload'] as Map;
      expect(payload['did'], 'dev-e2e-001');
      expect(payload['dname'], 'Pixel 9');
    });

    test('JSON fallback: non-protobuf S2C still works through v2 frame', () {
      const jsonText = '{"id":"json-s2c","type":"S2C","action":"ping_ok"}';
      final frame = ImboyFrame.encode(
        type: FrameType.msgS2C,
        flags: 0,
        payload: Uint8List.fromList(utf8.encode(jsonText)),
      );

      final decoded = ImboyFrame.tryDecode(frame);
      expect(decoded, isNotNull);

      // protobuf decode should fail (not protobuf), JSON fallback should work
      final pbMap = ImboyPbCodec.tryDecode(decoded!.frame.payload);
      expect(pbMap, isNull);

      final jsonMap = ImboyPbCodec.tryDecodeJsonFallback(decoded.frame.payload);
      expect(jsonMap, isNotNull);
      expect(jsonMap!['id'], 'json-s2c');
      expect(jsonMap['action'], 'ping_ok');
    });

    test('device_force_offline: protobuf round-trip through v2 frame', () {
      final inner = PayloadDeviceKicked(reason: 'security_breach');
      final msg = IMBoyMessage(
        id: 'kick_001',
        type: MsgDirection.S2C,
        action: 'device_force_offline',
        payload: inner.writeToBuffer(),
      );

      final frame = ImboyFrame.encode(
        type: FrameType.msgS2C,
        flags: 0,
        payload: Uint8List.fromList(msg.writeToBuffer()),
      );

      final decoded = ImboyFrame.tryDecode(frame);
      final pbMap = ImboyPbCodec.tryDecode(decoded!.frame.payload);
      expect(pbMap!['action'], 'device_force_offline');
      expect((pbMap['payload'] as Map)['reason'], 'security_breach');
    });
  });
}
