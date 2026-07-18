// ADR 02 §9 守护测试：Protocol Registry + ProtocolSuite 兼容矩阵。
// 纯函数 / 纯 Registry，无 vodozemac 原生库依赖（真机 round-trip 见集成测试）。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';

/// 手写 fake 协议实现（项目规范：fakes over mocks）。
class _FakeProtocol implements E2eeSessionProtocol {
  _FakeProtocol(this._suite);
  final ProtocolSuite _suite;

  @override
  ProtocolSuite get suite => _suite;

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
  }) async => E2eeCiphertext('ct:$plaintext', {'protocol': _suite.protocol});

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async => 'pt:$ciphertext';

  @override
  Future<void> clearAll() async {}
}

void main() {
  group('ProtocolSuite.fromMetadata — 兼容矩阵（ADR 02 §3.2 冻结）', () {
    test('v1 OLM.V1 → olm', () {
      expect(
        ProtocolSuite.fromMetadata({'e2ee_suite': 'OLM.V1'}),
        ProtocolSuite.olm,
      );
    });
    test('v1 MEGOLM.V1 → megolm', () {
      expect(
        ProtocolSuite.fromMetadata({'e2ee_suite': 'MEGOLM.V1'}),
        ProtocolSuite.megolm,
      );
    });
    test('v1 RSA-OAEP-256+AES-256-GCM → rsa-oaep', () {
      expect(
        ProtocolSuite.fromMetadata({'e2ee_suite': 'RSA-OAEP-256+AES-256-GCM'}),
        ProtocolSuite.rsa,
      );
    });
    test('v2 三元组 protocol=olm version=1 → olm', () {
      expect(
        ProtocolSuite.fromMetadata({'protocol': 'olm', 'version': 1}),
        ProtocolSuite.olm,
      );
    });
    test('v2 优先于 v1（双写时取 protocol 三元组）', () {
      final s = ProtocolSuite.fromMetadata({
        'protocol': 'megolm',
        'version': 1,
        'e2ee_suite': 'OLM.V1',
      });
      expect(s, ProtocolSuite.megolm);
    });
    test('未知 e2ee_suite 抛 FormatException（不静默 fallback）', () {
      expect(
        () => ProtocolSuite.fromMetadata({'e2ee_suite': 'BOGUS.V9'}),
        throwsFormatException,
      );
      expect(() => ProtocolSuite.fromMetadata({}), throwsFormatException);
    });
  });

  group('ProtocolSuite — 三元组语义', () {
    test('wire 格式 PROTOCOL.VERSION', () {
      expect(ProtocolSuite.olm.wire, 'OLM.1');
      expect(ProtocolSuite.megolm.wire, 'MEGOLM.1');
    });
    test('legacyWire 双写兼容旧客户端（OLM.V1 等）', () {
      expect(ProtocolSuite.olm.legacyWire, 'OLM.V1');
      expect(ProtocolSuite.megolm.legacyWire, 'MEGOLM.V1');
      expect(ProtocolSuite.rsa.legacyWire, 'RSA-OAEP-256+AES-256-GCM');
    });
    test('== / hashCode 基于三元组', () {
      expect(
        const ProtocolSuite('olm', 1, 'curve25519+ed25519+aes-256-gcm'),
        ProtocolSuite.olm,
      );
      expect(ProtocolSuite.olm == ProtocolSuite.megolm, isFalse);
    });
    test('mls 占位 version=0 reserved', () {
      expect(ProtocolSuite.mls.version, 0);
      expect(ProtocolSuite.mls.cipher, 'reserved');
    });
  });

  group('E2eeProtocolRegistry（ADR 02 §9.1 T-02-01..05）', () {
    setUp(E2eeProtocolRegistry.resetForTest);
    tearDown(E2eeProtocolRegistry.resetForTest);

    test('T-02-02: 同名 protocol 重复 register 抛 StateError', () {
      E2eeProtocolRegistry.register(_FakeProtocol(ProtocolSuite.olm));
      expect(
        () => E2eeProtocolRegistry.register(_FakeProtocol(ProtocolSuite.olm)),
        throwsStateError,
      );
    });

    test('T-02-01: resolve 对 3 种 legacy 字符串 + v2 三元组返回正确 impl', () {
      final olm = _FakeProtocol(ProtocolSuite.olm);
      final megolm = _FakeProtocol(ProtocolSuite.megolm);
      final rsa = _FakeProtocol(ProtocolSuite.rsa);
      E2eeProtocolRegistry.register(olm);
      E2eeProtocolRegistry.register(megolm);
      E2eeProtocolRegistry.register(rsa);

      expect(E2eeProtocolRegistry.resolve({'e2ee_suite': 'OLM.V1'}), same(olm));
      expect(
        E2eeProtocolRegistry.resolve({'e2ee_suite': 'MEGOLM.V1'}),
        same(megolm),
      );
      expect(
        E2eeProtocolRegistry.resolve({
          'e2ee_suite': 'RSA-OAEP-256+AES-256-GCM',
        }),
        same(rsa),
      );
      expect(
        E2eeProtocolRegistry.resolve({'protocol': 'olm', 'version': 1}),
        same(olm),
      );
    });

    test('T-02-03: resolve 未注册 protocol 抛 StateError（不静默 fallback）', () {
      E2eeProtocolRegistry.register(_FakeProtocol(ProtocolSuite.olm));
      expect(
        () => E2eeProtocolRegistry.resolve({'e2ee_suite': 'MEGOLM.V1'}),
        throwsStateError,
      );
    });

    test('T-02-04: all() = 已 register 集合（未注册的 MLS 不出现）', () {
      E2eeProtocolRegistry.register(_FakeProtocol(ProtocolSuite.olm));
      E2eeProtocolRegistry.register(_FakeProtocol(ProtocolSuite.megolm));
      final all = E2eeProtocolRegistry.all();
      expect(all, containsAll([ProtocolSuite.olm, ProtocolSuite.megolm]));
      expect(all.contains(ProtocolSuite.mls), isFalse);
      expect(all.length, 2);
    });

    test('T-02-05: 新增 FakeProtocol(suite=fake) 后业务层可路由，无需改路由逻辑', () async {
      final fake = _FakeProtocol(const ProtocolSuite('fake', 1, 'x'));
      E2eeProtocolRegistry.register(fake);
      final meta = {'protocol': 'fake', 'version': 1};
      final impl = E2eeProtocolRegistry.resolve(meta);
      expect(impl, same(fake));
      expect(await impl.decrypt(ciphertext: 'abc', metadata: meta), 'pt:abc');
    });
  });
}
