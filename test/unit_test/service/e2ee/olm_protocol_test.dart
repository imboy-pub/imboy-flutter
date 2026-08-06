// B.1 守护测试：OlmProtocol 参数校验 + 接口契约（纯测，不触发 vodozemac）。
// 真实 X3DH + Double Ratchet round-trip 需原生库，留真机集成测试。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee/olm_protocol.dart';

RecipientDevice _dev(String id) =>
    RecipientDevice(deviceId: id, keyId: 'k-$id', publicKey: 'pub-$id');

void main() {
  group('OlmProtocol —— 接口契约', () {
    test('suite 为 ProtocolSuite.olm', () {
      expect(OlmProtocol().suite, ProtocolSuite.olm);
    });

    test('注册到 Registry 后可按 olm 元数据 resolve', () {
      E2eeProtocolRegistry.resetForTest();
      final olm = OlmProtocol();
      E2eeProtocolRegistry.register(olm);
      expect(
        E2eeProtocolRegistry.resolve({'protocol': 'olm', 'version': 1}),
        same(olm),
      );
      expect(E2eeProtocolRegistry.resolve({'e2ee_suite': 'OLM.V1'}), same(olm));
      E2eeProtocolRegistry.resetForTest();
    });
  });

  group('OlmProtocol.encrypt —— per-device 校验（不触发 vodozemac）', () {
    const ctx = E2eeContext(peerUid: 'peerU', scope: 'c2c');

    test('recipients 非单元素抛 ArgumentError（Olm 是 per-device 会话）', () {
      final p = OlmProtocol();
      expect(
        () => p.encrypt(plaintext: 'hi', recipients: const [], context: ctx),
        throwsArgumentError,
      );
      expect(
        () => p.encrypt(
          plaintext: 'hi',
          recipients: [_dev('d1'), _dev('d2')],
          context: ctx,
        ),
        throwsArgumentError,
      );
    });

    test('缺 context.peerUid 抛 ArgumentError', () {
      final p = OlmProtocol();
      expect(
        () => p.encrypt(
          plaintext: 'hi',
          recipients: [_dev('d1')],
          context: const E2eeContext(scope: 'c2c'),
        ),
        throwsArgumentError,
      );
    });

    test('未 initialize（无 self uid）抛 StateError，在触发 vodozemac 前拦截', () {
      final p = OlmProtocol();
      expect(
        () =>
            p.encrypt(plaintext: 'hi', recipients: [_dev('d1')], context: ctx),
        throwsStateError,
      );
    });
  });

  group('OlmProtocol.decrypt —— 缺字段兜底（不触发 vodozemac）', () {
    test('缺 peer_uid/peer_device_id 抛 E2eeDecryptException(no_device_key)', () {
      final p = OlmProtocol();
      expect(
        () => p.decrypt(ciphertext: 'ct', metadata: const {}),
        throwsA(
          isA<E2eeDecryptException>().having(
            (e) => e.reason,
            'reason',
            'no_device_key',
          ),
        ),
      );
      expect(
        () => p.decrypt(ciphertext: 'ct', metadata: const {'peer_uid': 'a'}),
        throwsA(isA<E2eeDecryptException>()),
      );
    });
  });
}
