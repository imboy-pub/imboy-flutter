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

  test('未知异常仍落默认兜底文案', () {
    expect(
      service.getE2EEErrorMessage(Exception('whatever_unknown')),
      t.main.e2eeErrDefault,
    );
  });
}
