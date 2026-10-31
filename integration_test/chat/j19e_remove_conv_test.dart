// integration_test/chat/j19e_remove_conv_test.dart
//
// plan-v2.2 §9 J19.e（本机可见会话：仅从列表移除 → 只隐藏不清记录/
// 退群，复现遵既有消息合同）真机旅程：登录 demo_alice（群 5 成员）→
// 打开 J19E_REMOVE_GROUP 的 C2G（含 2 条 [J19E-SEED] 历史）→ 返回
// 会话列表 →
//   ① 侧滑该会话 → 点「删除」→ 该群会话从列表消失
//   ② 本机记录仍在：直查设备 sqlite msg_c2g，uk3=C2G_<alice>_<gid>
//      行数 >= 2（只隐藏不清记录）；不退群由 SQL 复核（member/世代）
//   ③ 复现：宿主经服务端注入 bob 新消息 [J19E-REAPPEAR]（WS 推送 →
//      会话行 is_show=1 合同）→ 轮询该会话重新出现在列表 → 打开聊天
//      页：[J19E-SEED] 历史仍在 + [J19E-REAPPEAR] 新消息已收
//
// 宿主握手：脚本打印「J19E removed; awaiting host injection」后，主
// 集成者在 /tmp/j19e_r1.log 观察到该行即执行 /tmp/j19de_reappear.erl。
//
// fixture（已落合成库）：group 120619900000000005 'J19E_REMOVE_GROUP'
// （alice role=4 群主 + bob/carol role=1 + 世代行 start_seq=1 + 2 条
// bob 发送的 [J19E-SEED] 种子消息）。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _groupId = String.fromEnvironment('TEST_GROUP_ID');
const _groupTitle = String.fromEnvironment('TEST_GROUP_TITLE');

const _seedMarker = '[J19E-SEED]';
const _reappearMarker = '[J19E-REAPPEAR]';
const _deleteLabel = '删除';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J19.e 从列表移除：只隐藏不清记录；新消息遵既有合同复现', (tester) async {
    if (_expectedUid.isEmpty || _groupId.isEmpty || _groupTitle.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID、TEST_GROUP_ID、TEST_GROUP_TITLE');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J19.e 前置失败：登录未进入主界面');
    }
    if (UserRepoLocal.to.currentUid != _expectedUid) {
      fail('登录账号 UID=${UserRepoLocal.to.currentUid} 与授权操作者 $_expectedUid 不一致');
    }
    await settle(tester, maxSeconds: 2);
    await dismissRecoveryGuide(tester);
    await settle(tester, maxSeconds: 2);

    // 会话列表 → 目标群 C2G（含种子历史）。
    if (!await openConversationTab(tester)) {
      fail('无法进入会话列表');
    }
    await settle(tester, maxSeconds: 2);
    final groupItem = find.byWidgetPredicate(
      (widget) =>
          widget is ConversationItem &&
          widget.model.type == 'C2G' &&
          widget.model.peerId.toString() == _groupId,
    );
    var itemSeen = false;
    for (var i = 0; i < 20 && !itemSeen; i++) {
      itemSeen = tester.any(groupItem);
      if (!itemSeen) await settle(tester, maxSeconds: 1);
    }
    if (!itemSeen) {
      fail('会话列表中无目标群 $_groupTitle (gid=$_groupId) 的 C2G 会话（fixture 缺失？）');
    }
    await safeTap(tester, groupItem.first);
    await settle(tester, maxSeconds: 3);
    final chatPage = find.byType(ChatPage);
    expect(chatPage, findsOneWidget, reason: '应进入群聊页');
    expect(tester.widget<ChatPage>(chatPage).peerId, _groupId);
    expect(
      find.textContaining(_seedMarker, findRichText: true),
      findsAtLeastNWidgets(2),
      reason: '聊天页应展示 2 条 [J19E-SEED] 本机历史',
    );

    // 返回会话列表。
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
    var backToList = false;
    for (var i = 0; i < 20 && !backToList; i++) {
      backToList = !tester.any(find.byType(ChatPage));
      if (!backToList) await settle(tester, maxSeconds: 1);
    }
    expect(backToList, isTrue, reason: '应返回会话列表');
    itemSeen = false;
    for (var i = 0; i < 20 && !itemSeen; i++) {
      itemSeen = tester.any(groupItem);
      if (!itemSeen) await settle(tester, maxSeconds: 1);
    }
    expect(itemSeen, isTrue, reason: '移除前该群会话应可见');

    // ① 侧滑 → 「删除」→ 会话从列表消失。
    await tester.drag(groupItem.first, const Offset(-300, 0));
    await settle(tester, maxSeconds: 2);
    final deleteAction = find.text(_deleteLabel);
    expect(deleteAction, findsWidgets, reason: '侧滑后应出现「删除」操作');
    await safeTap(tester, deleteAction.first);
    var gone = false;
    for (var i = 0; i < 30 && !gone; i++) {
      gone = !tester.any(groupItem);
      if (!gone) await settle(tester, maxSeconds: 1);
    }
    await takeScreenshot(tester, 'j19e_01_removed_from_list');
    expect(gone, isTrue, reason: '删除后该群会话应从列表消失');

    // ② 只隐藏不清记录：设备 sqlite 该会话消息行数 >= 2。
    final uk3 = ConversationUk3Generator.generateSmart(
      type: 'C2G',
      currentUserId: _expectedUid,
      peerId: _groupId,
    );
    final db = await SqliteService.to.db;
    final tb = MessageRepo.getTableName('C2G');
    final rows = await db!.query(
      tb,
      columns: [MessageRepo.id],
      where: '${MessageRepo.conversationUk3} = ?',
      whereArgs: [uk3],
    );
    debugPrint('J19E removed; local msg rows for $uk3 = ${rows.length}');
    expect(
      rows.length,
      greaterThanOrEqualTo(2),
      reason: '从列表移除只隐藏会话，不得清除本机消息记录（实际 ${rows.length} 行）',
    );

    // 会话行诊断：该 peer 的全部行（不限 is_show），隐藏后应恰 1 行且
    // is_show=0（多行=type/peer 表示漂移，单行 is_show=1=隐藏未落库）。
    Future<List<Map<String, Object?>>> convRows() => db.query(
      'conversation',
      columns: ['id', 'type', 'peer_id', 'is_show', 'user_id'],
      where: 'CAST(peer_id AS TEXT) = ?',
      whereArgs: [_groupId],
    );
    var afterHide = await convRows();
    debugPrint('J19E conv rows after hide=$afterHide');
    expect(
      afterHide.where((r) => r['is_show'] == 1),
      isEmpty,
      reason: '删除后该 peer 的会话行不得仍有 is_show=1（实际 $afterHide）',
    );

    // 隐藏稳定性窗口（30s，无注入）：会话必须保持隐藏。若此窗口内自行
    // 回弹，即为「删除回弹」竞态（复现非消息驱动），如实判负并留诊断。
    var flapped = false;
    for (var i = 0; i < 30; i++) {
      if (tester.any(groupItem)) {
        flapped = true;
        final flapRows = await convRows();
        debugPrint(
          'J19E FLAP at stability[$i]: item visible without injection; '
          'conv rows=$flapRows',
        );
        break;
      }
      await settle(tester, maxSeconds: 1);
    }
    await takeScreenshot(tester, 'j19e_01b_hidden_stable');
    expect(flapped, isFalse, reason: '隐藏稳定性窗口内会话不得自行回弹（复现必须由新消息驱动）');

    debugPrint('J19E removed; awaiting host injection');

    // ③ 复现：等宿主注入 bob 新消息 → 会话按既有合同重新出现。
    var reappeared = false;
    for (var i = 0; i < 150 && !reappeared; i++) {
      reappeared = tester.any(groupItem);
      if (!reappeared) await settle(tester, maxSeconds: 1);
    }
    if (reappeared) {
      final atReappear = await convRows();
      debugPrint('J19E reappeared on injection; conv rows=$atReappear');
    }
    await takeScreenshot(tester, 'j19e_02_reappeared');
    expect(reappeared, isTrue, reason: '群新消息到达后应按既有消息合同重新出现（150s 内）');

    // 复现后打开聊天页：历史仍在 + 新消息已收（不清记录的 UI 证据）。
    await safeTap(tester, groupItem.first);
    await settle(tester, maxSeconds: 3);
    expect(find.byType(ChatPage), findsOneWidget, reason: '复现后应可进入聊天页');
    var newMsgSeen = false;
    for (var i = 0; i < 30 && !newMsgSeen; i++) {
      newMsgSeen = tester.any(
        find.textContaining(_reappearMarker, findRichText: true),
      );
      if (!newMsgSeen) await settle(tester, maxSeconds: 1);
    }
    expect(newMsgSeen, isTrue, reason: '聊天页应展示新到达的 [J19E-REAPPEAR] 消息');
    expect(
      find.textContaining(_seedMarker, findRichText: true),
      findsAtLeastNWidgets(2),
      reason: '复现后历史 [J19E-SEED] 不得丢失（移除不清记录）',
    );
    await takeScreenshot(tester, 'j19e_03_history_intact');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 12)));
}
