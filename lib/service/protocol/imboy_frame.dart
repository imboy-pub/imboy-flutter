// IMBoy 分层二进制协议帧编解码 (v2)
//
// 与 Erlang 端 `imboy_frame.erl` 配套，保证字节级兼容。
//
// 帧结构:
//   [Magic:2 = "IB"] [Ver:1] [Flags:1] [Type:1] [PayloadLen:4 BE] [Payload:N]
//
// 设计原则:
//   - 无外部依赖（仅使用 dart:typed_data）
//   - 压缩解耦: CMP flag 保留给调用方按需处理
//   - 加密解耦: ENC flag 保留给未来 E2EE
//
// 规范: .claude/plans/imboy-frame-protocol.md

import 'dart:typed_data';

/// 帧 Flags 位定义
class FrameFlags {
  static const int cmp = 0x80; // bit7: 载荷是否 zstd 压缩
  static const int enc = 0x40; // bit6: 载荷是否 E2EE (预留)
  static const int ack = 0x20; // bit5: 是否需要 ACK
  static const int priorityMask = 0x07; // bits0-2: 优先级
}

/// 帧类型枚举
class FrameType {
  // 0x00-0x0F 控制帧
  static const int heartbeatPing = 0x01;
  static const int heartbeatPong = 0x02;
  static const int ack = 0x03;
  static const int nack = 0x04;
  static const int close = 0x05;
  static const int error = 0x06;

  // 0x10-0x1F 握手/认证
  static const int handshakeHello = 0x10;
  static const int handshakeAuth = 0x11;
  static const int handshakeOk = 0x12;

  // 0x20-0x7F 业务消息
  static const int msgC2C = 0x20;
  static const int msgC2G = 0x21;
  static const int msgC2S = 0x22;
  static const int msgS2C = 0x23;
  static const int msgSync = 0x24;
  static const int msgTyping = 0x25;
  static const int msgRead = 0x26;
  static const int msgRecall = 0x27;

  // 0x80-0xEF RPC/扩展
  static const int rpcReq = 0x80;
  static const int rpcRsp = 0x81;
}

/// 解码结果: 帧 + 消费的字节数
class DecodeResult {
  final ImboyFrame frame;
  final int consumed;
  const DecodeResult(this.frame, this.consumed);
}

/// 流式解码结果
class StreamDecodeResult {
  /// 解析出的帧列表
  final List<ImboyFrame> frames;

  /// 未消费的尾部字节（可能是不完整帧）
  final Uint8List remaining;

  /// 解析过程中遇到的错误 (bad_magic / frame_too_large)
  /// 调用方应据此决定是否关闭连接
  final FormatException? error;

  const StreamDecodeResult({
    required this.frames,
    required this.remaining,
    this.error,
  });

  bool get hasError => error != null;
}

/// IMBoy v2 分层协议帧
class ImboyFrame {
  /// 魔数 "IB" ASCII = 0x4942
  static const int magic = 0x4942;

  /// 协议版本
  static const int currentVersion = 2;

  /// 头部固定字节数
  static const int headerSize = 9;

  /// 最大载荷字节数 (16 MiB)
  static const int maxPayload = 16 * 1024 * 1024;

  final int version;
  final int flags;
  final int type;
  final Uint8List payload;

  ImboyFrame({
    this.version = ImboyFrame.currentVersion,
    required this.flags,
    required this.type,
    required this.payload,
  });

  bool get isCompressed => (flags & FrameFlags.cmp) != 0;
  bool get isEncrypted => (flags & FrameFlags.enc) != 0;
  bool get needsAck => (flags & FrameFlags.ack) != 0;
  int get priority => flags & FrameFlags.priorityMask;

  // ===== 编码 =====

  /// 将 (type, flags, payload) 编码为完整帧二进制
  static Uint8List encode({
    required int type,
    required int flags,
    required Uint8List payload,
  }) {
    if (payload.length > maxPayload) {
      throw ArgumentError(
          'payload too large: ${payload.length} > $maxPayload');
    }
    if (type < 0 || type > 255) {
      throw ArgumentError('type out of range: $type');
    }
    if (flags < 0 || flags > 255) {
      throw ArgumentError('flags out of range: $flags');
    }

    final len = payload.length;
    final out = Uint8List(headerSize + len);
    final bd = ByteData.sublistView(out);
    // 全部显式 big-endian —— 不依赖默认值，防止未来意外被改
    bd.setUint16(0, magic, Endian.big);
    bd.setUint8(2, currentVersion);
    bd.setUint8(3, flags);
    bd.setUint8(4, type);
    bd.setUint32(5, len, Endian.big);
    out.setRange(headerSize, headerSize + len, payload);
    return out;
  }

  // ===== 解码 =====

  /// 尝试从 bytes 起始位置解析一个完整帧。
  ///
  /// 返回:
  ///   - `null`    : 数据不足（头部或载荷不完整）
  ///   - `DecodeResult` : 解析成功
  ///
  /// 抛出:
  ///   - `FormatException` : bad magic 或 frame too large
  static DecodeResult? tryDecode(Uint8List bytes) {
    if (bytes.length < headerSize) return null;
    final bd = ByteData.sublistView(bytes);
    final m = bd.getUint16(0, Endian.big);
    if (m != magic) {
      throw FormatException(
          'bad magic: 0x${m.toRadixString(16).padLeft(4, '0')}');
    }
    final ver = bd.getUint8(2);
    final flags = bd.getUint8(3);
    final type = bd.getUint8(4);
    final len = bd.getUint32(5, Endian.big);
    if (len > maxPayload) {
      throw FormatException('frame too large: $len');
    }
    if (bytes.length < headerSize + len) return null;

    final payload = Uint8List.sublistView(bytes, headerSize, headerSize + len);
    final frame = ImboyFrame(
      version: ver,
      flags: flags,
      type: type,
      payload: payload,
    );
    return DecodeResult(frame, headerSize + len);
  }

  /// 流式解码: 从 buffer 解析尽可能多的完整帧。
  ///
  /// 错误处理:
  ///   - 遇到 `FormatException` (bad_magic / frame_too_large) 时停止解析,
  ///     已解析的帧保留在结果的 `frames` 字段, 错误放入 `error` 字段。
  ///   - 调用方应检查 `hasError` 并据此决定是否关闭连接。
  ///
  /// 兼容旧 API: 返回 record 以保持向后兼容（frames, remaining）。
  /// 推荐使用 `decodeStreamSafe` 获取完整错误信息。
  static (List<ImboyFrame>, Uint8List) decodeStream(Uint8List buffer) {
    final result = decodeStreamSafe(buffer);
    if (result.hasError) throw result.error!;
    return (result.frames, result.remaining);
  }

  /// 流式解码（错误安全版本）: 不抛出异常,返回包含错误的结果对象。
  static StreamDecodeResult decodeStreamSafe(Uint8List buffer) {
    final frames = <ImboyFrame>[];
    int offset = 0;
    FormatException? error;

    while (offset < buffer.length) {
      final view = Uint8List.sublistView(buffer, offset);
      try {
        final result = tryDecode(view);
        if (result == null) break;
        frames.add(result.frame);
        offset += result.consumed;
      } on FormatException catch (e) {
        error = e;
        break;
      }
    }

    final remaining = offset == buffer.length
        ? Uint8List(0)
        : Uint8List.sublistView(buffer, offset);
    return StreamDecodeResult(
      frames: frames,
      remaining: remaining,
      error: error,
    );
  }

  // ===== 快捷构造器 =====

  /// 心跳 Ping: ACK=1, PRI=7
  static Uint8List heartbeatPing(int seq) {
    _checkSeq(seq);
    final payload = Uint8List(2);
    ByteData.sublistView(payload).setUint16(0, seq, Endian.big);
    return encode(
      type: FrameType.heartbeatPing,
      flags: FrameFlags.ack | 7,
      payload: payload,
    );
  }

  /// 心跳 Pong: PRI=7, 无 ACK
  static Uint8List heartbeatPong(int seq) {
    _checkSeq(seq);
    final payload = Uint8List(2);
    ByteData.sublistView(payload).setUint16(0, seq, Endian.big);
    return encode(
      type: FrameType.heartbeatPong,
      flags: 7,
      payload: payload,
    );
  }

  /// ACK 帧
  static Uint8List ack(int msgId) {
    _checkUint64(msgId);
    final payload = Uint8List(8);
    ByteData.sublistView(payload).setUint64(0, msgId, Endian.big);
    return encode(
      type: FrameType.ack,
      flags: 0,
      payload: payload,
    );
  }

  /// NACK 帧
  static Uint8List nack(int msgId) {
    _checkUint64(msgId);
    final payload = Uint8List(8);
    ByteData.sublistView(payload).setUint64(0, msgId, Endian.big);
    return encode(
      type: FrameType.nack,
      flags: 0,
      payload: payload,
    );
  }

  static void _checkSeq(int seq) {
    if (seq < 0 || seq > 0xFFFF) {
      throw ArgumentError('seq out of uint16 range: $seq');
    }
  }

  static void _checkUint64(int v) {
    if (v < 0) {
      throw ArgumentError('msg id must be non-negative: $v');
    }
  }
}
