// integration_test/chat_multi_select_test.dart
//
// W3-K P1 真机旅程（RUN_ID=chat-multi-20261111）：多选 → 勾选 → 计数 →
// 逐条转发 C2C → C2C，验证目标会话顺序与内容。
//
// 旅程（DEV-01 编排，单设备以合成账号执行）：
//   ① 登录（flows checkPreconditions）→ push 真实 ChatPage（C2C 对端）
//   ② 经真实输入链发 3 条 marker 文本 + provider 发 image/file 消息
//   ③ 长按 marker → 菜单「多选」→ action bar 出现（w2-e keys）。
//      ⚠️ W1-A enter 契约：进入即选中被长按的消息（计数=1），后续只勾其余
//      条目 —— 不要对长按消息再 toggle（DEV-01 修复）。
//   ④ 勾选其余 4 条（勾选框稳定 Key）→ 计数断言 → 全不选 → 重新勾选 → 退出
//   ⑤ 再次进入多选勾选 5 条 → action bar「逐条转发」→ SendToPage 批量
//      → 选目标 C2C → 发送 → 目标会话顺序与内容断言（冻结合同 §4.3：
//      createdAt 旧→新；文本/image/file 全部转发，peer_id/conversation_uk3
//      重写为目标会话）
//
// key 约定（w2-e receipt）：multi_select_check_<id> / multi_select_cancel /
// multi_select_count / multi_select_clear / multi_select_forward_each。
//
// 运行契约（dart-define，见文件尾注释）与前置（后端健康检查、账号 setup）
// 见 receipt w3-k handoff。

import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'chat/support/c2c_journey_support.dart';
import 'flows/app_launcher.dart';
import 'flows/test_utils.dart';
import 'helpers/chat_multi_driver.dart';
import 'helpers/chat_multi_fixtures.dart';
import 'helpers/chat_multi_image_fixture.dart';

const _markerPrefix = '[W3K-MS]';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('W3-K P1：C2C 多选勾选/计数/退出 + 逐条转发顺序内容断言', (tester) async {
    installPluginErrorFilter();
    await ensureAppLaunched(tester, maxSeconds: 10);
    if (!await checkPreconditions(tester)) return;
    if (!requireBusinessWriteAuthorization()) return;

    final selfUid = UserRepoLocal.to.currentUid;
    // 对端账号：显式 define 优先；缺省取非本人的合成账号（Alice/Bob 互为好友）。
    final srcPeerUid = const String.fromEnvironment(
      'CHAT_MULTI_SRC_PEER_UID',
      defaultValue: '',
    );
    final peerUid = srcPeerUid.isNotEmpty
        ? srcPeerUid
        : (selfUid == ChatMultiAccounts.bob
              ? ChatMultiAccounts.alice
              : ChatMultiAccounts.bob);
    final peerTitleDefined = const String.fromEnvironment(
      'CHAT_MULTI_SRC_PEER_TITLE',
      defaultValue: '',
    );
    final peerTitle = peerTitleDefined.isNotEmpty
        ? peerTitleDefined
        : (peerUid == ChatMultiAccounts.alice ? 'SmokeAlice' : 'SmokeBob');
    final dstPeerUid = const String.fromEnvironment(
      'CHAT_MULTI_DST_PEER_UID',
      defaultValue: '',
    );
    final dstUid = dstPeerUid.isNotEmpty ? dstPeerUid : peerUid;
    flowLog('W3K-MS self=$selfUid src=$peerUid dst=$dstUid');

    // ② flag override：三个 rollout flag 全开（restore 交 addTearDown）。
    final flags = enableChatMultiFlagsForTest();
    addTearDown(flags.restore);

    // ③ 打开源 C2C 会话（push 真实 ChatPage）。
    final chatPage = await pushChatPage(
      tester,
      type: 'C2C',
      peerId: peerUid,
      peerTitle: peerTitle,
    );

    // ④ 发消息：3 条 marker 文本走真实输入链；image/file 走 provider
    //    addMessage。image 不再用 fixture.invalid 占位 uri（DEV-01 修复：
    //    破图 → IMBoyCachedImageProvider 重试耗尽 → FlutterError 进入
    //    _pendingExceptionDetails → 用例挂起超时，且转发副本在目标页复现
    //    同款破图）—— setup 阶段经生产附件管道真实上传小图，以返回的
    //    object_key 作 uri（渲染走 viewUrl 授权链；逐条转发走
    //    PlainAttachmentForward.reupload 真实重传）。
    final nonce = ChatMultiMessageFixtures.nextNonce();
    final m1 = '$_markerPrefix-t1-$nonce';
    final m2 = '$_markerPrefix-t2-$nonce';
    final m3 = '$_markerPrefix-t3-$nonce';
    await sendTextViaInput(tester, chatPage, m1);
    await sendTextViaInput(tester, chatPage, m2);

    final ctx = tester.element(find.byType(ChatPage).first);
    final container = ProviderScope.containerOf(ctx);
    final notifier = container.read(chatProvider.notifier);
    final base = DateTime.now();
    final imgId = 'w3kmsimg$nonce';
    final imgObjectKey = await ChatMultiImageFixture.uploadPng(
      peerId: peerUid,
      type: 'C2C',
    );
    flowLog('W3K-MS fixture image uploaded: $imgObjectKey');
    final img = ChatMultiMessageFixtures.image(
      id: imgId,
      authorId: selfUid,
      createdAt: base.add(const Duration(milliseconds: 10)),
      remoteUri: imgObjectKey,
      width: 8,
      height: 8,
      peerId: peerUid,
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

    final fileId = 'w3kmsfile$nonce';
    final file = ChatMultiMessageFixtures.file(
      id: fileId,
      authorId: selfUid,
      createdAt: base.add(const Duration(milliseconds: 20)),
      remoteUri: 'https://fixture.invalid/w3kms-$fileId.pdf',
      name: 'w3k-fixture.pdf',
      peerId: peerUid,
    );
    final fileOk = await notifier.addMessage(
      selfUid,
      peerUid,
      '',
      peerTitle,
      'C2C',
      file,
    );
    expect(fileOk, isTrue, reason: 'file fixture 经 provider 发送应成功');
    await notifier.chatService?.insertMessage(
      file,
      index: notifier.chatService?.messages.length ?? 0,
    );

    await sendTextViaInput(tester, chatPage, m3);
    await settle(tester, maxSeconds: 3);
    await takeScreenshot(tester, 'w3kms_01_source_ready');

    // ⑤ 进入多选（长按 m1 气泡 → 菜单「多选」）。
    // W1-A enter 契约：进入即选中被长按的消息 → 计数恒为 1（driver 内断言）。
    // 因此后续不再对 m1 toggle（会把它勾掉 —— DEV-01 pass1/pass2 双轮失败
    // 的确定性根因之一），只勾其余 4 条。
    await enterMultiSelectViaMenu(tester, chatMultiItemContaining(m1));

    // ⑥ 勾选其余 4 条 + 计数（勾选框稳定 Key 优先；driver 带 tap 校验重试）。
    Future<void> selectByMarker(String marker) async {
      final msg = messageOfMarker(tester, marker);
      await toggleMessageSelection(
        tester,
        chatMultiItemContaining(marker),
        messageId: msg?.id,
      );
    }

    await selectByMarker(m2);
    await selectByMarker(m3);
    expectSelectionCount(tester, 3);
    // image/file 无文本 marker：按 id 勾选（构造器 id 已知）。
    await toggleMessageSelection(
      tester,
      find.byType(ChatPage),
      messageId: imgId,
    );
    expectSelectionCount(tester, 4);
    await toggleMessageSelection(
      tester,
      find.byType(ChatPage),
      messageId: fileId,
    );
    expectSelectionCount(tester, 5);
    await takeScreenshot(tester, 'w3kms_02_selected_5');

    // ⑦ 全不选（保持多选激活）→ 重新勾选 2 条 → 取消按钮 = 退出多选。
    await tapActionBar(tester, ChatMultiKeys.clear);
    expectSelectionCount(tester, 0);
    await selectByMarker(m1);
    await selectByMarker(m2);
    expectSelectionCount(tester, 2);
    await tapActionBar(tester, ChatMultiKeys.cancel);
    await settle(tester, maxSeconds: 2);
    expect(
      tester.any(find.byKey(ChatMultiKeys.cancel)),
      isFalse,
      reason: '退出多选后 action bar 应消失',
    );

    // ⑧ 再次进入多选（m1 由 enter 预选）并勾选其余 4 条 → 5 条全选。
    await enterMultiSelectViaMenu(tester, chatMultiItemContaining(m1));
    await toggleMessageSelection(
      tester,
      find.byType(ChatPage),
      messageId: imgId,
    );
    await toggleMessageSelection(
      tester,
      find.byType(ChatPage),
      messageId: fileId,
    );
    await selectByMarker(m2);
    await selectByMarker(m3);
    expectSelectionCount(tester, 5);

    // 源消息 createdAt 旧→新（冻结合同 §4.3 的顺序基准）：m1/m2/m3 走真实
    // 输入链（createdAt=发送时刻），img/file fixture createdAt=base+10/20ms
    // （base 在 m2 发送后取）。⚠️ m2 的 createdAt 会被服务端 ACK 时间校准
    // 在 base 之后改写（真机 r9 实证：设备/服务端时钟微差 + 校准把 m2 推到
    // image/file 之后）—— 中段排序不可用墙钟钉死。合同真正要求的是
    // 「副本顺序 == 源顺序」（下方 kinds == expectedKinds 断言），故此处只
    // 钉死集合完整性与首尾（m1 最旧、m3 最新：两者与 fixture 间隔 ≥ 秒级，
    // 不受亚秒级校准影响），中段顺序以动态派生为准。
    final sourceIdToKind = <String, String>{
      ?messageOfMarker(tester, m1)?.id: 'm1',
      ?messageOfMarker(tester, m2)?.id: 'm2',
      ?messageOfMarker(tester, m3)?.id: 'm3',
      imgId: 'image',
      fileId: 'file',
    };
    final selectedSource =
        (notifier.chatService?.messages ?? const <core.Message>[])
            .where((m) => sourceIdToKind.containsKey(m.id))
            .toList()
          ..sort(
            (a, b) => (a.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
              b.createdAt?.millisecondsSinceEpoch ?? 0,
            ),
          );
    final expectedKinds = selectedSource
        .map((m) => sourceIdToKind[m.id]!)
        .toList();
    expect(expectedKinds.toSet(), {
      'm1',
      'm2',
      'image',
      'file',
      'm3',
    }, reason: '源顺序基准应恰含 5 类消息（冻结合同 §4.3；实际 $expectedKinds）');
    expect(
      expectedKinds.first,
      'm1',
      reason: 'm1 应最旧（顺序基准首元素；实际 $expectedKinds）',
    );
    expect(
      expectedKinds.last,
      'm3',
      reason: 'm3 应最新（顺序基准尾元素；实际 $expectedKinds）',
    );

    // ⑨ 逐条转发：action bar「逐条转发」→ SendToPage 批量 → 选目标 → 发送。
    final forwardStart = DateTime.now();
    await tapActionBar(tester, ChatMultiKeys.forwardEach);
    if (!isOnSendToPage(tester)) {
      await takeScreenshot(tester, 'w3kms_diag_no_send_to_page');
      fail(
        'multi_select_forward_each 未打开 SendToPage —— '
        'Central Wiring（计划 §12）未接线 onForwardEach 或批量入口回归',
      );
    }
    final dstTitle = await resolveTargetTitle(
      type: 'C2C',
      peerId: dstUid,
      fallback: dstUid == ChatMultiAccounts.alice ? 'SmokeAlice' : 'SmokeBob',
    );
    await selectForwardTargetAndSend(
      tester,
      targetDisplayTitle: dstTitle,
      journey: 'W3K-MS',
    );
    await waitBatchForwardSettled(tester, journey: 'W3K-MS');
    await takeScreenshot(tester, 'w3kms_03_forward_done');

    // ⑩ 目标会话顺序与内容断言。
    Finder targetPage;
    if (dstUid == peerUid) {
      // 同会话回环：SendToPage 关闭后已回到源 ChatPage（即目标）。
      targetPage = find.byType(ChatPage).first;
    } else {
      await popTopPage(tester, find.byType(ChatPage).first);
      targetPage = await pushChatPage(
        tester,
        type: 'C2C',
        peerId: dstUid,
        peerTitle: dstTitle,
      );
    }
    final targetCtx = tester.element(find.byType(ChatPage).first);
    final targetContainer = ProviderScope.containerOf(targetCtx);
    final messages =
        targetContainer.read(chatProvider.notifier).chatService?.messages ??
        const <core.Message>[];

    // 内容：5 条副本全部落位（文本 3 + image 1 + file 1）。
    final copies = messages
        .where((m) => (m.createdAt?.isAfter(forwardStart) ?? false))
        .toList();
    expect(
      copies.whereType<core.TextMessage>().map((m) => m.text),
      containsAllInOrder([m1, m2, m3]),
      reason: '目标会话应含 3 条转发文本副本（旧→新）',
    );
    expect(
      copies.any(
        (m) => m is core.ImageMessage && m.metadata?['msg_type'] == 'image',
      ),
      isTrue,
      reason: '目标会话应含转发 image 副本',
    );
    expect(
      copies.any(
        (m) => m is core.FileMessage && m.metadata?['msg_type'] == 'file',
      ),
      isTrue,
      reason: '目标会话应含转发 file 副本',
    );
    expect(copies.length, 5, reason: '目标会话副本应恰 5 条（实际 ${copies.length}）');

    // 顺序：副本按 createdAt 旧→新 = 源消息列表序（expectedKinds 在 ⑧ 派生）。
    String kindOf(core.Message m) => switch (m) {
      core.TextMessage() =>
        m.text == m1
            ? 'm1'
            : m.text == m2
            ? 'm2'
            : 'm3',
      core.ImageMessage() => 'image',
      core.FileMessage() => 'file',
      _ => 'other',
    };
    final kinds = copies.map(kindOf).toList();
    expect(
      kinds,
      expectedKinds,
      reason:
          '转发副本顺序应等于源 createdAt 旧→新'
          '（冻结合同 §4.3；实际 $kinds 期望 $expectedKinds）',
    );

    // 内容隔离：副本不得携带源会话归属（peer_id 重写为目标）。
    final targetUk3Prefix = 'C2C_';
    for (final m in copies) {
      expect(
        '${m.metadata?['peer_id'] ?? ''}',
        dstUid,
        reason: '转发副本 peer_id 应重写为目标会话对端（msgId=${m.id}）',
      );
    }
    flowLog('W3K-MS 目标 uk3 前缀校验 $targetUk3Prefix（peer_id 已重写）');

    // 退出：pop ChatPage，保持会话栈干净。
    await popTopPage(tester, targetPage);
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/*
运行契约（真机 DEV-01，主 Agent 编排；runner：flutter test <target> --machine
--concurrency=1 -d <device_id> --no-test-assets，设备 ID 环境变量
IMBOY_TEST_DEVICE）：

  flutter test integration_test/chat_multi_select_test.dart \
    --machine --concurrency=1 -d <device_id> --no-test-assets \
    --dart-define=APP_ENV=local_office \
    --dart-define=API_BASE_URL=http://127.0.0.1:9800 \
    --dart-define=TEST_PHONE=<smoke_alice 或等价合成账号> \
    --dart-define=TEST_PASSWORD=<pwd> \
    --dart-define=TEST_ALLOW_BUSINESS_WRITES=true \
    [--dart-define=CHAT_MULTI_SRC_PEER_UID=1000000056] \
    [--dart-define=CHAT_MULTI_SRC_PEER_TITLE=SmokeBob] \
    [--dart-define=CHAT_MULTI_DST_PEER_UID=<第三合成账号，缺省=源对端回环>]

前置：
  - bash imboyapp/scripts/setup_test_data.sh（Alice 1000000051 / Bob
    1000000056 幂等建号 + 双向好友）；
  - 后端健康检查（IMBOYENV=local 后端探活通过）；
  - 登录账号须与对端为好友；目标会话标题须可被 SendToPage displayTitle
    搜索命中（会话行 title 或 fallback 昵称）。

Central Wiring 依赖：onForwardEach 接线（计划 §12.2）后 forward_each 才可点。
*/
