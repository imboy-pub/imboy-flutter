import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';

/// H2 真机走查发现④：对端账号从未在任何设备登录（设备表为空）时，
/// 加密发送必须被拒绝，且错误文案路由到带行动指引的新键
/// （e2eeErrPeerNotOnboarded），而非通用的"无法获取设备密钥"。
///
/// 与既有 no_recipient_keys（解密侧/群组密钥故障）路由互不串线：
/// 加密侧对端离线 → e2eeErrPeerNotOnboarded；
/// 解密侧/群组 → e2eeErrNoRecipientKey（既有行为保持）。
void main() {
  const service = ChatNetworkService();

  test('peer_has_no_device 路由到带引导文案的新键', () {
    final message = service.getE2EEErrorMessage('peer_has_no_device');
    expect(message, t.common.e2eeErrPeerNotOnboarded);
    expect(message, isNot(t.main.e2eeErrDefault), reason: '必须路由到专用键，而不是兜底默认文案');
  });

  test('既有 no_recipient_keys 路由保持不变', () {
    final message = service.getE2EEErrorMessage('no_recipient_keys');
    expect(message, t.common.e2eeErrNoRecipientKey);
  });
}
