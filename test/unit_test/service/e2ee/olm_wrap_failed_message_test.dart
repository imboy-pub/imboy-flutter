import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';

/// strict 模式 Megolm rotate 时 room key 包裹失败（attachOlmWraps 抛
/// `olm_wrap_failed`，典型：新成员设备未完成 Olm onboarding / 对端 OTK
/// 未就绪）必须路由到带"稍后重试"指引的专用键，而不是笼统默认文案。
///
/// 背景（2026-08-31 用户真机复现）：workspace General 群连发消息，第三条
/// toast「端到端加密失败，消息未发送」——即 e2eeErrDefault 兜底。release
/// 下无日志，根因（olm_wrap_failed）完全不可诊断。修复后映射到
/// e2eeErrPeerDeviceNotReady，与 peer_has_no_device（对方从未登录）、
/// no_recipient_keys（密钥故障）三条路由互不串线。
void main() {
  const service = ChatNetworkService();

  test('olm_wrap_failed 路由到成员设备未就绪文案', () {
    final message = service.getE2EEErrorMessage(
      'E2eeSecurityException: olm_wrap_failed: empty wrapped key',
    );
    expect(message, t.main.e2eeErrPeerDeviceNotReady);
    expect(message, isNot(t.main.e2eeErrDefault), reason: '必须路由到专用键，而不是兜底默认文案');
  });

  test('peer_has_no_device / no_recipient_keys 既有路由保持不变', () {
    expect(
      service.getE2EEErrorMessage('peer_has_no_device'),
      t.common.e2eeErrPeerNotOnboarded,
    );
    expect(
      service.getE2EEErrorMessage('no_recipient_keys'),
      t.common.e2eeErrNoRecipientKey,
    );
  });

  test('sender_device_id_missing 路由到设备未初始化文案', () {
    final message = service.getE2EEErrorMessage(
      'E2eeSecurityException: sender_device_id_missing',
    );
    expect(message, t.main.e2eeErrDeviceNotReady);
    expect(message, isNot(t.main.e2eeErrDefault));
  });

  test('megolm_export_failed 路由到会话密钥生成失败文案', () {
    final message = service.getE2EEErrorMessage(
      Exception('megolm_export_failed'),
    );
    expect(message, t.main.e2eeErrSessionExportFailed);
    expect(message, isNot(t.main.e2eeErrDefault));
  });

  test('suite mismatch 路由到协议配置异常文案', () {
    final message = service.getE2EEErrorMessage(
      StateError('E2EE suite mismatch: selected=megolm, registered=olm'),
    );
    expect(message, t.main.e2eeErrProtocolMismatch);
    expect(message, isNot(t.main.e2eeErrDefault));
  });

  test('compliance_key_unavailable 路由到独立的稍后重试文案', () {
    final message = service.getE2EEErrorMessage(
      'E2eeSecurityException: compliance_key_unavailable',
    );
    // unavailable（取不到密钥）与 changed（已轮换）语义不同，
    // 必须路由到独立键，不能复用 compliance_key_changed 的"确认轮换"指引。
    expect(message, t.main.e2eeErrComplianceUnavailable);
    expect(message, isNot(t.main.e2eeErrComplianceChanged));
    expect(message, isNot(t.main.e2eeErrDefault));
  });

  test('未知异常落兜底稳定文案，不回显原始错误（Finding 014）', () {
    final message = service.getE2EEErrorMessage(
      Exception('Whatever_UNKNOWN_Error'),
    );
    expect(message, t.main.e2eeErrDefault);
    // Finding 014 重开：异常 toString 可能携带明文/密文/库错误原文，
    // 兜底文案不得再拼接原始错误字符串（此前"截断 80 字符进 toast"
    // 的可诊断性取舍由稳定错误码路由 + 服务端日志接管）。
    expect(message, isNot(contains('Whatever_UNKNOWN_Error')));
  });

  test('路由分支可诊断性回归：稳定错误码仍映射到专用文案', () {
    // 兜底去掉原文拼接后，olm_wrap_failed 等稳定错误码的路由必须保持，
    // 否则用户与开发者彻底失去区分故障类型的能力。
    // 入参形态对应 attachOlmWraps strict 模式抛出：
    // `olm_wrap_failed: <runtimeType>`（不携带底层异常原文）。
    final message = service.getE2EEErrorMessage(
      'E2eeSecurityException: olm_wrap_failed: StateError',
    );
    expect(message, t.main.e2eeErrPeerDeviceNotReady);
  });
}
