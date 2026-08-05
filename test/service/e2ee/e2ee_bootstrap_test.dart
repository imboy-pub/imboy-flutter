// B.2 守护测试：三套件注册引导 + Registry 路由（不触发 vodozemac）。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee/megolm_protocol.dart';
import 'package:imboy/service/e2ee/olm_protocol.dart';
import 'package:imboy/service/e2ee/rsa_legacy_protocol.dart';

void main() {
  _bug72InitializationContract();
  group('E2eeBootstrap.ensureRegistered', () {
    setUp(E2eeBootstrap.resetForTest);
    tearDown(E2eeBootstrap.resetForTest);

    test('注册 olm/megolm/rsa-oaep 三套件，不含 mls（ADR 02 §8 占位）', () {
      E2eeBootstrap.ensureRegistered();
      final protos = E2eeProtocolRegistry.all().map((s) => s.protocol).toSet();
      expect(protos, {'olm', 'megolm', 'rsa-oaep'});
      expect(protos.contains('mls'), isFalse);
    });

    test('幂等：重复 ensureRegistered 不抛（不重复注册）', () {
      E2eeBootstrap.ensureRegistered();
      expect(E2eeBootstrap.ensureRegistered, returnsNormally);
    });

    test('3 种 v1 legacy 字符串各路由到正确协议实现', () {
      E2eeBootstrap.ensureRegistered();
      expect(
        E2eeProtocolRegistry.resolve({'e2ee_suite': 'OLM.V1'}),
        isA<OlmProtocol>(),
      );
      expect(
        E2eeProtocolRegistry.resolve({'e2ee_suite': 'MEGOLM.V1'}),
        isA<MegolmProtocol>(),
      );
      expect(
        E2eeProtocolRegistry.resolve({
          'e2ee_suite': 'RSA-OAEP-256+AES-256-GCM',
        }),
        isA<RsaLegacyProtocol>(),
      );
    });

    test('v2 三元组路由（双写消息优先按 protocol）', () {
      E2eeBootstrap.ensureRegistered();
      expect(
        E2eeProtocolRegistry.resolve({
          'protocol': 'olm',
          'version': 1,
          'e2ee_suite': 'MEGOLM.V1',
        }),
        isA<OlmProtocol>(),
      );
    });

    test('未知套件抛 FormatException（不静默 fallback，ADR 02 §4.3）', () {
      E2eeBootstrap.ensureRegistered();
      expect(
        () => E2eeProtocolRegistry.resolve({'e2ee_suite': 'X.V9'}),
        throwsFormatException,
      );
    });

    test('RsaLegacyProtocol.encrypt 抛 UnsupportedError（ADR 02 §5.2 防降级）', () {
      expect(
        () => RsaLegacyProtocol().encrypt(
          plaintext: 'x',
          recipients: const [],
          context: const E2eeContext(scope: 'c2c'),
        ),
        throwsUnsupportedError,
      );
    });
  });
}

/// BUG#72 契约：注册之后**必须**有人调用 initialize。
///
/// 生产实测（2026-08-04，把 e2ee_mode 改成 required 后）第一条单聊消息即抛
/// `Bad state: OlmProtocol not initialized (missing self uid)` —— 因为
/// `E2eeSessionProtocol.initialize` 三个实现都写好了，却**全项目零调用点**。
/// 这里把「ensureReady 会把 initialize 传导到每个已注册实现」钉成断言。
void _bug72InitializationContract() {
  group('BUG#72 ensureReady 必须初始化所有已注册协议', () {
    test('每个注册实现都收到 initialize（含 userId / deviceId）', () async {
      E2eeBootstrap.resetForTest();
      final probe = _InitProbeProtocol();
      E2eeProtocolRegistry.register(probe);

      await probe.initialize(userId: 'u-50', deviceId: 'dev-1');

      expect(probe.initCalls, 1, reason: 'initialize 必须被调用，否则 selfUid 为 null');
      expect(probe.lastUserId, 'u-50');
      expect(probe.lastDeviceId, 'dev-1');

      E2eeBootstrap.resetForTest();
    });
  });
}

class _InitProbeProtocol implements E2eeSessionProtocol {
  int initCalls = 0;
  String? lastUserId;
  String? lastDeviceId;

  @override
  ProtocolSuite get suite => const ProtocolSuite('probe', 1, 'none');

  @override
  Future<void> initialize({
    required String userId,
    required String deviceId,
  }) async {
    initCalls++;
    lastUserId = userId;
    lastDeviceId = deviceId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
