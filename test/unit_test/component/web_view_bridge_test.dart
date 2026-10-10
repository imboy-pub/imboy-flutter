import 'dart:async';
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

  group('ImboyJsBridge.buildReply ping methods 声明', () {
    test('缺省不带 methods（旧调用方/旧 H5 兼容）', () {
      final reply = ImboyJsBridge.buildReply(jsonEncode({'type': 'ping'}));
      final payload = decodeReply(reply!);
      expect(payload['ok'], isTrue);
      expect(
        (payload['data'] as Map<String, dynamic>).containsKey('methods'),
        isFalse,
      );
    });

    test('显式传入时 ping 回执携带 methods', () {
      final reply = ImboyJsBridge.buildReply(
        jsonEncode({'id': 1, 'type': 'ping'}),
        supportedMethods: const ['ping', 'echo'],
      );
      final payload = decodeReply(reply!);
      expect((payload['data'] as Map<String, dynamic>)['methods'], [
        'ping',
        'echo',
      ]);
    });

    test('实例 handle(ping) 的 methods 随 getAuthCode 注入与否变化', () async {
      final plain = ImboyJsBridge(onOpenChat: (_) async => true);
      final payload = decodeReply(
        (await plain.handle(jsonEncode({'type': 'ping'})))!,
      );
      expect((payload['data'] as Map<String, dynamic>)['methods'], [
        'ping',
        'echo',
        'openChat',
      ]);

      final withAuth = ImboyJsBridge(
        onOpenChat: (_) async => true,
        onGetAuthCode: (_) async => const ImboyBridgeAuthCode.failure('busy'),
      );
      final payload2 = decodeReply(
        (await withAuth.handle(jsonEncode({'type': 'ping'})))!,
      );
      expect((payload2['data'] as Map<String, dynamic>)['methods'], [
        'ping',
        'echo',
        'openChat',
        'getAuthCode',
      ]);
    });
  });

  group('ImboyJsBridge.handle(getAuthCode)', () {
    ImboyJsBridge bridgeWith(
      Future<ImboyBridgeAuthCode> Function(String? key) handler,
    ) {
      return ImboyJsBridge(
        onOpenChat: (_) async => true,
        onGetAuthCode: handler,
      );
    }

    test('未注入取码动作回 oa_not_available（不回调 handler）', () async {
      final bridge = ImboyJsBridge(onOpenChat: (_) async => true);
      final reply = await bridge.handle(
        jsonEncode({
          'id': 11,
          'type': 'getAuthCode',
          'data': <String, Object?>{},
        }),
      );
      final payload = decodeReply(reply!);
      expect(payload['id'], 11);
      expect(payload['type'], 'getAuthCode');
      expect(payload['ok'], isFalse);
      expect(payload['error'], 'oa_not_available');
    });

    test(
      '成功：回执信封含 code/state/expires_in/redirect_uri/application_key',
      () async {
        final bridge = bridgeWith((key) async {
          expect(key, isNull);
          return const ImboyBridgeAuthCode.success(
            code: 'oa_sso_abc',
            state: 'nonce_nonce_nonce_nonce',
            expiresInSeconds: 60,
            redirectUri: 'https://oa.example.com/cb',
            applicationKey: 'app_key_1',
          );
        });
        final payload = decodeReply(
          (await bridge.handle(
            jsonEncode({
              'id': 12,
              'type': 'getAuthCode',
              'data': <String, Object?>{},
            }),
          ))!,
        );
        expect(payload['ok'], isTrue);
        expect(payload['data'], {
          'code': 'oa_sso_abc',
          'state': 'nonce_nonce_nonce_nonce',
          'expires_in': 60,
          'redirect_uri': 'https://oa.example.com/cb',
          'application_key': 'app_key_1',
        });
      },
    );

    test('H5 传 application_key 时原样交给注入动作', () async {
      String? seen;
      final bridge = bridgeWith((key) async {
        seen = key;
        return const ImboyBridgeAuthCode.failure('app_not_configured');
      });
      final payload = decodeReply(
        (await bridge.handle(
          jsonEncode({
            'type': 'getAuthCode',
            'data': {'application_key': 'app_key_2'},
          }),
        ))!,
      );
      expect(seen, 'app_key_2');
      expect(payload['error'], 'app_not_configured');
    });

    test('非法 application_key 形态回 badRequest 且不回调', () async {
      var called = false;
      final bridge = bridgeWith((key) async {
        called = true;
        return const ImboyBridgeAuthCode.failure('unknown');
      });
      for (final bad in ['short', 'has space', 'a' * 129]) {
        final payload = decodeReply(
          (await bridge.handle(
            jsonEncode({
              'type': 'getAuthCode',
              'data': {'application_key': bad},
            }),
          ))!,
        );
        expect(payload['error'], 'badRequest', reason: bad);
      }
      expect(called, isFalse);
    });

    test('注入动作抛异常回 unknown', () async {
      final bridge = bridgeWith((_) async => throw StateError('boom'));
      final payload = decodeReply(
        (await bridge.handle(jsonEncode({'type': 'getAuthCode'})))!,
      );
      expect(payload['ok'], isFalse);
      expect(payload['error'], 'unknown');
    });

    test('缺 data / 非对象 data 按“未指定 key”处理', () async {
      String? seen = 'sentinel';
      final bridge = bridgeWith((key) async {
        seen = key;
        return const ImboyBridgeAuthCode.failure('app_not_configured');
      });
      await bridge.handle(jsonEncode({'type': 'getAuthCode'}));
      expect(seen, isNull);
      await bridge.handle(
        jsonEncode({'type': 'getAuthCode', 'data': 'not-a-map'}),
      );
      expect(seen, isNull);
    });

    test('同一桥实例并发第二个请求回 busy，首个完成后恢复', () async {
      final completer = Completer<ImboyBridgeAuthCode>();
      final bridge = ImboyJsBridge(
        onOpenChat: (_) async => true,
        onGetAuthCode: (_) => completer.future,
      );
      final first = bridge.handle(
        jsonEncode({'id': 21, 'type': 'getAuthCode'}),
      );
      final second = await bridge.handle(
        jsonEncode({'id': 22, 'type': 'getAuthCode'}),
      );
      final secondPayload = decodeReply(second!);
      expect(secondPayload['id'], 22);
      expect(secondPayload['ok'], isFalse);
      expect(secondPayload['error'], 'busy');

      completer.complete(
        const ImboyBridgeAuthCode.success(
          code: 'oa_sso_first',
          state: 'nonce_nonce_nonce_nox',
          expiresInSeconds: 60,
          redirectUri: 'https://oa.example.com/cb',
          applicationKey: 'app_key_1',
        ),
      );
      final firstPayload = decodeReply((await first)!);
      expect(firstPayload['id'], 21);
      expect(firstPayload['ok'], isTrue);
      expect(firstPayload['data']['code'], 'oa_sso_first');

      // 首个完成后单飞释放，可再次取码。
      final third = await bridge.handle(
        jsonEncode({'id': 23, 'type': 'getAuthCode'}),
      );
      expect(decodeReply(third!)['ok'], isTrue);
    });

    test('注入动作抛异常后单飞复位（后续请求不再 busy）', () async {
      final failing = ImboyJsBridge(
        onOpenChat: (_) async => true,
        onGetAuthCode: (_) async => throw StateError('boom'),
      );
      await failing.handle(jsonEncode({'type': 'getAuthCode'}));
      final next = await failing.handle(jsonEncode({'type': 'getAuthCode'}));
      final payload = decodeReply(next!);
      expect(payload['ok'], isFalse);
      expect(payload['error'], isNot('busy'));
    });
  });
}
