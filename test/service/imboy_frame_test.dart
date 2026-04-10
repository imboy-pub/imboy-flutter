// IMBoy 分层二进制协议帧测试
//
// 对应 Erlang 端 imboy_frame.erl 的测试集（跨语言兼容）。
// 规范: .claude/plans/imboy-frame-protocol.md

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';

void main() {
  group('ImboyFrame 常量', () {
    test('magic 为 "IB" ASCII (0x4942)', () {
      expect(ImboyFrame.magic, 0x4942);
    });

    test('version 为 2', () {
      expect(ImboyFrame.currentVersion, 2);
    });

    test('headerSize 为 9 字节', () {
      expect(ImboyFrame.headerSize, 9);
    });
  });

  group('ImboyFrame.encode', () {
    test('空 payload 产生 9 字节帧', () {
      final bin = ImboyFrame.encode(
        type: FrameType.heartbeatPing,
        flags: 0,
        payload: Uint8List(0),
      );
      expect(bin.length, 9);
      final bd = ByteData.sublistView(bin);
      expect(bd.getUint16(0), 0x4942);
      expect(bd.getUint8(2), 2);
      expect(bd.getUint8(3), 0);
      expect(bd.getUint8(4), FrameType.heartbeatPing);
      expect(bd.getUint32(5), 0);
    });

    test('心跳 Ping 为 11 字节', () {
      final seq = Uint8List(2)..buffer.asByteData().setUint16(0, 42);
      final bin = ImboyFrame.encode(
        type: FrameType.heartbeatPing,
        flags: FrameFlags.ack | 7,
        payload: seq,
      );
      expect(bin.length, 11);
      expect(ByteData.sublistView(bin).getUint16(9), 42);
    });

    test('PayloadLen 为 big-endian', () {
      final payload = Uint8List(256);
      final bin = ImboyFrame.encode(
        type: FrameType.msgC2C,
        flags: 0,
        payload: payload,
      );
      // Len=256 big-endian = 00 00 01 00
      expect(bin[5], 0);
      expect(bin[6], 0);
      expect(bin[7], 1);
      expect(bin[8], 0);
    });

    test('超大 payload 抛异常', () {
      final tooBig = Uint8List(ImboyFrame.maxPayload + 1);
      expect(
        () => ImboyFrame.encode(type: 0x20, flags: 0, payload: tooBig),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('ImboyFrame.tryDecode', () {
    test('解码完整帧返回 frame + 消费字节数', () {
      final payload = Uint8List.fromList([1, 2, 3, 4, 5]);
      final bin = ImboyFrame.encode(
        type: FrameType.msgC2C,
        flags: FrameFlags.ack,
        payload: payload,
      );
      final result = ImboyFrame.tryDecode(bin);
      expect(result, isNotNull);
      expect(result!.consumed, 9 + 5);
      final frame = result.frame;
      expect(frame.version, 2);
      expect(frame.flags, FrameFlags.ack);
      expect(frame.type, FrameType.msgC2C);
      expect(frame.payload, payload);
    });

    test('头部不足 9 字节返回 null', () {
      expect(ImboyFrame.tryDecode(Uint8List(0)), isNull);
      expect(ImboyFrame.tryDecode(Uint8List(5)), isNull);
      expect(
        ImboyFrame.tryDecode(Uint8List.fromList([0x49, 0x42, 2, 0, 1])),
        isNull,
      );
    });

    test('payload 不足返回 null', () {
      // 头部说 Len=100 但只有 3 字节 payload
      final buf = Uint8List.fromList([
        0x49, 0x42, 2, 0, 0x20, // header
        0x00, 0x00, 0x00, 100, // Len=100
        0xAA, 0xBB, 0xCC, // 只有 3 字节
      ]);
      expect(ImboyFrame.tryDecode(buf), isNull);
    });

    test('bad magic 抛异常', () {
      final buf = Uint8List.fromList([
        0xFF, 0xFF, 2, 0, 1, 0, 0, 0, 0,
      ]);
      expect(
        () => ImboyFrame.tryDecode(buf),
        throwsA(isA<FormatException>()),
      );
    });

    test('frame too large 抛异常', () {
      final buf = Uint8List.fromList([
        0x49, 0x42, 2, 0, 0x20,
        0x01, 0x00, 0x00, 0x01, // Len = 0x01000001 > 16MB
      ]);
      expect(
        () => ImboyFrame.tryDecode(buf),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ImboyFrame 往返', () {
    test('多种 type+flags 组合往返一致', () {
      final cases = <(int, int, Uint8List)>[
        (FrameType.heartbeatPing, FrameFlags.ack | 7, _u16(42)),
        (FrameType.heartbeatPong, 0, _u16(42)),
        (FrameType.ack, 0, _u64(0xDEADBEEFCAFEBABE)),
        (FrameType.msgC2C, FrameFlags.ack, Uint8List.fromList([1, 2, 3])),
        (FrameType.msgC2G, FrameFlags.cmp | FrameFlags.ack,
            Uint8List(1024)..fillRange(0, 1024, 0xAB)),
      ];

      for (final (t, f, p) in cases) {
        final bin = ImboyFrame.encode(type: t, flags: f, payload: p);
        final result = ImboyFrame.tryDecode(bin);
        expect(result, isNotNull, reason: 'type=$t');
        expect(result!.frame.type, t);
        expect(result.frame.flags, f);
        expect(result.frame.payload, p);
      }
    });
  });

  group('ImboyFrame.decodeStream', () {
    test('解析多个连续帧', () {
      final f1 = ImboyFrame.encode(
        type: FrameType.heartbeatPing,
        flags: 0,
        payload: _u16(1),
      );
      final f2 = ImboyFrame.encode(
        type: FrameType.ack,
        flags: 0,
        payload: _u64(100),
      );
      final f3 = ImboyFrame.encode(
        type: FrameType.msgC2C,
        flags: FrameFlags.ack,
        payload: Uint8List.fromList([0x61, 0x62, 0x63]),
      );

      final buf = Uint8List.fromList([...f1, ...f2, ...f3]);
      final (frames, remaining) = ImboyFrame.decodeStream(buf);

      expect(frames.length, 3);
      expect(remaining.length, 0);
      expect(frames[0].type, FrameType.heartbeatPing);
      expect(frames[1].type, FrameType.ack);
      expect(frames[2].type, FrameType.msgC2C);
      expect(frames[2].payload, [0x61, 0x62, 0x63]);
    });

    test('尾部不完整帧留在 remaining', () {
      final f1 = ImboyFrame.encode(
        type: FrameType.ack,
        flags: 0,
        payload: _u64(1),
      );
      final partial = Uint8List.fromList([0x49, 0x42, 2, 0, 0x20, 0, 0, 0, 100, 1, 2]);
      final buf = Uint8List.fromList([...f1, ...partial]);

      final (frames, remaining) = ImboyFrame.decodeStream(buf);
      expect(frames.length, 1);
      expect(remaining, partial);
    });

    test('空 buffer 返回空列表', () {
      final (frames, remaining) = ImboyFrame.decodeStream(Uint8List(0));
      expect(frames, isEmpty);
      expect(remaining, isEmpty);
    });

    test('decodeStreamSafe 捕获 bad magic 不抛异常', () {
      final f1 = ImboyFrame.encode(
        type: FrameType.ack,
        flags: 0,
        payload: _u64(1),
      );
      final garbage = Uint8List.fromList([0xFF, 0xFF, 2, 0, 1, 0, 0, 0, 0]);
      final buf = Uint8List.fromList([...f1, ...garbage]);

      final result = ImboyFrame.decodeStreamSafe(buf);
      expect(result.frames.length, 1);
      expect(result.hasError, isTrue);
      expect(result.error, isA<FormatException>());
    });

    test('decodeStream 遇到 bad magic 抛出（严格模式）', () {
      final buf = Uint8List.fromList([0xFF, 0xFF, 2, 0, 1, 0, 0, 0, 0]);
      expect(
        () => ImboyFrame.decodeStream(buf),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Flags 判定', () {
    test('位标志访问器', () {
      final frame = ImboyFrame(
        flags: FrameFlags.cmp | FrameFlags.ack | 2,
        type: FrameType.msgC2C,
        payload: Uint8List(0),
      );
      expect(frame.isCompressed, isTrue);
      expect(frame.isEncrypted, isFalse);
      expect(frame.needsAck, isTrue);
      expect(frame.priority, 2);
    });

    test('无 flag 的情况', () {
      final frame = ImboyFrame(
        flags: 0,
        type: FrameType.ack,
        payload: Uint8List(0),
      );
      expect(frame.isCompressed, isFalse);
      expect(frame.isEncrypted, isFalse);
      expect(frame.needsAck, isFalse);
      expect(frame.priority, 0);
    });
  });

  group('快捷构造器', () {
    test('heartbeatPing 生成有效帧', () {
      final bin = ImboyFrame.heartbeatPing(7);
      final result = ImboyFrame.tryDecode(bin);
      expect(result, isNotNull);
      expect(result!.frame.type, FrameType.heartbeatPing);
      expect(
        ByteData.sublistView(result.frame.payload).getUint16(0),
        7,
      );
    });

    test('heartbeatPong 生成有效帧', () {
      final bin = ImboyFrame.heartbeatPong(42);
      final result = ImboyFrame.tryDecode(bin);
      expect(result, isNotNull);
      expect(result!.frame.type, FrameType.heartbeatPong);
      expect(
        ByteData.sublistView(result.frame.payload).getUint16(0),
        42,
      );
    });

    test('ack 帧 17 字节', () {
      final bin = ImboyFrame.ack(0x1234567890ABCDEF);
      expect(bin.length, 17);
      final result = ImboyFrame.tryDecode(bin);
      expect(result!.frame.type, FrameType.ack);
      expect(
        ByteData.sublistView(result.frame.payload).getUint64(0),
        0x1234567890ABCDEF,
      );
    });
  });

  group('跨语言兼容性 (与 Erlang 端字节一致)', () {
    // 这些是从 Erlang 端生成并固化的字节序列
    // 用于确保 Dart 端编码与 Erlang 端编码字节完全一致
    test('heartbeat ping seq=7 的字节序列', () {
      final bin = ImboyFrame.heartbeatPing(7);
      expect(bin, [
        0x49, 0x42,        // magic "IB"
        0x02,              // version
        0x27,              // flags = ACK(0x20) | PRI=7 (0x07)
        0x01,              // type = HEARTBEAT_PING
        0x00, 0x00, 0x00, 0x02, // len = 2
        0x00, 0x07,        // seq = 7
      ]);
    });

    test('ack msg_id=0x1234567890ABCDEF 的字节序列', () {
      final bin = ImboyFrame.ack(0x1234567890ABCDEF);
      expect(bin, [
        0x49, 0x42,
        0x02,
        0x00,
        0x03,
        0x00, 0x00, 0x00, 0x08,
        0x12, 0x34, 0x56, 0x78, 0x90, 0xAB, 0xCD, 0xEF,
      ]);
    });
  });
}

Uint8List _u16(int v) {
  final b = Uint8List(2);
  ByteData.sublistView(b).setUint16(0, v);
  return b;
}

Uint8List _u64(int v) {
  final b = Uint8List(8);
  ByteData.sublistView(b).setUint64(0, v);
  return b;
}
