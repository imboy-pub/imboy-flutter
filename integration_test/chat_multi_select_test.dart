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

import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:imboy/modules/messaging/domain/selection/message_selection.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'chat/support/c2c_journey_support.dart';
import 'flows/app_launcher.dart';
import 'flows/test_utils.dart';
import 'helpers/chat_multi_driver.dart';
import 'helpers/chat_multi_fixtures.dart';
import 'helpers/chat_multi_image_fixture.dart';

const _markerPrefix = '[W3K-MS]';

const _ownedStorageTag = String.fromEnvironment('UX_STORAGE_TAG');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('W3-K P1：C2C 多选勾选/计数/退出 + 逐条转发顺序内容断言', (tester) async {
    installPluginErrorFilter();
    ChatMultiDriverRunStats.reset();
    if (_ownedStorageTag.isNotEmpty) {
      const expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
      const viewerUid = String.fromEnvironment('PEER_UID');
      expect(viewerUid, matches(RegExp(r'^[1-9][0-9]{0,19}$')));
      expect(viewerUid, isNot(expectedUid));
      expect(
        const String.fromEnvironment('CHAT_MULTI_SRC_PEER_UID'),
        viewerUid,
      );
      expect(
        const String.fromEnvironment('CHAT_MULTI_DST_PEER_UID'),
        viewerUid,
      );
      expect(
        const String.fromEnvironment('CHAT_MULTI_SRC_PEER_TITLE'),
        isNotEmpty,
      );
      await restoreOwnedChat(tester, _ownedStorageTag, expectedUid);
    } else {
      await ensureAppLaunched(tester, maxSeconds: 10);
    }
    // G6-11：后端探活/登录失败 = 环境契约破坏，fail 而非静默 SKIP。
    if (!await checkPreconditions(tester, failOnEnvMissing: true)) return;
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

    // ② 连续两次真实刷新，服务端必须明确开启三个 rollout flag。
    await requireChatMultiServerFlags();

    // ③ 打开源 C2C 会话（push 真实 ChatPage）。
    final chatPage = await pushChatPage(
      tester,
      type: 'C2C',
      peerId: peerUid,
      peerTitle: peerTitle,
    );

    // ④ 发消息：3 条 marker 文本走真实输入链；image/file 走 provider
    //    addMessage。image/file 均不再用 fixture.invalid 占位 uri（DEV-01
    //    修复 + G6-6）：setup 阶段经生产附件管道真实上传小图/小文本文件，
    //    以返回的 object_key 作 uri —— 渲染走 viewUrl 授权链；逐条转发走
    //    PlainAttachmentForward.reupload 真实重传（http 占位 uri 会被
    //    _objectKeyOf 判 null → 不重传 → 死 uri 落库）。metadata 带
    //    w3k_run_nonce=nonce（G6-1：副本识别走内容过滤，不依赖墙钟）。
    final nonce = ChatMultiMessageFixtures.nextNonce();
    // nonce 的字符串形态（G6-1 内容过滤 / w3k_run_nonce 均按字符串对账）。
    final nonceStr = '$nonce';
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
      size: ChatMultiImageFixture.pngBytes.length,
      peerId: peerUid,
      runNonce: nonceStr,
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

    // G6-6：file fixture 真实化 —— 小文本文件经生产管道上传（text/plain
    // 在服务端白名单内），源消息 size=真实字节数（副本 size 断言基准）。
    final fileId = 'w3kmsfile$nonce';
    final fileName = 'w3kms-file-$nonce.txt';
    final fileObjectKey = await ChatMultiImageFixture.uploadTextFile(
      fileName: fileName,
      peerId: peerUid,
      type: 'C2C',
    );
    flowLog('W3K-MS fixture file uploaded: $fileObjectKey');
    final file = ChatMultiMessageFixtures.file(
      id: fileId,
      authorId: selfUid,
      createdAt: base.add(const Duration(milliseconds: 20)),
      remoteUri: fileObjectKey,
      name: fileName,
      size: ChatMultiImageFixture.textBytes.length,
      peerId: peerUid,
      runNonce: nonceStr,
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

    // G6-9：断言期不再从 widget 树回读 id（列表虚拟化未构建的行会静默丢
    // key）—— 发送后立即从 provider 数据源（chatService.messages）按文本
    // 解析缓存，后续勾选/顺序基准一律用缓存 id。
    String? idOfMarker(String marker) {
      for (final msg
          in notifier.chatService?.messages ?? const <core.Message>[]) {
        if (msg is core.TextMessage && msg.text.contains(marker)) return msg.id;
      }
      return null;
    }

    final m1Id = idOfMarker(m1);
    final m2Id = idOfMarker(m2);
    final m3Id = idOfMarker(m3);
    expect(m1Id, isNotNull, reason: '发送后应能从 provider 数据源解析 m1 id');
    expect(m2Id, isNotNull, reason: '发送后应能从 provider 数据源解析 m2 id');
    expect(m3Id, isNotNull, reason: '发送后应能从 provider 数据源解析 m3 id');
    await takeScreenshot(tester, 'w3kms_01_source_ready');

    // ⑤ 进入多选（长按 m1 气泡 → 菜单「多选」）。
    // W1-A enter 契约：进入即选中被长按的消息 → 计数恒为 1（driver 内断言）。
    // 因此后续不再对 m1 toggle（会把它勾掉 —— DEV-01 pass1/pass2 双轮失败
    // 的确定性根因之一），只勾其余 4 条。
    await enterMultiSelectViaMenu(tester, chatMultiItemContaining(m1));

    // ⑥ 勾选其余 4 条 + 计数（勾选框稳定 Key 优先；driver 带 tap 校验重试）。
    Future<void> selectByMarker(String marker, String? cachedId) async {
      await toggleMessageSelection(
        tester,
        chatMultiItemContaining(marker),
        messageId: cachedId,
        journey: 'W3K-MS',
      );
    }

    await selectByMarker(m2, m2Id);
    await selectByMarker(m3, m3Id);
    expectSelectionCount(tester, 3);
    // image/file 无文本 marker：按 id 勾选（构造器 id 已知）。
    await toggleMessageSelection(
      tester,
      find.byType(ChatPage),
      messageId: imgId,
      journey: 'W3K-MS',
    );
    expectSelectionCount(tester, 4);
    await toggleMessageSelection(
      tester,
      find.byType(ChatPage),
      messageId: fileId,
      journey: 'W3K-MS',
    );
    expectSelectionCount(tester, 5);
    await takeScreenshot(tester, 'w3kms_02_selected_5');

    // ⑦ 全不选（保持多选激活）→ 重新勾选 2 条 → 取消按钮 = 退出多选。
    // G6-3：action bar tap 统一 tapViaNewGesture + 效果校验重试。
    await tapActionBar(
      tester,
      ChatMultiKeys.clear,
      journey: 'W3K-MS',
      effectCheck: () => actionBarSelectedCount(tester) == 0,
    );
    expectSelectionCount(tester, 0);
    await selectByMarker(m1, m1Id);
    await selectByMarker(m2, m2Id);
    expectSelectionCount(tester, 2);
    await tapActionBar(
      tester,
      ChatMultiKeys.cancel,
      journey: 'W3K-MS',
      effectCheck: () => !tester.any(find.byKey(ChatMultiKeys.cancel)),
    );
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
      journey: 'W3K-MS',
    );
    await toggleMessageSelection(
      tester,
      find.byType(ChatPage),
      messageId: fileId,
      journey: 'W3K-MS',
    );
    await selectByMarker(m2, m2Id);
    await selectByMarker(m3, m3Id);
    expectSelectionCount(tester, 5);

    // 源消息 createdAt 旧→新（冻结合同 §4.3 的顺序基准）：m1/m2/m3 走真实
    // 输入链（createdAt=发送时刻），img/file fixture createdAt=base+10/20ms
    // （base 在 m2 发送后取）。⚠️ m2 的 createdAt 会被服务端 ACK 时间校准
    // 在 base 之后改写（真机 r9 实证：设备/服务端时钟微差 + 校准把 m2 推到
    // image/file 之后）—— 中段排序不可用墙钟钉死。合同真正要求的是
    // 「副本顺序 == 源顺序」（下方 kinds == expectedKinds 断言），故此处只
    // 钉死集合完整性与首尾（m1 最旧、m3 最新：两者与 fixture 间隔 ≥ 秒级，
    // 不受亚秒级校准影响），中段顺序以动态派生为准。
    // id 取自 ④ 末尾的 provider 数据源缓存（G6-9）。
    final sourceIdToKind = <String, String>{
      ?m1Id: 'm1',
      ?m2Id: 'm2',
      ?m3Id: 'm3',
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

    // 先验证弹层两种返回方式不改变选区，也不创建目标消息。
    final sourceConversation = await ConversationRepo().findByPeerId(
      'C2C',
      peerUid,
    );
    expect(sourceConversation, isNotNull);
    final selectionProvider = messageSelectionProvider(sourceConversation!.uk3);
    final selectionBeforeDismiss = container.read(selectionProvider);
    final targetRepo = MessageRepo(tableName: MessageRepo.c2cTable);
    final targetCountBeforeDismiss = await targetRepo.countMessagesWithUser(
      dstUid,
    );
    const forwardCancel = ValueKey('multi_select_forward_cancel');
    for (final systemBack in [false, true]) {
      await tapActionBar(
        tester,
        ChatMultiKeys.forward,
        journey: 'W3K-MS-dismiss',
        effectCheck: () => tester.any(find.byKey(forwardCancel)),
      );
      if (systemBack) {
        await tester.binding.handlePopRoute();
        await settle(tester, maxSeconds: 2);
      } else {
        await tapActionBar(
          tester,
          forwardCancel,
          journey: 'W3K-MS-dismiss',
          effectCheck: () => !tester.any(find.byKey(forwardCancel)),
        );
      }
      expect(find.byKey(forwardCancel), findsNothing);
      expect(isOnSendToPage(tester), isFalse, reason: '返回弹层不得打开目标选择页');
      expect(
        container.read(selectionProvider),
        selectionBeforeDismiss,
        reason: '返回弹层必须保留激活状态与全部已选消息 ID',
      );
      expectSelectionCount(tester, 5);
      expect(
        await targetRepo.countMessagesWithUser(dstUid),
        targetCountBeforeDismiss,
        reason: '返回弹层不得创建目标会话消息',
      );
    }

    // ⑨ 逐条转发：action bar「逐条转发」→ SendToPage 批量 → 选目标 → 发送。
    await tapActionBar(
      tester,
      ChatMultiKeys.forward,
      journey: 'forward-options',
      effectCheck: () => tester.any(find.byKey(ChatMultiKeys.forwardEach)),
    );
    await tapActionBar(
      tester,
      ChatMultiKeys.forwardEach,
      journey: 'W3K-MS',
      effectCheck: () => isOnSendToPage(tester),
    );
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

    // 内容：5 条副本全部落位（文本 3 + image 1 + file 1）。
    // ⚠️ 副本落位是异步的：批量发送 → 本地 DB 插入 → 事件 → in-memory 列表
    // 有秒级延迟（真机 r11 实证：后端 3 条文本副本 server_ts 14:17:23-33
    // 已全部落库，而 SendToPage 关闭后 ~3.5s 内存列表仍为空）。轮询等待
    // 落位（与 c2g 用例同款策略），不要读一次就断言。
    //
    // G6-1：副本识别改 nonce 内容过滤 —— 文本副本 text 含本轮 nonce；
    // image/file 副本 metadata['w3k_run_nonce'] == nonce（buildForwardPayload
    // 的 `{...?sourceMetadata}` 原样保留，reupload 只重写 uri/size/
    // file_hash256，故不能按源 uri 过滤）。回环配置下源消息也在同一列表，
    // 以 sourceIds 显式排除（副本 id 为全新 Xid，不与源碰撞）。
    final sourceIds = <String>{?m1Id, ?m2Id, ?m3Id, imgId, fileId};
    bool isThisRunCopy(core.Message m) {
      if (sourceIds.contains(m.id)) return false;
      if (m is core.TextMessage) return m.text.contains(nonceStr);
      return '${m.metadata?['w3k_run_nonce'] ?? ''}' == nonceStr;
    }

    List<core.Message> readCopies() =>
        (targetContainer.read(chatProvider.notifier).chatService?.messages ??
                const <core.Message>[])
            .where(isThisRunCopy)
            .toList();
    var copies = readCopies();
    for (var i = 0; i < 20 && copies.length < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
      copies = readCopies();
    }
    flowLog('W3K-MS 目标副本落位: ${copies.length}/5');
    // chatService.messages 存储序为「新→旧」（reverse 列表 index 0=最新）；
    // 合同 §4.3 考察副本 createdAt 旧→新，排序后再断言（DEV-01 真机 r1：
    // 原始序 [m3..m1]，派发序与 createdAt 序均正确）。
    List<core.Message> orderedCopies() => copies.toList()
      ..sort(
        (a, b) => (a.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
          b.createdAt?.millisecondsSinceEpoch ?? 0,
        ),
      );
    expect(
      orderedCopies().whereType<core.TextMessage>().map((m) => m.text),
      containsAllInOrder([m1, m2, m3]),
      reason: '目标会话应含 3 条转发文本副本（旧→新）',
    );
    final imageCopies = copies.whereType<core.ImageMessage>().toList();
    expect(imageCopies, isNotEmpty, reason: '目标会话应含转发 image 副本');
    final fileCopies = copies.whereType<core.FileMessage>().toList();
    expect(fileCopies, isNotEmpty, reason: '目标会话应含转发 file 副本');
    expect(copies.length, 5, reason: '目标会话副本应恰 5 条（实际 ${copies.length}）');

    // G6-6：副本内容真实对账 —— image 副本 uri 必须是目标 scope 重传后的
    // **新** objectKey（≠源 uri，证明确实走了 PlainAttachmentForward.reupload
    // 而非死 uri 原样复制）；file 副本 name/size 与源一致（重传只换 uri，
    // 展示字段原样保留）。
    expect(
      imageCopies.first.metadata?['uri'] == imgObjectKey,
      isFalse,
      reason:
          'image 副本 uri 应为新 objectKey（≠源 uri ${imgObjectKey.length}字符；'
          '相等 = 未重传，死 uri 复制）',
    );
    expect(
      fileCopies.first.name,
      fileName,
      reason: 'file 副本 name 应与源一致（msgId=${fileCopies.first.id}）',
    );
    expect(
      fileCopies.first.size,
      ChatMultiImageFixture.textBytes.length,
      reason: 'file 副本 size 应与源字节数一致（msgId=${fileCopies.first.id}）',
    );

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
    final kinds = orderedCopies().map(kindOf).toList();
    expect(
      kinds,
      expectedKinds,
      reason:
          '转发副本顺序应等于源 createdAt 旧→新'
          '（冻结合同 §4.3；实际 $kinds 期望 $expectedKinds）',
    );

    // 内容隔离（G6-5）：副本不得携带源会话归属。真第三账号（dstUid != 源
    // 对端）时经 repo 真值断言副本行 conversation_uk3 == 目标会话 uk3 +
    // peer_id 重写；回环配置（dst=源对端）下这两条断言恒真（副本归属与源
    // 相同），显式记录覆盖缺口，不做空断言 —— 激活隔离断言需
    // CHAT_MULTI_DST_PEER_UID 指向第三合成账号。
    if (dstUid == peerUid) {
      flowLog(
        'LOOPBACK: W3K-MS isolation assertions skipped'
        '（dst=源对端回环：peer_id/uk3 隔离断言恒真；'
        '覆盖缺口 —— 以 CHAT_MULTI_DST_PEER_UID=<第三合成账号> 运行可激活）',
      );
    } else {
      final targetConversation = await ConversationRepo().findByPeerId(
        'C2C',
        dstUid,
      );
      expect(targetConversation, isNotNull, reason: '目标会话行应已建立（转发落库后）');
      final targetUk3 = targetConversation!.uk3;
      final msgRepo = MessageRepo(tableName: MessageRepo.c2cTable);
      for (final m in orderedCopies()) {
        expect(
          '${m.metadata?['peer_id'] ?? ''}',
          dstUid,
          reason: '转发副本 peer_id 应重写为目标会话对端（msgId=${m.id}）',
        );
        final row = await msgRepo.find(m.id);
        expect(row, isNotNull, reason: '副本行应可经 MessageRepo 读到（msgId=${m.id}）');
        expect(
          row!.conversationUk3,
          targetUk3,
          reason: '副本行 conversation_uk3 应为目标会话 $targetUk3（msgId=${m.id}）',
        );
      }
      flowLog('W3K-MS 隔离断言通过: 副本行 conversation_uk3 == $targetUk3');
    }

    // 退出：pop ChatPage，保持会话栈干净；通道终局对账（G6-2）。
    await popTopPage(tester, targetPage);
    finishChatMultiJourney('W3K-MS');
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
