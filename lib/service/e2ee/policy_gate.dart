/// E2EE 发送前的 fail-closed 策略门（ADR 14 §S1.1 / ADR 20 CB-01/02/09/10）。
///
/// 单一不可绕过入口：出站加密决策必须先经此门。Strict/Compliance 的任何
/// 非 valid 状态返回 typed [E2eeSecurityException]，绝不静默降级为明文或
/// 仅设备加密。
library;

import 'package:imboy/service/compliance_key_service.dart';
import 'package:imboy/service/e2ee_settings.dart';
import 'package:imboy/service/encryption_mode.dart';

/// 出站加密的 typed 安全异常（fail-closed）。
///
/// [reason] 为机器可读原因，不含任何密钥/明文/PII：
/// `policy_not_initialized` / `compliance_key_unavailable` /
/// `compliance_key_expired`。
class E2eeSecurityException implements Exception {
  const E2eeSecurityException(this.reason);

  final String reason;

  @override
  String toString() => 'E2eeSecurityException: $reason';
}

/// 发送策略决策（sealed，穷尽匹配）。
sealed class SendPolicyDecision {
  const SendPolicyDecision();
}

/// 必须加密（strict 或 compliance）。
final class EncryptRequired extends SendPolicyDecision {
  const EncryptRequired(this.mode);

  final EncryptionMode mode;
}

/// 允许明文（部署策略已确认为 plaintext，且本地 optional 关闭）。
final class PlaintextAllowed extends SendPolicyDecision {
  const PlaintextAllowed();
}

/// 发送前策略门。
class PolicyGate {
  const PolicyGate._();

  /// 发送前不可绕过的策略门。返回加密决策，或对非 valid 状态抛
  /// [E2eeSecurityException]。
  ///
  /// - 非 C2C/C2G（action/系统消息）：不施加 E2EE → [PlaintextAllowed]。
  /// - 策略未初始化（无法证明部署为明文）：fail-closed 抛异常。
  /// - strict/compliance：[EncryptRequired]。
  /// - plaintext（已确认）+ 本地 optional 关闭：[PlaintextAllowed]。
  ///
  /// ponytail: 未初始化即拒发——极端下（plaintext 部署且 policy 端点不可达）
  /// 会阻断聊天发送；升级路径见 S2 PolicyGate 正式化（policy-ready 重试 + UX 门）。
  static SendPolicyDecision requireReadyForSend(String chatType) {
    final isChat = chatType == 'C2C' || chatType == 'C2G';
    if (!isChat) return const PlaintextAllowed();

    if (!EncryptionModeService.isInitialized) {
      throw const E2eeSecurityException('policy_not_initialized');
    }

    final mode = EncryptionModeService.current;
    if (mode.requiresEncryption) return EncryptRequired(mode);

    // 已确认明文部署；本地 optional 开关已废弃（E2EESettings.isEnabled 恒 false）。
    if (E2EESettings.isEnabled()) {
      return const EncryptRequired(EncryptionMode.strictE2ee);
    }
    return const PlaintextAllowed();
  }

  /// Compliance 模式下校验合规审计公钥；缺失/过期即 fail-closed 抛异常，
  /// 绝不静默降级为仅设备加密或复用 stale cache（CB-09/10）。
  ///
  /// 仅在 [EncryptionMode.complianceE2ee] 下由发送路径调用。
  static ComplianceKeyInfo requireComplianceKey(ComplianceKeyInfo? key) {
    if (key == null) {
      throw const E2eeSecurityException('compliance_key_unavailable');
    }
    if (key.isExpired) {
      throw const E2eeSecurityException('compliance_key_expired');
    }
    return key;
  }
}
