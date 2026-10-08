import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/web_view.dart';

/// imboyJSBridge 最小双向协议（component/web_view.dart）的纯逻辑单测。
/// 通道只挂在 imboy.pub 域名上；协议方法白名单制，未知方法回 unsupported。
void main() {
  Map<String, dynamic> decodeReply(String js) {
    // buildReply 产出固定形态：
    // window.dispatchEvent(new MessageEvent('imboyBridgeMessage', {data: {...}}));
    const marker = '{data: ';
    final start = js.indexOf(marker) + marker.length;
    return jsonDecode(js.substring(start, js.length - 4))
        as Map<String, dynamic>;
  }

  group('ImboyJsBridge.buildReply', () {
    test('ping 回 ok 与 pong', () {
      final reply = ImboyJsBridge.buildReply(
        jsonEncode({'id': 7, 'type': 'ping'}),
      );
      expect(reply, isNotNull);
      final payload = decodeReply(reply!);
      expect(payload['id'], 7);
      expect(payload['type'], 'ping');
      expect(payload['ok'], isTrue);
      expect((payload['data'] as Map<String, dynamic>)['pong'], isTrue);
    });

    test('echo 原样回显 data', () {
      final reply = ImboyJsBridge.buildReply(
        jsonEncode({
          'type': 'echo',
          'data': {'msg': 'hello', 'n': 1},
        }),
      );
      final payload = decodeReply(reply!);
      expect(payload['ok'], isTrue);
      expect(payload['data'], {'msg': 'hello', 'n': 1});
    });

    test('未知方法回 unsupported 错误回执', () {
      final reply = ImboyJsBridge.buildReply(
        jsonEncode({'id': 'abc', 'type': 'sendChatMessage', 'data': 'x'}),
      );
      final payload = decodeReply(reply!);
      expect(payload['ok'], isFalse);
      expect(payload['error'], 'unsupported');
    });

    test('坏 JSON 静默忽略（无法构造回执）', () {
      expect(ImboyJsBridge.buildReply('not-json'), isNull);
    });

    test('非对象 JSON 静默忽略', () {
      expect(ImboyJsBridge.buildReply(jsonEncode([1, 2])), isNull);
      expect(ImboyJsBridge.buildReply(jsonEncode('str')), isNull);
    });

    test('回推语句派发到 imboyBridgeMessage 事件', () {
      final reply = ImboyJsBridge.buildReply(jsonEncode({'type': 'ping'}));
      expect(reply, contains("imboyBridgeMessage"));
      expect(reply, startsWith("window.dispatchEvent(new MessageEvent("));
      expect(reply, endsWith("));"));
    });
  });
}
