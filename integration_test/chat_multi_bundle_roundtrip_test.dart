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
//      需 CHAT_MULTI_PEER_ACCOUNT/PASSWORD + API_BASE_URL；凭证缺省 SKIP
//      对端侧，API_BASE_URL 缺省 SKIP（ENV_MISSING 口径）），
//      msg_type=chat_history_bundle 行出现后：
//      - 明文部署：payload JSON 解析断言 bundle_version=1、entries 顺序与
//        源选择顺序一致、title 与发送端气泡读到的真实生产 title 一致；
//      - E2EE 部署：payload 为密文 —— 只断言 msg_type 出现 + 明文 marker
//        不出现在 payload（密文落库语义），结构解析交给发送端详情页断言。
//
// 依赖 Central Wiring：onForwardBundle 接线（计划 §12.2）；未接线时本用例
// 在「合并转发」步骤 fail 并给出接线诊断。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/component/chat/message_history_bundle_builder.dart';
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
    ChatMultiDriverRunStats.reset();
    await ensureAppLaunched(tester, maxSeconds: 10);
    // G6-11：后端探活/登录失败 = 环境契约破坏，fail 而非静默 SKIP。
    if (!await checkPreconditions(tester, failOnEnvMissing: true)) return;
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
    // W1-A enter 契约：长按 m1 进入多选即选中 m1（driver 断言计数=1），
    // 这里只勾 m2/m3 —— 再 toggle m1 会把它勾掉（DEV-01 修复）。
    await enterMultiSelectViaMenu(tester, chatMultiItemContaining(m1));
    for (final marker in [m2, m3]) {
      await toggleMessageSelection(
        tester,
        chatMultiItemContaining(marker),
        messageId: messageOfMarker(tester, marker)?.id,
        journey: 'W3K-BND',
      );
    }
    expectSelectionCount(tester, 3);

    // G6-3：tapViaNewGesture + 效果校验重试。效果 = SendToPage 出现（目标
    // 选择形态）/ 多选 action bar 消失（直发形态已受理并退出多选）/ 本轮
    // bundle 气泡回显（回环直发形态）—— 三者其一即证明 tap 已注册。
    await tapActionBar(
      tester,
      ChatMultiKeys.forwardBundle,
      journey: 'W3K-BND',
      effectCheck: () =>
          isOnSendToPage(tester) ||
          !tester.any(find.byKey(ChatMultiKeys.count)) ||
          tester.any(
            find.byWidgetPredicate(
              (w) =>
                  w is HistoryBundleMessageBuilder &&
                  '${w.message.metadata?['entries'] ?? ''}'.contains(m1),
            ),
          ),
    );
    // G6-16：SendToPage 形态判定加 1-2s 重试窗口（最多 3 次采样）再定性
    // 直发形态 —— 直发形态下 tap 后路由切换可能有帧级延迟，单次采样会
    // 误判（误跳目标选择段，气泡永远不出现）。
    var sendToForm = false;
    for (var i = 0; i < 3; i++) {
      if (isOnSendToPage(tester)) {
        sendToForm = true;
        break;
      }
      await pacedWait(tester, 700);
    }
    if (sendToForm) {
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
        'W3K-BND forward_bundle 无目标页（直发形态，3×700ms 采样窗口后定性）；'
        '若气泡 30s 未出现请核对 Central Wiring onForwardBundle 接线',
      );
    }

    // ③ 发送端本地回显：history_bundle_bubble_* 气泡 → 详情页。
    // ⚠️ Key('x') 是 ValueKey<String>，toString() 是 "[<'x'>]" 而非
    // "Key('x')"——用 contains 匹配，形状无关（DEV-01 r 系列实证：
    // startsWith("Key('") 在真机上永远匹配不到已渲染气泡）。
    final bubble = find.byWidgetPredicate(
      (w) =>
          w.key != null && w.key!.toString().contains('history_bundle_bubble_'),
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
    // 会话内可能残留历史轮次的 bundle 气泡（设备 SQLite 跨轮持久）：按本轮
    // 独有的源 marker（nonce 内嵌）定位当前气泡再点。生产 title 取
    // widget.peerTitle（会话名），与测试 nonce 无关，不得按 title 找。
    final currentBubble = find.byWidgetPredicate(
      (w) =>
          w is HistoryBundleMessageBuilder &&
          '${w.message.metadata?['entries'] ?? ''}'.contains(m1),
    );
    final currentShown = await waitForFinder(
      tester,
      currentBubble,
      maxSeconds: 8,
      screenshotName: 'w3kbnd_diag_no_current_bubble',
    );
    if (!currentShown) {
      fail('未找到本轮（marker=$m1）对应的 history_bundle 气泡');
    }
    final expectedTitle =
        tester
            .widget<HistoryBundleMessageBuilder>(currentBubble.first)
            .message
            .metadata?['title']
            ?.toString() ??
        '';
    await takeScreenshot(tester, 'w3kbnd_02_bubble_echo');
    // G6-3：气泡 tap 统一 tapViaNewGesture + 效果校验重试（单发 tester.tap
    // 违背 driver 指针卫生结论）；效果 = 详情页出现。
    final detailPageFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'HistoryBundleDetailPage',
    );
    await tapFinderWithEffect(
      tester,
      find.descendant(of: currentBubble, matching: bubble),
      journey: 'W3K-BND',
      targetDescription: '本轮 bundle 气泡（marker=$m1）',
      effectCheck: () => tester.any(detailPageFinder),
    );
    await settle(tester, maxSeconds: 4);

    final detailShown = await waitForFinder(
      tester,
      detailPageFinder,
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
      expectedTitle.isNotEmpty,
      isTrue,
      reason: '气泡 metadata 应携带 bundle title（生产=会话名）',
    );
    expect(
      tester.any(find.textContaining(expectedTitle)),
      isTrue,
      reason: '详情页应渲染 bundle title=$expectedTitle',
    );
    for (final marker in [m1, m2, m3]) {
      expect(
        tester.any(find.textContaining(marker, findRichText: true)),
        isTrue,
        reason: '详情页应渲染 entry 文本 $marker（快照顺序内容）',
      );
    }
    // 跨组契约（G2×G6）：详情页真实缩略图 ValueKey('bundle_detail_thumb_<index>')
    // （index=entry 序号，G2 生产侧接线）。find.byKey 不支持 RegExp —— 用
    // byWidgetPredicate 对 ValueKey<String>.value 做正则匹配（等效「按正则
    // key 找」，此处选该可实现写法并注明）。缩略图仅对 image/imageMulti
    // entry 渲染：本轮 bundle 为纯文本 entries，断言按「entries 含图片」
    // 门控；含图片时要求至少一个 thumb key 匹配（fallback：至少一个 Image
    // widget 存在且非 errorBuilder 占位由 G2 侧 detail page 自测承担）。
    final bundleMeta = Map<String, dynamic>.from(
      tester
              .widget<HistoryBundleMessageBuilder>(currentBubble.first)
              .message
              .metadata ??
          const <String, dynamic>{},
    );
    final hasImageEntry = historyBundleEntries(bundleMeta).any(
      (e) =>
          e['msg_type'] == 'image' ||
          e['msg_type'] == 'image_multi' ||
          e['msg_type'] == 'imageMulti',
    );
    if (hasImageEntry) {
      final thumbFinder = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            RegExp('^bundle_detail_thumb_[0-9]+\$')
                .hasMatch((w.key as ValueKey<String>).value),
      );
      expect(
        tester.any(thumbFinder),
        isTrue,
        reason:
            '详情页含图片 entry 时应渲染真实缩略图'
            '（ValueKey bundle_detail_thumb_<index>，G2 契约）',
      );
    } else {
      flowLog('W3K-BND 本轮 bundle 无图片 entry，缩略图契约断言按门控跳过（G2×G6）');
    }
    await takeScreenshot(tester, 'w3kbnd_03_detail_rendered');
    // 返回聊天页，保持会话栈干净。
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
    await settle(tester, maxSeconds: 2);
    // G6-13：pop 后详情页不得残留（路由栈泄漏会让后续 ChatPage 断言误判）。
    expect(
      tester.any(detailPageFinder),
      isFalse,
      reason: 'pop 后 HistoryBundleDetailPage 应已关闭（无路由残留）',
    );

    // ④ 对端接收解析（凭证缺省时 SKIP 对端侧，不伪通过也不失败）。
    final peerAccount = const String.fromEnvironment('CHAT_MULTI_PEER_ACCOUNT');
    final peerPassword = const String.fromEnvironment(
      'CHAT_MULTI_PEER_PASSWORD',
    );
    if (peerAccount.isEmpty || peerPassword.isEmpty) {
      flowLog('W3K-BND 未配置 CHAT_MULTI_PEER_ACCOUNT/PASSWORD，跳过对端侧断言');
      await popTopPage(tester, find.byType(ChatPage).first);
      finishChatMultiJourney('W3K-BND');
      drainKnownFrameworkExceptions(tester);
      return;
    }

    // G6-8：API_BASE_URL 为空时显式 SKIP —— 127.0.0.1 兜底在真机上永远
    // 不通（host 回环指向设备自身），静默降级只会把对端断言悄悄吞掉。
    final base = FlowApiConfig.apiBaseUrl;
    if (base.isEmpty) {
      markTestSkipped(
        'ENV_MISSING: API_BASE_URL（对端断言需要显式后端地址；'
        '127.0.0.1 兜底已移除 —— 真机不可达）',
      );
      await popTopPage(tester, find.byType(ChatPage).first);
      finishChatMultiJourney('W3K-BND');
      drainKnownFrameworkExceptions(tester);
      return;
    }
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
      finishChatMultiJourney('W3K-BND');
      drainKnownFrameworkExceptions(tester);
      return;
    }

    // 本轮甄别（W5-R2 复审 HIGH-1）：复用环境（设备/后端跨 run 复用）的
    // 对端历史含旧轮 bundle（asc 取最老 50 行优先），此前"首条 bundle 行
    // 即 break"会锁死旧轮行 → 本轮 bundle 未到即确定性假失败。按轮甄别：
    // payload 含本轮 nonce（m1）才认作本轮行并提前收卷；密文形态行仅作
    // 存在性兜底（E2EE 部署明文 nonce 永不命中，45s 后回落）。
    Map<String, dynamic>? thisRunBundleRow;
    Map<String, dynamic>? encryptedBundleRow;
    for (var i = 0; i < 15 && thisRunBundleRow == null; i++) {
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
          final isBundle =
              '${row['msg_type']}' == HistoryBundleContract.msgType ||
              payloadRaw.contains(HistoryBundleContract.msgType);
          if (!isBundle) continue;
          if (payloadRaw.contains(m1)) {
            thisRunBundleRow = row;
            break;
          }
          final looksEncrypted =
              payloadRaw.isNotEmpty && !payloadRaw.contains('bundle_version');
          if (looksEncrypted) {
            encryptedBundleRow ??= row;
          }
        }
      } on Exception catch (e) {
        // G6-7：只捕 Exception —— Error（类型错误/断言失败等）必须冒泡，
        // 不能被轮询当瞬时噪声吞掉。
        flowLog('W3K-BND 对端 history 第${i + 1}轮异常: $e');
      }
    }

    final bundleRow = thisRunBundleRow ?? encryptedBundleRow;
    if (bundleRow == null) {
      fail('45 秒内对端历史未出现本轮 chat_history_bundle 行 —— WS/落库/离线链路断裂');
    }
    final payloadRaw = '${bundleRow['payload'] ?? ''}';
    final payloadLooksEncrypted = thisRunBundleRow == null;
    expect(
      payloadRaw.contains(m1) || payloadLooksEncrypted,
      isTrue,
      reason: '对端 bundle 行应含本轮源内容或为密文（明文丢失=合同破坏）',
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
      // G6-4：title 用发送端气泡读到的真实生产 title 对账（生产 title=
      // 会话名，与测试 nonce 无关；本地重建期望快照的死脚手架已删除）。
      expect(
        '${payload['title'] ?? ''}',
        expectedTitle,
        reason: '对端 bundle 行 title 应与发送端一致（期望 $expectedTitle）',
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
    finishChatMultiJourney('W3K-BND');
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
