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

  group('ImboyJsBridge.handle(openChat)', () {
    late String? capturedPeerId;
    late ImboyJsBridge bridge;

    setUp(() {
      capturedPeerId = null;
      bridge = ImboyJsBridge(
        onOpenChat: (peerId) async {
          capturedPeerId = peerId;
          return true;
        },
      );
    });

    test('合法纯数字 to 触发导航并回 ok', () async {
      final reply = await bridge.handle(
        jsonEncode({
          'id': 3,
          'type': 'openChat',
          'data': {'to': '56321'},
        }),
      );
      expect(capturedPeerId, '56321');
      final payload = decodeReply(reply!);
      expect(payload['id'], 3);
      expect(payload['type'], 'openChat');
      expect(payload['ok'], isTrue);
      expect(payload['data'], {'to': '56321'});
    });

    test('非数字/空/超长 to 拒绝且不触发导航', () async {
      for (final bad in ['abc', '', '12 34', '-1', '1' * 19]) {
        final reply = await bridge.handle(
          jsonEncode({
            'type': 'openChat',
            'data': {'to': bad},
          }),
        );
        final payload = decodeReply(reply!);
        expect(payload['ok'], isFalse, reason: 'to=$bad');
        expect(payload['error'], 'invalid_to', reason: 'to=$bad');
      }
      expect(capturedPeerId, isNull);
    });

    test('缺 data 字段按 invalid_to 拒绝', () async {
      final reply = await bridge.handle(jsonEncode({'type': 'openChat'}));
      final payload = decodeReply(reply!);
      expect(payload['ok'], isFalse);
      expect(payload['error'], 'invalid_to');
    });

    test('导航异常回 navigate_failed', () async {
      final failing = ImboyJsBridge(
        onOpenChat: (_) async => throw StateError('boom'),
      );
      final reply = await failing.handle(
        jsonEncode({
          'type': 'openChat',
          'data': {'to': '56321'},
        }),
      );
      final payload = decodeReply(reply!);
      expect(payload['ok'], isFalse);
      expect(payload['error'], 'navigate_failed');
    });

    test('ping/echo 仍经 handle 分发（协议不回归）', () async {
      final reply = await bridge.handle(jsonEncode({'type': 'ping'}));
      final payload = decodeReply(reply!);
      expect(payload['ok'], isTrue);
      expect((payload['data'] as Map<String, dynamic>)['pong'], isTrue);
    });
  });
}
