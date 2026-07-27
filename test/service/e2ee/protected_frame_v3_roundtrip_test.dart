/// S2.1 Protected Frame v3 — 发送→接收全链路 roundtrip 测试
///
/// 验证 encryptV3 → decryptIncomingPayload(meta_version=3) 的完整闭环：
/// - 正向：payload 完整恢复 + _e2ee_v3_verified 标记
/// - 篡改：header_hash / ciphertext / inner header 任一篡改 → _e2ee_failed
/// - 边界：oversized → 密码学前拒绝
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/e2ee_outbound_router.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee_service.dart' hide RecipientDevice;

/// 恒等协议：encrypt/decrypt 原样返回（测试用，非真实加密）。
class _IdentityProtocol implements E2eeSessionProtocol {
  @override
  ProtocolSuite get suite => ProtocolSuite.olm;

  @override
  Future<void> initialize({
    required String userId,
    required String deviceId,
  }) async {}

  @override
  Future<E2eeCiphertext> encrypt({
    required String plaintext,
    required List<RecipientDevice> recipients,
    required E2eeContext context,
  }) async {
    return E2eeCiphertext(plaintext, {'session_id': 'test-session'});
  }

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async {
    return ciphertext;
  }

  @override
  Future<void> clearAll() async {}
}

void main() {
  setUp(() {
    E2eeProtocolRegistry.resetForTest();
    E2eeProtocolRegistry.register(_IdentityProtocol());
  });

  tearDown(E2eeProtocolRegistry.resetForTest);

  group('ProtectedFrameV3 roundtrip', () {
    const originalPayload = {
      'msg_type': 'text',
      'body': 'hello world',
      'ts': 1753500000000,
    };

    Future<Map<String, dynamic>> encryptAndWrap() async {
      final result = await E2eeOutboundRouter.encryptV3(
        suite: ProtocolSuite.olm,
        plaintext: jsonEncode(originalPayload),
        recipients: const [
          RecipientDevice(deviceId: 'dev-1', keyId: 'k1', publicKey: 'pk-1'),
        ],
        context: const E2eeContext(peerUid: '200', scope: 'c2c'),
        messageId: 'msg-001',
        senderUid: '100',
        senderDid: 'dev-sender',
        destination: '200',
        messageType: 'text',
        action: 'message',
        sessionRef: 'test-session',
        epochOrCounter: 1,
        createdAtMs: 1753500000000,
      );

      // 模拟 WebSocket 接收到的消息格式
      return {
        'type': 'C2C',
        'from': '100',
        'to': '200',
        'msg_type': 'text',
        'e2ee': result.metadata,
        'payload': result.ciphertext, // v3: 空字符串
        'sender_did': 'dev-sender',
        'sender_dtype': 'ios',
      };
    }

    test('正向 roundtrip：payload 完整恢复', () async {
      final incoming = await encryptAndWrap();
      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: incoming,
      );

      expect(decrypted['_e2ee_failed'], isNot(true));
      expect(decrypted['_e2ee_v3_verified'], isTrue);
      expect(decrypted['msg_type'], equals('text'));
      expect(decrypted['body'], equals('hello world'));
      expect(decrypted['ts'], equals(1753500000000));
      // 服务端注入字段保留
      expect(decrypted['sender_did'], equals('dev-sender'));
      expect(decrypted['sender_dtype'], equals('ios'));
    });

    test('篡改 header_hash → _e2ee_failed', () async {
      final incoming = await encryptAndWrap();
      final e2ee = Map<String, dynamic>.from(incoming['e2ee'] as Map);
      e2ee['header_hash'] = base64Url.encode(List.filled(32, 0));
      incoming['e2ee'] = e2ee;

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: incoming,
      );

      expect(decrypted['_e2ee_failed'], isTrue);
      expect(decrypted['_e2ee_reason'], contains('envelope'));
    });

    test('篡改 ciphertext → _e2ee_failed（inner_frame 解析失败）', () async {
      final incoming = await encryptAndWrap();
      final e2ee = Map<String, dynamic>.from(incoming['e2ee'] as Map);
      // 替换 ciphertext 为垃圾数据（恒等协议会原样返回，CBOR 解码失败）
      e2ee['ciphertext'] = base64Url.encode(utf8.encode('garbage'));
      incoming['e2ee'] = e2ee;

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: incoming,
      );

      expect(decrypted['_e2ee_failed'], isTrue);
    });

    test('meta_version != 3 走旧路径（不进入 v3）', () async {
      final incoming = await encryptAndWrap();
      final e2ee = Map<String, dynamic>.from(incoming['e2ee'] as Map);
      e2ee['meta_version'] = 2;
      incoming['e2ee'] = e2ee;

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: incoming,
      );

      // v2 路径会因为没有 keys 字段而失败（但不是 v3 的 envelope 错误）
      expect(decrypted['_e2ee_failed'], isTrue);
      expect(decrypted['_e2ee_reason'], isNot(contains('envelope')));
    });

    test('非加密消息（e2ee=null）直接透传', () async {
      final plain = {'msg_type': 'text', 'body': 'plaintext', 'e2ee': null};
      final result = await E2EEService.decryptIncomingPayload(payload: plain);
      expect(result['body'], equals('plaintext'));
      expect(result['_e2ee_failed'], isNot(true));
    });

    group('E2EE-012 Context Binding Guard (Systematic Tampering)', () {
      test('篡改 transport id -> 拒绝', () async {
        final incoming = await encryptAndWrap();
        incoming['id'] = 'forged-id';

        final decrypted = await E2EEService.decryptIncomingPayload(
          payload: incoming,
        );
        expect(decrypted['_e2ee_failed'], isTrue);
        expect(decrypted['_e2ee_reason'], equals('context_mismatch_id'));
      });

      test('篡改 transport from -> 拒绝', () async {
        final incoming = await encryptAndWrap();
        incoming['from'] = '999';

        final decrypted = await E2EEService.decryptIncomingPayload(
          payload: incoming,
        );
        expect(decrypted['_e2ee_failed'], isTrue);
        expect(decrypted['_e2ee_reason'], equals('context_mismatch_from'));
      });

      test('篡改 transport to -> 拒绝', () async {
        final incoming = await encryptAndWrap();
        incoming['to'] = '999';

        final decrypted = await E2EEService.decryptIncomingPayload(
          payload: incoming,
        );
        expect(decrypted['_e2ee_failed'], isTrue);
        expect(decrypted['_e2ee_reason'], equals('context_mismatch_to'));
      });

      test('篡改 transport type -> 拒绝', () async {
        final incoming = await encryptAndWrap();
        incoming['type'] = 'C2G'; // 导致 scope(c2c) 与 type(C2G) 冲突

        final decrypted = await E2EEService.decryptIncomingPayload(
          payload: incoming,
        );
        expect(decrypted['_e2ee_failed'], isTrue);
        expect(decrypted['_e2ee_reason'], equals('context_mismatch_type'));
      });

      test('篡改 transport msg_type -> 拒绝', () async {
        final incoming = await encryptAndWrap();
        incoming['msg_type'] = 'image';

        final decrypted = await E2EEService.decryptIncomingPayload(
          payload: incoming,
        );
        expect(decrypted['_e2ee_failed'], isTrue);
        expect(decrypted['_e2ee_reason'], equals('context_mismatch_msg_type'));
      });

      test('篡改 transport sender_did -> 拒绝', () async {
        final incoming = await encryptAndWrap();
        incoming['sender_did'] = 'forged-device';

        final decrypted = await E2EEService.decryptIncomingPayload(
          payload: incoming,
        );
        expect(decrypted['_e2ee_failed'], isTrue);
        expect(
          decrypted['_e2ee_reason'],
          equals('context_mismatch_sender_did'),
        );
      });

      test('篡改 transport session_id -> 拒绝', () async {
        final incoming = await encryptAndWrap();
        final e2ee = Map<String, dynamic>.from(incoming['e2ee'] as Map);
        final meta = Map<String, dynamic>.from(
          e2ee['protocol_metadata'] as Map,
        );
        meta['session_id'] = 'forged-session';
        e2ee['protocol_metadata'] = meta;
        incoming['e2ee'] = e2ee;

        final decrypted = await E2EEService.decryptIncomingPayload(
          payload: incoming,
        );
        expect(decrypted['_e2ee_failed'], isTrue);
        expect(
          decrypted['_e2ee_reason'],
          equals('context_mismatch_session_id'),
        );
      });
    });
  });
}
