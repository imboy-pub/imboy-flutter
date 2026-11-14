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
//   ④ 对端历史：发送前用 FlowApiClient 记录 safe_head/conv_key，发送后按
//      本轮气泡 message.id == history.msg_id 且 conv_seq > 基线对账。
//      缺 CHAT_MULTI_PEER_ACCOUNT/PASSWORD 或 API_BASE_URL 时整条 P2
//      在写入前 SKIP；已配置但登录/基线失败必须 fail。
//      - 明文部署：payload JSON 解析断言 bundle_version=1、entries 顺序与
//        源选择顺序一致、title 与发送端气泡读到的真实生产 title 一致；
//      - E2EE 部署：只检查本轮身份/公开信封与无明文泄漏，不解析密文。
//        历史可见不代表接收设备已经解密/渲染，设备验收另计。
//
// 依赖 Central Wiring：onForwardBundle 接线（计划 §12.2）；未接线时本用例
// 在「合并转发」步骤 fail 并给出接线诊断。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/component/chat/message_history_bundle_builder.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'chat/support/c2c_journey_support.dart';
import 'flows/api_test_client.dart';
import 'flows/app_launcher.dart';
import 'flows/test_utils.dart';
import 'helpers/chat_multi_bundle_history.dart';
import 'helpers/chat_multi_driver.dart';
import 'helpers/chat_multi_fixtures.dart';
import 'helpers/chat_multi_image_fixture.dart';

const _markerPrefix = '[W3K-BND]';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('W3-K P2：合并转发收发快照一致 + 详情页渲染断言', (tester) async {
    const peerAccount = String.fromEnvironment('CHAT_MULTI_PEER_ACCOUNT');
    const peerPassword = String.fromEnvironment('CHAT_MULTI_PEER_PASSWORD');
    final base = FlowApiConfig.apiBaseUrl;
    if (peerAccount.isEmpty || peerPassword.isEmpty || base.isEmpty) {
      markTestSkipped(
        'ENV_MISSING: P2 需要 CHAT_MULTI_PEER_ACCOUNT/PASSWORD + API_BASE_URL；'
        'PEER_NOT_VERIFIED，不执行本轮消息/附件写入',
      );
      return;
    }
    const expectedMode = String.fromEnvironment('CHAT_MULTI_EXPECT_E2EE');
    if (expectedMode.isNotEmpty &&
        expectedMode != 'true' &&
        expectedMode != 'false') {
      fail('CHAT_MULTI_EXPECT_E2EE 必须是 true/false 或缺省');
    }
    if (!requireBusinessWriteAuthorization()) return;
    installPluginErrorFilter();
    ChatMultiDriverRunStats.reset();
    await ensureAppLaunched(tester, maxSeconds: 10);
    // G6-11：后端探活/登录失败 = 环境契约破坏，fail 而非静默 SKIP。
    if (!await checkPreconditions(tester, failOnEnvMissing: true)) return;

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

    // 对端登录/身份/基线必须先于本轮所有发送和上传；失败不得降级为通过。
    final peer = FlowApiClient(baseUrl: base, deviceId: 'w3kbnd-peer');
    addTearDown(peer.close);
    final loginRes = await peer.login(
      account: peerAccount,
      password: peerPassword,
      type: 'email',
      plainPassword: true,
    );
    expect(loginRes['code'], 0, reason: 'P2 对端登录失败，未取得接收证据');
    expect(peer.currentUid, dstUid, reason: 'P2 对端登录账号必须是本轮目标账号');
    final history = ChatMultiBundleHistory(
      senderUid: selfUid,
      recipientUid: dstUid,
      fetchPage: (query) =>
          peer.get('/api/v1/msg/history', queryParameters: query),
    );
    await history.captureBaseline();
    flowLog('W3K-BND history baseline=${history.baselineSeq}');

    await requireChatMultiServerFlags();

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

    // R2-G6-L4 收口：本轮 bundle 增加一条真实上传的图片 entry，激活详情页
    // 缩略图契约断言（G2×G6：ValueKey bundle_detail_thumb_<index>）——
    // 此前纯文本旅程该断言恒门控跳过（死断言）。镜像 select 旅程的
    // 生产上传形态（presign→PUT→confirm，process:false）。
    final ctx = tester.element(find.byType(ChatPage).first);
    final container = ProviderScope.containerOf(ctx);
    final notifier = container.read(chatProvider.notifier);
    final imgBase = DateTime.now();
    final imgId = 'w3kbndimg$nonce';
    final imgObjectKey = await ChatMultiImageFixture.uploadPng(
      peerId: peerUid,
      type: 'C2C',
    );
    flowLog('W3K-BND fixture image uploaded: $imgObjectKey');
    final img = ChatMultiMessageFixtures.image(
      id: imgId,
      authorId: selfUid,
      createdAt: imgBase.add(const Duration(milliseconds: 5)),
      remoteUri: imgObjectKey,
      width: 8,
      height: 8,
      size: ChatMultiImageFixture.pngBytes.length,
      peerId: peerUid,
      runNonce: '$nonce',
    );
    final imgOk = await notifier.addMessage(
      selfUid,
      peerUid,
      '',
      peerTitle,
      'C2C',
      img,
    );
    expect(imgOk, isTrue, reason: 'image fixture 经 provider 发送应成功');
    await notifier.chatService?.insertMessage(
      img,
      index: notifier.chatService?.messages.length ?? 0,
    );
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
    // 图片行无文本 marker：按 messageId 定位（driver 生产通道/checkbox key
    // 双通道，select 旅程同款）。
    await toggleMessageSelection(
      tester,
      find.byType(ChatPage),
      messageId: imgId,
      journey: 'W3K-BND',
    );
    expectSelectionCount(tester, 4);

    // G6-3：tapViaNewGesture + 效果校验重试。效果 = SendToPage 出现（目标
    // 选择形态）/ 多选 action bar 消失（直发形态已受理并退出多选）/ 本轮
    // bundle 气泡回显（回环直发形态）—— 三者其一即证明 tap 已注册。
    await tapActionBar(
      tester,
      ChatMultiKeys.forward,
      journey: 'forward-options',
      effectCheck: () => tester.any(find.byKey(ChatMultiKeys.forwardBundle)),
    );
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
    expect(currentBubble, findsOneWidget, reason: '本轮 marker 必须唯一定位一个 bundle');
    final currentMessage = tester
        .widget<HistoryBundleMessageBuilder>(currentBubble.first)
        .message;
    final expectedMessageId = currentMessage.id;
    expect(expectedMessageId.isNotEmpty, isTrue);
    expect(currentMessage.authorId, selfUid);
    final expectedTitle = currentMessage.metadata?['title']?.toString() ?? '';
    // 缩略图契约的 bubble 元数据必须在 **tap 之前** 读取：详情页打开后
    // 聊天页气泡已不在树上，回头读 currentBubble 会 StateError（W5-D r1
    // 实证：详情页断言全过后在 :256 处 No element → 整旅程挂死）。
    final bundleMetaBeforeTap = Map<String, dynamic>.from(
      currentMessage.metadata ?? const <String, dynamic>{},
    );
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
    final bundleMeta = bundleMetaBeforeTap;
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

    // ④ 只有本轮精确 ID + 发送前基线之后的行可验收；无密文候选兜底。
    final bundleRow = await history.waitForBundle(messageId: expectedMessageId);
    final payload = bundleHistoryPlaintext(
      bundleRow,
      markers: [m1, m2, m3],
      expectEncrypted: expectedMode.isEmpty ? null : expectedMode == 'true',
    );

    if (payload != null) {
      // 明文部署：同时支持当前 history 的 JSON 对象和旧部署的 JSON 字符串。
      expect(
        '${payload['bundle_version'] ?? ''}',
        '${HistoryBundleContract.bundleVersion}',
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
      expect(
        entries.length,
        4,
        reason: 'entries 应为 4 条（3 文本 + 1 图片，实际 ${entries.length}）',
      );
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
      expect(
        entries,
        historyBundleEntries(bundleMetaBeforeTap),
        reason: '4 条 entries 必须与发送端快照完整一致（含图片附件字段）',
      );
      flowLog('W3K-BND 对端 payload 结构对账通过（title/entries/顺序）');
    } else {
      flowLog('W3K-BND E2EE 信封/无明文检查通过；接收设备解密渲染尚未验证');
    }

    flowLog(
      'W3K-BND PEER_HISTORY_VERIFIED msg_id=$expectedMessageId '
      'conv_seq=${bundleRow['conv_seq']} baseline=${history.baselineSeq} '
      'mode=${payload == null ? 'e2ee' : 'plaintext'}',
    );

    await popTopPage(tester, find.byType(ChatPage).first);
    finishChatMultiJourney('W3K-BND');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 12)));
}

/*
运行契约（真机 DEV-01）：同 chat_multi_select_test.dart 头注释配方，另加：

  --dart-define=CHAT_MULTI_PEER_ACCOUNT=<对端登录账号> \
  --dart-define=CHAT_MULTI_PEER_PASSWORD=<对端密码>

对端凭证/API_BASE_URL 缺省：写入前整条 P2 SKIP（不是跨端 PASS）。
已配置却登录失败、目标 UID 不符或历史合同异常：FAIL。
发送前取 safe_head；发送后仅认本轮气泡 msg_id + 更大的 conv_seq。
明文部署：对端 payload 结构对账（bundle_version/title/4 entries 顺序/内容）。
E2EE 部署：只查本轮身份、信封与无明文；不解密、不代表对端设备渲染。
验收指定部署时加 --dart-define=CHAT_MULTI_EXPECT_E2EE=true（明文用 false），
防止预期 E2EE 的环境意外降级明文仍通过；缺省时只记录实际观察到的模式。
真实执行会写入消息和附件，仍须单独批准目标环境/清理范围。
*/
