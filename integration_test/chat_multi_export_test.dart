// integration_test/chat_multi_export_test.dart
//
// W3-K P3 真机旅程（RUN_ID=chat-multi-20261111）：E2EE 导出确认 dialog
// 「取消 = 零副作用」。
//
// 旅程：
//   ① 登录 → push C2C ChatPage → 真实输入链发 2 条 marker 文本
//   ② 多选勾选 2 条 → action bar「导出」
//   ③ strict E2EE 部署：W3-J E2EE 确认弹窗（export_e2ee_confirm）出现
//      → 点「取消」（export_confirm_cancel）→ 弹窗关闭且零副作用断言：
//      - 多选仍激活、已选计数不变（2）
//      - 仍在 ChatPage（无路由漂移）
//      - 无「已分享」成功 toast（exportShared 文案不出现）
//   ④ 非 strict 部署：SKIP（E2EE 确认弹窗场景只存在于加密会话；
//      ENV_MISSING 口径，不伪通过）。
//
//      DEV-01（chat-multi-20261111）决策：保持 ENV 门控 SKIP —— strict E2EE
//      启用需要 product-feature-manifest + 后端重建 + 对端密钥引导，且 strict
//      模式会拒绝明文 C2C/C2G 写入、破坏明文种子用例（risk_if_adopted）；
//      归档决策见 receipts/fixes/strict-e2ee-decision.json
//      （NOT_ADOPTED / DOCUMENTED_SKIP_ACCEPTED）。补偿证据：EXP-02/03 本地
//      widget 冒烟 + COMP-01 fixture 测试。
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

    // E2EE 前置：非 strict 部署下加密会话不存在，弹窗场景不可达（DEV-01
    // 决策保持 ENV 门控 SKIP，见文件头注释与 strict-e2ee-decision receipt；
    // 不用测试注入伪通过）。
    var policyReady = false;
    for (var i = 0; i < 10 && !policyReady; i++) {
      policyReady = EncryptionModeService.isInitialized;
      if (!policyReady) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    if (!policyReady) {
      markTestSkipped('加密策略未就绪（EncryptionModeService 未初始化）');
      return;
    }
    if (EncryptionModeService.current != EncryptionMode.strictE2ee) {
      markTestSkipped(
        '当前部署非 strict E2EE（current=${EncryptionModeService.current}），'
        'E2EE 导出确认弹窗场景只存在于加密会话'
        '（决策归档：receipts/fixes/strict-e2ee-decision.json）',
      );
      return;
    }

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

E2EE 前置：strict E2EE 部署（EncryptionModeService.current == strictE2ee），
否则用例 SKIP —— E2EE 导出确认弹窗只存在于加密会话（W3-J 判定）。DEV-01
（chat-multi-20261111）明确保持该 ENV 门控 SKIP，不做测试注入伪通过
（决策归档：receipts/fixes/strict-e2ee-decision.json，
DOCUMENTED_SKIP_ACCEPTED）。
gateway fake 注入断言在本地冒烟
test/unit_test/page/chat/integration_smoke/chat_multi_export_smoke_test.dart。
*/
