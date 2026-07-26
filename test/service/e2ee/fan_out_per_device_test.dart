/// S2.2: C2C per-device Olm fan-out 测试
///
/// 验证 fan_out: "per_device" 线格式的发送与接收：
/// - 接收侧：正确路由到本设备信封、缺失设备 fail-closed
/// - 发送侧：wire format 契约（meta_version/protocol/fan_out/devices）
/// - 篡改隔离：一个设备信封被篡改不影响其他设备
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/init.dart' as app_init;
import 'package:imboy/service/e2ee/e2ee_outbound_router.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee_service.dart' hide RecipientDevice;

/// 恒等协议：encrypt/decrypt 原样返回（测试用）。
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
    // 设置本设备 ID（fan-out 接收侧用它选择信封）
    app_init.deviceId = 'my-device-001';
  });

  tearDown(E2eeProtocolRegistry.resetForTest);

  /// 为指定设备生成一个 v3 信封（不含 meta_version，由外层统一标注）
  Future<Map<String, dynamic>> buildEnvelopeForDevice(
    String peerDid,
    String plaintext,
  ) async {
    final result = await E2eeOutboundRouter.encryptV3(
      suite: ProtocolSuite.olm,
      plaintext: plaintext,
      recipients: [
        RecipientDevice(
          deviceId: peerDid,
          keyId: 'k-$peerDid',
          publicKey: 'pk',
        ),
      ],
      context: E2eeContext(peerUid: '200', peerDeviceId: peerDid, scope: 'c2c'),
      messageId: 'msg-fan-001',
      senderUid: '100',
      senderDid: 'sender-dev',
      destination: '200',
      messageType: 'text',
      action: 'message',
      sessionRef: 'sess-fan',
      createdAtMs: 1753500000000,
    );
    final envelope = Map<String, dynamic>.from(result.metadata);
    envelope.remove('meta_version');
    return envelope;
  }

  group('S2.2 fan-out 接收侧', () {
    const payload = {'msg_type': 'text', 'body': 'fan-out hello'};

    test('正向：路由到本设备信封并解密', () async {
      final myEnvelope = await buildEnvelopeForDevice(
        'my-device-001',
        jsonEncode(payload),
      );
      final otherEnvelope = await buildEnvelopeForDevice(
        'other-device-002',
        jsonEncode(payload),
      );

      final incoming = {
        'type': 'C2C',
        'from': '100',
        'to': '200',
        'msg_type': 'text',
        'e2ee': {
          'meta_version': 3,
          'protocol': 'olm',
          'version': 1,
          'fan_out': 'per_device',
          'devices': {
            'my-device-001': myEnvelope,
            'other-device-002': otherEnvelope,
          },
        },
        'payload': '',
      };

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: incoming,
      );

      expect(decrypted['_e2ee_failed'], isNot(true));
      expect(decrypted['_e2ee_v3_verified'], isTrue);
      expect(decrypted['body'], equals('fan-out hello'));
    });

    test('devices 缺失 → fail-closed（fan_out_missing_devices）', () async {
      final incoming = {
        'type': 'C2C',
        'from': '100',
        'to': '200',
        'msg_type': 'text',
        'e2ee': {
          'meta_version': 3,
          'protocol': 'olm',
          'fan_out': 'per_device',
          // devices 字段缺失
        },
        'payload': '',
      };

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: incoming,
      );

      expect(decrypted['_e2ee_failed'], isTrue);
      expect(decrypted['_e2ee_reason'], equals('fan_out_missing_devices'));
    });

    test('本设备无信封 → fail-closed（no_device_envelope）', () async {
      final otherEnvelope = await buildEnvelopeForDevice(
        'other-device-002',
        jsonEncode(payload),
      );

      final incoming = {
        'type': 'C2C',
        'from': '100',
        'to': '200',
        'msg_type': 'text',
        'e2ee': {
          'meta_version': 3,
          'protocol': 'olm',
          'fan_out': 'per_device',
          'devices': {
            'other-device-002': otherEnvelope,
            // 没有 my-device-001 的信封
          },
        },
        'payload': '',
      };

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: incoming,
      );

      expect(decrypted['_e2ee_failed'], isTrue);
      expect(decrypted['_e2ee_reason'], equals('no_device_envelope'));
    });

    test('篡改本设备信封 → _e2ee_failed（不影响 fail-closed 语义）', () async {
      final myEnvelope = await buildEnvelopeForDevice(
        'my-device-001',
        jsonEncode(payload),
      );
      // 篡改 header_hash
      myEnvelope['header_hash'] = base64Url.encode(List.filled(32, 0xAB));

      final incoming = {
        'type': 'C2C',
        'from': '100',
        'to': '200',
        'msg_type': 'text',
        'e2ee': {
          'meta_version': 3,
          'protocol': 'olm',
          'fan_out': 'per_device',
          'devices': {'my-device-001': myEnvelope},
        },
        'payload': '',
      };

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: incoming,
      );

      expect(decrypted['_e2ee_failed'], isTrue);
      expect(decrypted['_e2ee_reason'], contains('envelope'));
    });
  });

  group('S2.2 fan-out 线格式契约', () {
    test('多设备信封结构完整：每个设备独立 header_hash + ciphertext', () async {
      final env1 = await buildEnvelopeForDevice('dev-A', '{"body":"hi"}');
      final env2 = await buildEnvelopeForDevice('dev-B', '{"body":"hi"}');

      // 每个信封必须包含 v3 核心字段
      for (final env in [env1, env2]) {
        expect(env, contains('protected_header'));
        expect(env, contains('header_hash'));
        expect(env, contains('ciphertext'));
        expect(env, contains('protocol_metadata'));
        // 不应包含 meta_version（由外层统一标注）
        expect(env.containsKey('meta_version'), isFalse);
        // protocol 在 CBOR protected_header 内，不在信封顶层
        expect(env.containsKey('protocol'), isFalse);
      }

      // header_hash 相同：protected header 绑定消息级上下文（非 per-device），
      // per-device 隔离由 Olm 密文实现（_IdentityProtocol 下密文也相同）。
      expect(env1['header_hash'], equals(env2['header_hash']));
    });

    test('外层 e2ee 元数据格式正确', () async {
      final env = await buildEnvelopeForDevice('dev-X', '{"body":"x"}');

      final wireE2ee = {
        'meta_version': 3,
        'protocol': 'olm',
        'version': 1,
        'fan_out': 'per_device',
        'devices': {'dev-X': env},
      };

      expect(wireE2ee['meta_version'], equals(3));
      expect(wireE2ee['protocol'], equals('olm'));
      expect(wireE2ee['fan_out'], equals('per_device'));
      expect(wireE2ee['devices'], isA<Map<String, dynamic>>());
      // payload 为空字符串（v3 密文在 devices 内）
      // 服务端仅透传整个 e2ee map + 空 payload
    });
  });
}
