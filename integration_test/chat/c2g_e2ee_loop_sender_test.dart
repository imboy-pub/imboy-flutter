// integration_test/chat/c2g_e2ee_loop_sender_test.dart
//
// 批次181：C2G E2EE 双端回环·发送侧（macOS smoke_bob）。
//
// 前置：
//   - 群 110073884384167936（bob+alice 双成员）已 set_e2ee_mode=1
//     （curl POST /api/v1/group/set_e2ee_mode，仅群主）；
//   - 接收侧（真机 smoke_alice，c2g_e2ee_loop_receiver_test.dart）先行
//     启动并保持 WS 在线，两侧用同一 C2G_E2EE_LOOP_MARKER。
//
// 链路：GroupApi().detail 同步 e2ee 旗标 → isGroupE2EE=true →
//       白盒 sendMessage(C2G) → groupMegolm 分支（ensureOutboundSession
//       分发 room-key + encryptV3）→ WS 提交。
//
// 运行（define 同批次177 配方，另加 C2G_E2EE_LOOP_MARKER）。

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _gid = '110073884384167936';
const _marker = String.fromEnvironment(
  'C2G_E2EE_LOOP_MARKER',
  defaultValue: 'c2g-loop-marker',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('C2G E2EE 回环·发送侧：详情同步旗标→白盒 Megolm 发送', (tester) async {
    installPluginErrorFilter();
    await ensureAppLaunched(tester, maxSeconds: 10);
    if (!await checkPreconditions(tester)) return;
    await settle(tester, maxSeconds: 2);

    // 群详情同步会写本地 e2ee 旗标（group_api.dart detail→setGroupE2EEMode）
    final detail = await GroupApi().detail(gid: _gid);
    flowLog('[C2G-LOOP] TX 群详情 sync: keys=${detail.keys.toList()}');
    final flagOn = await GroupSessionService.to.isGroupE2EE(_gid);
    if (!flagOn) {
      markTestSkipped('群 e2ee 旗标未同步（detail 未带 e2ee_mode=1）');
      return;
    }
    flowLog('[C2G-LOOP] TX 旗标就位 gid=$_gid');

    final msgId =
        'c2gloop${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final ok = await const ChatNetworkService().sendMessage({
      'id': msgId,
      'type': 'C2G',
      'from': UserRepoLocal.to.currentUid,
      'to': _gid,
      'msg_type': 'text',
      'action': '',
      'payload': <String, dynamic>{'msg_type': 'text', 'text': _marker},
    });
    expect(ok, isTrue, reason: 'C2G Megolm 发送应成功：false=旗标/会话建立/加密/WS 任一环失败');
    // ignore: avoid_print
    print('[C2G-LOOP] TX SEND OK msgId=$msgId marker=$_marker');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
