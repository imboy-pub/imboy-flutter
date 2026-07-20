// ADR 14 §S1.1 / ADR 20 CB-01/02/09/10：Policy Gate fail-closed 守护测试。
//
// 复现旧 fail-open：策略未初始化时旧路径以 plaintext 默认继续发送；
// compliance 密钥缺失/过期时旧 buildE2EEData 静默降级为仅设备加密 /
// 复用 stale cache。本测试断言新 gate 对上述状态一律 fail-closed 抛
// typed [E2eeSecurityException]，并在生产谓词 shouldEncryptOutgoingPayload
// 上验证。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/compliance_key_service.dart';
import 'package:imboy/service/e2ee/policy_gate.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/encryption_mode.dart';

void main() {
  tearDown(() {
    // 复位静态策略，避免测试间污染。
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: false,
    );
  });

  group('PolicyGate.requireReadyForSend — CB-01/02 fail-closed', () {
    test('策略未初始化 + C2C → 抛 policy_not_initialized，不返回决策', () {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: false,
      );
      expect(
        () => PolicyGate.requireReadyForSend('C2C'),
        throwsA(
          isA<E2eeSecurityException>().having(
            (e) => e.reason,
            'reason',
            'policy_not_initialized',
          ),
        ),
      );
    });

    test('策略未初始化（后端本应 strict）+ C2G → fail-closed 抛异常', () {
      // 后端策略 strict 但客户端从未成功加载 → 旧路径会以 plaintext 默认发送。
      EncryptionModeService.debugSet(
        mode: EncryptionMode.strictE2ee,
        initialized: false,
      );
      expect(
        () => PolicyGate.requireReadyForSend('C2G'),
        throwsA(isA<E2eeSecurityException>()),
      );
    });

    test('已初始化 strict + C2C → EncryptRequired(strict)', () {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.strictE2ee,
        initialized: true,
      );
      final d = PolicyGate.requireReadyForSend('C2C');
      expect(d, isA<EncryptRequired>());
      expect((d as EncryptRequired).mode, EncryptionMode.strictE2ee);
    });

    test('已初始化 compliance + C2G → EncryptRequired(compliance)', () {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.complianceE2ee,
        initialized: true,
      );
      expect(PolicyGate.requireReadyForSend('C2G'), isA<EncryptRequired>());
    });

    test('已确认 plaintext 部署 + C2C → PlaintextAllowed（不抛）', () {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: true,
      );
      expect(PolicyGate.requireReadyForSend('C2C'), isA<PlaintextAllowed>());
    });

    test('非聊天类型（C2S/action）即使未初始化也不施加 E2EE，不抛', () {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: false,
      );
      expect(PolicyGate.requireReadyForSend('C2S'), isA<PlaintextAllowed>());
    });
  });

  group('生产谓词 shouldEncryptOutgoingPayload 经 gate fail-closed', () {
    test('未初始化 + C2C → 抛 E2eeSecurityException（send/encrypt=0）', () {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: false,
      );
      expect(
        () => E2EEService.shouldEncryptOutgoingPayload('C2C'),
        throwsA(isA<E2eeSecurityException>()),
      );
    });

    test('已初始化 strict + C2C → true（要求加密）', () {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.strictE2ee,
        initialized: true,
      );
      expect(E2EEService.shouldEncryptOutgoingPayload('C2C'), isTrue);
    });

    test('已确认 plaintext + C2C → false（明文部署，不抛）', () {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: true,
      );
      expect(E2EEService.shouldEncryptOutgoingPayload('C2C'), isFalse);
    });
  });

  group('PolicyGate.requireComplianceKey — CB-09/10 fail-closed', () {
    test('合规密钥缺失 → 抛 compliance_key_unavailable（不静默降级设备加密）', () {
      expect(
        () => PolicyGate.requireComplianceKey(null),
        throwsA(
          isA<E2eeSecurityException>().having(
            (e) => e.reason,
            'reason',
            'compliance_key_unavailable',
          ),
        ),
      );
    });

    test('合规密钥过期 → 抛 compliance_key_expired（不用 stale cache）', () {
      final expired = ComplianceKeyInfo(
        keyId: 'k1',
        publicKey: 'pem',
        fetchedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      expect(expired.isExpired, isTrue);
      expect(
        () => PolicyGate.requireComplianceKey(expired),
        throwsA(
          isA<E2eeSecurityException>().having(
            (e) => e.reason,
            'reason',
            'compliance_key_expired',
          ),
        ),
      );
    });

    test('合规密钥有效 → 返回该 key（供审计包装）', () {
      final fresh = ComplianceKeyInfo(
        keyId: 'k1',
        publicKey: 'pem',
        fetchedAt: DateTime.now(),
      );
      expect(PolicyGate.requireComplianceKey(fresh), same(fresh));
    });
  });
}
