/// v2 帧载荷可能是 protobuf，也可能是 JSON 原文（后端 imboy_codec:pb_lossless/1
/// 判定 IMBoyMessage schema 装不下时会退回 JSON）。
///
/// 这里锁住兼容前提：protobuf 解码器遇到 JSON 字节必须失败返回 null，
/// 否则老客户端（先 protobuf 解、失败才回退 JSON）会把每条 ACK 解成一条
/// 字段全为默认值的空消息 —— 比丢字段更糟，且无法通过后端热修。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/protocol/imboy_pb_codec.dart';

void main() {
  test('protobuf 解码器不得把 JSON 载荷误判为有效 IMBoyMessage', () {
    final json = jsonEncode({
      'id': 'msg-ack-001',
      'type': 'CLIENT_ACK_ERROR',
      'in_reply_to': 'msg-ack-001',
      'action': 'CLIENT_ACK_ERROR',
      'reason': 'invalid_did',
      'server_ts': 1785312537582,
    });

    expect(ImboyPbCodec.tryDecode(Uint8List.fromList(utf8.encode(json))), null);
    // JSON 回退通道仍能正确解出全部字段
    final fallback = ImboyPbCodec.tryDecodeJsonFallback(
      Uint8List.fromList(utf8.encode(json)),
    );
    expect(fallback?['reason'], 'invalid_did');
    expect(fallback?['in_reply_to'], 'msg-ack-001');
  });
}
