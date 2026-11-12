// integration_test/chat_multi_forward_c2g_test.dart
//
// W3-K P1 真机旅程（RUN_ID=chat-multi-20261111）：多选逐条转发 C2C → C2G。
//
// 旅程：
//   ① 登录 → push 群 ChatPage（C2G）→ 真实输入链发预热文本
//      （在本地建立群会话行，SendToPage 目标列表可见）→ pop
//   ② push C2C ChatPage → 真实输入链发 2 条 marker 文本
//   ③ 长按进多选 → 勾选 2 条 → 计数断言 →「逐条转发」
//   ④ SendToPage → 搜索群名 → 选目标 → 发送 → 批量完成
//   ⑤ 打开群 ChatPage：2 条副本按源顺序（旧→新）落位，peer_id 重写为 gid，
//      并进入正向已发送态（C2G 出网链真实执行）
//
// 前置：CHAT_MULTI_C2G_GID 指向的群存在且登录账号为成员（合成库群；
// 缺失时 SKIP —— ENV_MISSING 口径，不伪通过）。
//
// 运行契约见文件尾注释；key 约定同 chat_multi_select_test.dart。

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:integration_test/integration_test.dart';

import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'chat/support/c2c_journey_support.dart';
import 'flows/app_launcher.dart';
import 'flows/test_utils.dart';
import 'helpers/chat_multi_driver.dart';
import 'helpers/chat_multi_fixtures.dart';

const _markerPrefix = '[W3K-C2G]';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('W3-K P1：C2C 多选逐条转发 → C2G 目标顺序内容断言', (tester) async {
    installPluginErrorFilter();
    ChatMultiDriverRunStats.reset();
    await ensureAppLaunched(tester, maxSeconds: 10);
    // G6-11：后端探活/登录失败 = 环境契约破坏，fail 而非静默 SKIP。
    if (!await checkPreconditions(tester, failOnEnvMissing: true)) return;
    if (!requireBusinessWriteAuthorization()) return;

    final gid = const String.fromEnvironment('CHAT_MULTI_C2G_GID');
    if (gid.isEmpty) {
      markTestSkipped(
        '需显式 CHAT_MULTI_C2G_GID（合成群，登录账号须为成员）；'
        'ENV_MISSING —— 前置 fixture 见 receipt w3-k handoff',
      );
      return;
    }
    final gidTitle = () {
      final defined = const String.fromEnvironment('CHAT_MULTI_C2G_TITLE');
      if (defined.isNotEmpty) return defined;
      return 'W3K-C2G-$gid';
    }();

    final selfUid = UserRepoLocal.to.currentUid;
    final srcPeerUid = () {
      final defined = const String.fromEnvironment('CHAT_MULTI_SRC_PEER_UID');
      if (defined.isNotEmpty) return defined;
      return selfUid == ChatMultiAccounts.bob
          ? ChatMultiAccounts.alice
          : ChatMultiAccounts.bob;
    }();
    final srcPeerTitle = () {
      final defined = const String.fromEnvironment('CHAT_MULTI_SRC_PEER_TITLE');
      if (defined.isNotEmpty) return defined;
      return srcPeerUid == ChatMultiAccounts.alice ? 'SmokeAlice' : 'SmokeBob';
    }();
    flowLog('W3K-C2G self=$selfUid src=$srcPeerUid gid=$gid');

    final flags = enableChatMultiFlagsForTest();
    addTearDown(flags.restore);

    // ① 预热群会话：push 群 ChatPage 发一条真实文本，建立本地群会话行。
    final groupPage = await pushChatPage(
      tester,
      type: 'C2G',
      peerId: gid,
      peerTitle: gidTitle,
    );
    final warmup =
        '$_markerPrefix-warmup-${ChatMultiMessageFixtures.nextNonce()}';
    await sendTextViaInput(tester, groupPage, warmup);
    await popTopPage(tester, groupPage);

    // ② 源 C2C 会话：2 条 marker 文本。
    final chatPage = await pushChatPage(
      tester,
      type: 'C2C',
      peerId: srcPeerUid,
      peerTitle: srcPeerTitle,
    );
    final nonce = ChatMultiMessageFixtures.nextNonce();
    final nonceStr = '$nonce';
    final m1 = '$_markerPrefix-t1-$nonce';
    final m2 = '$_markerPrefix-t2-$nonce';
    await sendTextViaInput(tester, chatPage, m1);
    await sendTextViaInput(tester, chatPage, m2);
    await settle(tester, maxSeconds: 2);
    await takeScreenshot(tester, 'w3kc2g_01_source_ready');

    // ③ 多选 + 勾选 2 条 + 计数。
    // W1-A enter 契约：长按 m1 进入多选即选中 m1（driver 断言计数=1），
    // 这里只勾 m2 —— 再 toggle m1 会把它勾掉（DEV-01 修复）。
    await enterMultiSelectViaMenu(tester, chatMultiItemContaining(m1));
    await toggleMessageSelection(
      tester,
      chatMultiItemContaining(m2),
      messageId: messageOfMarker(tester, m2)?.id,
      journey: 'W3K-C2G',
    );
    expectSelectionCount(tester, 2);

    // ④ 逐条转发到群（G6-3：tapViaNewGesture + 效果校验重试）。
    await tapActionBar(
      tester,
      ChatMultiKeys.forwardEach,
      journey: 'W3K-C2G',
      effectCheck: () => isOnSendToPage(tester),
    );
    final groupTitle = await resolveTargetTitle(
      type: 'C2G',
      peerId: gid,
      fallback: gidTitle,
    );
    await selectForwardTargetAndSend(
      tester,
      targetDisplayTitle: groupTitle,
      journey: 'W3K-C2G',
    );
    await waitBatchForwardSettled(tester, journey: 'W3K-C2G');
    await takeScreenshot(tester, 'w3kc2g_02_forward_done');

    // ⑤ 群会话断言：pop 源会话后重新打开群页（重新从 DB 加载真相源）。
    await popTopPage(tester, find.byType(ChatPage).first);
    final targetPage = await pushChatPage(
      tester,
      type: 'C2G',
      peerId: gid,
      peerTitle: groupTitle,
    );
    await settle(tester, maxSeconds: 3);

    // G6-1：副本识别改 nonce 内容过滤 —— 文本副本 text 含本轮 nonce
    // （墙钟过滤 createdAt.isAfter(forwardStart) 在设备/服务端时钟微差下
    // 环境性 flaky；nonce 每轮唯一，旧轮残留/本轮 warmup 均不会误命中）。
    final copies = <core.Message>[];
    for (var i = 0; i < 40; i++) {
      final items = tester
          .widgetList<ChatMessageItem>(find.byType(ChatMessageItem))
          .map((w) => w.message)
          .toList();
      final fresh = items
          .where((m) => m is core.TextMessage && m.text.contains(nonceStr))
          .toList();
      if (fresh.length >= 2) {
        copies
          ..clear()
          ..addAll(fresh);
        break;
      }
      copies
        ..clear()
        ..addAll(fresh);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(copies.length, 2, reason: '群会话应恰有 2 条转发副本（实际 ${copies.length}）');

    // chatService.messages 的存储序是「新→旧」（reverse 列表 index 0=最新），
    // 合同 §4.3 考察的是副本 createdAt 旧→新 —— 排序后按显式文本断言
    // （G6-10：kindOf 兜底会把任何非 m1 文本映射成 m2，掩盖内容回归）。
    final orderedCopies = copies.toList()
      ..sort(
        (a, b) => (a.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
          b.createdAt?.millisecondsSinceEpoch ?? 0,
        ),
      );
    final orderedTexts = orderedCopies
        .whereType<core.TextMessage>()
        .map((m) => m.text)
        .toList();
    expect(orderedTexts, [
      m1,
      m2,
    ], reason: '群内副本文本与顺序应与源一致（旧→新，冻结合同 §4.3；实际 $orderedTexts）');
    for (final m in copies) {
      expect(
        '${m.metadata?['peer_id'] ?? ''}',
        gid,
        reason: 'C2G 副本 peer_id 应重写为群 gid（msgId=${m.id}）',
      );
    }

    // 出网语义：副本应进入正向已发送态（C2G WS 提交真实执行）。
    final settled = await _waitCopiesSettled(tester, copies, maxSeconds: 30);
    expect(
      settled,
      isTrue,
      reason:
          '群内副本 30s 内未进入正向已发送态 —— C2G 出网链失败'
          '（E2EE 群需 Megolm 会话就绪）',
    );
    await takeScreenshot(tester, 'w3kc2g_03_group_asserted');

    await popTopPage(tester, targetPage);
    finishChatMultiJourney('W3K-C2G');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 10)));
}

Future<bool> _waitCopiesSettled(
  WidgetTester tester,
  List<core.Message> copies, {
  int maxSeconds = 30,
}) async {
  bool allSettled() {
    final items = tester
        .widgetList<ChatMessageItem>(find.byType(ChatMessageItem))
        .map((w) => w.message)
        .toList();
    final ids = copies.map((m) => m.id).toSet();
    final rows = items.where((m) => ids.contains(m.id));
    if (rows.length != copies.length) return false;
    return rows.every(
      (m) =>
          m.status == core.MessageStatus.sent ||
          m.status == core.MessageStatus.delivered ||
          m.status == core.MessageStatus.seen,
    );
  }

  for (var i = 0; i < maxSeconds; i++) {
    if (allSettled()) return true;
    await tester.pump(const Duration(seconds: 1));
  }
  return allSettled();
}

/*
运行契约（真机 DEV-01）：同 chat_multi_select_test.dart 头注释配方，另加：

  --dart-define=CHAT_MULTI_C2G_GID=<合成群 gid> \
  [--dart-define=CHAT_MULTI_C2G_TITLE=<群名>]

前置：合成群存在且登录账号为成员（合成库 fixture；缺 gid 时用例 SKIP =
ENV_MISSING 口径）。E2EE 群需 Megolm 会话就绪（群内先有消息历史）。
*/
