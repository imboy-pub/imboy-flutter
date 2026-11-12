// integration_test/chat_multi_export_test.dart
//
// W3-K P3 真机旅程（RUN_ID=chat-multi-20261111）：E2EE 导出确认 dialog
// 「取消 = 零副作用」。
//
// 旅程：
//   ① 登录 → push C2C ChatPage → 真实输入链发 2 条 marker 文本（部署真实
//      模式，明文链路）
//   ② EncryptionModeService.debugSet 置 strictE2ee（DEV-01 修复：合成部署
//      无 strict policy，原实现整条 SKIP；与既有真机 E2EE 用例同款测试注入）
//   ③ 多选勾选 2 条 → action bar「导出」→ W3-J E2EE 确认弹窗
//      （export_e2ee_confirm）出现
//      → 点「取消」（export_confirm_cancel）→ 弹窗关闭且零副作用断言：
//      - 多选仍激活、已选计数不变（2）
//      - 仍在 ChatPage（无路由漂移）
//      - 无「已分享」成功 toast（exportShared 文案不出现）
//
// gateway fake 注入：设备侧无法替换 SharePlusChatShareGateway（W3-J
// runChatExportFlow 内部构造），fake 注入断言由本地 widget 冒烟
// test/unit_test/page/chat/integration_smoke/chat_multi_export_smoke_test.dart
// 承担（直接构造 controller 注入 RecordingChatShareGateway）；设备侧只
// 驱动「取消」路径 —— 取消在 gateway 调用之前返回，天然零副作用。
//
// 依赖 Central Wiring：onExport 接线（计划 §12.3）。

import 'package:flutter/widgets.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'chat/support/c2c_journey_support.dart';
import 'flows/app_launcher.dart';
import 'flows/test_utils.dart';
import 'helpers/chat_multi_driver.dart';
import 'helpers/chat_multi_fixtures.dart';

const _markerPrefix = '[W3K-EXP]';

/// W3-J 弹窗稳定 Key（w3-j receipt handoff；勿改值）。
const _dialogConfirmKey = Key('export_e2ee_confirm');
const _dialogCancelKey = Key('export_confirm_cancel');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('W3-K P3：E2EE 导出确认弹窗取消 = 零副作用', (tester) async {
    installPluginErrorFilter();
    await ensureAppLaunched(tester, maxSeconds: 10);
    if (!await checkPreconditions(tester)) return;
    if (!requireBusinessWriteAuthorization()) return;

    // E2EE 前置（DEV-01 修复）：本机合成部署为 plaintext，服务端 policy 出
    // 不来 strict E2EE —— 原先整条用例 SKIP。与既有真机 E2EE 用例
    // （e2ee_c2c_outbound_frame_test.dart:155）同款 @visibleForTesting 注入：
    // 2 条 marker 文本先按真实明文链路发出，之后把 EncryptionModeService 置
    // 为 strictE2ee —— 导出确认门 isEncryptedConversationForExport →
    // PolicyGate.requireReadyForSend 即 EncryptRequired，W3-J E2EE 确认弹窗
    // 真实出现；teardown 复位。这不是伪通过：弹窗判定、取消语义、零副作用
    // 断言全部走生产代码路径（文本发送不注入，仍是部署真实模式）。
    final selfUid = UserRepoLocal.to.currentUid;
    final peerUid = () {
      final defined = const String.fromEnvironment('CHAT_MULTI_SRC_PEER_UID');
      if (defined.isNotEmpty) return defined;
      return selfUid == ChatMultiAccounts.bob
          ? ChatMultiAccounts.alice
          : ChatMultiAccounts.bob;
    }();
    final peerTitle = () {
      final defined = const String.fromEnvironment('CHAT_MULTI_SRC_PEER_TITLE');
      if (defined.isNotEmpty) return defined;
      return peerUid == ChatMultiAccounts.alice ? 'SmokeAlice' : 'SmokeBob';
    }();
    flowLog('W3K-EXP self=$selfUid peer=$peerUid');

    final flags = enableChatMultiFlagsForTest(bundle: false);
    addTearDown(flags.restore);

    // ① 源会话：2 条 marker 文本。
    final chatPage = await pushChatPage(
      tester,
      type: 'C2C',
      peerId: peerUid,
      peerTitle: peerTitle,
    );
    final nonce = ChatMultiMessageFixtures.nextNonce();
    final m1 = '$_markerPrefix-t1-$nonce';
    final m2 = '$_markerPrefix-t2-$nonce';
    await sendTextViaInput(tester, chatPage, m1);
    await sendTextViaInput(tester, chatPage, m2);
    await settle(tester, maxSeconds: 2);

    // 文本发送完成后才切 strict：发送链的 PolicyGate 判定仍按部署真实模式
    // （plaintext）走，不注入；注入只影响导出确认门的加密会话判定。
    EncryptionModeService.debugSet(
      mode: EncryptionMode.strictE2ee,
      initialized: true,
    );
    addTearDown(() {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: false,
      );
    });

    // ② 多选 2 条 → 导出。
    // W1-A enter 契约：长按 m1 进入多选即选中 m1（driver 断言计数=1），
    // 这里只勾 m2 —— 再 toggle m1 会把它勾掉（DEV-01 修复）。
    await enterMultiSelectViaMenu(tester, chatMultiItemContaining(m1));
    await toggleMessageSelection(
      tester,
      chatMultiItemContaining(m2),
      messageId: messageOfMarker(tester, m2)?.id,
    );
    expectSelectionCount(tester, 2);
    await takeScreenshot(tester, 'w3kexp_01_selected_2');

    await tapActionBar(tester, ChatMultiKeys.export);

    // ③ 确认弹窗出现（Central Wiring onExport 已接线时）。
    final dialogShown = await waitForFinder(
      tester,
      find.byKey(_dialogConfirmKey),
      maxSeconds: 8,
      screenshotName: 'w3kexp_diag_no_confirm_dialog',
    );
    if (!dialogShown) {
      fail(
        'E2EE 会话点导出后 8s 未出现 export_e2ee_confirm 弹窗 —— '
        'Central Wiring onExport 未接线（计划 §12.3）或 W3-J 确认弹窗未集成',
      );
    }
    expect(
      tester.any(find.byKey(_dialogCancelKey)),
      isTrue,
      reason: '确认弹窗应含「取消」动作（export_confirm_cancel）',
    );
    await takeScreenshot(tester, 'w3kexp_02_confirm_dialog');

    // 取消 = 零副作用。
    await tester.tap(find.byKey(_dialogCancelKey).first, warnIfMissed: false);
    await settle(tester, maxSeconds: 3);

    expect(
      tester.any(find.byKey(_dialogConfirmKey)),
      isFalse,
      reason: '取消后确认弹窗应关闭',
    );
    expect(
      tester.any(find.byType(ChatPage)),
      isTrue,
      reason: '取消后应停留在 ChatPage（无路由漂移）',
    );
    expect(
      tester.any(find.byKey(ChatMultiKeys.cancel)),
      isTrue,
      reason: '取消导出后多选应仍激活（零副作用：不动多选状态）',
    );
    expectSelectionCount(tester, 2);
    expect(
      tester.any(find.textContaining('已分享')),
      isFalse,
      reason: '取消路径不得出现分享成功 toast（exportShared）',
    );
    await takeScreenshot(tester, 'w3kexp_03_cancel_zero_side_effect');

    // 退出多选，pop ChatPage，保持会话栈干净。
    await tapActionBar(tester, ChatMultiKeys.cancel);
    await popTopPage(tester, chatPage);
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 8)));
}

/*
运行契约（真机 DEV-01）：同 chat_multi_select_test.dart 头注释配方。

E2EE 前置（DEV-01 修复后）：不依赖部署 policy —— 文本发出后经
EncryptionModeService.debugSet(mode: strictE2ee, initialized: true) 注入
（@visibleForTesting，与 e2ee_c2c_outbound_frame_test.dart 同款），teardown
复位 plaintext。确认弹窗判定/取消/零副作用全走生产代码路径。
gateway fake 注入断言在本地冒烟
test/unit_test/page/chat/integration_smoke/chat_multi_export_smoke_test.dart。
*/
