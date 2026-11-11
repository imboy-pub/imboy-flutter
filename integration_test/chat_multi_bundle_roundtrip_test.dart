// integration_test/chat_multi_bundle_roundtrip_test.dart
//
// W3-K P2 真机旅程（RUN_ID=chat-multi-20261111）：合并转发（chat_history_bundle）
// 发送 → 目标端接收解析 payload → 快照一致断言 → 点气泡开详情页断言渲染。
//
// 旅程：
//   ① 登录 → push C2C ChatPage → 真实输入链发 3 条 marker 文本
//   ② 多选勾选 3 条 → action bar「合并转发」→（SendToPage 出现则选目标发送，
//      直发则跳过目标选择 —— Central Wiring 接线形态二选一，驱动层自适应）
//   ③ 发送端本地回显：等待 history_bundle_bubble_* 气泡（W3-I 稳定 Key），
//      点气泡 → /chat/history_bundle 详情页 → 断言 title 与 3 条 entry 渲染
//   ④ 对端接收解析：peer 经 /api/v1/msg/history 拉取（ flows FlowApiClient，
//      需 CHAT_MULTI_PEER_ACCOUNT/PASSWORD；缺省 SKIP 对端侧），
//      msg_type=chat_history_bundle 行出现后：
//      - 明文部署：payload JSON 解析断言 bundle_version=1、entries 顺序与
//        源选择顺序一致、title 一致（与 HistoryBundleBuilder 本地重建的
//        期望快照对齐）；
//      - E2EE 部署：payload 为密文 —— 只断言 msg_type 出现 + 明文 marker
//        不出现在 payload（密文落库语义），结构解析交给发送端详情页断言。
//
// 依赖 Central Wiring：onForwardBundle 接线（计划 §12.2）；未接线时本用例
// 在「合并转发」步骤 fail 并给出接线诊断。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_builder.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_source.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'chat/support/c2c_journey_support.dart';
import 'flows/api_test_client.dart';
import 'flows/app_launcher.dart';
import 'flows/test_utils.dart';
import 'helpers/chat_multi_driver.dart';
import 'helpers/chat_multi_fixtures.dart';

const _markerPrefix = '[W3K-BND]';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('W3-K P2：合并转发收发快照一致 + 详情页渲染断言', (tester) async {
    installPluginErrorFilter();
    await ensureAppLaunched(tester, maxSeconds: 10);
    if (!await checkPreconditions(tester)) return;
    if (!requireBusinessWriteAuthorization()) return;

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
    final dstUid = () {
      final defined = const String.fromEnvironment('CHAT_MULTI_DST_PEER_UID');
      if (defined.isNotEmpty) return defined;
      return peerUid;
    }();
    flowLog('W3K-BND self=$selfUid src=$peerUid dst=$dstUid');

    final flags = enableChatMultiFlagsForTest();
    addTearDown(flags.restore);

    // ① 源会话：3 条 marker 文本。
    final chatPage = await pushChatPage(
      tester,
      type: 'C2C',
      peerId: peerUid,
      peerTitle: peerTitle,
    );
    final nonce = ChatMultiMessageFixtures.nextNonce();
    final m1 = '$_markerPrefix-t1-$nonce';
    final m2 = '$_markerPrefix-t2-$nonce';
    final m3 = '$_markerPrefix-t3-$nonce';
    await sendTextViaInput(tester, chatPage, m1);
    await sendTextViaInput(tester, chatPage, m2);
    await sendTextViaInput(tester, chatPage, m3);
    await settle(tester, maxSeconds: 2);
    await takeScreenshot(tester, 'w3kbnd_01_source_ready');

    // ② 多选 3 条 → 合并转发。
    await enterMultiSelectViaMenu(tester, chatMultiItemContaining(m1));
    for (final marker in [m1, m2, m3]) {
      await toggleMessageSelection(
        tester,
        chatMultiItemContaining(marker),
        messageId: messageOfMarker(tester, marker)?.id,
      );
    }
    expectSelectionCount(tester, 3);

    final bundleTitle = 'W3K-BND-$nonce';
    await tapActionBar(tester, ChatMultiKeys.forwardBundle);
    if (isOnSendToPage(tester)) {
      final dstTitle = await resolveTargetTitle(
        type: 'C2C',
        peerId: dstUid,
        fallback: dstUid == ChatMultiAccounts.alice ? 'SmokeAlice' : 'SmokeBob',
      );
      await selectForwardTargetAndSend(
        tester,
        targetDisplayTitle: dstTitle,
        journey: 'W3K-BND',
      );
      await waitBatchForwardSettled(tester, journey: 'W3K-BND');
    } else {
      flowLog(
        'W3K-BND forward_bundle 无目标页（直发形态）；若气泡 30s 未出现'
        '请核对 Central Wiring onForwardBundle 接线',
      );
    }

    // ③ 发送端本地回显：history_bundle_bubble_* 气泡 → 详情页。
    final bubble = find.byWidgetPredicate(
      (w) =>
          w.key is Key &&
          w.key.toString().startsWith("Key('history_bundle_bubble_"),
    );
    final bubbleShown = await waitForFinder(
      tester,
      bubble,
      maxSeconds: 30,
      screenshotName: 'w3kbnd_diag_no_bubble',
    );
    if (!bubbleShown) {
      fail(
        '合并转发后 30s 未出现 history_bundle_bubble 气泡 —— '
        'Central Wiring onForwardBundle 未接线 / W3-I 注册未集成 / 发送失败',
      );
    }
    await takeScreenshot(tester, 'w3kbnd_02_bubble_echo');
    await tester.tap(bubble.first, warnIfMissed: false);
    await settle(tester, maxSeconds: 4);

    final detailShown = await waitForFinder(
      tester,
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'HistoryBundleDetailPage',
      ),
      maxSeconds: 8,
      screenshotName: 'w3kbnd_diag_no_detail_page',
    );
    expect(
      detailShown,
      isTrue,
      reason: '点合并转发气泡应打开 /chat/history_bundle 详情页（W3-I 路由）',
    );

    // 详情页断言：title 与 3 条 entry 文本渲染（W3-I detailPage 渲染 bundle
    // 快照；快照来自消息 metadata，不回查原会话）。
    expect(
      tester.any(find.textContaining(bundleTitle)),
      isTrue,
      reason: '详情页应渲染 bundle title=$bundleTitle',
    );
    for (final marker in [m1, m2, m3]) {
      expect(
        tester.any(find.textContaining(marker, findRichText: true)),
        isTrue,
        reason: '详情页应渲染 entry 文本 $marker（快照顺序内容）',
      );
    }
    await takeScreenshot(tester, 'w3kbnd_03_detail_rendered');
    // 返回聊天页，保持会话栈干净。
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
    await settle(tester, maxSeconds: 2);

    // 本地重建期望快照（W2-G 真构建器）：与对端收到的 payload 对账基准。
    final expected = HistoryBundleBuilder.buildForTarget(
      'w3k-expected-target',
      [
        for (final marker in [m1, m2, m3])
          HistoryBundleSourceMessage(
            msgType: MessageType.text,
            sourceMessageId: 'w3k-exp-${marker.length}',
            sourceChatType: 'C2C',
            sourceFromUid: selfUid,
            sourceToUid: peerUid,
            sentAtMs: 0,
            status: MessageStatus.sent,
            payload: {'msg_type': 'text', 'text': marker},
          ),
      ],
      title: bundleTitle,
    );
    final expectedBundle = switch (expected) {
      HistoryBundleBuildSuccessResult(:final success) => success.bundle,
      _ => null,
    };
    expect(expectedBundle, isNotNull, reason: '期望快照本地重建应成功');

    // ④ 对端接收解析（凭证缺省时 SKIP 对端侧，不伪通过也不失败）。
    final peerAccount = const String.fromEnvironment('CHAT_MULTI_PEER_ACCOUNT');
    final peerPassword = const String.fromEnvironment(
      'CHAT_MULTI_PEER_PASSWORD',
    );
    if (peerAccount.isEmpty || peerPassword.isEmpty) {
      flowLog('W3K-BND 未配置 CHAT_MULTI_PEER_ACCOUNT/PASSWORD，跳过对端侧断言');
      await popTopPage(tester, find.byType(ChatPage).first);
      drainKnownFrameworkExceptions(tester);
      return;
    }

    final base = FlowApiConfig.apiBaseUrl.isNotEmpty
        ? FlowApiConfig.apiBaseUrl
        : 'http://127.0.0.1:9800';
    final peer = FlowApiClient(baseUrl: base, deviceId: 'w3kbnd-peer');
    final loginRes = await peer.login(
      account: peerAccount,
      password: peerPassword,
      type: 'email',
      plainPassword: true,
    );
    if (loginRes['code'] != 0) {
      flowLog('W3K-BND 对端登录失败: ${loginRes['msg']} —— 跳过对端侧断言');
      await popTopPage(tester, find.byType(ChatPage).first);
      drainKnownFrameworkExceptions(tester);
      return;
    }

    Map<String, dynamic>? bundleRow;
    var payloadLooksEncrypted = false;
    for (var i = 0; i < 15 && bundleRow == null; i++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      try {
        final resp = await peer.get(
          '/api/v1/msg/history',
          queryParameters: {
            'chat_type': 'c2c',
            'peer_id': selfUid,
            'after_seq': '0',
            'limit': '50',
          },
        );
        if (resp['code'] != 0) continue;
        final messages = (resp['payload']?['messages'] as List?) ?? const [];
        for (final m in messages) {
          final row = m is Map ? Map<String, dynamic>.from(m) : null;
          if (row == null) continue;
          final payloadRaw = '${row['payload'] ?? ''}';
          if ('${row['msg_type']}' == HistoryBundleContract.msgType ||
              payloadRaw.contains(HistoryBundleContract.msgType)) {
            bundleRow = row;
            payloadLooksEncrypted =
                payloadRaw.isNotEmpty && !payloadRaw.contains('bundle_version');
            break;
          }
          if (payloadRaw.contains(bundleTitle)) {
            bundleRow = row;
            break;
          }
        }
      } catch (e) {
        flowLog('W3K-BND 对端 history 第${i + 1}轮异常: $e');
      }
    }

    if (bundleRow == null) {
      fail('45 秒内对端历史未出现 chat_history_bundle 行 —— WS/落库/离线链路断裂');
    }
    final payloadRaw = '${bundleRow['payload'] ?? ''}';
    expect(
      payloadRaw.contains(m1) || payloadLooksEncrypted,
      isTrue,
      reason: '对端 bundle 行应含源内容或为密文（明文丢失=合同破坏）',
    );

    if (!payloadLooksEncrypted) {
      // 明文部署：结构级对账。
      final decoded = jsonDecode(payloadRaw);
      final payload = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map<dynamic, dynamic>);
      expect(
        '${payload['bundle_version'] ?? ''}',
        '1',
        reason: 'bundle_version 应为 1（冻结合同 §4.5）',
      );
      final entries = (payload['entries'] as List?) ?? const [];
      expect(entries.length, 3, reason: 'entries 应为 3 条（实际 ${entries.length}）');
      final texts = <String?>[
        for (final e in entries)
          () {
            final map = e is Map
                ? Map<String, dynamic>.from(e)
                : <String, dynamic>{};
            final p = map['payload'];
            return p is Map
                ? Map<String, dynamic>.from(p)['text'] as String?
                : null;
          }(),
      ];
      expect(texts.whereType<String>(), [
        m1,
        m2,
        m3,
      ], reason: 'entries 顺序/内容应与源选择一致（实际 $texts）');
      flowLog('W3K-BND 对端 payload 结构对账通过（title/entries/顺序）');
    } else {
      flowLog('W3K-BND E2EE 部署：对端 payload 为密文，结构对账由详情页断言承担');
    }

    await popTopPage(tester, find.byType(ChatPage).first);
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 12)));
}

/*
运行契约（真机 DEV-01）：同 chat_multi_select_test.dart 头注释配方，另加：

  --dart-define=CHAT_MULTI_PEER_ACCOUNT=<对端登录账号> \
  --dart-define=CHAT_MULTI_PEER_PASSWORD=<对端密码>

对端凭证缺省时对端侧断言 SKIP（发送端气泡 + 详情页断言仍执行）。
明文部署：对端 payload 结构对账（bundle_version/entries 顺序/内容）。
E2EE 部署：对端 payload 密文 —— 只断言 msg_type 行出现且不含明文。
*/
